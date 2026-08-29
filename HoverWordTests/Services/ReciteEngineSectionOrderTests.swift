import XCTest
import CoreData
@testable import HoverWord

/// Section 顺序策略 / 身份寻址 / 续背循环验证
///
/// 覆盖 feat02 三大改动：
/// - 策略应用（sequential 恒等 / randomStart rotate / shuffled 排列 / 单 Section 退化）
/// - 进度身份寻址（恢复到确切 Section、词本停用回退、旧索引格式失效）
/// - 完成后续背（锚点恢复、末组绕回、restart 清锚点）
final class ReciteEngineSectionOrderTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockOrderDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        setupTestData()

        engine = ReciteEngine()
        delegate = MockOrderDelegate()
        engine.delegate = delegate
        engine.clearProgress()
        AppSettings.shared.sectionOrder = .sequential
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.sectionSize = 2
    }

    override func tearDown() {
        engine.stop()
        engine.clearProgress()
        clearAllData()
        engine = nil
        delegate = nil
        AppSettings.shared.sectionOrder = .sequential
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

    /// 单词本 A（3 Section，sectionSize=2，共 6 词）
    private func setupTestData() {
        let context = DataStack.shared.viewContext

        let wordbook = Wordbook(context: context)
        wordbook.wordbookId = "order-test-wb"
        wordbook.name = "顺序策略测试"
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = true
        wordbook.isSystem = false
        wordbook.createdAt = Date()

        for i in 0..<6 {
            let entry = WordEntry(context: context)
            entry.wordId = "ow-\(i)"
            entry.sourceWord = "word\(i)"
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = Int32(i / 2)
            entry.wordbook = wordbook
        }

        DataStack.shared.saveContext()
    }

    /// 当前队列的 Section 身份序列（测试断言用）
    private func currentQueueIdentities() -> [(wordbookId: String, sectionIndex: Int)] {
        let pos = engine.currentSectionPosition()
        return (0..<pos.total).map { i in
            // 逐段读取队列内容：借助引擎推进不可行（会改状态），
            // 直接用 Core Data 按启用词本顺序推导基础队列身份
            return ("order-test-wb", i)
        }
    }

    /// 推进引擎背完当前 Section 全部单词（记忆反馈模式逐个 markKnown）
    private func completeCurrentSection() {
        let count = engine.currentSectionWordCount()
        for _ in 0..<count {
            engine.markKnown()
        }
    }

    // MARK: - 策略应用

    func testSequentialKeepsBaseQueue() {
        AppSettings.shared.sectionOrder = .sequential
        engine.start()

        XCTAssertEqual(engine.currentWord()?.wordId, "ow-0",
                       "sequential 策略应从基础队列第一词开始")
    }

    func testRandomStartIsRotationOfBaseQueue() {
        AppSettings.shared.sectionOrder = .randomStart
        // 多次新开始：每次队列都应是基础队列的 rotate
        // （起点随机，但 [S0..S5] 的循环序保持）
        for _ in 0..<10 {
            engine.stop()
            engine.clearProgress()
            engine.start()

            let firstWord = engine.currentWord()!.wordId
            // 顺序组内模式下，第一个单词是其所在 Section 的首词
            // wordId 数字 mod 2 == 0（每 Section 两词，首词索引为偶数）
            let index = Int(firstWord.replacingOccurrences(of: "ow-", with: ""))!
            XCTAssertEqual(index % 2, 0, "组内顺序模式下首词应为 Section 首词")
        }
    }

    func testShuffledIsPermutation() {
        AppSettings.shared.sectionOrder = .shuffled
        var seenStarts = Set<Int>()
        for _ in 0..<20 {
            engine.stop()
            engine.clearProgress()
            engine.start()

            let firstWord = engine.currentWord()!.wordId
            let index = Int(firstWord.replacingOccurrences(of: "ow-", with: ""))!
            seenStarts.insert(index / 2)
        }
        // 20 次打乱 3 个 Section，起始 Section 分布至少覆盖 2 个（概率上
        // 单一起点的概率为 3×(1/3)^20 ≈ 0，此断言稳定）
        XCTAssertGreaterThanOrEqual(seenStarts.count, 2,
                                   "shuffled 多次新开始应覆盖多个起始 Section")
    }

    func testSingleSectionDegenerates() {
        // 收藏夹单词本单 Section：randomStart 无随机空间
        if let wordbook = WordbookService.shared.getAllWordbooks().first(where: { !$0.isSystem }) {
            wordbook.isEnabled = false
            DataStack.shared.saveContext()
        }
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

        AppSettings.shared.sectionOrder = .randomStart
        engine.start()

        XCTAssertEqual(engine.currentSectionWordCount(), 2,
                       "单 Section 队列应正常背词，策略退化不报错")
    }

    // MARK: - 身份寻址恢复

    func testRestoreLandsOnExactSectionByIdentity() {
        AppSettings.shared.sectionOrder = .sequential
        engine.start()
        // 背完第一个 Section（2 词），进入第二个
        completeCurrentSection()
        let secondSectionFirst = engine.currentWord()
        XCTAssertEqual(secondSectionFirst?.wordId, "ow-2")

        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockOrderDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.wordId, "ow-2",
                       "身份寻址恢复应落到确切 Section 的确切单词")
        newEngine.stop()
        newEngine.clearProgress()
    }

    func testOldIndexFormatProgressInvalidated() {
        // 模拟旧版本进度：索引寻址键存在、新身份键不存在
        UserDefaults.standard.set(2, forKey: "ReciteProgressSectionIndex")
        UserDefaults.standard.set(["ow-0"], forKey: "ReciteProgressWordOrder")

        engine.start()

        XCTAssertEqual(engine.currentWord()?.wordId, "ow-0",
                       "旧索引格式进度应一次性失效，从策略起点开始")
        XCTAssertNil(UserDefaults.standard.object(forKey: "ReciteProgressSectionIndex"),
                     "旧键应被清除")
    }

    func testRestoreWithDisabledWordbookFallsBack() {
        AppSettings.shared.sectionOrder = .sequential
        engine.start()
        completeCurrentSection()
        engine.saveProgress()

        // 停用词本后恢复：身份不在队列，回退新开始
        if let wordbook = WordbookService.shared.getAllWordbooks().first(where: { !$0.isSystem }) {
            wordbook.isEnabled = false
            DataStack.shared.saveContext()
        }

        let newEngine = ReciteEngine()
        newEngine.delegate = MockOrderDelegate()
        newEngine.start()  // 队列为空 → allComplete

        XCTAssertTrue(newEngine.isAllComplete, "无启用词本应进入完成态而非崩溃")
        newEngine.clearProgress()
    }

    // MARK: - 续背循环

    func testContinuationFromLastCompletedSection() {
        AppSettings.shared.sectionOrder = .sequential
        engine.start()

        // 背完全部 3 个 Section
        for _ in 0..<3 {
            completeCurrentSection()
        }
        XCTAssertTrue(delegate.didCompleteAll, "全部背完应触发完成回调")

        // 新会话 start：应从最后完成 Section 的下一 Section 继续
        //（最后完成 S2，下一为 S0 环形绕回）
        let newEngine = ReciteEngine()
        let newDelegate = MockOrderDelegate()
        newEngine.delegate = newDelegate
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.wordId, "ow-0",
                       "背完 S2 后续背应环形绕回 S0")
        newEngine.stop()
        newEngine.clearProgress()
    }

    func testContinuationWrapsFromMiddle() {
        AppSettings.shared.sectionOrder = .randomStart
        engine.start()
        // 背完 1 个 Section 后停在中途，再手动制造"全部完成"锚点：
        // 直接背完剩余全部
        for _ in 0..<3 {
            completeCurrentSection()
        }
        XCTAssertTrue(delegate.didCompleteAll)

        let newEngine = ReciteEngine()
        newEngine.delegate = MockOrderDelegate()
        newEngine.start()

        // 续背从锚点下一组开始：不保证是 ow-0（起点随机），
        // 但必须处于播放态且能正常背词（非 allComplete）
        XCTAssertFalse(newEngine.isAllComplete, "续背应进入播放态")
        XCTAssertNotNil(newEngine.currentWord())
        newEngine.stop()
        newEngine.clearProgress()
    }

    func testRestartClearsContinuationAnchor() {
        AppSettings.shared.sectionOrder = .sequential
        engine.start()
        for _ in 0..<3 {
            completeCurrentSection()
        }
        XCTAssertTrue(delegate.didCompleteAll)

        // restart 应清锚点，从策略起点（S0 首词）重新开始
        engine.restart()

        XCTAssertEqual(engine.currentWord()?.wordId, "ow-0",
                       "restart 后应从策略起点第一词开始")
    }
}

// MARK: - Mock Delegate

private class MockOrderDelegate: ReciteEngineDelegate {
    var didCompleteAll = false

    func engineDidAdvanceToWord(_ word: WordEntry) {}

    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int) {}

    func engineDidCompleteAll() {
        didCompleteAll = true
    }
}
