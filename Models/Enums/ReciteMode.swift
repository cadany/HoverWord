import Foundation

/// 背记模式枚举
///
/// 全局二选一，切换模式后背记进度重置。
enum ReciteMode: String, Codable, CaseIterable {
    /// 记忆反馈模式：用户主动标记"认识/不认识"，确保记忆效果
    case memoryFeedback

    /// 走马灯式刷词模式：纯被动视觉曝光，无需用户操作
    case carousel

    /// 用户可读的显示名称
    var displayName: String {
        switch self {
        case .memoryFeedback: return "记忆反馈模式"
        case .carousel: return "走马灯式刷词模式"
        }
    }
}
