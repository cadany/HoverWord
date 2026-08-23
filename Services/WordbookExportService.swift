import Foundation
import CoreData

/// TXT 词库导出服务
///
/// 与 WordbookImportService 的导入格式完全对称：
/// - 每行一个词条，Tab 分隔 8 字段（源词条/注音/词性1/释义1/词性2/释义2/词性3/释义3）
/// - 空字段输出空字符串，换行 `\n`，UTF-8 无 BOM（导入 parse 不剥离 BOM，加了会污染首行）
/// - 普通单词本按导入顺序（orderIndex 升序）导出
/// - 系统收藏夹按收藏时间（collectedAt 升序）从 wordDetail 快照导出
///
/// 导出文件可直接经现有导入功能无损还原（round-trip）。
class WordbookExportService {

    // MARK: - 错误类型

    /// 导出错误
    enum ExportError: LocalizedError {
        /// 目标单词本不存在（可能已被删除）
        case wordbookMissing

        var errorDescription: String? {
            switch self {
            case .wordbookMissing:
                return L10n.t("wordbook.error.notFound")
            }
        }
    }

    // MARK: - 公开接口

    /// 导出指定单词本的全部词条为 TXT 数据
    ///
    /// 在后台上下文取数与序列化，不阻塞主线程；大词库（10000 条）毫秒级完成。
    ///
    /// - Parameter wordbookId: 目标单词本 ID
    /// - Returns: UTF-8 编码（无 BOM）的 TXT 文件数据；空词本返回空数据
    static func export(wordbookId: String) async throws -> Data {
        let context = DataStack.shared.newBackgroundContext()

        let lines: [String] = try await context.perform {
            // 1. 后台上下文中定位目标词本
            let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
            request.predicate = NSPredicate(format: "wordbookId == %@", wordbookId)
            request.fetchLimit = 1

            guard let wordbook = try context.fetch(request).first else {
                throw ExportError.wordbookMissing
            }

            // 2. 取数：收藏夹走快照还原，普通词本按导入顺序
            if wordbook.isSystem {
                return try exportFavorites(context: context)
            }
            return try exportRegularEntries(context: context, wordbookId: wordbookId)
        }

        guard let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8) else {
            throw ExportError.wordbookMissing
        }
        return data
    }

    /// 清洗词本名为合法文件名（macOS Finder 对 `/` 与 `:` 敏感，换行亦非法）
    static func sanitizedFileName(from name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\n\r\t")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "wordbook" : cleaned
    }

    // MARK: - 私有：序列化

    /// 普通单词本：按 orderIndex 升序导出词条
    private static func exportRegularEntries(context: NSManagedObjectContext, wordbookId: String) throws -> [String] {
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordbook.wordbookId == %@", wordbookId)
        request.sortDescriptors = [
            NSSortDescriptor(key: "orderIndex", ascending: true),
            NSSortDescriptor(key: "sourceWord", ascending: true)  // 平局兜底，与预览排序一致
        ]
        let entries = try context.fetch(request)
        return entries.map { entry in
            entryLine(
                sourceWord: entry.sourceWord ?? "",
                phonetic: entry.phonetic,
                pos1: entry.pos1,
                meaning1: entry.meaning1,
                pos2: entry.pos2,
                meaning2: entry.meaning2,
                pos3: entry.pos3,
                meaning3: entry.meaning3
            )
        }
    }

    /// 收藏夹：按 collectedAt 升序从 wordDetail 快照还原 8 字段
    ///
    /// 快照损坏（JSON 解析失败）时跳过该条并 NSLog，与 favoriteToWordEntry 行为一致
    private static func exportFavorites(context: NSManagedObjectContext) throws -> [String] {
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "collectedAt", ascending: true)]
        let favorites = try context.fetch(request)

        return favorites.compactMap { favorite in
            guard let data = favorite.wordDetail,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                NSLog("[WordbookExportService] Failed to decode wordDetail for favorite: \(favorite.sourceWord)")
                return nil
            }
            return entryLine(
                sourceWord: favorite.sourceWord,
                phonetic: json["phonetic"] as? String,
                pos1: json["pos1"] as? String,
                meaning1: json["meaning1"] as? String,
                pos2: json["pos2"] as? String,
                meaning2: json["meaning2"] as? String,
                pos3: json["pos3"] as? String,
                meaning3: json["meaning3"] as? String
            )
        }
    }

    /// 拼接单行：8 字段 Tab 分隔，nil 字段输出空字符串
    private static func entryLine(
        sourceWord: String,
        phonetic: String?,
        pos1: String?,
        meaning1: String?,
        pos2: String?,
        meaning2: String?,
        pos3: String?,
        meaning3: String?
    ) -> String {
        [
            sourceWord,
            phonetic ?? "",
            pos1 ?? "",
            meaning1 ?? "",
            pos2 ?? "",
            meaning2 ?? "",
            pos3 ?? "",
            meaning3 ?? ""
        ].joined(separator: "\t")
    }
}
