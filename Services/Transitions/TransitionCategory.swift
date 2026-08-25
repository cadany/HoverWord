import Foundation

/// 动效分类
///
/// 用于设置界面的分组展示，将动效按风格归类。
enum TransitionCategory: String, Codable, CaseIterable, Sendable {
    /// 简约风格：轻量、克制、低干扰
    case minimal
    /// 趣味风格：有趣、有设计感、有记忆点
    case playful
    /// 沉浸风格：视觉冲击、动态感强
    case immersive

    /// 分类显示名称（本地化）
    var displayName: String {
        switch self {
        case .minimal:
            return L10n.t("settings.transition.category.minimal")
        case .playful:
            return L10n.t("settings.transition.category.playful")
        case .immersive:
            return L10n.t("settings.transition.category.immersive")
        }
    }
}
