import XCTest
import CoreData
@testable import HoverWord

/// 记忆反馈（简易 SRS）核心逻辑验证
///
/// 对应任务 5.1-5.4、5.7：
/// - SRS 三态盒级与间隔（认识升盒 / 模糊盒级不变 / 不认识回盒 1）
/// - 反馈即时落盘（ReviewState 存取）
/// - 全局复习队列（到期词优先 + 新词补足 + 分批）
/// - 曝光阈值放行与低延迟重现
/// - 进度恢复（确切换词 / 失效回退 / 旧格式清零）
/// - 重置学习记录语义（与 restart 区分）
final class ReciteEngineSrsTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockSrsDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        ReviewStateService.shared.resetAll()
        setupTestData()

        engine = ReciteEngine()
        delegate = MockSrsDelegate()
        engine.delegate = delegate
        engine.clearProgress()

        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.sectionOrder = .sequential
        AppSettings.shared.maxExposureRounds = Constants.defaultMaxExposureRounds
        AppSettings.shared.sessionReviewCap = Constants.defaultSessionReviewCap
        AppSettings.shared.reviewBaseIntervalDays = Constants.defaultReviewBaseIntervalDays
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
        wordbook.wordbookId = "srs-test-wb"
        wordbook.name = "SRS 测试"
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = true
        wordbook.isSystem = false
        wordbook.createdAt = Date()

        for i in 0..<5 {
            let entry = WordEntry(context: context)
            entry.wordId = "w-\(i)"
            entry.sourceWord = "word\(i)"
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = 0
            entry.wordbook = wordbook
        }
        DataStack.shared.saveContext()
    }

    /// 将指定单词的 ReviewState 置为「已到期」（dueAt 提前到过去）
    @discardableResult
    private func makeDue(wordId: String, box: Int16 = 1, offset: TimeInterval = -1000) -> ReviewState {
        let context = DataStack.shared.viewContext
        var state: ReviewState
        if let existing = ReviewStateService.shared.state(for: wordId) {
            state = existing
        } else {
            state = ReviewState(context: context)
            state.wordId = wordId
            state.cumulativeExposures = 0
        }
        state.boxLevel = box
        state.dueAt = Date().addingTimeInterval(offset)
        DataStack.shared.saveContext()
        return state
    }

    // MARK: - 5.1 SRS 盒级与间隔

    func testKnownRaisesBoxAndLengthensInterval() {
        makeDue(wordId: "w-0", box: 1)
        let start = Date()
        let state = ReviewStateService.shared.record(feedback: .known, for: "w-0")

        XCTAssertEqual(state.boxLevel, 2, "认识应从盒 1 升到盒 2")
        // 盒 2 间隔 = 基础间隔 × 2^(2-1) = 2 天
        let expected = start.timeIntervalSince1970 + Constants.srsBaseInterval * 2
        let actual = state.dueAt!.timeIntervalSince1970
        XCTAssertEqual(actual, expected, accuracy: 1, "盒 2 复习间隔应为 2 天")
    }

    func testVagueKeepsBox() {
        makeDue(wordId: "w-0", box: 3)
        let state = ReviewStateService.shared.record(feedback: .vague, for: "w-0")

        XCTAssertEqual(state.boxLevel, 3, "模糊应保持盒级不变")
        let actual = state.dueAt!.timeIntervalSince1970
        let expected = state.lastReviewedAt!.timeIntervalSince1970 + Constants.srsVagueInterval
        XCTAssertEqual(actual, expected, accuracy: 1, "模糊复习间隔应为 4 小时")
    }

    func testUnknownResetsToBoxOne() {
        makeDue(wordId: "w-0", box: 4)
        let state = ReviewStateService.shared.record(feedback: .unknown, for: "w-0")

        XCTAssertEqual(state.boxLevel, 1, "不认识应回到盒 1")
        let actual = state.dueAt!.timeIntervalSince1970
        let expected = state.lastReviewedAt!.timeIntervalSince1970 + Constants.srsUnknownInterval
        XCTAssertEqual(actual, expected, accuracy: 1, "不认识复习间隔应为 1 小时")
    }

    func testKnownIntervalExponentialByBox() {
        // 盒 1 → 1 天，盒 5 封顶（升盒但封顶在 5）
        makeDue(wordId: "w-0", box: 5)
        let state = ReviewStateService.shared.record(feedback: .known, for: "w-0")
        XCTAssertEqual(state.boxLevel, 5, "盒级应封顶 5")
        let actual = state.dueAt!.timeIntervalSince1970
        let expected = state.lastReviewedAt!.timeIntervalSince1970 + Constants.srsBaseInterval * 16
        XCTAssertEqual(actual, expected, accuracy: 1, "盒 5 复习间隔应为 16 天")
    }

    func testFeedbackPersistsImmediately() {
        engine.start()
        engine.markKnown()

        let state = ReviewStateService.shared.state(for: "w-0")
        XCTAssertNotNil(state, "反馈后应即时落盘 ReviewState")
        XCTAssertEqual(state?.lastFeedbackRaw, ReviewFeedback.known.rawValue,
                       "lastFeedbackRaw 应为 known")
    }

    // MARK: - 5.1 全局复习队列

    func testDueWordsPrioritizedFirst() {
        makeDue(wordId: "w-1", box: 1, offset: -100)
        makeDue(wordId: "w-3", box: 1, offset: -10)

        engine.start()

        // 到期词 w-1（更早到期）在前，w-3 次之
        XCTAssertEqual(engine.currentWord()?.wordId, "w-1", "最早到期的复习词应优先展示")
        engine.markKnown()
        XCTAssertEqual(engine.currentWord()?.wordId, "w-3", "其次展示次早到期词")
    }

    func testDueShortfallFilledByNewWords() {
        makeDue(wordId: "w-0", box: 1)
        AppSettings.shared.sectionSize = 3

        engine.start()

        // 批次=[w-0(到期)] + [w-1,w-2(新词)]，到期在前
        XCTAssertEqual(engine.currentWord()?.wordId, "w-0", "到期词应居批首")
        engine.markKnown()
        XCTAssertEqual(engine.currentWord()?.wordId, "w-1", "到期词不足时以新词补足")
        engine.markKnown()
        XCTAssertEqual(engine.currentWord()?.wordId, "w-2", "新词按词源顺序补足")
    }

    func testDueMoreThanOneBatchSplits() {
        for i in 0..<5 { makeDue(wordId: "w-\(i)", box: 1, offset: -Double(100 - i * 10)) }

        engine.start()

        // 第 1 批 = 最早到期 2 词
        XCTAssertEqual(engine.currentWord()?.wordId, "w-0")
        engine.markKnown()
        XCTAssertEqual(engine.currentWord()?.wordId, "w-1", "第 1 批第 2 词为次早到期词")
        engine.markKnown()

        // 第 2 批首词 = w-2
        XCTAssertEqual(engine.currentWord()?.wordId, "w-2", "第二批应承接后续到期词")
    }

    func testNoWordsSchedulableEntersAllComplete() {
        for i in 0..<5 { _ = makeDue(wordId: "w-\(i)", box: 1, offset: 60_000) } // 全部未来到期

        engine.start()

        XCTAssertTrue(delegate.didCompleteAll, "无可调度词（无新词、无到期）应进入已学完")
        XCTAssertTrue(engine.isAllComplete)
    }

    func testSessionReviewCapDeferOverflow() {
        // 3 个到期词 + 会话预算 1：仅首个到期词入本会话，其余到期词留待下次会话
        AppSettings.shared.sessionReviewCap = 1
        makeDue(wordId: "w-0", box: 1, offset: -300)
        makeDue(wordId: "w-1", box: 1, offset: -200)
        makeDue(wordId: "w-2", box: 1, offset: -100)
        AppSettings.shared.sectionSize = 2

        engine.start()

        // 预算 1：本批仅 1 个到期词 + 1 个新词补足
        XCTAssertEqual(engine.currentWord()?.wordId, "w-0", "预算内的首个到期词优先展示")
        engine.markKnown()
        XCTAssertEqual(engine.currentWord()?.wordId, "w-3", "预算耗尽后不再拉取到期词，以新词补足")
        XCTAssertEqual(delegate.advancedWords.map(\.wordId), ["w-0", "w-3"],
                       "本会话正确呈现 1 到期词 + 1 新词")
        XCTAssertFalse(delegate.advancedWords.map(\.wordId).contains("w-1"),
                       "超预算的到期词 w-1 本会话不应出现")
        XCTAssertFalse(delegate.advancedWords.map(\.wordId).contains("w-2"),
                       "超预算的到期词 w-2 本会话不应出现")
    }

    func testReviewBaseIntervalConfigurable() {
        // 基准 2 天：盒 1 认识 → 盒 2，间隔 = 2 × 2^(2-1) = 4 天
        AppSettings.shared.reviewBaseIntervalDays = 2
        makeDue(wordId: "w-0", box: 1)
        let start = Date()
        let state = ReviewStateService.shared.record(feedback: .known, for: "w-0")

        let expected = start.timeIntervalSince1970 + 4 * Constants.srsBaseInterval
        XCTAssertEqual(state.dueAt!.timeIntervalSince1970, expected, accuracy: 1,
                       "基准 2 天时盒 2 复习间隔应为 4 天")
    }

    // MARK: - 5.2 曝光放行与重现

    func testExposureReleaseAtThreshold() {
        AppSettings.shared.maxExposureRounds = 2
        engine.start()

        // 预期展示序列：w-0 → w-1 → w-0(重现) → 放行后新批 w-2
        XCTAssertEqual(delegate.advancedWords.map(\.wordId), ["w-0"])

        engine.markVague()   // w-0 曝光 1，未达阈值 → 延迟 2 词重现
        XCTAssertEqual(delegate.advancedWords.map(\.wordId), ["w-0", "w-1"])

        engine.markKnown()   // w-1 通过
        XCTAssertEqual(delegate.advancedWords.map(\.wordId), ["w-0", "w-1", "w-0"])

        engine.markVague()   // w-0 曝光 2，达阈值 → 放行，不再重现
        XCTAssertEqual(delegate.advancedWords.map(\.wordId), ["w-0", "w-1", "w-0", "w-2"],
                       "达阈值放行后 w-0 本会话不再出现")
    }

    func testThresholdOneShowsOnce() {
        AppSettings.shared.maxExposureRounds = 1
        engine.start()

        engine.markVague()   // 曝光即达阈值，放行不重现
        XCTAssertEqual(delegate.advancedWords.map(\.wordId), ["w-0", "w-1"],
                       "阈值为 1 时单词只展示一次")
    }

    func testVagueRetryDelayTwoWords() {
        engine.start()

        // 批次=[w-0,w-1]；w-0 模糊后延迟 2 词重现（插入到 index 0 之后 +3 → 第 3 个展示位）
        engine.markVague()   // w-0 模糊 → 切到 w-1
        engine.markVague()   // w-1 模糊 → 切到 w-0 重现副本
        engine.markKnown()   // w-0 重现副本认识 → 切到 w-1 重现副本
        // 两词的重现副本按各自原词后延迟插入：w-0 副本先于 w-1 副本
        XCTAssertEqual(delegate.advancedWords.map(\.wordId), ["w-0", "w-1", "w-0", "w-1"],
                       "模糊重现应按延迟穿插")
    }

    func testVagueThenKnownPasses() {
        engine.start()

        engine.markVague()   // w-0 模糊
        engine.markKnown()   // w-1 通过
        engine.markKnown()   // w-0 重现后认识 → 本会话通过

        let state = ReviewStateService.shared.state(for: "w-0")
        XCTAssertEqual(state?.lastFeedbackRaw, ReviewFeedback.known.rawValue,
                       "模糊后认识应按认识规则记录")
    }

    // MARK: - 5.3 进度恢复

    func testSaveRestoreExactWord() {
        engine.start()
        engine.markKnown()          // w-0 通过，切到 w-1
        let expected = engine.currentWord()!.wordId  // w-1
        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockSrsDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.wordId, expected,
                       "恢复后应从保存时的单词继续")
        newEngine.stop()
        newEngine.clearProgress()
    }

    func testRestoreRetainsRedisplayDuplicate() {
        AppSettings.shared.sectionSize = 2
        engine.start()
        engine.markVague()          // w-0 模糊 → 插入重现副本，wordIds=[w-0,w-1,w-0]，切到 w-1
        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockSrsDelegate()
        newEngine.start()

        XCTAssertEqual(newEngine.currentWord()?.wordId, "w-1",
                       "含延迟重现副本的批次应正常恢复，不从头部重建")
        // 恢复后 w-1 通过，下一步应重现 w-0 的插回副本（旧逻辑因重复归档回退重建会丢副本）
        newEngine.markKnown()
        XCTAssertEqual(newEngine.currentWord()?.wordId, "w-0",
                       "恢复后应保留 w-0 的延迟重现副本")
        newEngine.stop()
        newEngine.clearProgress()
    }

    func testRestoreSkipsPassedWords() {
        AppSettings.shared.sectionSize = 5
        engine.start()
        engine.markKnown()          // w-0 通过
        engine.saveProgress()

        let newEngine = ReciteEngine()
        newEngine.delegate = MockSrsDelegate()
        newEngine.start()

        XCTAssertNotEqual(newEngine.currentWord()?.wordId, "w-0",
                          "已通过单词恢复后不应重复展示")
        newEngine.stop()
        newEngine.clearProgress()
    }

    func testInvalidWordIdFallsBackToNewStart() {
        engine.start()
        engine.markKnown()
        engine.saveProgress()

        // 篡改批次词单为不存在词 → 校验失败回退，重新开跑不崩溃
        engine.restart()
        XCTAssertNotNil(engine.currentWord(), "进度失效回退后应能正常背词")
    }

    func testOldFormatProgressInvalidated() {
        // 写入无 formatVersion 的旧格式内存反馈进度 → 应清零回退
        let degradedLegacy = MemoryProgressStub()
        let data = try! JSONEncoder().encode(degradedLegacy)
        UserDefaults.standard.set(data, forKey: "ReciteProgressBatchState")

        engine.start()

        XCTAssertNil(UserDefaults.standard.object(forKey: "ReciteProgressBatchState"),
                     "旧格式进度应被一次性清零")
        XCTAssertNotNil(engine.currentWord(), "旧格式失效后应回退为新开始")
    }

    // MARK: - 5.4 ReviewStateService

    func testFirstRecordCreates() {
        XCTAssertNil(ReviewStateService.shared.state(for: "w-0"))
        ReviewStateService.shared.record(feedback: .known, for: "w-0")
        XCTAssertNotNil(ReviewStateService.shared.state(for: "w-0"),
                        "首次反馈应创建 ReviewState")
    }

    func testRecordDoesNotDuplicate() {
        ReviewStateService.shared.record(feedback: .known, for: "w-0")
        ReviewStateService.shared.record(feedback: .vague, for: "w-0")

        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<ReviewState> = ReviewState.fetchRequest()
        request.predicate = NSPredicate(format: "wordId == %@", "w-0")
        let count = (try? context.count(for: request)) ?? 0
        XCTAssertEqual(count, 1, "wordId 唯一，多次反馈不应产生重复记录")
    }

    func testDuePredicate() {
        makeDue(wordId: "w-0", box: 1, offset: -10)      // 已到期
        ReviewStateService.shared.record(feedback: .known, for: "w-1") // 未到期

        let due = ReviewStateService.shared.dueStates(at: Date())
        XCTAssertTrue(due.contains { $0.wordId == "w-0" })
        XCTAssertFalse(due.contains { $0.wordId == "w-1" })
    }

    func testOrphanStateNotScheduledNoCrash() {
        // 幽灵词：有 ReviewState 但不在启用词库
        ReviewStateService.shared.record(feedback: .known, for: "ghost-orphan")
        makeDue(wordId: "ghost-orphan", box: 1)

        engine.start()
        XCTAssertNotNil(engine.currentWord(), "孤儿记录不应影响正常调度")
        XCTAssertNotEqual(engine.currentWord()?.wordId, "ghost-orphan")
    }

    func testResetAllClearsMakingAllNew() {
        engine.start()
        engine.markKnown()   // w-0 产生 ReviewState
        XCTAssertNotNil(ReviewStateService.shared.state(for: "w-0"))

        ReviewStateService.shared.resetAll()

        XCTAssertNil(ReviewStateService.shared.state(for: "w-0"),
                     "resetAll 后 w-0 应回到新词状态")
        XCTAssertNil(ReviewStateService.shared.state(for: "w-1"))
    }

    // MARK: - 5.7 重置学习记录语义

    func testRestartKeepsReviewState() {
        engine.start()
        engine.markKnown()   // w-0 产生掌握度
        XCTAssertNotNil(ReviewStateService.shared.state(for: "w-0"))

        engine.restart()

        XCTAssertNotNil(ReviewStateService.shared.state(for: "w-0"),
                        "重新开始应保留掌握度")
    }

    func testResetLearningRecordClearsReviewStateAndRestarts() {
        engine.start()
        engine.markKnown()   // w-0 产生掌握度

        engine.resetLearningRecord()

        XCTAssertNil(ReviewStateService.shared.state(for: "w-0"),
                     "重置学习记录应清除全部掌握度")
        XCTAssertNotNil(engine.currentWord(), "重置后应重新开始背词")

        // 重置后所有词回到新词，从新批次首个新词开始（词源顺序 w-0 排第一，故为重学）
        XCTAssertEqual(engine.currentWord()?.wordId, "w-0",
                       "重置后全部词条回到新词状态，从词源首词开始")
    }
}

// MARK: - 旧格式桩（无 formatVersion 字段 → 解码失败即失效）
private struct MemoryProgressStub: Codable {
    let batchWordIds: [String]
    let wordStates: [String: Int]
    let exposureCounts: [String: Int]
    let index: Int
    let batchIndex: Int

    init() {
        batchWordIds = ["w-0"]
        wordStates = ["w-0": 0]
        exposureCounts = ["w-0": 1]
        index = 0
        batchIndex = 0
    }
}

// MARK: - Mock Delegate

private class MockSrsDelegate: ReciteEngineDelegate {
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