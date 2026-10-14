import XCTest
import CoreData
@testable import HoverWord

/// 背记引擎基础逻辑验证（走马灯回归 + 记忆反馈基础切换 + 完成检测 + 性能）
///
/// 记忆反馈的三态盒级 / 队列调度 / 曝光放行 / 进度恢复 / 重置语义专项见 ReciteEngineSrsTests。
final class ReciteEngineTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockEngineDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        ReviewStateService.shared.resetAll()
        setupTestData()

        engine = ReciteEngine()
        delegate = MockEngineDelegate()
        engine.delegate = delegate

        AppSettings.shared.sectionSize = 2
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.sectionOrder = .sequential
        AppSettings.shared.reciteMode = .memoryFeedback
        engine.clearProgress()
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

        let wordbookA = Wordbook(context: context)
        wordbookA.wordbookId = "test-wb-a"
        wordbookA.name = "测试A"
        wordbookA.sourceLang = "en"
        wordbookA.targetLang = "zh-Hans"
        wordbookA.isEnabled = true
        wordbookA.isSystem = false
        wordbookA.createdAt = Date()

        for (i, word) in ["apple", "banana", "cherry", "date", "elderberry"].enumerated() {
            let entry = WordEntry(context: context)
            entry.wordId = "a-\(i)"
            entry.sourceWord = word
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = Int32(i / 2)
            entry.wordbook = wordbookA
        }

        let wordbookB = Wordbook(context: context)
        wordbookB.wordbookId = "test-wb-b"
        wordbookB.name = "测试B"
        wordbookB.sourceLang = "en"
        wordbookB.targetLang = "zh-Hans"
        wordbookB.isEnabled = true
        wordbookB.isSystem = false
        wordbookB.createdAt = Date().addingTimeInterval(1)

        for (i, word) in ["fig", "grape", "honeydew"].enumerated() {
            let entry = WordEntry(context: context)
            entry.wordId = "b-\(i)"
            entry.sourceWord = word
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = Int32(i / 2)
            entry.wordbook = wordbookB
        }

        DataStack.shared.saveContext()
    }

    // MARK: - 队列构建

    func testQueueBuilding() {
        engine.start()

        let pos = engine.currentSectionPosition()
        XCTAssertEqual(pos.total, 5, "应有 5 个 Section（A 3 个 + B 2 个）")
        XCTAssertEqual(pos.index, 0, "初始应在第一个 Section")
    }

    func testEmptyQueueOnNoEnabledWordbooks() {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        if let wordbooks = try? context.fetch(request) {
            for wb in wordbooks { wb.isEnabled = false }
        }
        DataStack.shared.saveContext()

        engine.start()

        XCTAssertTrue(delegate.didCompleteAll, "空队列应直接完成")
    }

    // MARK: - 记忆反馈基础切换

    func testMemoryFeedbackMarkKnownAdvances() {
        engine.start()
        let first = engine.currentWord()!.wordId
        engine.markKnown()
        XCTAssertNotEqual(engine.currentWord()!.wordId, first, "认识后应切到下一词")
    }

    func testMemoryFeedbackMarkVagueAdvances() {
        engine.start()
        let first = engine.currentWord()!.wordId
        engine.markVague()
        XCTAssertNotEqual(engine.currentWord()!.wordId, first, "模糊后应切到下一词")
    }

    func testFirstWordNotSkipped() {
        AppSettings.shared.sectionSize = 5
        engine.start()

        XCTAssertEqual(delegate.advancedWords.count, 1, "启动后应恰好收到 1 个单词回调")
        XCTAssertEqual(delegate.advancedWords.first!.wordId, engine.currentWord()!.wordId,
                       "currentWord 应与 delegate 收到的一致")
    }

    // MARK: - 完成检测

    func testAllSectionsComplete() {
        // 只启用单词本 A（5 词），sectionSize=5 → 单批
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        if let wordbooks = try? context.fetch(request) {
            for wb in wordbooks where wb.wordbookId == "test-wb-b" { wb.isEnabled = false }
        }
        DataStack.shared.saveContext()
        AppSettings.shared.sectionSize = 5

        engine.start()

        for _ in 0..<5 { engine.markKnown() }

        XCTAssertTrue(delegate.didCompleteAll, "批内全部认识后应进入已学完")
    }

    // MARK: - 走马灯模式回归

    func testCarouselModeAutoAdvance() {
        AppSettings.shared.reciteMode = .carousel
        AppSettings.shared.stayDuration = 1
        AppSettings.shared.carouselLoopCount = 1

        let expectation = XCTestExpectation(description: "走马灯自动切换")
        engine.start()
        let first = engine.currentWord()!.wordId

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            XCTAssertNotEqual(self.engine.currentWord()?.wordId, first,
                              "走马灯模式应自动切换单词")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - 性能

    func testWordSwitchPerformance() {
        engine.start()
        engine.markKnown()
        measure {
            for _ in 0..<50 { engine.markKnown() }
        }
    }
}

// MARK: - Mock Delegate

private class MockEngineDelegate: ReciteEngineDelegate {
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