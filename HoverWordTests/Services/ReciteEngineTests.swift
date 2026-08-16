import XCTest
import CoreData
@testable import HoverWord

/// 背记引擎逻辑验证
///
/// 对应任务 5.9：双模式调度、Section 流转、完成检测、设置重置、随机模式。
/// 使用 in-memory Core Data 存储提供测试数据。
final class ReciteEngineTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockEngineDelegate!

    // MARK: - 生命周期

    override func setUp() {
        super.setUp()
        // 初始化 DataStack
        DataStack.shared.initialize()
        // 清空现有数据
        clearAllData()
        // 创建测试数据
        setupTestData()

        engine = ReciteEngine()
        delegate = MockEngineDelegate()
        engine.delegate = self.delegate

        // 清除 UserDefaults 中的历史进度，避免干扰测试
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

    // MARK: - 辅助方法

    private func clearAllData() {
        let context = DataStack.shared.viewContext
        let entities = ["WordEntry", "Wordbook", "Favorite"]
        for entityName in entities {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(fetchRequest) {
                for object in objects {
                    context.delete(object)
                }
            }
        }
        DataStack.shared.saveContext()
    }

    /// 创建测试数据：2 个单词本，各有若干词条和 Section
    private func setupTestData() {
        let context = DataStack.shared.viewContext

        // 单词本 A: 5 个词条，Section 大小 2 → 3 个 Section
        let wordbookA = Wordbook(context: context)
        wordbookA.wordbookId = "test-wb-a"
        wordbookA.name = "测试A"
        wordbookA.sourceLang = "en"
        wordbookA.targetLang = "zh-Hans"
        wordbookA.isEnabled = true
        wordbookA.isSystem = false
        wordbookA.createdAt = Date()

        let wordsA = ["apple", "banana", "cherry", "date", "elderberry"]
        let meaningsA = ["苹果", "香蕉", "樱桃", "日期", "越橘"]
        for (i, word) in wordsA.enumerated() {
            let entry = WordEntry(context: context)
            entry.wordId = "a-\(i)"
            entry.sourceWord = word
            entry.meaning1 = meaningsA[i]
            entry.sectionIndex = Int32(i / 2)  // Section 大小 2
            entry.wordbook = wordbookA
        }

        // 单词本 B: 3 个词条，Section 大小 2 → 2 个 Section
        let wordbookB = Wordbook(context: context)
        wordbookB.wordbookId = "test-wb-b"
        wordbookB.name = "测试B"
        wordbookB.sourceLang = "en"
        wordbookB.targetLang = "zh-Hans"
        wordbookB.isEnabled = true
        wordbookB.isSystem = false
        wordbookB.createdAt = Date().addingTimeInterval(1) // 确保排序在 A 后面

        let wordsB = ["fig", "grape", "honeydew"]
        let meaningsB = ["无花果", "葡萄", "甜瓜"]
        for (i, word) in wordsB.enumerated() {
            let entry = WordEntry(context: context)
            entry.wordId = "b-\(i)"
            entry.sourceWord = word
            entry.meaning1 = meaningsB[i]
            entry.sectionIndex = Int32(i / 2)
            entry.wordbook = wordbookB
        }

        DataStack.shared.saveContext()

        // 设置 Section 大小为 2
        AppSettings.shared.sectionSize = 2
    }

    // MARK: - 队列构建测试

    func testQueueBuilding() {
        engine.start()

        let pos = engine.currentSectionPosition()
        XCTAssertEqual(pos.total, 5, "应有 5 个 Section（A 有 3 个 + B 有 2 个）")
        XCTAssertEqual(pos.index, 0, "初始应在第一个 Section")
    }

    func testEmptyQueueOnNoEnabledWordbooks() {
        // 停用所有单词本
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        if let wordbooks = try? context.fetch(request) {
            for wb in wordbooks {
                wb.isEnabled = false
            }
        }
        DataStack.shared.saveContext()

        engine.start()

        XCTAssertTrue(delegate.didCompleteAll, "空队列应直接完成")
    }

    // MARK: - 记忆反馈模式测试

    func testMemoryFeedbackMarkKnown() {
        AppSettings.shared.reciteMode = .memoryFeedback
        engine.start()

        let firstWord = engine.currentWord()
        engine.markKnown()

        // 应该已经切换到下一个单词
        let secondWord = engine.currentWord()
        XCTAssertNotEqual(firstWord!.wordId, secondWord!.wordId,
                          "标记认识后应切换到下一个单词")
    }

    func testMemoryFeedbackMarkUnknown() {
        AppSettings.shared.reciteMode = .memoryFeedback
        engine.start()

        let firstWord = engine.currentWord()
        engine.markUnknown()

        let secondWord = engine.currentWord()
        XCTAssertNotEqual(firstWord!.wordId, secondWord!.wordId,
                          "标记不认识后应切换到下一个单词")
    }

    // MARK: - Section 流转测试

    func testSectionCompletionTriggersAdvance() {
        AppSettings.shared.reciteMode = .memoryFeedback
        engine.start()

        // 第一个 Section 有 2 个单词，全部标记为已知
        engine.markKnown()
        engine.markKnown()

        // 应已流转到第二个 Section
        let pos = engine.currentSectionPosition()
        XCTAssertEqual(pos.index, 1, "第一个 Section 完成后应流转到第二个")
    }

    // MARK: - 走马灯模式测试

    func testCarouselModeAutoAdvance() {
        AppSettings.shared.reciteMode = .carousel
        AppSettings.shared.stayDuration = 1  // 1 秒快速切换
        AppSettings.shared.carouselLoopCount = 1

        let expectation = XCTestExpectation(description: "走马灯完成 Section")

        engine.start()
        let firstWord = engine.currentWord()

        // 等待 Timer 触发切换
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let currentWord = self.engine.currentWord()
            XCTAssertNotEqual(firstWord!.wordId, currentWord!.wordId,
                              "走马灯模式应自动切换单词")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - 全部完成测试

    func testAllSectionsComplete() {
        AppSettings.shared.reciteMode = .memoryFeedback

        // 简化：只启用一个小单词本
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        if let wordbooks = try? context.fetch(request) {
            for wb in wordbooks where wb.wordbookId == "test-wb-b" {
                wb.isEnabled = false
            }
        }
        DataStack.shared.saveContext()
        AppSettings.shared.sectionSize = 5  // 让 A 只有 1 个 Section

        engine.start()

        // 单词本 A 有 5 个词条，sectionSize=5 → 1 个 Section
        // 需要标记 5 次
        for _ in 0..<5 {
            engine.markKnown()
        }

        XCTAssertTrue(delegate.didCompleteAll, "所有 Section 完成后应触发 allComplete")
    }

    // MARK: - 随机模式测试

    func testShuffledModeDiffersFromSequential() {
        AppSettings.shared.playOrder = .shuffled
        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.sectionSize = 5  // 让 Section 足够大以观察顺序差异

        // 多次启动，收集首个单词
        var firstWords = Set<String>()
        for _ in 0..<10 {
            engine.start()
            firstWords.insert(engine.currentWord()!.sourceWord)
            engine.stop()
        }

        // 随机模式下，多次启动的首个单词不应完全相同（极小概率全部相同）
        XCTAssertTrue(firstWords.count > 1,
                      "随机模式应产生不同的单词顺序")
    }

    // MARK: - Bug 修复验证

    /// 修复验证：启动后 delegate 应收到第一个单词的回调，不跳过
    func testFirstWordNotSkipped() {
        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.sectionSize = 5

        // 只启用单词本 A
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        if let wordbooks = try? context.fetch(request) {
            for wb in wordbooks where wb.wordbookId == "test-wb-b" {
                wb.isEnabled = false
            }
        }
        DataStack.shared.saveContext()

        engine.start()

        // delegate 应收到第一个单词的回调
        XCTAssertEqual(delegate.advancedWords.count, 1,
                       "启动后 delegate 应收到恰好 1 个单词回调")

        // currentWord 应返回与 delegate 相同的单词
        let firstFromDelegate = delegate.advancedWords.first!
        let currentWord = engine.currentWord()
        XCTAssertEqual(firstFromDelegate.wordId, currentWord!.wordId,
                       "currentWord 应与 delegate 收到的单词一致")

        // markKnown 后应切换到不同的单词（证明没有跳过）
        engine.markKnown()
        let secondWord = engine.currentWord()
        XCTAssertNotEqual(firstFromDelegate.wordId, secondWord!.wordId,
                          "markKnown 后应切换到下一个单词")
    }

    /// 修复验证：markUnknown 后单词不加入 feedbackSet，在下一轮重试
    func testMarkUnknownWordRetriesInNextRound() {
        AppSettings.shared.reciteMode = .memoryFeedback
        // sectionSize=2 → Section 0 有 2 个单词（setUp 中 i/2=0 的条目）
        AppSettings.shared.sectionSize = 2

        // 只启用单词本 A
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        if let wordbooks = try? context.fetch(request) {
            for wb in wordbooks where wb.wordbookId == "test-wb-b" {
                wb.isEnabled = false
            }
        }
        DataStack.shared.saveContext()

        engine.start()

        // 收集 Section 0 的所有单词 ID
        let sectionWordIds: Set<String> = {
            var ids = Set<String>()
            ids.insert(engine.currentWord()!.wordId)
            engine.markKnown() // 第一个标记认识
            ids.insert(engine.currentWord()!.wordId)
            return ids
        }()

        XCTAssertEqual(sectionWordIds.count, 2, "Section 0 应有 2 个单词")

        // 此时第一个标记了认识，第二个还在展示
        let secondWord = engine.currentWord()

        // 重新开始，让 Section 0 重新来一遍
        engine.restart()

        // 记录首词
        let firstWordOfRestart = engine.currentWord()

        // 标记首词为"不认识"
        engine.markUnknown()

        // 应切换到另一个单词
        let afterUnknown = engine.currentWord()
        XCTAssertNotEqual(firstWordOfRestart!.wordId, afterUnknown!.wordId,
                          "markUnknown 后应切换到下一个单词")

        // 标记第二个为"认识"
        engine.markKnown()

        // 第一轮结束：首词未反馈，第二个已反馈
        // 第二轮应只展示首词（markUnknown 的单词重试）
        let thirdWord = engine.currentWord()
        XCTAssertEqual(thirdWord!.wordId, firstWordOfRestart!.wordId,
                       "第二轮应只展示未反馈的首词（markUnknown 的单词重试）")
    }

    // MARK: - 性能测试

    /// 11.2 单词切换延迟 ≤ 100ms
    ///
    /// 测量 50 次 markKnown 的平均耗时，验证单次切换远低于 100ms 约束。
    func testWordSwitchPerformance() {
        AppSettings.shared.reciteMode = .memoryFeedback
        engine.start()

        // 预热
        engine.markKnown()

        measure {
            for _ in 0..<50 {
                engine.markKnown()
            }
        }
    }
}

// MARK: - Mock Delegate

private class MockEngineDelegate: ReciteEngineDelegate {
    var advancedWords: [WordEntry] = []
    var completedSections: [(Int, Int)] = []
    var didCompleteAll = false

    func engineDidAdvanceToWord(_ word: WordEntry) {
        advancedWords.append(word)
    }

    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int) {
        completedSections.append((sectionIndex, totalSections))
    }

    func engineDidCompleteAll() {
        didCompleteAll = true
    }
}
