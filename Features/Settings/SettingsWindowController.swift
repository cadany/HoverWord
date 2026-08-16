import AppKit
import SwiftUI

/// 主设置窗口控制器
///
/// Liquid Glass 玻璃材质 + sidebar 导航设计。
/// 使用 NavigationSplitView 实现左侧 sidebar + 右侧内容区布局。
/// 包含 5 个导航项：单词本 / 背记 / 外观 / 发音 / 通用。
/// 持有 LanguageManager：界面语言切换时整树重建 + 窗口标题刷新。
class SettingsWindowController: NSWindowController {

    private let languageManager = LanguageManager()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Constants.settingsWindowWidth, height: Constants.settingsWindowHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.t("settings.title")
        window.center()
        window.minSize = NSSize(
            width: Constants.settingsWindowMinWidth,
            height: Constants.settingsWindowMinHeight
        )

        // 窗口透明：让 SwiftUI .regularMaterial / .thinMaterial 能透出桌面，呈现玻璃质感
        window.isOpaque = false
        window.backgroundColor = .clear

        // 窗口委托：关闭时隐藏而非退出
        window.delegate = SettingsWindowDelegate.shared

        self.init(window: window)

        // self 初始化完成后再装配依赖 LanguageManager 的内容与观察者
        let rootView = SettingsRootView(languageManager: languageManager)
        window.contentView = NSHostingView(rootView: rootView)

        // 界面语言切换时刷新窗口标题（SwiftUI 树由 LanguageManager 驱动重建）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: .appLanguageDidChange,
            object: nil
        )
    }

    @objc private func handleLanguageChange() {
        window?.title = L10n.t("settings.title")
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
/// 整窗 Liquid Glass 材质。语言切换时以 `.id(languageManager.current)`
/// 强制重建子树，所有 L10n 查词随重建生效（选中项等父层状态保持）。
struct SettingsRootView: View {
    @ObservedObject var languageManager: LanguageManager
    @State private var selectedItemId: String = SidebarItem.wordbook.id
    /// 已访问过的页面集合：首次访问后常驻层级，切换仅改透明度。
    /// Group+switch 每次切换都会销毁重建整页（ColorPicker/字体菜单等重控件
    /// 反复实例化，是切换卡顿的根因），常驻后 @State 与滚动位置也得以保留。
    @State private var visited: Set<String> = [SidebarItem.wordbook.id]

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
            // 内容区：所有已访问页叠放，仅当前页可见（懒加载 + 常驻）
            ZStack {
                tabPage(SidebarItem.wordbook.id) { WordbookTabView() }
                tabPage(SidebarItem.recite.id) { ReciteSettingsView() }
                tabPage(SidebarItem.appearance.id) { AppearanceView() }
                tabPage(SidebarItem.speech.id) { SpeechSettingsView() }
                tabPage(SidebarItem.general.id) { GeneralSettingsView() }
            }
            .optionalLiquidGlassBackground(.content)
            .animation(.spring(duration: 0.2), value: selectedItemId)
            .onChange(of: selectedItemId) { newId in
                visited.insert(newId)
            }
            // 后台预热：窗口打开后错峰构建其余页面（60ms 间隔），
            // 将首次访问的构建成本从"点击那一刻"挪到打开设置窗后的空闲时段
            .task {
                for item in SidebarItem.allItems where !visited.contains(item.id) {
                    try? await Task.sleep(nanoseconds: 60_000_000)
                    guard !Task.isCancelled else { return }
                    visited.insert(item.id)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .environmentObject(languageManager)
        .id(languageManager.current)
        .frame(
            minWidth: Constants.settingsWindowMinWidth,
            minHeight: Constants.settingsWindowMinHeight
        )
    }

    /// 单个设置页容器：首次访问时加入层级，此后常驻；
    /// 非选中页透明且不参与命中测试，保持各自状态不销毁
    @ViewBuilder
    private func tabPage<Content: View>(
        _ id: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if visited.contains(id) {
            content()
                .opacity(selectedItemId == id ? 1 : 0)
                .allowsHitTesting(selectedItemId == id)
                .accessibilityHidden(selectedItemId != id)
        }
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
