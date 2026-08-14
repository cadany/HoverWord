import AppKit
import SwiftUI

/// 主设置窗口控制器
///
/// Liquid Glass 玻璃材质 + sidebar 导航设计。
/// 使用 NavigationSplitView 实现左侧 sidebar + 右侧内容区布局。
/// 包含 4 个导航项：单词本 / 背记 / 外观 / 发音。
class SettingsWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Constants.settingsWindowWidth, height: Constants.settingsWindowHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HoverWord 设置"
        window.center()
        window.minSize = NSSize(
            width: Constants.settingsWindowMinWidth,
            height: Constants.settingsWindowMinHeight
        )

        // 窗口透明：让 SwiftUI .regularMaterial / .thinMaterial 能透出桌面，呈现玻璃质感
        window.isOpaque = false
        window.backgroundColor = .clear

        // 内容区使用 SwiftUI 宿主
        let rootView = SettingsRootView()
        let hostingView = NSHostingView(rootView: rootView)
        window.contentView = hostingView

        // 窗口委托：关闭时隐藏而非退出
        window.delegate = SettingsWindowDelegate.shared

        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.center()
    }
}

/// 设置窗口委托
///
/// 拦截关闭事件：隐藏窗口（orderOut）+ 隐藏 Dock 图标，不退出程序。
/// 使用 orderOut 而非 close，确保窗口可重新显示。
class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 隐藏窗口但不销毁，保留 window 实例以便重新显示
        sender.orderOut(nil)
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)
        return false // 阻止真正关闭
    }

    func windowDidBecomeKey(_ notification: Notification) {
        // 恢复 Dock 图标
        NSApp.setActivationPolicy(.regular)
        // 通知内容视图刷新数据（单词本列表等）
        NotificationCenter.default.post(name: .settingsWindowDidBecomeKey, object: nil)
    }
}

/// 设置窗口根视图（SwiftUI）
///
/// NavigationSplitView sidebar 布局：左侧导航 + 右侧内容。
/// 整窗 Liquid Glass 材质。
struct SettingsRootView: View {
    @State private var selectedItemId: String = SidebarItem.wordbook.id

    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(SidebarItem.allItems, selection: $selectedItemId) { item in
                SidebarRow(item: item, isSelected: selectedItemId == item.id)
                    .tag(item.id)
            }
            .listStyle(.sidebar)
            .optionalLiquidGlassBackground(.sidebar)
            .scrollContentBackground(.hidden)
            .navigationSplitViewColumnWidth(
                min: Constants.settingsSidebarWidth,
                ideal: Constants.settingsSidebarWidth,
                max: Constants.settingsSidebarWidth
            )
        } detail: {
            // 内容区
            Group {
                switch selectedItemId {
                case SidebarItem.wordbook.id:
                    WordbookTabView()
                case SidebarItem.recite.id:
                    ReciteSettingsView()
                case SidebarItem.appearance.id:
                    AppearanceView()
                case SidebarItem.speech.id:
                    SpeechSettingsView()
                default:
                    WordbookTabView() // String switch 需要 default 才能编译
                }
            }
            .optionalLiquidGlassBackground(.content)
            .animation(.spring(duration: 0.3), value: selectedItemId)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: Constants.settingsWindowMinWidth,
            minHeight: Constants.settingsWindowMinHeight
        )
    }
}

/// Sidebar 导航行视图
///
/// 图标 + 文字标签，选中态使用玻璃药丸高亮。
private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.system(size: 14))
                .frame(width: 20)
                .foregroundColor(isSelected ? Color.primary : .secondary)
            Text(item.label)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? Color.primary : .secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    isSelected ? Color.accentColor.opacity(0.25) : Color.clear,
                    lineWidth: 0.5
                )
        )
        .animation(.easeOut(duration: Constants.sidebarHoverDuration), value: isHovering)
        .animation(.easeOut(duration: Constants.sidebarHoverDuration), value: isSelected)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.15)
        } else if isHovering {
            return Color.primary.opacity(0.06)
        } else {
            return .clear
        }
    }
}
