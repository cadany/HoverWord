import SwiftUI

/// Sidebar 导航项模型
///
/// 定义设置窗口左侧 sidebar 的导航项：图标 + 文字标签。
/// 每个项对应一个 Tab 页内容。
struct SidebarItem: Identifiable, Hashable {
    let id: String
    let label: String
    let icon: String  // SF Symbol name

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 预定义导航项

extension SidebarItem {
    static let wordbook = SidebarItem(id: "wordbook", label: "单词本", icon: "book")
    static let recite = SidebarItem(id: "recite", label: "背记", icon: "arrow.triangle.2.circlepath")
    static let appearance = SidebarItem(id: "appearance", label: "外观", icon: "paintbrush")
    static let speech = SidebarItem(id: "speech", label: "发音", icon: "speaker.wave.2")

    /// 全部导航项，按显示顺序排列
    static let allItems: [SidebarItem] = [.wordbook, .recite, .appearance, .speech]
}
