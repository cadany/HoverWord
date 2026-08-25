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
        favorites.sourceLang = Constants.defaultSourceLang
        favorites.targetLang = Constants.defaultTargetLang
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
        wordbook.sourceLang = Constants.defaultSourceLang
        wordbook.targetLang = Constants.defaultTargetLang
        wordbook.isEnabled = false
        wordbook.isSystem = false
        wordbook.createdAt = Date()

        DataStack.shared.saveContext()
        return wordbook
    }

    /// 删除单词本
    ///
    /// 收藏一致性对齐 deleteEntry：级联删除词条后，无其他单词本
    /// 包含相同 sourceWord 的收藏一并移除，避免收藏夹残留孤儿词条
    ///
    /// - Parameter wordbook: 要删除的单词本
    /// - Returns: 是否删除成功（系统单词本不可删除，返回 false）
    func deleteWordbook(_ wordbook: Wordbook) -> Bool {
        guard !wordbook.isSystem else { return false }

        let context = DataStack.shared.viewContext

        // 级联删除后词条不可再查，先收集 sourceWord 快照
        let entryRequest: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        entryRequest.predicate = NSPredicate(format: "wordbook.wordbookId == %@", wordbook.wordbookId)
        let sourceWords = Set(((try? context.fetch(entryRequest)) ?? []).map { $0.sourceWord })

        context.delete(wordbook)

        var favoritesChanged = false
        for sourceWord in sourceWords {
            if !anyOtherWordbookContains(
                sourceWord: sourceWord,
                excludingWordbookId: wordbook.wordbookId,
                context: context
            ) {
                favoritesChanged = removeFavorites(sourceWord: sourceWord, in: context) || favoritesChanged
            }
        }

        DataStack.shared.saveContext()

        NotificationCenter.default.post(name: .wordbookEnablementDidChange, object: nil)
        if favoritesChanged {
            NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
        }
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
    ///
    /// 仅依据 isSystem 标记判定，不比对名称：系统单词本的界面显示名
    /// 已本地化（词条映射），存储名与显示名不再一致。
    private func isFavoritesWordbook(_ wordbook: Wordbook) -> Bool {
        return wordbook.isSystem
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

    /// 一次返回单词本 (词条数, Section 数)——列表刷新场景使用
    ///
    /// 收藏夹两条数据本就同源（均为 Favorite count），合并后单次查询，
    /// 消除 getEntryCount + getSectionCount 成对调用时的重复 count
    func getStats(for wordbook: Wordbook) -> (entryCount: Int, sectionCount: Int) {
        if isFavoritesWordbook(wordbook) {
            let favoriteCount = getFavoriteCount()
            let sectionSize = AppSettings.shared.sectionSize
            return (favoriteCount, favoriteCount == 0 ? 0 : (favoriteCount + sectionSize - 1) / sectionSize)
        }
        let entryCount = getEntryCount(for: wordbook)
        return (entryCount, getSectionCount(for: wordbook))
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

    /// 一次查询取出单词本全部词条并按 Section 分组（供引擎构建队列）
    ///
    /// 对比逐 Section 调用 getEntries 的 N+1 模式（万级词库 500+ 次主线程
    /// fetch，设置变更/收藏切换均会触发），单次查询 + 内存分组消除瓶颈。
    /// 排序口径与 getEntries 一致（sectionIndex → orderIndex → sourceWord）。
    func getAllEntriesGroupedBySection(for wordbook: Wordbook) -> [[WordEntry]] {
        if isFavoritesWordbook(wordbook) {
            let sectionSize = max(AppSettings.shared.sectionSize, 1)
            let context = DataStack.shared.viewContext
            let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "collectedAt", ascending: true)]

            guard let favorites = try? context.fetch(request) else { return [] }
            let entries = favorites.enumerated().compactMap { index, favorite in
                favoriteToWordEntry(favorite, sectionIndex: index / sectionSize)
            }
            return stride(from: 0, to: entries.count, by: sectionSize).map {
                Array(entries[$0..<min($0 + sectionSize, entries.count)])
            }
        }

        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordbook.wordbookId == %@", wordbook.wordbookId)
        request.sortDescriptors = [
            NSSortDescriptor(key: "sectionIndex", ascending: true),
            NSSortDescriptor(key: "orderIndex", ascending: true),
            NSSortDescriptor(key: "sourceWord", ascending: true)  // 平局兜底
        ]

        let entries = (try? context.fetch(request)) ?? []
        var grouped: [[WordEntry]] = []
        for entry in entries {
            let section = Int(entry.sectionIndex)
            while grouped.count <= section {
                grouped.append([])
            }
            grouped[section].append(entry)
        }
        return grouped
    }

    // MARK: - 词条预览（分页 CRUD）

    /// 分页获取单词本词条
    ///
    /// 对系统收藏夹单词本，查询 Favorite 并按收藏时间（collectedAt 升序）分页，
    /// 通过 `favoriteToWordEntry` 转换为游离 WordEntry（仅供预览展示；
    /// 编辑/删除服务按 wordId 匹配不到实体，预览层对收藏夹呈只读态）。
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
        if isFavoritesWordbook(wordbook) {
            let context = DataStack.shared.viewContext
            let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "collectedAt", ascending: true)]

            let totalCount = (try? context.count(for: request)) ?? 0
            let totalPages = pageSize > 0 ? max(1, (totalCount + pageSize - 1) / pageSize) : 1

            request.fetchOffset = page * pageSize
            request.fetchLimit = pageSize
            let favorites = (try? context.fetch(request)) ?? []
            let entries = favorites.compactMap { favoriteToWordEntry($0, sectionIndex: 0) }
            return (entries, totalPages, totalCount)
        }

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
        meaning1: String?,
        pos2: String? = nil,
        meaning2: String? = nil,
        pos3: String? = nil,
        meaning3: String? = nil,
        replaceSecondaryMeanings: Bool = false
    ) {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordId == %@", wordId)
        request.fetchLimit = 1

        guard let entry = (try? context.fetch(request))?.first else { return }
        let oldSourceWord = entry.sourceWord
        entry.sourceWord = sourceWord
        entry.phonetic = phonetic?.isEmpty == true ? nil : phonetic
        entry.pos1 = pos1?.isEmpty == true ? nil : pos1
        entry.meaning1 = meaning1?.isEmpty == true ? nil : meaning1
        // 第 2/3 组释义仅在调用方显式要求整体替换时回写（预览编辑场景），
        // 其他调用方传 nil 保持原值不被清空
        if replaceSecondaryMeanings {
            entry.pos2 = pos2?.isEmpty == true ? nil : pos2
            entry.meaning2 = meaning2?.isEmpty == true ? nil : meaning2
            entry.pos3 = pos3?.isEmpty == true ? nil : pos3
            entry.meaning3 = meaning3?.isEmpty == true ? nil : meaning3
        }

        // 收藏一致性：同步关联收藏的 sourceWord 与 wordDetail 快照
        let favoritesChanged = syncFavoriteAfterEdit(of: entry, oldSourceWord: oldSourceWord)

        DataStack.shared.saveContext()

        // 收藏在前、内容在后（与导入链路次序约定一致），本方法仅在主线程调用
        if favoritesChanged {
            NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
        }
        postContentDidChange(wordbookId: entry.wordbook?.wordbookId)
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
        let wordbookId = entry.wordbook?.wordbookId
        let sourceWord = entry.sourceWord
        context.delete(entry)

        // 收藏一致性：无其他单词本包含相同 sourceWord 时移除关联收藏
        //（与导入后收藏同步的隔离语义一致）
        let favoritesChanged: Bool
        if !anyOtherWordbookContains(
            sourceWord: sourceWord,
            excludingWordbookId: wordbookId ?? "",
            context: context
        ) {
            favoritesChanged = removeFavorites(sourceWord: sourceWord, in: context)
        } else {
            favoritesChanged = false
        }

        DataStack.shared.saveContext()

        if favoritesChanged {
            NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
        }
        postContentDidChange(wordbookId: wordbookId)
    }

    // MARK: - 收藏一致性

    /// 编辑词条后同步关联收藏（按旧 sourceWord 匹配）
    ///
    /// - 改名：更新收藏的 sourceWord；若新词文本已被其他收藏占用，
    ///   删除旧收藏（保持 sourceWord 全局唯一，toggleFavorite / isFavorite 依赖此假设）
    /// - 任意编辑：刷新收藏的 wordDetail 快照，收藏夹展示与词库实时一致
    /// - Returns: 收藏状态是否实际变化（用于决定是否补发 favoritesDidChange）
    @discardableResult
    private func syncFavoriteAfterEdit(of entry: WordEntry, oldSourceWord: String) -> Bool {
        let context = DataStack.shared.viewContext
        guard !oldSourceWord.isEmpty,
              let favorite = fetchFavorite(sourceWord: oldSourceWord, in: context) else {
            return false
        }

        let newSourceWord = entry.sourceWord
        if newSourceWord != oldSourceWord {
            if fetchFavorite(sourceWord: newSourceWord, in: context) != nil {
                // 新词文本已被收藏：删除旧收藏，保持 sourceWord 唯一
                context.delete(favorite)
                return true
            }
            favorite.sourceWord = newSourceWord
        }

        // 刷新快照；内容无变化时保持 false，避免无谓的收藏通知
        let newDetail = entry.encodeWordDetail()
        if favorite.wordDetail != newDetail {
            favorite.wordDetail = newDetail
            return true
        }
        return newSourceWord != oldSourceWord
    }

    /// 按源语言文本查找收藏记录
    private func fetchFavorite(sourceWord: String, in context: NSManagedObjectContext) -> Favorite? {
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        request.predicate = NSPredicate(format: "sourceWord == %@", sourceWord)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    /// 移除指定 sourceWord 的全部收藏记录
    ///
    /// - Returns: 是否实际移除了记录
    @discardableResult
    private func removeFavorites(sourceWord: String, in context: NSManagedObjectContext) -> Bool {
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        request.predicate = NSPredicate(format: "sourceWord == %@", sourceWord)
        guard let favorites = try? context.fetch(request), !favorites.isEmpty else {
            return false
        }
        for favorite in favorites {
            context.delete(favorite)
        }
        return true
    }

    /// 发送单词本内容变更通知（仅在主线程同步接口内调用）
    private func postContentDidChange(wordbookId: String?) {
        guard let wordbookId, !wordbookId.isEmpty else { return }
        NotificationCenter.default.post(
            name: .wordbookContentDidChange,
            object: nil,
            userInfo: ["wordbookId": wordbookId]
        )
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

        // 导入后同步收藏夹（await 完成，保证收藏删除落库后才进入后续通知链路）
        await syncFavoritesAfterImport(wordbook: wordbook, importedSourceWords: Set(entries.map { $0.sourceWord }))

        // 全量覆盖导入的内容即真相：按导入内容自动识别并回写语言对
        let detectedSource = LanguageDetectionService.sourceLanguage(from: entries.map { $0.sourceWord })
        let detectedTarget = LanguageDetectionService.targetLanguage(from: entries.map { $0.meaning1 })
        await applyLanguagesToWordbook(
            wordbookId: wordbook.wordbookId,
            sourceLang: detectedSource,
            targetLang: detectedTarget
        )

        // 内容变更通知经主线程队列派发：syncFavoritesAfterImport 内的
        // favoritesDidChange 已先行入队，同队列 FIFO 保证 content 通知最后到达，
        // 引擎以最新数据收尾
        let wordbookId = wordbook.wordbookId
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .wordbookContentDidChange,
                object: nil,
                userInfo: ["wordbookId": wordbookId]
            )
        }
    }

    // MARK: - 语言对

    /// 手动设置词本语言对（行内"语言…"编辑保存路径，按 ID 定位，任意线程可调）
    func updateWordbookLanguages(wordbookId: String, sourceLang: String, targetLang: String) async {
        await applyLanguagesToWordbook(
            wordbookId: wordbookId,
            sourceLang: sourceLang,
            targetLang: targetLang
        )
    }

    /// 按词本当前词条内容检测语言对（语言编辑页"自动检测"按钮）
    ///
    /// - Returns: (source, target)；空词本返回 nil
    func detectLanguages(for wordbook: Wordbook) -> (source: String, target: String)? {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
        request.predicate = NSPredicate(format: "wordbook.wordbookId == %@", wordbook.wordbookId)
        request.sortDescriptors = [NSSortDescriptor(key: "orderIndex", ascending: true)]
        request.fetchLimit = Constants.languageDetectionSampleCount
        let entries = (try? context.fetch(request)) ?? []
        guard !entries.isEmpty else { return nil }
        return (
            LanguageDetectionService.sourceLanguage(from: entries.map { $0.sourceWord ?? "" }),
            LanguageDetectionService.targetLanguage(from: entries.map { $0.meaning1 ?? "" })
        )
    }

    /// 按 ID 定位词本并回写语言对（后台上下文，任意线程可调）；
    /// 有实际变化时保存并在主线程广播 `.wordbookLanguageDidChange`
    private func applyLanguagesToWordbook(wordbookId: String, sourceLang: String, targetLang: String) async {
        let context = DataStack.shared.newBackgroundContext()
        let changed: Bool = await context.perform {
            let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
            request.predicate = NSPredicate(format: "wordbookId == %@", wordbookId)
            request.fetchLimit = 1
            guard let wordbook = (try? context.fetch(request))?.first else { return false }
            guard wordbook.sourceLang != sourceLang || wordbook.targetLang != targetLang else { return false }

            wordbook.sourceLang = sourceLang
            wordbook.targetLang = targetLang
            do {
                try context.save()
                return true
            } catch {
                NSLog("[WordbookService] Failed to save language pair: \(error)")
                return false
            }
        }
        if changed {
            await MainActor.run {
                NotificationCenter.default.post(name: .wordbookLanguageDidChange, object: nil)
            }
        }
    }

    // MARK: - 收藏夹同步

    /// 导入后同步收藏夹状态
    ///
    /// 基于 source_word 精确匹配：
    /// - 新导入词条与历史收藏匹配的保留收藏
    /// - 历史收藏但新导入不存在的自动移除
    /// - 仅检查源自该单词本的收藏（按单词本范围隔离）
    ///
    /// 通知时序约束：favoritesDidChange 必须晚于收藏删除落库，
    /// 否则引擎重建队列会读到过期收藏（已删词条继续被背诵）
    private func syncFavoritesAfterImport(wordbook: Wordbook, importedSourceWords: Set<String>) async {
        let context = DataStack.shared.newBackgroundContext()

        await context.perform {
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

        // 落库完成后再通知（主线程），引擎重建时读到的是已删除后的收藏
        await MainActor.run {
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
