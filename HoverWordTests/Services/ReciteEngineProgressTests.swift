import XCTest
import CoreData
@testable import HoverWord

/// 背记进度持久化验证（新语义）
///
/// 覆盖任务 5.3、5.6：
/// - 记忆反馈专用进度键（formatVersion 校验、失效回退、不写续背锚点）
/// - 走马灯身份寻址恢复回归
/// - 收藏夹启用时恢复到确切词条
final class ReciteEngineProgressTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockProgressDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        ReviewStateService.shared.resetAll()
        setupTestData()

        engine = ReciteEngine()
        delegate = MockProgressDelegate()
        engine.delegate = delegate
        engine.clearProgress()

        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.sectionOrder = .sequential
        AppSettings.shared.sectionSize = 2
    }

    override func tearDown() {
        engine.stop()
        engine.clearProgress()
        ReviewStateService.shared.resetAll()
        clearAllData()
        engine = nil
        delegate = nil
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

    private func setupTestData() {
        let context = DataStack.shared.viewContext
        let wordbook = Wordbook(context: context)
        wordbook.wordbookId = "progress-test-wb"
        wordbook.name = "进度测试"
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = true
        wordbook.isSystem = false
        wordbook.createdAt = Date()

        for (i, word) in ["alpha", "beta", "gamma", "delta", "epsilon"].enumerated() {
            let entry = WordEntry(context: context)
            entry.wordId = "pw-\(i)"
            entry.sourceWord = word
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = Int32(i / 2)
            entry.wordbook = wordbook
        }
        DataStack.shared.saveContext()
    }

    // MARK: - 记忆反馈进度

    func testSaveRestoreProgressExactWord() {
        engine.start()
        engine.markKnown()   // pw-0 通过，切到 pw-1
        let expected = engine.currentWord()!.wordId
        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockProgressDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.wordId, expected,
                       "记忆反馈进度应恢复到保存时的确切单词")
        newEngine.stop()
        newEngine.clearProgress()
    }

    func testMemoryModeDoesNotWriteContinuationAnchor() {
        AppSettings.shared.sectionSize = 5
        engine.start()
        for _ in 0..<5 { engine.markKnown() }
        XCTAssertTrue(delegate.didCompleteAll)

        XCTAssertNil(UserDefaults.standard.object(forKey: "ReciteProgressLastCompleted"),
                     "记忆反馈模式完成时不应写续背锚点")
    }

    func testMemoryProgressInvalidWordFallsBack() {
        // 写入 formatVersion=1 但词单含不存在词 → 恢复校验失败回退，不崩溃
        let payload: [String: Any] = [
            "formatVersion": 1,
            "batchWordIds": ["ghost-word"],
            "wordStates": ["ghost-word": 0],
            "exposureCounts": ["ghost-word": 1],
            "index": 0,
            "batchIndex": 0
        ]
        writeMemoryProgress(payload)

        let newEngine = ReciteEngine()
        newEngine.delegate = MockProgressDelegate()
        newEngine.start()

        XCTAssertNotNil(newEngine.currentWord(), "进度词单失效应回退为正常新开始")
        newEngine.stop()
        newEngine.clearProgress()
    }

    func testRestartClearsProgress() {
        engine.start()
        engine.markKnown()   // pw-0 认识 → 产生掌握度，切到 pw-1
        engine.saveProgress()
        engine.restart()

        // restart 清会话进度且保留掌握度：pw-0 已认识（升盒、非到期）故不再作为新词，
        // 重新开始后从下个新词 pw-1 起
        XCTAssertEqual(engine.currentWord()?.wordId, "pw-1",
                       "restart 应保留掌握度，已认识词不再作为新词重现")
    }

    // MARK: - 收藏夹

    func testFavoritesWordbookEnabledRestore() {
        if let normal = WordbookService.shared.getAllWordbooks().first(where: { !$0.isSystem }) {
            normal.isEnabled = false
        }
        DataStack.shared.saveContext()

        WordbookService.shared.ensureSystemFavorites()
        for word in ["apple", "banana"] {
            let json = try? JSONSerialization.data(withJSONObject: ["meaning1": "释义"])
            _ = WordbookService.shared.toggleFavorite(sourceWord: word, wordDetail: json)
        }
        guard let favorites = WordbookService.shared.getFavoritesWordbook() else {
            XCTFail("系统收藏夹单词本不存在")
            return
        }
        favorites.isEnabled = true
        DataStack.shared.saveContext()

        engine.start()
        engine.markVague()   // 推进到第二个收藏词
        XCTAssertEqual(engine.currentWord()?.sourceWord, "banana")

        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockProgressDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.sourceWord, "banana",
                       "收藏夹启用时重启后应恢复到第二个收藏词条")
        newEngine.stop()
        newEngine.clearProgress()
    }

    // MARK: - 走马灯身份寻址回归

    func testCarouselIdentityRestoreExactWord() {
        AppSettings.shared.reciteMode = .carousel
        AppSettings.shared.carouselLoopCount = 1
        engine.start()

        let first = engine.currentWord()!.wordId
        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockProgressDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.wordId, first,
                       "走马灯身份寻址应恢复到保存时的单词")
        newEngine.stop()
        newEngine.clearProgress()
    }

    /// 写入一条记忆反馈进度 Json
    private func writeMemoryProgress(_ obj: [String: Any]) {
        let data = try! JSONSerialization.data(withJSONObject: obj)
        UserDefaults.standard.set(data, forKey: "ReciteProgressBatchState")
    }
}

// MARK: - Mock Delegate

private class MockProgressDelegate: ReciteEngineDelegate {
    var didCompleteAll = false

    func engineDidAdvanceToWord(_ word: WordEntry) {}

    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int) {}

    func engineDidCompleteAll() {
        didCompleteAll = true
    }
}