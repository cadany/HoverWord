import AppKit
import SwiftUI

/// 应用生命周期委托
///
/// 负责：
/// - 应用启动时初始化 Core Data 栈、创建系统收藏夹、打开主设置窗口与悬浮窗
/// - 管理 Dock 图标与主窗口显隐联动
/// - 管理全屏自动隐藏悬浮窗
/// - 作为应用唯一退出入口的协调者
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - 全局单例引用

    /// AppDelegate 全局访问点
    ///
    /// 因 SwiftUI `@NSApplicationDelegateAdaptor` 会创建内部 wrapper 作为 `NSApp.delegate`，
    /// 直接转型 `NSApp.delegate as? AppDelegate` 永远返回 nil，
    /// 故通过此静态属性在 `applicationDidFinishLaunching` 时保存真实实例引用。
    static var shared: AppDelegate!

    // MARK: - 窗口控制器引用

    /// 主设置窗口控制器
    var settingsWindowController: SettingsWindowController?

    /// 悬浮背记窗口控制器
    var floatWindowController: FloatWindowController?

    // MARK: - 全屏检测

    private var fullscreenObserver: NSObjectProtocol?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 保存真实 AppDelegate 实例（供 FloatWindowController 等非 SwiftUI 组件访问）
        AppDelegate.shared = self

        // 1. 初始化 Core Data 栈
        DataStack.shared.initialize()

        // 2. 确保系统收藏夹单词本存在
        WordbookService.shared.ensureSystemFavorites()

        // 3. 加载全局设置
        AppSettings.shared.load()
        SpeechService.shared.applySettings()

        // 4. 打开主设置窗口
        showSettingsWindow()

        // 5. 启动悬浮背记窗口
        showFloatWindow()

        // 6. 监听全屏变化
        setupFullscreenObserver()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 关闭窗口不退出程序，悬浮窗持续运行
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 保存悬浮窗位置
        floatWindowController?.saveWindowPosition()

        // 保存背记进度
        floatWindowController?.saveEngineProgress()

        // 保存全局设置
        AppSettings.shared.save()

        // 保存 Core Data 上下文
        DataStack.shared.saveContext()

        // 移除观察者
        if let observer = fullscreenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - 窗口管理

    /// 显示主设置窗口，同时恢复 Dock 图标
    ///
    /// 重要：必须先将 activation policy 改为 `.regular`，再调用 showWindow。
    /// 因 app 处于 `.accessory` 模式时，makeKeyAndOrderFront 会被窗口服务器拒绝，
    /// 导致窗口即使被 order 也不会显示。
    func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }

        // 第一步：切换到 regular 模式（恢复 Dock 图标 + 允许窗口显示）
        showDockIcon()

        // 第二步：窗口在 regular 模式下才能被正确 orderFront
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 隐藏主设置窗口，同时隐藏 Dock 图标
    func hideSettingsWindow() {
        settingsWindowController?.window?.orderOut(nil)
        // 隐藏 Dock 图标，仅保留悬浮窗作为程序入口
        hideDockIcon()
    }

    /// 显示悬浮背记窗口
    func showFloatWindow() {
        if floatWindowController == nil {
            floatWindowController = FloatWindowController()
        }
        floatWindowController?.showWindow(nil)
    }

    /// 完全退出应用
    func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Dock 图标控制

    /// 显示 Dock 图标
    private func showDockIcon() {
        NSApp.setActivationPolicy(.regular)
    }

    /// 隐藏 Dock 图标
    private func hideDockIcon() {
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - 全屏自动隐藏

    private func setupFullscreenObserver() {
        // 监听空间变化（包括全屏切换）
        fullscreenObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreenState()
        }

        // 也监听窗口变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationDidBecomeActive() {
        checkFullscreenState()
    }

    private func checkFullscreenState() {
        guard AppSettings.shared.fullscreenAutoHide else { return }

        // 遍历所有窗口检查是否存在全屏窗口（排除悬浮窗自身）
        let isFullscreen = NSApp.windows.contains { window in
            window !== floatWindowController?.window
                && window.styleMask.contains(.fullScreen)
        }

        if isFullscreen {
            // 隐藏悬浮窗
            floatWindowController?.window?.orderOut(nil)
        } else {
            // 恢复悬浮窗
            floatWindowController?.window?.orderFront(nil)
        }
    }
}
