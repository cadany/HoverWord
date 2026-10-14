import Foundation
import CoreData

/// 记忆反馈三态反馈类型
///
/// `rawValue` 与 `ReviewState.lastFeedbackRaw` 存储值对应。
enum ReviewFeedback: Int16 {
    /// 认识：升盒并按新盒级重算到期
    case known = 1
    /// 模糊：盒级不变，按模糊间隔重算到期
    case vague = 2
    /// 不认识（超时自动记录）：回盒 1，按短间隔重算到期
    case unknown = 3

    /// 按反馈重算盒级并返回（known 升盒封顶；unknown 回 1；vague 不变）
    ///
    /// - Parameter currentBox: 当前盒级
    func applyBox(to currentBox: Int16) -> Int16 {
        switch self {
        case .known: return min(currentBox + 1, Int16(Constants.srsBoxMax))
        case .unknown: return 1
        case .vague: return currentBox
        }
    }

    /// 反馈对应的跨会话复习间隔
    var reviewInterval: TimeInterval {
        switch self {
        case .known: return Constants.srsBaseInterval
        case .vague: return Constants.srsVagueInterval
        case .unknown: return Constants.srsUnknownInterval
        }
    }
}

/// 单词掌握度（SRS 复习状态）读写服务
///
/// 负责 ReviewState 记录的查询与原子更新。主上下文读写（引擎单线程消费）。
class ReviewStateService {
    static let shared = ReviewStateService()

    private init() {}

    /// 按 wordId 查询复习状态；无记录返回 nil
    func state(for wordId: String) -> ReviewState? {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<ReviewState> = ReviewState.fetchRequest()
        request.predicate = NSPredicate(format: "wordId == %@", wordId)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    /// 记录一次反馈（取或建 + 原子更新 + 即时落盘）
    ///
    /// - Parameters:
    ///   - feedback: 反馈类型
    ///   - wordId: 目标词条
    /// - Returns: 更新后的复习状态（无论取或建）
    @discardableResult
    func record(feedback: ReviewFeedback, for wordId: String) -> ReviewState {
        let context = DataStack.shared.viewContext
        let now = Date()

        // 取或建（wordId 唯一索引保证并发下仍为单条，mergePolicy 兜底）
        let state: ReviewState
        if let existing = self.state(for: wordId) {
            state = existing
        } else {
            state = ReviewState(context: context)
            state.wordId = wordId
            state.boxLevel = 1
            state.cumulativeExposures = 0
        }

        // 更新盒级：known 基于新盒级算间隔，其余基于当前语义
        let newBox = feedback.applyBox(to: state.boxLevel)
        state.boxLevel = newBox

        // known 的间隔按"升盒后"的新盒级计算（基准间隔 × 2^(盒-1)）
        let baseBox = feedback == .known ? newBox : state.boxLevel
        let interval: TimeInterval
        if feedback == .known {
            // 基准间隔可调（默认 1 天），见 AppSettings.reviewBaseIntervalDays
            let baseSeconds = Constants.srsBaseInterval * AppSettings.shared.reviewBaseIntervalDays
            interval = baseSeconds * pow(2.0, Double(max(Int(baseBox) - 1, 0)))
        } else {
            interval = feedback.reviewInterval
        }
        state.dueAt = now.addingTimeInterval(interval)
        state.lastReviewedAt = now
        state.lastFeedbackRaw = feedback.rawValue
        state.cumulativeExposures += 1

        DataStack.shared.saveContext()
        postReviewStateDidChange()
        return state
    }

    /// 查询在指定时间点已到期的全部复习状态（按 dueAt 升序）
    func dueStates(at now: Date = Date()) -> [ReviewState] {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<ReviewState> = ReviewState.fetchRequest()
        request.predicate = NSPredicate(format: "dueAt != nil AND dueAt <= %@", now as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "dueAt", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    /// 清除全部 ReviewState（重置学习记录）
    func resetAll() {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<ReviewState> = ReviewState.fetchRequest()
        if let states = try? context.fetch(request) {
            for state in states {
                context.delete(state)
            }
            DataStack.shared.saveContext()
            postReviewStateDidChange()
        }
    }

    // MARK: - 学习统计只读聚合

    /// 掌握度聚合结果（学习统计只读查询，口径见 change feat05 D2/D6/D7）
    ///
    /// 三态口径：已掌握 = boxLevel 达上限（`Constants.srsBoxMax`）、进行中 = 1-4、
    /// 未学 = 无 ReviewState 记录；待复习 = dueAt ≤ 统计时刻且词条在聚合范围内
    /// （与引擎全局复习队列的到期词取数口径一致）；孤儿记录（词条已删除）不计入。
    struct MasterySummary: Equatable {
        /// 范围内词条总数（未学的分母）
        var wordCount: Int = 0
        /// 已掌握词数
        var mastered: Int = 0
        /// 进行中词数
        var inProgress: Int = 0
        /// 待复习词数
        var dueForReview: Int = 0
        /// 累计曝光次数之和
        var totalExposures: Int = 0
        /// 最近学习时间（范围内 max lastReviewedAt；无记录为 nil）
        var lastReviewedAt: Date?

        /// 未学词数（无 ReviewState 记录的词条）
        var unlearned: Int {
            wordCount - mastered - inProgress
        }
    }

    /// 聚合指定词本范围的掌握度统计
    ///
    /// 单次 fetch 全量 ReviewState + 范围内词条 wordId 集合后内存 join，
    /// 一次调用同时产出各词本汇总与范围总览（统计页无需逐词本 N+1 查询）。
    /// 收藏夹词条的 wordId 即 favoriteId（见 `favoriteToWordEntry` 转换约定）。
    ///
    /// - Parameters:
    ///   - wordbookIds: 聚合范围（学习统计页传当前启用词本 id）
    ///   - now: 统计时刻（待复习判定基准）
    /// - Returns: wordbooks 为各词本汇总（key 为 wordbookId），total 为范围总览
    func masterySummaries(
        wordbookIds: [String],
        now: Date = Date()
    ) -> (wordbooks: [String: MasterySummary], total: MasterySummary) {
        let context = DataStack.shared.viewContext
        var wordbookByWordId: [String: String] = [:]

        // 范围内普通词条的 wordId 归属
        if !wordbookIds.isEmpty {
            let entryRequest: NSFetchRequest<WordEntry> = WordEntry.fetchRequest()
            entryRequest.predicate = NSPredicate(format: "wordbook.wordbookId IN %@", wordbookIds)
            let entries = (try? context.fetch(entryRequest)) ?? []
            for entry in entries {
                guard let owner = entry.wordbook?.wordbookId else { continue }
                wordbookByWordId[entry.wordId] = owner
            }
        }

        // 收藏夹启用时纳入：全部收藏词条归属系统收藏夹词本
        if let favoritesWordbook = WordbookService.shared.getFavoritesWordbook(),
           wordbookIds.contains(favoritesWordbook.wordbookId) {
            let favoriteRequest: NSFetchRequest<Favorite> = Favorite.fetchRequest()
            let favoriteRecords = (try? context.fetch(favoriteRequest)) ?? []
            for favorite in favoriteRecords {
                wordbookByWordId[favorite.favoriteId] = favoritesWordbook.wordbookId
            }
        }

        var summaries: [String: MasterySummary] = [:]
        for id in wordbookIds {
            summaries[id] = MasterySummary()
        }

        // wordId 归属计数（未学分母）与 ReviewState join（孤儿记录自然排除）
        var wordCountByWordbook: [String: Int] = [:]
        for owner in Set(wordbookByWordId.values) {
            wordCountByWordbook[owner] = 0
        }
        for (_, owner) in wordbookByWordId {
            wordCountByWordbook[owner, default: 0] += 1
        }
        for (id, count) in wordCountByWordbook {
            summaries[id]?.wordCount = count
        }

        let stateRequest: NSFetchRequest<ReviewState> = ReviewState.fetchRequest()
        let states = (try? context.fetch(stateRequest)) ?? []
        for state in states {
            guard let owner = wordbookByWordId[state.wordId], summaries[owner] != nil else { continue }
            var summary = summaries[owner]!
            if state.boxLevel >= Int16(Constants.srsBoxMax) {
                summary.mastered += 1
            } else {
                summary.inProgress += 1
            }
            if let dueAt = state.dueAt, dueAt <= now {
                summary.dueForReview += 1
            }
            summary.totalExposures += Int(state.cumulativeExposures)
            if let reviewedAt = state.lastReviewedAt {
                summary.lastReviewedAt = max(summary.lastReviewedAt ?? reviewedAt, reviewedAt)
            }
            summaries[owner] = summary
        }

        var total = MasterySummary()
        for summary in summaries.values {
            total.wordCount += summary.wordCount
            total.mastered += summary.mastered
            total.inProgress += summary.inProgress
            total.dueForReview += summary.dueForReview
            total.totalExposures += summary.totalExposures
            if let reviewedAt = summary.lastReviewedAt {
                total.lastReviewedAt = max(total.lastReviewedAt ?? reviewedAt, reviewedAt)
            }
        }
        return (summaries, total)
    }

    /// 落盘后广播数据变更（学习统计刷新用，不携带引擎副作用）
    private func postReviewStateDidChange() {
        NotificationCenter.default.post(name: .reviewStateDidChange, object: nil)
    }
}