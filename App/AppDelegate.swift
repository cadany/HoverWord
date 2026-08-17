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

    private var fullscreenObservers: [NSObjectProtocol] = []

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
        for observer in fullscreenObservers {
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
        // 活跃空间切换：进入/退出全屏必然伴随空间变化
        fullscreenObservers.append(NotificationCenter.default.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreenState()
        })

        // 任意前台应用激活：覆盖"切换前台应用但不切空间"的入口
        //（原 NSApplication.didBecomeActive 仅本应用激活，检测不到其他应用场景）
        fullscreenObservers.append(NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreenState()
        })
    }

    private func checkFullscreenState() {
        guard AppSettings.shared.fullscreenAutoHide else { return }

        if hasFullscreenWindowOnAnyScreen() {
            floatWindowController?.hideWindowWithAnimation()
        } else {
            floatWindowController?.showWindowWithAnimation()
        }
    }

    /// 屏幕级全屏检测
    ///
    /// 通过 CGWindowList 查询屏幕上的其他进程普通层级（layer 0）窗口，
    /// 存在 bounds 完整覆盖某块屏幕（含菜单栏区域，以此区分"最大化"与"全屏"）
    /// 的窗口即判定为全屏。
    /// 仅读取 ownerPID / layer / bounds，不读窗口标题，无需屏幕录制权限。
    private func hasFullscreenWindowOnAnyScreen() -> Bool {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        let ownPID = getpid()
        let screenFrames = NSScreen.screens.map { $0.frame }

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int,
                  ownerPID != ownPID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.width > 0,
                  bounds.height > 0 else {
                continue
            }
            if screenFrames.contains(where: { NSContainsRect($0, bounds) }) {
                return true
            }
        }
        return false
    }
}
