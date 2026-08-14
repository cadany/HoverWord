import AppKit
import SwiftUI

/// 主设置窗口控制器
///
/// 标准标题栏 + Liquid Glass 内容区设计。窗口内嵌 SwiftUI TabView，
/// 包含 4 个 Tab 页：单词本管理 / 背记规则 / 外观 / 发音。
class SettingsWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "HoverWord 设置"
        window.center()

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
struct SettingsRootView: View {
    var body: some View {
        TabView {
            WordbookTabView()
                .tabItem { Label("单词本", systemImage: "book") }

            ReciteSettingsView()
                .tabItem { Label("背记", systemImage: "arrow.triangle.2.circlepath") }

            AppearanceView()
                .tabItem { Label("外观", systemImage: "paintbrush") }

            SpeechSettingsView()
                .tabItem { Label("发音", systemImage: "speaker.wave.2") }
        }
        .frame(minWidth: 640, minHeight: 520)
    }
}
