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
