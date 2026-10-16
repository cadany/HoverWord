import XCTest
import CoreData
@testable import HoverWord

/// 学习统计只读查询验证
///
/// 对应 feat05 任务 4.1-4.4：
/// - ReviewStateService 掌握度聚合（三态计数 / 待复习口径 / 孤儿排除 / 空范围）
/// - 续背锚点状态判定矩阵（nil / 删除 / 停用 / 有效 / Section 无词条）
/// - record() / resetAll() 触发 reviewStateDidChange
/// - restore 行为回归（锚点判定重构不改变续背恢复结果）
final class LearningStatsTests: XCTestCase {

    private var engine: ReciteEngine!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        ReviewStateService.shared.resetAll()
        setupTestData()

        engine = ReciteEngine()
        engine.clearProgress()

        AppSettings.shared.reciteMode = .carousel
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
        super.tearDown()
    }

    private func clearAllData() {
        let context = DataStack.shared.viewContext
        for entityName in ["WordEntry", "Wordbook", "Favorite", "ReviewState"] {
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
        wordbookA.wordbookId = "stats-wb-a"
        wordbookA.name = "统计词本A"
        wordbookA.sourceLang = "en"
        wordbookA.targetLang = "zh-Hans"
        wordbookA.isEnabled = true
        wordbookA.isSystem = false
        wordbookA.createdAt = Date()
        // Section 0 三词 + Section 1 两词
        for i in 0..<5 {
            let entry = WordEntry(context: context)
            entry.wordId = "w-a-\(i)"
            entry.sourceWord = "statA\(i)"
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = i < 3 ? 0 : 1
            entry.wordbook = wordbookA
        }

        let wordbookB = Wordbook(context: context)
        wordbookB.wordbookId = "stats-wb-b"
        wordbookB.name = "统计词本B"
        wordbookB.sourceLang = "en"
        wordbookB.targetLang = "zh-Hans"
        wordbookB.isEnabled = true
        wordbookB.isSystem = false
        wordbookB.createdAt = Date()
        for i in 0..<2 {
            let entry = WordEntry(context: context)
            entry.wordId = "w-b-\(i)"
            entry.sourceWord = "statB\(i)"
            entry.meaning1 = "释义B\(i)"
            entry.sectionIndex = 0
            entry.wordbook = wordbookB
        }

        DataStack.shared.saveContext()
    }

    /// 直接构造 ReviewState（绕开 record 的间隔重算，精确控制各字段）
    @discardableResult
    private func makeState(
        wordId: String,
        box: Int16,
        dueOffset: TimeInterval? = -1000,
        exposures: Int32 = 1,
        reviewedOffset: TimeInterval = -3600
    ) -> ReviewState {
        let context = DataStack.shared.viewContext
        let state = ReviewState(context: context)
        state.wordId = wordId
        state.boxLevel = box
        state.dueAt = dueOffset.map { Date().addingTimeInterval($0) }
        state.cumulativeExposures = exposures
        state.lastReviewedAt = Date().addingTimeInterval(reviewedOffset)
        DataStack.shared.saveContext()
        return state
    }

    /// 写入续背锚点（与引擎 saveContinuationAnchor 同一存储约定）
    private func writeAnchor(wordbookId: String, sectionIndex: Int) {
        let identity = ReciteEngine.SectionIdentity(wordbookId: wordbookId, sectionIndex: sectionIndex)
        if let data = try? JSONEncoder().encode(identity) {
            UserDefaults.standard.set(data, forKey: "ReciteProgressLastCompleted")
        }
    }

    // MARK: - 4.1 掌握度聚合

    func testMasterySummaryThreeStates() {
        makeState(wordId: "w-a-0", box: Int16(Constants.srsBoxMax))
        makeState(wordId: "w-a-1", box: 2)

        let result = ReviewStateService.shared.masterySummaries(wordbookIds: ["stats-wb-a", "stats-wb-b"])

        let summaryA = result.wordbooks["stats-wb-a"]
        XCTAssertEqual(summaryA?.wordCount, 5, "词本 A 词数应为 5")
        XCTAssertEqual(summaryA?.mastered, 1, "box 达上限应计入已掌握")
        XCTAssertEqual(summaryA?.inProgress, 1, "box 1-4 应计入进行中")
        XCTAssertEqual(summaryA?.unlearned, 3, "无记录词条应计入未学")

        XCTAssertEqual(result.wordbooks["stats-wb-b"]?.unlearned, 2, "无任何记录的词本应全部计入未学")
        XCTAssertEqual(result.total.wordCount, 7)
        XCTAssertEqual(result.total.mastered, 1)
        XCTAssertEqual(result.total.inProgress, 1)
        XCTAssertEqual(result.total.unlearned, 5)
    }

    func testMasterySummaryDueForReviewWindow() {
        makeState(wordId: "w-a-0", box: 1, dueOffset: -1000)   // 已到期
        makeState(wordId: "w-a-1", box: 1, dueOffset: 1000)    // 未来到期
        makeState(wordId: "w-a-2", box: 1, dueOffset: nil)     // 无 dueAt

        let result = ReviewStateService.shared.masterySummaries(wordbookIds: ["stats-wb-a"])
        XCTAssertEqual(result.wordbooks["stats-wb-a"]?.dueForReview, 1, "仅 dueAt 不晚于当前时间的词计入待复习")
        XCTAssertEqual(result.total.dueForReview, 1)
    }

    func testMasterySummaryExcludesOrphans() {
        makeState(wordId: "ghost-word", box: Int16(Constants.srsBoxMax), exposures: 10)

        let result = ReviewStateService.shared.masterySummaries(wordbookIds: ["stats-wb-a"])
        let summaryA = result.wordbooks["stats-wb-a"]
        XCTAssertEqual(summaryA?.mastered, 0, "孤儿记录（词条已删除）不应计入已掌握")
        XCTAssertEqual(summaryA?.wordCount, 5)
        XCTAssertEqual(result.total.totalExposures, 0, "孤儿记录的曝光不应计入累计曝光")
    }

    func testMasterySummaryEmptyRange() {
        let result = ReviewStateService.shared.masterySummaries(wordbookIds: [])
        XCTAssertEqual(result.total.wordCount, 0)
        XCTAssertEqual(result.total.mastered, 0)
        XCTAssertEqual(result.total.inProgress, 0)
        XCTAssertEqual(result.total.unlearned, 0)
        XCTAssertNil(result.total.lastReviewedAt)
    }

    func testMasterySummaryExposuresAndLastReviewed() {
        makeState(wordId: "w-a-0", box: 2, exposures: 2, reviewedOffset: -7200)
        makeState(wordId: "w-a-1", box: 3, exposures: 3, reviewedOffset: -600)

        let result = ReviewStateService.shared.masterySummaries(wordbookIds: ["stats-wb-a"])
        XCTAssertEqual(result.total.totalExposures, 5, "累计曝光应为 Σ cumulativeExposures")
        let lastReviewed = result.total.lastReviewedAt
        XCTAssertNotNil(lastReviewed)
        if let lastReviewed {
            XCTAssertEqual(
                lastReviewed.timeIntervalSince1970,
                Date().addingTimeInterval(-600).timeIntervalSince1970,
                accuracy: 2,
                "最近学习应取 max lastReviewedAt"
            )
        }
    }

    // MARK: - 4.2 锚点判定矩阵

    func testAnchorStateNone() {
        XCTAssertEqual(engine.continuationAnchorState, .none, "无锚点应判定为 none")
    }

    func testAnchorStateValid() {
        writeAnchor(wordbookId: "stats-wb-a", sectionIndex: 0)
        XCTAssertEqual(
            engine.continuationAnchorState,
            .valid(wordbookId: "stats-wb-a", wordbookName: "统计词本A", sectionIndex: 0),
            "词本启用且 Section 有词条应判定为 valid"
        )
    }

    func testAnchorStateWordbookDisabled() {
        writeAnchor(wordbookId: "stats-wb-a", sectionIndex: 0)
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "wordbookId == %@", "stats-wb-a")
        (try? context.fetch(request))?.first?.isEnabled = false
        DataStack.shared.saveContext()

        XCTAssertEqual(engine.continuationAnchorState, .wordbookDisabled, "锚点词本未启用应判定为 wordbookDisabled")
    }

    func testAnchorStateWordbookMissing() {
        writeAnchor(wordbookId: "ghost-wb", sectionIndex: 0)
        XCTAssertEqual(engine.continuationAnchorState, .wordbookMissing, "锚点词本不存在应判定为 wordbookMissing")
    }

    func testAnchorStateSectionInvalid() {
        writeAnchor(wordbookId: "stats-wb-a", sectionIndex: 9)
        XCTAssertEqual(engine.continuationAnchorState, .sectionInvalid, "Section 无词条应判定为 sectionInvalid")
    }

    // MARK: - 4.3 变更通知

    func testRecordPostsReviewStateDidChange() {
        let expectation = expectation(forNotification: .reviewStateDidChange, object: nil)
        ReviewStateService.shared.record(feedback: .known, for: "w-a-0")
        wait(for: [expectation], timeout: 1)
    }

    func testResetAllPostsReviewStateDidChange() {
        makeState(wordId: "w-a-0", box: 1)
        let expectation = expectation(forNotification: .reviewStateDidChange, object: nil)
        ReviewStateService.shared.resetAll()
        wait(for: [expectation], timeout: 1)
    }

    // MARK: - 4.4 restore 行为回归

    func testResumeFromValidAnchorStillRestores() {
        // 合流队列 = 词本 A 两个 Section + 词本 B 一个 Section（共 3），锚点指向 A Section 0，
        // 续背应从锚点的下一 Section（队列索引 1）开始并清除锚点
        writeAnchor(wordbookId: "stats-wb-a", sectionIndex: 0)

        engine.start()

        XCTAssertEqual(engine.currentSectionPosition().total, 3, "合流队列应含 3 个 Section（A 2 + B 1）")
        XCTAssertEqual(
            engine.currentSectionPosition().index, 1,
            "有效锚点应从其下一 Section 续背"
        )
        XCTAssertNil(
            UserDefaults.standard.object(forKey: "ReciteProgressLastCompleted"),
            "续背恢复后锚点应清除（新轮进度由正常保存路径接管）"
        )
    }

    func testStartWithInvalidAnchorFallsBack() {
        // 锚点指向不存在的词本：与旧实现一致，清除锚点后按策略新开始
        writeAnchor(wordbookId: "ghost-wb", sectionIndex: 0)

        engine.start()

        XCTAssertNil(
            UserDefaults.standard.object(forKey: "ReciteProgressLastCompleted"),
            "失效锚点应由 restore 路径清除"
        )
        XCTAssertEqual(engine.currentSectionPosition().index, 0, "失效锚点应回退为新开始")
    }

    // MARK: - 4.5 走马灯实时快照

    func testCarouselProgressSnapshotOnFreshStart() {
        engine.start()

        let snapshot = engine.carouselProgressSnapshot
        XCTAssertEqual(snapshot.sectionIndex, 0, "新开始应位于第一个 Section")
        XCTAssertEqual(snapshot.totalSections, 3, "快照总数应与合流队列一致（A 2 + B 1）")
        XCTAssertEqual(snapshot.wordIndex, 0, "新 Section 应从第一个词开始展示")
        XCTAssertEqual(snapshot.wordCountInSection, 3, "词数应取自当前 Section 实际词条（A Section 0 三词）")
        XCTAssertTrue(snapshot.isActive)
    }

    func testCarouselProgressSnapshotRestoresAnchorPosition() {
        writeAnchor(wordbookId: "stats-wb-a", sectionIndex: 0)
        engine.start()

        let snapshot = engine.carouselProgressSnapshot
        XCTAssertEqual(snapshot.sectionIndex, 1, "快照应反映续背恢复后的 Section 位置")
        XCTAssertEqual(snapshot.wordCountInSection, 2, "A Section 1 应为两词")
        XCTAssertTrue(snapshot.isActive)
    }

    func testIdleSnapshotIsInactive() {
        XCTAssertFalse(ReciteEngine.CarouselProgressSnapshot.idle.isActive, "idle 快照不应视为有效位置")
    }
}
