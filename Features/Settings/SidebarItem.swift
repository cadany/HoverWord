import SwiftUI

/// Sidebar 导航项模型
///
/// 定义设置窗口左侧 sidebar 的导航项：图标 + 文字标签。
/// 每个项对应一个 Tab 页内容。标签存词条 key，渲染时按界面语言查词。
struct SidebarItem: Identifiable, Hashable {
    let id: String
    let labelKey: String
    let icon: String  // SF Symbol name

    /// 按当前界面语言解析的显示标签
    var label: String {
        return L10n.t(labelKey)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 预定义导航项

extension SidebarItem {
    static let wordbook = SidebarItem(id: "wordbook", labelKey: "sidebar.wordbook", icon: "book")
    static let recite = SidebarItem(id: "recite", labelKey: "sidebar.recite", icon: "arrow.triangle.2.circlepath")
    static let appearance = SidebarItem(id: "appearance", labelKey: "sidebar.appearance", icon: "paintbrush")
    static let speech = SidebarItem(id: "speech", labelKey: "sidebar.speech", icon: "speaker.wave.2")
    static let general = SidebarItem(id: "general", labelKey: "sidebar.general", icon: "gearshape")
    static let experience = SidebarItem(id: "experience", labelKey: "sidebar.experience", icon: "wand.and.stars")

    /// 全部导航项，按显示顺序排列
    static let allItems: [SidebarItem] = [.wordbook, .recite, .appearance, .speech, .general, .experience]
}
