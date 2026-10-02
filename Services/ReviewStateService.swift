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
        }
    }
}