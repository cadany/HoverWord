import Foundation

/// Section 顺序策略枚举
///
/// 作用于 Section 队列层面（Section 之间的先后顺序），
/// 与 Section 内展示顺序（PlayOrder）正交：后者仅管单个 Section 内部的单词顺序。
/// 策略仅在新开始时执行随机化，恢复进行中进度时按持久化布局还原队列。
enum SectionOrder: String, Codable, CaseIterable {
    /// 顺序从第一个 Section 开始：队列即基础队列（词本顺序 × Section 升序）
    case sequential

    /// 随机起点：新开始时随机选起点 Section，队列 rotate 至该起点，
    /// 之后顺序推进（环形语义——保留词书相邻段落局部性）
    case randomStart

    /// 随机打乱：新开始时打乱全部 Section 顺序（曝光分布最均匀）
    case shuffled

    /// 用户可读的显示名称（计算属性实时查词，语言切换即时生效）
    var displayName: String {
        switch self {
        case .sequential: return L10n.t("enum.sectionOrder.sequential")
        case .randomStart: return L10n.t("enum.sectionOrder.randomStart")
        case .shuffled: return L10n.t("enum.sectionOrder.shuffled")
        }
    }

    /// 分段控件等紧凑场景的短文案（计算属性实时查词）
    var shortDisplayName: String {
        switch self {
        case .sequential: return L10n.t("enum.sectionOrder.sequential.short")
        case .randomStart: return L10n.t("enum.sectionOrder.randomStart.short")
        case .shuffled: return L10n.t("enum.sectionOrder.shuffled.short")
        }
    }
}
