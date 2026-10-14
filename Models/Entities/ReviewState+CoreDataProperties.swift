import Foundation
import CoreData

extension ReviewState {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReviewState> {
        return NSFetchRequest<ReviewState>(entityName: "ReviewState")
    }

    /// 词条唯一标识（对应 WordEntry.wordId / Favorite.favoriteId），全局唯一
    @NSManaged public var wordId: String
    /// Leitner 盒级 1-5，默认 1
    @NSManaged public var boxLevel: Int16
    /// 下次到期时间（全局复习队列按此排序纳入调度）
    @NSManaged public var dueAt: Date?
    /// 最近反馈时间
    @NSManaged public var lastReviewedAt: Date?
    /// 最近反馈原始值（0=none 1=known 2=vague 3=unknown）
    @NSManaged public var lastFeedbackRaw: Int16
    /// 累计曝光次数（统计预留）
    @NSManaged public var cumulativeExposures: Int32
}