import Foundation
import CoreData

/// TXT 词库导入服务
///
/// 负责 UTF-8 .txt 文件的解析、校验与导入执行：
/// - 按行拆分、空行过滤、Tab 分隔字段解析
/// - 必填字段校验（词条 + 释义 1），错误行号精准报告
/// - 整体校验失败时返回错误不写入任何数据
/// - 校验通过后在事务内完成全量覆盖导入
///
/// 文件格式：每行一个词条，字段以 Tab 分隔，字段顺序固定：
/// 源语言词条(必填) / 注音 / 词性1 / 释义1(必填) / 词性2 / 释义2 / 词性3 / 释义3
class WordbookImportService {

    // MARK: - 错误类型

    /// 导入错误
    enum ImportError: LocalizedError {
        /// 文件编码非 UTF-8
        case invalidEncoding
        /// 格式错误，包含行号与原因
        case formatError(lineNumber: Int, reason: String)
        /// 文件为空
        case emptyFile
        /// 目标单词本不存在（导入面板打开期间被删除的竞态）
        case wordbookMissing

        var errorDescription: String? {
            switch self {
            case .invalidEncoding:
                return L10n.t("import.error.encoding")
            case .formatError(let line, let reason):
                return L10n.t("import.error.line.format", line, reason)
            case .emptyFile:
                return L10n.t("import.error.empty")
            case .wordbookMissing:
                return L10n.t("import.error.wordbookMissing")
            }
        }
    }

    // MARK: - 解析结果

    /// 单行解析结果
    struct ParsedEntry {
        let sourceWord: String
        let phonetic: String?
        let pos1: String?
        let meaning1: String
        let pos2: String?
        let meaning2: String?
        let pos3: String?
        let meaning3: String?
        /// 在原 TXT 文件中的真实行号（从 1 起计，含被跳过的空行），供预览溯源
        let lineNumber: Int
    }

    // MARK: - 公开接口

    /// 解析 TXT 文件内容，返回解析后的词条数组或错误
    ///
    /// - Parameter data: 文件原始数据
    /// - Returns: 解析后的词条数组
    /// - Throws: ImportError（空文件 / 仅空行的文件抛出 emptyFile，避免全量覆盖导入清空词库）
    static func parse(data: Data) throws -> [ParsedEntry] {
        // 1. UTF-8 编码检测
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidEncoding
        }

        // 2. 按行拆分，过滤空行
        let lines = content.split(whereSeparator: \.isNewline).map(String.init)

        var entries: [ParsedEntry] = []

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1

            // 跳过空行
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            // Tab 分隔
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)

            // 字段数量校验：至少需要 4 个字段（词条 + 注音 + 词性1 + 释义1）
            // 但实际上必填的是词条(0) 和释义1(3)，中间两个可以为空
            guard fields.count >= 4 else {
                throw ImportError.formatError(
                    lineNumber: lineNumber,
                    reason: L10n.t("import.error.fields")
                )
            }

            let sourceWord = fields[0].trimmingCharacters(in: .whitespaces)
            let phonetic = fields[safe: 1]?.trimmingCharacters(in: .whitespaces).nilIfEmpty
            let pos1 = fields[safe: 2]?.trimmingCharacters(in: .whitespaces).nilIfEmpty
            let meaning1 = fields[3].trimmingCharacters(in: .whitespaces)
            let pos2 = fields[safe: 4]?.trimmingCharacters(in: .whitespaces).nilIfEmpty
            let meaning2 = fields[safe: 5]?.trimmingCharacters(in: .whitespaces).nilIfEmpty
            let pos3 = fields[safe: 6]?.trimmingCharacters(in: .whitespaces).nilIfEmpty
            let meaning3 = fields[safe: 7]?.trimmingCharacters(in: .whitespaces).nilIfEmpty

            // 必填字段校验
            if sourceWord.isEmpty {
                throw ImportError.formatError(
                    lineNumber: lineNumber,
                    reason: L10n.t("import.error.word")
                )
            }
            if meaning1.isEmpty {
                throw ImportError.formatError(
                    lineNumber: lineNumber,
                    reason: L10n.t("import.error.meaning")
                )
            }

            entries.append(ParsedEntry(
                sourceWord: sourceWord,
                phonetic: phonetic,
                pos1: pos1,
                meaning1: meaning1,
                pos2: pos2,
                meaning2: meaning2,
                pos3: pos3,
                meaning3: meaning3,
                lineNumber: lineNumber
            ))
        }

        // 无任何有效词条：空文件或仅含空行，拒绝导入
        // （否则 importEntries 会清空目标单词本的所有词条）
        guard !entries.isEmpty else {
            throw ImportError.emptyFile
        }
        return entries
    }

    /// 将解析后的词条全量覆盖导入指定单词本
    ///
    /// 操作为事务性：清空旧词条 → 批量插入新词条 → 自动分配 Section。
    /// 全部在后台上下文中执行，不阻塞主线程。
    ///
    /// - Parameters:
    ///   - entries: 解析后的词条数组
    ///   - wordbook: 目标单词本
    ///   - sectionSize: 每个 Section 的单词数
    static func importEntries(
        _ entries: [ParsedEntry],
        to wordbook: Wordbook,
        sectionSize: Int
    ) async throws {
        let context = DataStack.shared.newBackgroundContext()
        let effectiveSectionSize = max(sectionSize, Constants.minSectionSize)

        try await context.perform {
            // 1. 在后台上下文中获取目标单词本
            let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
            request.predicate = NSPredicate(format: "wordbookId == %@", wordbook.wordbookId)
            request.fetchLimit = 1

            guard let targetWordbook = try context.fetch(request).first else {
                throw ImportError.wordbookMissing
            }

            // 2. 清空旧词条（级联删除由 Core Data 处理）
            if let existingEntries = targetWordbook.entries {
                for entry in existingEntries {
                    if let e = entry as? WordEntry {
                        context.delete(e)
                    }
                }
            }

            // 3. 批量插入新词条，自动分配 section_index
            for (index, parsed) in entries.enumerated() {
                let sectionIndex = Int32(index / effectiveSectionSize)

                let entry = WordEntry(context: context)
                entry.wordId = UUID().uuidString
                entry.sectionIndex = sectionIndex
                entry.orderIndex = Int32(index)
                entry.sourceLineNumber = Int32(parsed.lineNumber)
                entry.sourceWord = parsed.sourceWord
                entry.phonetic = parsed.phonetic
                entry.pos1 = parsed.pos1
                entry.meaning1 = parsed.meaning1
                entry.pos2 = parsed.pos2
                entry.meaning2 = parsed.meaning2
                entry.pos3 = parsed.pos3
                entry.meaning3 = parsed.meaning3
                entry.wordbook = targetWordbook
            }

            // 4. 保存
            guard context.hasChanges else { return }
            try context.save()
        }
    }
}

// MARK: - 辅助扩展

private extension Array {
    /// 安全下标访问，越界返回 nil
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

private extension String {
    /// 空字符串转为 nil
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
