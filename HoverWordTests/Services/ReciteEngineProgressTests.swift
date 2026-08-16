import XCTest
import CoreData
@testable import HoverWord

/// 背记进度持久化验证
///
/// 验证 saveProgress / restoreProgress / clearProgress 的正确性，
/// 以及进度校验逻辑（Section 越界 / 单词越界 / feedbackSet 单词不存在）。
final class ReciteEngineProgressTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockProgressDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        setupTestData()

        engine = ReciteEngine()
        delegate = MockProgressDelegate()
        engine.delegate = delegate
        engine.clearProgress()
    }

    override func tearDown() {
        engine.stop()
        engine.clearProgress()
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

        let words = ["alpha", "beta", "gamma", "delta", "epsilon"]
        for (i, word) in words.enumerated() {
            let entry = WordEntry(context: context)
            entry.wordId = "pw-\(i)"
            entry.sourceWord = word
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = Int32(i / 2)
            entry.wordbook = wordbook
        }

        DataStack.shared.saveContext()
        AppSettings.shared.sectionSize = 2
        AppSettings.shared.reciteMode = .memoryFeedback
    }

    // MARK: - 进度保存与恢复

    func testSaveAndRestoreProgress() {
        // 使用顺序模式避免 shuffle 导致的不确定性
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.reciteMode = .memoryFeedback
        engine.start()

        // 第一个 Section 有 2 个单词，标记第一个为已知
        let firstWord = engine.currentWord()
        XCTAssertNotNil(firstWord)
        engine.markKnown()

        // 记录 markKnown 后显示的单词（第二个）
        let secondWord = engine.currentWord()
        XCTAssertNotEqual(firstWord!.wordId, secondWord!.wordId)

        // 保存进度
        engine.saveProgress()

        // 模拟重启：新建引擎
        let newEngine = ReciteEngine()
        let newDelegate = MockProgressDelegate()
        newEngine.delegate = newDelegate
        newEngine.start()

        // 应恢复到第二个单词
        let restoredWord = newEngine.currentWord()
        XCTAssertNotNil(restoredWord)
        XCTAssertEqual(secondWord!.wordId, restoredWord!.wordId,
                       "恢复后应显示 markKnown 后的同一个单词")

        newEngine.stop()
        newEngine.clearProgress()
    }

    func testClearProgressOnAllComplete() {
        AppSettings.shared.sectionSize = 5  // 所有 5 个单词在 1 个 Section
        AppSettings.shared.playOrder = .sequential

        engine.start()
        // 标记全部 5 个单词为已知
        for _ in 0..<5 {
            engine.markKnown()
        }

        XCTAssertTrue(delegate.didCompleteAll)

        // 新建引擎应从头开始（进度已被清除）
        let newEngine = ReciteEngine()
        newEngine.start()
        let pos = newEngine.currentSectionPosition()
        XCTAssertEqual(pos.index, 0, "全部完成后进度应清除，新引擎从 Section 0 开始")

        newEngine.stop()
        newEngine.clearProgress()
    }

    func testClearProgressOnRestart() {
        AppSettings.shared.playOrder = .sequential
        engine.start()
        engine.markKnown()
        engine.saveProgress()

        engine.restart()

        // restart 应清除进度并从 Section 0 第一个单词开始
        let pos = engine.currentSectionPosition()
        XCTAssertEqual(pos.index, 0, "restart 后应回到 Section 0")
    }

    // MARK: - 进度校验

    func testRestoreLaterLoopLandsOnCorrectWord() {
        // 顺序模式第二轮：currentWordOrder 已被过滤为"未反馈子集"，
        // 恢复后必须仍停留在该子集内，而不是重建全量顺序后回到已认识的单词
        AppSettings.shared.sectionSize = 2
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.reciteMode = .memoryFeedback
        engine.start()

        let alpha = engine.currentWord()!
        engine.markKnown()          // alpha 已认识
        let beta = engine.currentWord()!
        engine.markUnknown()        // 本轮结束，进入第二轮（仅剩 beta）
        let resumed = engine.currentWord()!
        XCTAssertEqual(resumed.wordId, beta.wordId, "第二轮应从 beta 开始")
        XCTAssertNotEqual(resumed.wordId, alpha.wordId)

        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockProgressDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.wordId, beta.wordId,
                       "恢复后应停留在第二轮的 beta，而不是已认识的 alpha")

        newEngine.stop()
        newEngine.clearProgress()
    }

    func testRestoreShuffledPreservesExactWord() {
        // shuffle 模式下播放顺序随机，恢复时必须还原保存时的顺序，
        // 否则 currentWordIndex 指向的单词与保存时不同
        AppSettings.shared.sectionSize = 5  // 5 个单词在同一 Section
        AppSettings.shared.playOrder = .shuffled
        AppSettings.shared.reciteMode = .memoryFeedback
        engine.start()

        let first = engine.currentWord()!
        engine.markUnknown()   // 推进到下一个单词
        let second = engine.currentWord()!
        XCTAssertNotEqual(first.wordId, second.wordId)

        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockProgressDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.wordId, second.wordId,
                       "shuffle 模式恢复后应显示保存时的同一个单词")

        newEngine.stop()
        newEngine.clearProgress()
    }

    func testRestoreWithFavoritesWordbookEnabled() {
        // 收藏夹词条由 Favorite 记录转换而来，其 wordId 必须跨会话稳定，
        // 否则重启后 buildQueue 重新生成的 wordId 与保存的进度对不上，进度被整体重置
        AppSettings.shared.sectionSize = 2
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.reciteMode = .memoryFeedback

        // 停用普通测试单词本，让队列仅包含收藏夹
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
        let first = engine.currentWord()
        XCTAssertNotNil(first)
        engine.markUnknown()
        let second = engine.currentWord()!
        XCTAssertEqual(second.sourceWord, "banana")

        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockProgressDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.sourceWord, "banana",
                       "收藏夹启用时重启后应恢复到第二个收藏词条，而不是被重置回第一个")

        newEngine.stop()
        newEngine.clearProgress()
    }

    func testInvalidSectionIndexClearsProgress() {
        AppSettings.shared.playOrder = .sequential
        engine.start()
        engine.markKnown()
        engine.saveProgress()

        // 手动写入越界的 Section 索引
        UserDefaults.standard.set(999, forKey: "ReciteProgressSectionIndex")

        let newEngine = ReciteEngine()
        newEngine.start()

        // 应回退到 Section 0
        let pos = newEngine.currentSectionPosition()
        XCTAssertEqual(pos.index, 0, "越界 Section 索引应回退到 0")

        newEngine.stop()
        newEngine.clearProgress()
    }

    func testInvalidWordIndexClearsProgress() {
        AppSettings.shared.playOrder = .sequential
        engine.start()
        engine.saveProgress()

        // 手动写入越界的单词索引
        UserDefaults.standard.set(999, forKey: "ReciteProgressWordIndex")

        let newEngine = ReciteEngine()
        newEngine.start()

        // 应回退到第一个单词
        let word = newEngine.currentWord()
        XCTAssertNotNil(word)

        newEngine.stop()
        newEngine.clearProgress()
    }

    func testInvalidFeedbackSetClearsProgress() {
        AppSettings.shared.playOrder = .sequential
        engine.start()
        engine.markKnown()
        engine.saveProgress()

        // 手动写入不存在的单词 ID 到 feedbackSet
        UserDefaults.standard.set(["nonexistent-word-id"], forKey: "ReciteProgressFeedbackSet")

        let newEngine = ReciteEngine()
        newEngine.start()

        // 应回退到从头开始
        let pos = newEngine.currentSectionPosition()
        XCTAssertEqual(pos.index, 0, "feedbackSet 中含无效单词 ID 应回退到 0")

        newEngine.stop()
        newEngine.clearProgress()
    }
}

// MARK: - Mock Delegate

private class MockProgressDelegate: ReciteEngineDelegate {
    var advancedWords: [WordEntry] = []
    var didCompleteAll = false

    func engineDidAdvanceToWord(_ word: WordEntry) {
        advancedWords.append(word)
    }

    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int) {}

    func engineDidCompleteAll() {
        didCompleteAll = true
    }
}
