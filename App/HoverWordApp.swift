import SwiftUI

/// HoverWord 应用入口
///
/// 使用 SwiftUI 的 @main 属性作为应用入口，实际生命周期与窗口管理
/// 委托给 AppDelegate 处理，以支持 AppKit 级别的精细控制（Dock 图标、
/// 悬浮窗管理等）。
@main
struct HoverWordApp: App {
    /// 使用 NSApplicationDelegateAdaptor 桥接 AppDelegate，
    /// 使其接收完整的应用生命周期回调。
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 不通过 SwiftUI Scene 创建任何窗口。
        // 所有窗口（主设置窗口 + 悬浮窗）由 AppDelegate 使用 AppKit 管理。
        // 保留 Settings scene 以生成标准应用菜单，但重写其默认设置项：
        // ⌘, 与菜单栏"HoverWord 设置…"均打开 AppKit 管理的设置窗口。
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(L10n.t("menu.appSettings")) {
                    AppDelegate.shared.showSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
