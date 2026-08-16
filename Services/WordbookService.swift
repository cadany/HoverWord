import Foundation
import CoreData

/// 单词本业务服务
///
/// 负责：
/// - 单词本 CRUD（新建 / 删除 / 重命名 / 启用停用）
/// - 系统收藏夹单词本的初始化与管理
/// - TXT 词库导入调度（解析 + 事务写入 + 收藏夹同步）
/// - 收藏状态管理
///
/// 所有变更操作完成后通过 Notification 广播，通知 ReciteEngine 等监听方。
class WordbookService {
    static let shared = WordbookService()

    private init() {}

    // MARK: - 系统收藏夹

    /// 确保系统收藏夹单词本存在
    ///
    /// 应用首次启动时自动创建"我的收藏"单词本。
    func ensureSystemFavorites() {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "isSystem == YES")

        if let existing = try? context.fetch(request), !existing.isEmpty {
            return
        }

        let favorites = Wordbook(context: context)
        favorites.wordbookId = UUID().uuidString
        favorites.name = Constants.favoritesWordbookName
        favorites.sourceLang = "en"
        favorites.targetLang = "zh-Hans"
        favorites.isEnabled = false
        favorites.isSystem = true
        favorites.createdAt = Date()

        DataStack.shared.saveContext()
    }

    /// 获取系统收藏夹单词本
    func getFavoritesWordbook() -> Wordbook? {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "isSystem == YES")
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    // MARK: - CRUD

    /// 获取所有单词本（按创建时间排序）
    func getAllWordbooks() -> [Wordbook] {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    /// 获取所有启用的单词本（按创建时间排序，用于构建背记队列）
    func getEnabledWordbooks() -> [Wordbook] {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "isEnabled == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    /// 新建单词本
    ///
    /// - Parameter name: 单词本名称
    /// - Returns: 新创建的单词本
    @discardableResult
    func createWordbook(name: String) -> Wordbook {
        let context = DataStack.shared.viewContext
        let wordbook = Wordbook(context: context)
        wordbook.wordbookId = UUID().uuidString
        wordbook.name = name
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = false
        wordbook.isSystem = false
        wordbook.createdAt = Date()

        DataStack.shared.saveContext()
        return wordbook
    }

    /// 删除单词本
    ///
    /// - Parameter wordbook: 要删除的单词本
    /// - Returns: 是否删除成功（系统单词本不可删除，返回 false）
    func deleteWordbook(_ wordbook: Wordbook) -> Bool {
        guard !wordbook.isSystem else { return false }

        let context = DataStack.shared.viewContext
        context.delete(wordbook)
        DataStack.shared.saveContext()

        NotificationCenter.default.post(name: .wordbookEnablementDidChange, object: nil)
        return true
    }

    /// 重命名单词本
    func renameWordbook(_ wordbook: Wordbook, to newName: String) {
        wordbook.name = newName
        DataStack.shared.saveContext()
    }

    /// 设置单词本启用/停用状态
    ///
    /// - Parameters:
    ///   - wordbook: 目标单词本
    ///   - enabled: 是否启用
    /// - Returns: 是否操作成功（空单词本无法启用，返回 false）
    func setWordbookEnabled(_ wordbook: Wordbook, enabled: Bool) -> Bool {
        if enabled {
            // 启用时检查是否有词条
            let entryCount = getEntryCount(for: wordbook)
            guard entryCount > 0 else { return false }
        }

        wordbook.isEnabled = enabled
        DataStack.shared.saveContext()

        NotificationCenter.default.post(name: .wordbookEnablementDidChange, object: nil)
        return true
    }

    // MARK: - 查询

    /// 判断单词本是否为系统收藏夹
    private func isFavoritesWordbook(_ wordbook: Wordbook) -> Bool {
        return wordbook.isSystem && wordbook.name == Constants.favoritesWordbookName
    }

    /// 获取收藏词条总数
    func getFavoriteCount() -> Int {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        return (try? context.count(for: request)) ?? 0
    }

    /// 将 Favorite 记录转换为游离 WordEntry（不写入 Core Data，仅用于引擎调度）
    ///
    /// 从 `Favorite.wordDetail` JSON 反序列化字段。
    /// wordId 使用收藏记录的 favoriteId（持久化且跨会话稳定），
    /// 供进度保存/恢复与 feedbackSet 匹配；临时 UUID 会导致重启后进度失效。
    /// 解析失败时返回 nil。
    private func favoriteToWordEntry(_ favorite: Favorite, sectionIndex: Int) -> WordEntry? {
        guard let data = favorite.wordDetail,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NSLog("[WordbookService] Failed to decode wordDetail for favorite: \(favorite.sourceWord)")
            return nil
        }

        // 创建游离 WordEntry（不插入 context）
        let entry = WordEntry(entity: WordEntry.entity(), insertInto: nil)
        entry.wordId = favorite.favoriteId
        entry.sectionIndex = Int32(sectionIndex)
        entry.sourceWord = favorite.sourceWord
        entry.phonetic = json["phonetic"] as? String
        entry.pos1 = json["pos1"] as? String
        entry.meaning1 = json["meaning1"] as? String
        entry.pos2 = json["pos2"] as? String
        entry.meaning2 = json["meaning2"] as? String
        entry.pos3 = json["pos3"] as? String
        entry.meaning3 = json["meaning3"] as? String
        return entry
    }

    /// 获取单词本的词条总数
    ///
    /// 对系统收藏夹单词本，返回 Favorite 实体数量。
    func getEntryCount(for wordbook: Wordbook) -> Int {
        if isFavoritesWordbook(wordbook) {
            return getFavoriteCount()
        }
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordbook.wordbookId == %@", wordbook.wordbookId)
        return (try? context.count(for: request)) ?? 0
    }

    /// 获取单词本的 Section 数量
    ///
    /// 对系统收藏夹单词本，按收藏总数和全局 sectionSize 计算。
    func getSectionCount(for wordbook: Wordbook) -> Int {
        if isFavoritesWordbook(wordbook) {
            let favoriteCount = getFavoriteCount()
            guard favoriteCount > 0 else { return 0 }
            let sectionSize = AppSettings.shared.sectionSize
            return (favoriteCount + sectionSize - 1) / sectionSize
        }

        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordbook.wordbookId == %@", wordbook.wordbookId)
        request.sortDescriptors = [NSSortDescriptor(key: "sectionIndex", ascending: false)]
        request.fetchLimit = 1

        // 通过最大 sectionIndex + 1 计算 Section 数
        guard let maxEntry = try? context.fetch(request).first else { return 0 }
        return Int(maxEntry.sectionIndex) + 1
    }

    /// 获取单词本指定 Section 的所有词条（按 sectionIndex 排序）
    ///
    /// 对系统收藏夹单词本，查询 Favorite 并按 section 分页，
    /// 通过 `favoriteToWordEntry` 转换为游离 WordEntry。
    func getEntries(for wordbook: Wordbook, sectionIndex: Int) -> [WordEntry] {
        if isFavoritesWordbook(wordbook) {
            let sectionSize = AppSettings.shared.sectionSize
            let offset = sectionIndex * sectionSize

            let context = DataStack.shared.viewContext
            let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "collectedAt", ascending: true)]
            request.fetchOffset = offset
            request.fetchLimit = sectionSize

            guard let favorites = try? context.fetch(request) else { return [] }
            return favorites.compactMap { favoriteToWordEntry($0, sectionIndex: sectionIndex) }
        }

        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "wordbook.wordbookId == %@ AND sectionIndex == %d",
            wordbook.wordbookId, Int32(sectionIndex)
        )
        request.sortDescriptors = [
            NSSortDescriptor(key: "orderIndex", ascending: true),
            NSSortDescriptor(key: "sourceWord", ascending: true)  // 平局兜底
        ]
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - 词条预览（分页 CRUD）

    /// 分页获取单词本词条
    ///
    /// 不支持系统收藏夹单词本（返回空结果）。
    ///
    /// - Parameters:
    ///   - wordbook: 目标单词本
    ///   - page: 页码（从 0 开始）
    ///   - pageSize: 每页条数
    /// - Returns: (entries: 当前页词条列表, totalPages: 总页数, totalCount: 总条数)
    func getEntriesPaginated(
        for wordbook: Wordbook,
        page: Int,
        pageSize: Int
    ) -> (entries: [WordEntry], totalPages: Int, totalCount: Int) {
        guard !isFavoritesWordbook(wordbook) else { return ([], 0, 0) }

        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordbook.wordbookId == %@", wordbook.wordbookId)

        let totalCount = (try? context.count(for: request)) ?? 0
        let totalPages = pageSize > 0 ? max(1, (totalCount + pageSize - 1) / pageSize) : 1

        request.sortDescriptors = [
            NSSortDescriptor(key: "orderIndex", ascending: true),
            NSSortDescriptor(key: "sourceWord", ascending: true)
        ]
        request.fetchOffset = page * pageSize
        request.fetchLimit = pageSize

        let entries = (try? context.fetch(request)) ?? []
        return (entries, totalPages, totalCount)
    }

    /// 更新词条字段
    ///
    /// - Parameters:
    ///   - wordId: 词条唯一标识
    ///   - sourceWord: 新的单词文本
    ///   - phonetic: 新的音标
    ///   - pos1: 新的词性
    ///   - meaning1: 新的释义
    func updateEntry(
        wordId: String,
        sourceWord: String,
        phonetic: String?,
        pos1: String?,
        meaning1: String?
    ) {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordId == %@", wordId)
        request.fetchLimit = 1

        guard let entry = (try? context.fetch(request))?.first else { return }
        entry.sourceWord = sourceWord
        entry.phonetic = phonetic?.isEmpty == true ? nil : phonetic
        entry.pos1 = pos1?.isEmpty == true ? nil : pos1
        entry.meaning1 = meaning1?.isEmpty == true ? nil : meaning1
        DataStack.shared.saveContext()
    }

    /// 删除词条
    ///
    /// - Parameter wordId: 词条唯一标识
    func deleteEntry(wordId: String) {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordId == %@", wordId)
        request.fetchLimit = 1

        guard let entry = (try? context.fetch(request))?.first else { return }
        context.delete(entry)
        DataStack.shared.saveContext()
    }

    // MARK: - 导入

    /// 导入 TXT 文件到指定单词本（全量覆盖）
    ///
    /// - Parameters:
    ///   - fileURL: TXT 文件 URL
    ///   - wordbook: 目标单词本
    /// - Throws: WordbookImportService.ImportError
    func importFromFile(fileURL: URL, to wordbook: Wordbook) async throws {
        let data = try Data(contentsOf: fileURL)
        let entries = try WordbookImportService.parse(data: data)
        let sectionSize = AppSettings.shared.sectionSize

        try await WordbookImportService.importEntries(entries, to: wordbook, sectionSize: sectionSize)

        // 导入后同步收藏夹
        syncFavoritesAfterImport(wordbook: wordbook, importedSourceWords: Set(entries.map { $0.sourceWord }))
    }

    // MARK: - 收藏夹同步

    /// 导入后同步收藏夹状态
    ///
    /// 基于 source_word 精确匹配：
    /// - 新导入词条与历史收藏匹配的保留收藏
    /// - 历史收藏但新导入不存在的自动移除
    /// - 仅检查源自该单词本的收藏（按单词本范围隔离）
    private func syncFavoritesAfterImport(wordbook: Wordbook, importedSourceWords: Set<String>) {
        let context = DataStack.shared.newBackgroundContext()

        context.perform {
            // 获取该单词本导入前的所有 source_word（此时已为新数据）
            // 收藏夹同步基于：收藏中的 source_word 是否还存在于导入后的数据中
            let favRequest: NSFetchRequest<Favorite> = Favorite.fetchRequest()

            // 获取所有收藏
            guard let allFavorites = try? context.fetch(favRequest) else { return }

            // 检查每个收藏的 source_word 是否在新导入数据中
            for favorite in allFavorites {
                if !importedSourceWords.contains(favorite.sourceWord) {
                    // 该单词本导入后不再包含此收藏词条，移除收藏
                    // 注意：这里需要更精确的隔离逻辑（仅移除源自该单词本的收藏）
                    // 简化实现：检查是否有任何其他启用单词本包含此词条
                    let otherWordbookHasEntry = self.anyOtherWordbookContains(
                        sourceWord: favorite.sourceWord,
                        excludingWordbookId: wordbook.wordbookId,
                        context: context
                    )
                    if !otherWordbookHasEntry {
                        context.delete(favorite)
                    }
                }
            }

            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    NSLog("[WordbookService] 收藏夹同步保存失败: \(error as NSError)")
                }
            }
        }

        // context.perform 在后台上下文队列执行，通知引擎必须回到主线程
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
        }
    }

    /// 检查是否有其他单词本包含指定词条
    private func anyOtherWordbookContains(
        sourceWord: String,
        excludingWordbookId: String,
        context: NSManagedObjectContext
    ) -> Bool {
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "sourceWord == %@ AND wordbook.wordbookId != %@",
            sourceWord, excludingWordbookId
        )
        request.fetchLimit = 1
        let count = (try? context.count(for: request)) ?? 0
        return count > 0
    }

    // MARK: - 收藏操作

    /// 切换收藏状态
    ///
    /// - Parameter sourceWord: 词条的源语言文本
    /// - Returns: 切换后的收藏状态（true=已收藏，false=未收藏）
    @discardableResult
    func toggleFavorite(sourceWord: String, wordDetail: Data?) -> Bool {
        let context = DataStack.shared.viewContext

        // 查找现有收藏
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        request.predicate = NSPredicate(format: "sourceWord == %@", sourceWord)
        request.fetchLimit = 1

        let nowFavorite: Bool
        if let existing = try? context.fetch(request), let fav = existing.first {
            // 已收藏 → 取消收藏
            context.delete(fav)
            DataStack.shared.saveContext()
            nowFavorite = false
        } else {
            // 未收藏 → 添加收藏
            let favorite = Favorite(context: context)
            favorite.favoriteId = UUID().uuidString
            favorite.sourceWord = sourceWord
            favorite.wordDetail = wordDetail
            favorite.collectedAt = Date()
            DataStack.shared.saveContext()
            nowFavorite = true
        }

        // 通知引擎收藏内容变化（收藏夹单词本启用时需重建队列）
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
        return nowFavorite
    }

    /// 检查某词条是否已收藏
    func isFavorite(sourceWord: String) -> Bool {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        request.predicate = NSPredicate(format: "sourceWord == %@", sourceWord)
        request.fetchLimit = 1
        let count = (try? context.count(for: request)) ?? 0
        return count > 0
    }
}
