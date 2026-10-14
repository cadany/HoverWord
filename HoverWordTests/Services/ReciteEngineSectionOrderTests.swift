import XCTest
import CoreData
@testable import HoverWord

/// Section 顺序策略 / 身份寻址 / 续背循环验证（走马灯模式）
///
/// 记忆反馈改为全局复习队列后，Section 顺序策略、身份寻址、续背锚点均归走马灯专用，
/// 本文件以走马灯模式轻量验证（进度/锚点经 UserDefaults 注入，无需 Timer 推进）。
final class ReciteEngineSectionOrderTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockOrderDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        ReviewStateService.shared.resetAll()
        setupTestData()

        engine = ReciteEngine()
        delegate = MockOrderDelegate()
        engine.delegate = delegate

        AppSettings.shared.sectionOrder = .sequential
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.reciteMode = .carousel
        AppSettings.shared.carouselLoopCount = 1
        AppSettings.shared.sectionSize = 2
        engine.clearProgress()
    }

    override func tearDown() {
        engine.stop()
        engine.clearProgress()
        ReviewStateService.shared.resetAll()
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

    /// 单词本（3 Section，sectionSize=2，共 6 词）
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

    /// 注入一条续背锚点（编码 ReciteEngine.SectionIdentity）
    private func seedAnchor(sectionIndex: Int) {
        let identity = ReciteEngine.SectionIdentity(wordbookId: "order-test-wb", sectionIndex: sectionIndex)
        let data = try! JSONEncoder().encode(identity)
        UserDefaults.standard.set(data, forKey: "ReciteProgressLastCompleted")
    }

    /// 注入一条走马灯进行中进度（身份 + 播放顺序 + 单词索引）
    private func seedProgress(sectionIndex: Int, orderIds: [String], wordIndex: Int) {
        let identity = ReciteEngine.SectionIdentity(wordbookId: "order-test-wb", sectionIndex: sectionIndex)
        let data = try! JSONEncoder().encode(identity)
        UserDefaults.standard.set(data, forKey: "ReciteProgressSectionIdentity")
        UserDefaults.standard.set(orderIds, forKey: "ReciteProgressWordOrder")
        UserDefaults.standard.set(wordIndex, forKey: "ReciteProgressWordIndex")
        UserDefaults.standard.set(0, forKey: "ReciteProgressCompletedLoops")
        UserDefaults.standard.removeObject(forKey: "ReciteProgressQueueLayout")
    }

    // MARK: - 策略应用

    func testSequentialKeepsBaseQueue() {
        AppSettings.shared.sectionOrder = .sequential
        engine.start()
        XCTAssertEqual(engine.currentWord()?.wordId, "ow-0", "sequential 策略应从基础队列第一词开始")
    }

    func testRandomStartIsRotationOfBaseQueue() {
        AppSettings.shared.sectionOrder = .randomStart
        for _ in 0..<10 {
            engine.stop()
            engine.clearProgress()
            engine.start()
            let index = Int(engine.currentWord()!.wordId.replacingOccurrences(of: "ow-", with: ""))!
            XCTAssertEqual(index % 2, 0, "顺时针 rotate 下首词应为某 Section 首词（偶数索引）")
        }
    }

    func testShuffledIsPermutation() {
        AppSettings.shared.sectionOrder = .shuffled
        var seenStarts = Set<Int>()
        for _ in 0..<20 {
            engine.stop()
            engine.clearProgress()
            engine.start()
            let index = Int(engine.currentWord()!.wordId.replacingOccurrences(of: "ow-", with: ""))!
            seenStarts.insert(index / 2)
        }
        XCTAssertGreaterThanOrEqual(seenStarts.count, 2,
                                    "shuffled 多次新开始应覆盖多个起始 Section")
    }

    func testSingleSectionDegenerates() {
        if let normal = WordbookService.shared.getAllWordbooks().first(where: { !$0.isSystem }) {
            normal.isEnabled = false
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
        XCTAssertEqual(engine.currentSectionWordCount(), 2, "单 Section 队列应正常背词，策略退化不报错")
    }

    // MARK: - 身份寻址恢复

    func testRestoreLandsOnExactSectionByIdentity() {
        seedProgress(sectionIndex: 1, orderIds: ["ow-2", "ow-3"], wordIndex: 0)
        engine.start()
        XCTAssertEqual(engine.currentWord()?.wordId, "ow-2",
                       "身份寻址恢复应落到确切 Section 的确切单词")
    }

    func testOldIndexFormatProgressInvalidated() {
        UserDefaults.standard.set(2, forKey: "ReciteProgressSectionIndex")
        UserDefaults.standard.set(["ow-0"], forKey: "ReciteProgressWordOrder")

        engine.start()

        XCTAssertEqual(engine.currentWord()?.wordId, "ow-0", "旧索引格式进度应一次失效，从策略起点开始")
        XCTAssertNil(UserDefaults.standard.object(forKey: "ReciteProgressSectionIndex"),
                     "旧键应被清除")
    }

    func testRestoreWithDisabledWordbookFallsBack() {
        seedProgress(sectionIndex: 0, orderIds: ["ow-0", "ow-1"], wordIndex: 0)

        if let wordbook = WordbookService.shared.getAllWordbooks().first(where: { !$0.isSystem }) {
            wordbook.isEnabled = false
            DataStack.shared.saveContext()
        }

        let newEngine = ReciteEngine()
        newEngine.delegate = MockOrderDelegate()
        newEngine.start()
        XCTAssertTrue(newEngine.isAllComplete, "无启用词本应进入完成态而非崩溃")
        newEngine.clearProgress()
    }

    // MARK: - 续背循环

    func testContinuationFromLastCompletedSection() {
        // 背完 S2（sectionIndex 2）后：续背应从 S2 的下一 Section 环形绕回 S0
        seedAnchor(sectionIndex: 2)
        engine.start()
        XCTAssertEqual(engine.currentWord()?.wordId, "ow-0", "背完末 Section 后续背应环形绕回 S0")
    }

    func testContinuationWrapsFromMiddle() {
        AppSettings.shared.sectionOrder = .randomStart
        // 背完 S1 后：续背应从 S2 开始
        seedAnchor(sectionIndex: 1)
        engine.start()
        XCTAssertFalse(engine.isAllComplete, "续背应进入播放态")
        XCTAssertEqual(engine.currentWord()?.wordId, "ow-4", "S1 完成后续背应落到 S2 首词")
    }

    func testRestartClearsContinuationAnchor() {
        seedAnchor(sectionIndex: 2)
        engine.start()
        XCTAssertEqual(engine.currentWord()?.wordId, "ow-0")

        engine.restart()
        XCTAssertEqual(engine.currentWord()?.wordId, "ow-0",
                       "restart 清除锚点后应从策略起点重新开始")
        XCTAssertNil(UserDefaults.standard.object(forKey: "ReciteProgressLastCompleted"),
                     "restart 应清除续背锚点")
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