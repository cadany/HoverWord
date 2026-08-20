import Foundation

/// 悬浮窗内容显示模式（注音 / 释义共用）
///
/// - always: 始终显示（默认，保持现有行为）
/// - hover: 鼠标进入悬浮窗时淡入，离开时淡出（主动回忆记忆法：先回忆再验证）
/// - hidden: 始终隐藏
enum ContentVisibility: String, Codable, CaseIterable {
    case always
    case hover
    case hidden

    /// 本地化显示名
    var displayName: String {
        switch self {
        case .always: return L10n.t("appearance.displayMode.always")
        case .hover: return L10n.t("appearance.displayMode.hover")
        case .hidden: return L10n.t("appearance.displayMode.hidden")
        }
    }
}
