import XCTest
import CoreData
@testable import HoverWord

/// 词条内容变更通知与引擎响应验证
///
/// 覆盖：编辑停留原位、删除当前词回退、重导入从头开始、
/// 空闲忽略、未启用词本忽略、无效 wordId 不通知、连续双通知幂等。
///
/// 注：sectionComplete 状态在当前代码中不可达（从未被赋值），
/// 该场景以 guard 条件预留（见 ReciteEngine.handleDataChange），不做单测。
final class ReciteEngineContentChangeTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: CountingEngineDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        setupTestData()

        engine = ReciteEngine()
        delegate = CountingEngineDelegate()
        engine.delegate = delegate
        engine.clearProgress()

        AppSettings.shared.sectionSize = 2
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.reciteMode = .memoryFeedback
    }

    override func tearDown() {
        engine.stop()
        engine.clearProgress()
        clearAllData()
        engine = nil
        delegate = nil
        super.tearDown()
    }

    // MARK: - 数据准备

    /// 启用词本 wb-enabled（Section 0: alpha/beta，Section 1: gamma/delta），
    /// 停用词本 wb-disabled（one/two）
    private func setupTestData() {
        let context = DataStack.shared.viewContext

        let enabled = Wordbook(context: context)
        enabled.wordbookId = "wb-enabled"
        enabled.name = "启用词本"
        enabled.sourceLang = "en"
        enabled.targetLang = "zh-Hans"
        enabled.isEnabled = true
        enabled.isSystem = false
        enabled.createdAt = Date()

        let section0 = [("cw-alpha", "alpha", "0"), ("cw-beta", "beta", "1")]
        let section1 = [("cw-gamma", "gamma", "2"), ("cw-delta", "delta", "3")]
        for (wordId, word, meaning) in section0 + section1 {
            let entry = WordEntry(context: context)
            entry.wordId = wordId
            entry.sourceWord = word
            entry.meaning1 = meaning
            entry.sectionIndex = section0.contains(where: { $0.0 == wordId }) ? 0 : 1
            entry.wordbook = enabled
        }

        let disabled = Wordbook(context: context)
        disabled.wordbookId = "wb-disabled"
        disabled.name = "停用词本"
        disabled.sourceLang = "en"
        disabled.targetLang = "zh-Hans"
        disabled.isEnabled = false
        disabled.isSystem = false
        disabled.createdAt = Date()

        for (wordId, word) in [("dw-one", "one"), ("dw-two", "two")] {
            let entry = WordEntry(context: context)
            entry.wordId = wordId
            entry.sourceWord = word
            entry.meaning1 = word
            entry.sectionIndex = 0
            entry.wordbook = disabled
        }

        DataStack.shared.saveContext()
    }

    private func clearAllData() {
        let context = DataStack.shared.viewContext
        for entityName in ["WordEntry", "Wordbook", "Favorite"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(request) {
                for object in objects { context.delete(object) }
            }
        }
        DataStack.shared.saveContext()
    }

    // MARK: - 引擎响应场景

    /// 编辑词条（非删除性内容）后停留原词，后续轮换使用新内容
    func testEditEntryKeepsCurrentPosition() {
        engine.start()
        let before = engine.currentWord()
        XCTAssertNotNil(before)
        XCTAssertEqual(before?.wordId, "cw-alpha")

        let advancesBefore = delegate.advanceCount
        WordbookService.shared.updateEntry(
            wordId: "cw-alpha", sourceWord: "alpha",
            phonetic: nil, pos1: nil, meaning1: "新释义"
        )

        let after = engine.currentWord()
        XCTAssertEqual(after?.wordId, before?.wordId, "编辑后应停留在当前单词")
        XCTAssertEqual(after?.meaning1, "新释义", "重建后应使用编辑后的内容")
        XCTAssertEqual(delegate.advanceCount, advancesBefore + 1, "重建后应重新展示当前单词")
    }

    /// 删除当前正在展示的词条后，从头开始背记
    func testDeleteCurrentWordRestartsFromBeginning() {
        engine.start()
        XCTAssertEqual(engine.currentWord()?.wordId, "cw-alpha")

        WordbookService.shared.deleteEntry(wordId: "cw-alpha")

        XCTAssertEqual(engine.currentSectionPosition().index, 0, "应回退到第一个 Section")
        XCTAssertEqual(engine.currentWord()?.wordId, "cw-beta", "不应展示已删除的词条")
    }

    /// 重新导入后 wordId 全部更新，进度回退从头开始
    func testReimportRestartsFromBeginning() async throws {
        engine.start()
        engine.markKnown()

        guard let wordbook = WordbookService.shared.getAllWordbooks()
            .first(where: { $0.wordbookId == "wb-enabled" }) else {
            XCTFail("测试词本不存在")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reimport-test-\(UUID().uuidString).txt")
        // Tab 分隔：词条 / 注音 / 词性 / 释义（中间两个字段可为空）
        let content = "echo\t\t\t回声\nfox\t\t\t狐狸\nhotel\t\t\t酒店\n"
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let exp = expectation(forNotification: .wordbookContentDidChange, object: nil)
        try await WordbookService.shared.importFromFile(fileURL: tempURL, to: wordbook)
        await fulfillment(of: [exp], timeout: 2)

        XCTAssertEqual(engine.currentSectionPosition().index, 0, "重导入后应回退到第一个 Section")
        let word = engine.currentWord()
        XCTAssertNotNil(word)
        XCTAssertTrue(
            ["echo", "fox", "hotel"].contains(word?.sourceWord ?? ""),
            "应展示新导入词条，而不是旧词条"
        )
    }

    /// 引擎空闲时忽略内容变更
    func testIdleEngineIgnoresContentChange() {
        engine.start()
        engine.stop()

        let advancesBefore = delegate.advanceCount
        WordbookService.shared.updateEntry(
            wordId: "cw-alpha", sourceWord: "alpha",
            phonetic: nil, pos1: nil, meaning1: "新释义"
        )

        XCTAssertEqual(delegate.advanceCount, advancesBefore, "空闲状态应忽略通知")
    }

    /// 未启用单词本的内容变更应被忽略
    func testDisabledWordbookChangeIgnored() {
        engine.start()
        let advancesBefore = delegate.advanceCount
        let currentId = engine.currentWord()?.wordId

        WordbookService.shared.updateEntry(
            wordId: "dw-one", sourceWord: "one",
            phonetic: nil, pos1: nil, meaning1: "改动"
        )

        XCTAssertEqual(delegate.advanceCount, advancesBefore, "未启用词本的变更应被忽略")
        XCTAssertEqual(engine.currentWord()?.wordId, currentId, "当前进度不应受影响")
    }

    /// wordId 不存在（无实际变更）时不发送通知
    func testNonexistentWordIdDoesNotNotify() {
        engine.start()
        let advancesBefore = delegate.advanceCount

        WordbookService.shared.updateEntry(
            wordId: "no-such-id", sourceWord: "ghost",
            phonetic: nil, pos1: nil, meaning1: "无"
        )
        WordbookService.shared.deleteEntry(wordId: "no-such-id")

        XCTAssertEqual(delegate.advanceCount, advancesBefore, "无变更路径不应触发引擎重建")
    }

    /// 同一删除操作引发 favorites + content 双通知连续到达，引擎幂等处理
    func testConsecutiveNotificationsAreIdempotent() throws {
        engine.start()
        XCTAssertEqual(engine.currentWord()?.wordId, "cw-alpha")

        // setUp 的 clearAllData 会清掉系统收藏夹，此处先重建再收藏
        WordbookService.shared.ensureSystemFavorites()

        // 收藏当前词并启用收藏夹（直接改属性，避免触发启用重置语义）
        let detail = try JSONSerialization.data(withJSONObject: ["meaning1": "0"])
        _ = WordbookService.shared.toggleFavorite(sourceWord: "alpha", wordDetail: detail)
        guard let favorites = WordbookService.shared.getFavoritesWordbook() else {
            XCTFail("系统收藏夹单词本不存在")
            return
        }
        favorites.isEnabled = true
        DataStack.shared.saveContext()

        // 删除已收藏的当前词条 → favoritesDidChange（收藏移除）
        //   + wordbookContentDidChange（词条删除）连续同步到达
        WordbookService.shared.deleteEntry(wordId: "cw-alpha")

        XCTAssertEqual(engine.state, .playing, "连续处理后引擎应保持可用")
        XCTAssertEqual(
            engine.currentWord()?.wordId, "cw-beta",
            "最终应停留与新数据一致的进度"
        )
    }
}

// MARK: - 收藏一致性验证

/// 覆盖：改名同步收藏（favoriteId 不变）、改名冲突删除旧收藏、
/// 快照刷新、删除词条的收藏隔离清除。
final class FavoriteConsistencyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        WordbookService.shared.ensureSystemFavorites()
        AppSettings.shared.sectionSize = Constants.defaultSectionSize
    }

    override func tearDown() {
        clearAllData()
        super.tearDown()
    }

    private func clearAllData() {
        let context = DataStack.shared.viewContext
        for entityName in ["WordEntry", "Wordbook", "Favorite"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(request) {
                for object in objects { context.delete(object) }
            }
        }
        DataStack.shared.saveContext()
    }

    /// 创建测试词本（默认启用）并返回
    @discardableResult
    private func createWordbook(id: String, enabled: Bool = true) -> Wordbook {
        let context = DataStack.shared.viewContext
        let wordbook = Wordbook(context: context)
        wordbook.wordbookId = id
        wordbook.name = id
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = enabled
        wordbook.isSystem = false
        wordbook.createdAt = Date()
        DataStack.shared.saveContext()
        return wordbook
    }

    /// 在词本中创建词条
    @discardableResult
    private func createEntry(
        wordId: String, sourceWord: String, meaning: String, in wordbook: Wordbook
    ) -> WordEntry {
        let context = DataStack.shared.viewContext
        let entry = WordEntry(context: context)
        entry.wordId = wordId
        entry.sourceWord = sourceWord
        entry.meaning1 = meaning
        entry.sectionIndex = 0
        entry.wordbook = wordbook
        DataStack.shared.saveContext()
        return entry
    }

    private func favoriteId(of sourceWord: String) -> String? {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Favorite> = Favorite.fetchRequest()
        request.predicate = NSPredicate(format: "sourceWord == %@", sourceWord)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first?.favoriteId
    }

    // MARK: - 场景

    /// 编辑已收藏词条的单词文本，收藏跟随新文本且 favoriteId 不变
    func testRenameSyncsFavorite() {
        let wordbook = createWordbook(id: "wb-consistency")
        createEntry(wordId: "fw-1", sourceWord: "apple", meaning: "苹果", in: wordbook)

        let detail = try? JSONSerialization.data(withJSONObject: ["meaning1": "苹果"])
        _ = WordbookService.shared.toggleFavorite(sourceWord: "apple", wordDetail: detail)
        let originalFavoriteId = favoriteId(of: "apple")
        XCTAssertNotNil(originalFavoriteId)

        WordbookService.shared.updateEntry(
            wordId: "fw-1", sourceWord: "apricot",
            phonetic: nil, pos1: nil, meaning1: "杏"
        )

        XCTAssertFalse(
            WordbookService.shared.isFavorite(sourceWord: "apple"),
            "旧文本不应再命中收藏"
        )
        XCTAssertTrue(
            WordbookService.shared.isFavorite(sourceWord: "apricot"),
            "收藏应跟随新文本"
        )
        XCTAssertEqual(
            favoriteId(of: "apricot"), originalFavoriteId,
            "改名同步不应更换收藏身份（进度持久化依赖 favoriteId 稳定）"
        )
    }

    /// 改名后新文本已被其他收藏占用时，删除旧收藏保持 sourceWord 唯一
    func testRenameToExistingFavoriteDeletesOld() {
        let wordbook = createWordbook(id: "wb-conflict")
        createEntry(wordId: "fw-a", sourceWord: "apple", meaning: "苹果", in: wordbook)
        createEntry(wordId: "fw-b", sourceWord: "banana", meaning: "香蕉", in: wordbook)

        let detail = try? JSONSerialization.data(withJSONObject: [:])
        _ = WordbookService.shared.toggleFavorite(sourceWord: "apple", wordDetail: detail)
        _ = WordbookService.shared.toggleFavorite(sourceWord: "banana", wordDetail: detail)
        XCTAssertEqual(WordbookService.shared.getFavoriteCount(), 2)

        WordbookService.shared.updateEntry(
            wordId: "fw-a", sourceWord: "banana",
            phonetic: nil, pos1: nil, meaning1: "香蕉"
        )

        XCTAssertEqual(
            WordbookService.shared.getFavoriteCount(), 1,
            "冲突时应删除旧收藏，不允许 sourceWord 重复"
        )
        XCTAssertTrue(WordbookService.shared.isFavorite(sourceWord: "banana"))
        XCTAssertFalse(WordbookService.shared.isFavorite(sourceWord: "apple"))
    }

    /// 编辑释义（不改单词文本）后刷新收藏的 wordDetail 快照
    func testEditRefreshesWordDetailSnapshot() {
        let wordbook = createWordbook(id: "wb-snapshot")
        createEntry(wordId: "fw-s", sourceWord: "apple", meaning: "旧释义", in: wordbook)

        let staleDetail = try? JSONSerialization.data(withJSONObject: ["meaning1": "旧释义"])
        _ = WordbookService.shared.toggleFavorite(sourceWord: "apple", wordDetail: staleDetail)

        WordbookService.shared.updateEntry(
            wordId: "fw-s", sourceWord: "apple",
            phonetic: nil, pos1: nil, meaning1: "新释义"
        )

        guard let favorites = WordbookService.shared.getFavoritesWordbook() else {
            XCTFail("系统收藏夹单词本不存在")
            return
        }
        let entries = WordbookService.shared.getEntries(for: favorites, sectionIndex: 0)
        XCTAssertEqual(entries.first?.meaning1, "新释义", "收藏夹展示应与词库实时一致")
    }

    /// 删除已收藏词条且无其他词本包含同词时，收藏被移除
    func testDeleteRemovesFavoriteWhenNoOtherWordbook() {
        let wordbook = createWordbook(id: "wb-del-1")
        createEntry(wordId: "fw-del", sourceWord: "apple", meaning: "苹果", in: wordbook)

        let detail = try? JSONSerialization.data(withJSONObject: ["meaning1": "苹果"])
        _ = WordbookService.shared.toggleFavorite(sourceWord: "apple", wordDetail: detail)
        XCTAssertTrue(WordbookService.shared.isFavorite(sourceWord: "apple"))

        WordbookService.shared.deleteEntry(wordId: "fw-del")

        XCTAssertFalse(
            WordbookService.shared.isFavorite(sourceWord: "apple"),
            "无其他词本包含同词时，收藏应随之移除"
        )
    }

    /// 删除已收藏词条但其他词本仍包含同词时，收藏保留
    func testDeleteKeepsFavoriteWhenOtherWordbookContains() {
        let wordbook1 = createWordbook(id: "wb-keep-1")
        let wordbook2 = createWordbook(id: "wb-keep-2")
        createEntry(wordId: "fw-keep-1", sourceWord: "apple", meaning: "苹果", in: wordbook1)
        createEntry(wordId: "fw-keep-2", sourceWord: "apple", meaning: "苹果", in: wordbook2)

        let detail = try? JSONSerialization.data(withJSONObject: ["meaning1": "苹果"])
        _ = WordbookService.shared.toggleFavorite(sourceWord: "apple", wordDetail: detail)

        WordbookService.shared.deleteEntry(wordId: "fw-keep-1")

        XCTAssertTrue(
            WordbookService.shared.isFavorite(sourceWord: "apple"),
            "其他词本仍包含同词时，收藏应保留"
        )
    }
}

// MARK: - Mock Delegate

private final class CountingEngineDelegate: ReciteEngineDelegate {
    private(set) var advanceCount = 0

    func engineDidAdvanceToWord(_ word: WordEntry) {
        advanceCount += 1
    }

    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int) {}

    func engineDidCompleteAll() {}
}
