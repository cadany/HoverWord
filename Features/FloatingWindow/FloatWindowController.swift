import AppKit
import CoreData

/// 悬浮背记窗口控制器
///
/// 无边框圆角玻璃窗口（NSPanel 子类），支持：
/// - 全局置顶（floating level）
/// - 任意区域拖拽
/// - 位置记忆与多显示器支持
/// - 右键菜单（打开设置 / 退出程序）
/// - 单词内容展示与双模式交互
/// - 完成状态展示
class FloatWindowController: NSWindowController {

    // MARK: - 依赖

    private let engine = ReciteEngine()
    private let contentViewContainer = FloatContentView()
    private var rightClickMonitor: Any?

    // MARK: - 初始化

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(
                x: 0, y: 0,
                width: Constants.floatWindowWidth,
                height: Constants.floatWindowMinHeight
            ),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView = nil // 稍后设置

        // 窗口缩放边界
        panel.contentMinSize = NSSize(
            width: Constants.floatWindowMinWidth,
            height: Constants.floatWindowMinHeight
        )
        panel.contentMaxSize = NSSize(
            width: Constants.floatWindowMaxWidth,
            height: Constants.floatWindowMaxHeight
        )

        self.init(window: panel)

        // 设置内容视图
        setupContentView()

        // 设置引擎委托
        engine.delegate = self

        // 监听窗口缩放结束，保存位置与尺寸
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidEndLiveResize),
            name: NSWindow.didEndLiveResizeNotification,
            object: panel
        )

        // 监听窗口移动结束，保存位置（修复拖拽移动后位置不保存的 bug）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification,
            object: panel
        )

        // 恢复位置
        restoreWindowPosition()

        // 右键事件监听（nonactivatingPanel 下 rightMouseDown 可能无法到达视图）
        setupRightClickMonitor()
    }

    deinit {
        if let monitor = rightClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupRightClickMonitor() {
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            guard let self = self, let panel = self.window else { return event }
            // 仅处理本悬浮窗的右键事件
            if event.window === panel {
                self.showContextMenu(event: event)
                return nil // 消费事件
            }
            return event
        }
    }

    // MARK: - 设置

    private func setupContentView() {
        guard let panel = window as? NSPanel else { return }
        contentViewContainer.frame = panel.contentView?.bounds ?? .zero
        contentViewContainer.autoresizingMask = [.width, .height]
        panel.contentView = contentViewContainer

        // 绑定按钮事件
        contentViewContainer.onKnowTap = { [weak self] in
            self?.engine.markKnown()
        }
        contentViewContainer.onUnknownTap = { [weak self] in
            self?.engine.markUnknown()
        }
        contentViewContainer.onFavoriteTap = { [weak self] in
            guard let self = self, let word = self.engine.currentWord() else { return }
            _ = WordbookService.shared.toggleFavorite(
                sourceWord: word.sourceWord,
                wordDetail: word.encodeWordDetail()
            )
            self.contentViewContainer.updateFavoriteState(
                isFavorite: WordbookService.shared.isFavorite(sourceWord: word.sourceWord)
            )
        }
        contentViewContainer.onRightClick = { [weak self] event in
            self?.showContextMenu(event: event)
        }
    }

    override func showWindow(_ sender: Any?) {
        guard let panel = window as? NSPanel else {
            super.showWindow(sender)
            engine.start()
            return
        }

        // 抑制收缩动画期间的 didMoveNotification，避免保存错误的中间帧
        isSuppressingPositionSave = true

        // 设置初始状态：透明 + 微缩
        panel.alphaValue = 0
        let originalFrame = panel.frame
        let shrunkFrame = originalFrame.shrink(by: 0.95)
        panel.setFrame(shrunkFrame, display: true)

        // 显示窗口
        super.showWindow(sender)
        engine.start()

        // 动画到正常状态
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.windowFadeDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
            panel.animator().setFrame(originalFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.isSuppressingPositionSave = false
            // 动画结束后显式保存最终位置，确保与用户上次关闭时一致
            self?.saveWindowPosition()
        })
    }

    /// 带动画隐藏窗口（全屏自动隐藏路径）
    ///
    /// 已隐藏（不可见或透明度已为 0）时跳过，避免重复动画。
    func hideWindowWithAnimation() {
        guard let panel = window as? NSPanel else {
            window?.orderOut(nil)
            return
        }
        guard panel.isVisible, panel.alphaValue > 0 else { return }

        visibilityAnimationToken += 1
        let token = visibilityAnimationToken

        // 保存最终位置（隐藏前的真实位置），再抑制动画期间的通知
        saveWindowPosition()
        isSuppressingPositionSave = true

        let originalFrame = panel.frame
        let shrunkFrame = originalFrame.shrink(by: 0.95)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.windowFadeDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0.0
            panel.animator().setFrame(shrunkFrame, display: true)
        }, completionHandler: { [weak self] in
            guard let self = self, self.visibilityAnimationToken == token else { return }
            panel.orderOut(nil)
            // 恢复 frame 和 alpha，以便下次显示
            panel.setFrame(originalFrame, display: false)
            panel.alphaValue = 1.0
            self.isSuppressingPositionSave = false
        })
    }

    /// 带动画恢复显示窗口（退出全屏路径）
    ///
    /// 纯 UI 恢复：不重启引擎、不重置进度。
    /// 已完整显示时跳过；透明度为 0（隐藏动画进行中或残留）时仍执行以纠正状态。
    func showWindowWithAnimation() {
        guard let panel = window as? NSPanel else { return }
        guard !(panel.isVisible && panel.alphaValue >= 1.0) else { return }

        visibilityAnimationToken += 1
        let token = visibilityAnimationToken
        isSuppressingPositionSave = true

        let originalFrame = panel.frame
        // 初始状态：透明 + 微缩
        panel.alphaValue = 0
        panel.setFrame(originalFrame.shrink(by: 0.95), display: false)
        panel.orderFront(nil)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.windowFadeDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
            panel.animator().setFrame(originalFrame, display: true)
        }, completionHandler: { [weak self] in
            guard let self = self, self.visibilityAnimationToken == token else { return }
            self.isSuppressingPositionSave = false
            // 动画结束后显式保存最终位置
            self.saveWindowPosition()
        })
    }

    // MARK: - 右键菜单

    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(event: event)
    }

    private func showContextMenu(event: NSEvent) {
        let menu = NSMenu()

        // 已学完状态时，顶部插入"重新开始"
        if engine.isAllComplete {
            let restartItem = NSMenuItem(title: L10n.t("float.menu.restart"), action: #selector(menuItemAction(_:)), keyEquivalent: "")
            restartItem.tag = Constants.FloatMenuTag.restart
            restartItem.target = self
            menu.addItem(restartItem)
            menu.addItem(NSMenuItem.separator())
        }

        let settingsItem = NSMenuItem(title: L10n.t("float.menu.settings"), action: #selector(menuItemAction(_:)), keyEquivalent: "")
        settingsItem.tag = Constants.FloatMenuTag.openSettings
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: L10n.t("float.menu.quit"), action: #selector(menuItemAction(_:)), keyEquivalent: "")
        quitItem.tag = Constants.FloatMenuTag.quit
        quitItem.target = self
        menu.addItem(quitItem)

        // event.locationInWindow 已是窗口坐标系，等价于 contentView 坐标系
        // 注意：不能用 NSEvent.mouseLocation（屏幕坐标），from:nil 期望的是窗口基坐标系，
        // 两者相差窗口在屏幕上的 origin，会导致菜单位置偏移
        let viewPoint = event.locationInWindow
        menu.popUp(positioning: nil, at: viewPoint, in: contentViewContainer)
    }

    @objc private func menuItemAction(_ sender: NSMenuItem) {
        handleMenuAction(tag: sender.tag)
    }

    func handleMenuAction(tag: Int) {
        switch tag {
        case Constants.FloatMenuTag.restart:
            engine.restart()
        case Constants.FloatMenuTag.openSettings:
            // 延迟到下一轮 run loop，确保 popUp 的 modal tracking 完全退出后再操作窗口
            DispatchQueue.main.async {
                AppDelegate.shared.showSettingsWindow()
            }
        case Constants.FloatMenuTag.quit:
            AppDelegate.shared.quitApp()
        default: break
        }
    }

    // MARK: - 位置记忆

    private let positionKey = "FloatWindowPosition"
    /// 布局版本号。布局结构发生破坏性变更时递增，强制重置存储的窗口尺寸。
    private let layoutVersionKey = "FloatWindowLayoutVersion"
    private let currentLayoutVersion: Int = 2

    /// 动画期间抑制位置保存（避免 showWindow/hideWindow 的收缩动画覆盖真实位置）
    private var isSuppressingPositionSave = false

    /// 显隐动画代际标记：新一轮动画使旧动画的 completion 失效，
    /// 避免滞后的 orderOut 覆盖新动画的最终状态
    private var visibilityAnimationToken = 0

    @objc private func windowDidEndLiveResize() {
        saveWindowPosition()
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard !isSuppressingPositionSave else { return }
        saveWindowPosition()
    }

    /// 保存引擎背记进度（App 退出时调用）
    func saveEngineProgress() {
        engine.saveProgress()
    }

    func saveWindowPosition() {
        guard let frame = window?.frame else { return }
        let frameString = NSStringFromRect(frame)
        UserDefaults.standard.set(frameString, forKey: positionKey)
        UserDefaults.standard.set(currentLayoutVersion, forKey: layoutVersionKey)
    }

    private func restoreWindowPosition() {
        let savedVersion = UserDefaults.standard.integer(forKey: layoutVersionKey)

        if savedVersion != currentLayoutVersion {
            UserDefaults.standard.removeObject(forKey: positionKey)
            UserDefaults.standard.set(currentLayoutVersion, forKey: layoutVersionKey)
            centerOnMainScreen()
            return
        }

        guard let frameString = UserDefaults.standard.string(forKey: positionKey),
              !frameString.isEmpty else {
            centerOnMainScreen()
            return
        }
        let savedFrame = NSRectFromString(frameString)

        let clampedSize = clampSize(savedFrame.size)
        let restoredFrame = NSRect(origin: savedFrame.origin, size: clampedSize)

        // 使用 NSPointInRect 判断窗口原点是否落在某个屏幕内
        // 注意：不能用 NSIntersectsRect + zero-size rect，因为 NSIsEmptyRect 把 width/height<=0 视为空
        let isValidScreen = NSScreen.screens.contains { screen in
            NSPointInRect(restoredFrame.origin, screen.frame)
        }

        if isValidScreen {
            window?.setFrame(restoredFrame, display: true)
        } else {
            centerOnMainScreen()
        }
    }

    /// 将尺寸 clamp 到当前悬浮窗最小/最大边界
    private func clampSize(_ size: NSSize) -> NSSize {
        NSSize(
            width: min(max(size.width, Constants.floatWindowMinWidth), Constants.floatWindowMaxWidth),
            height: min(max(size.height, Constants.floatWindowMinHeight), Constants.floatWindowMaxHeight)
        )
    }

    private func centerOnMainScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = NSSize(
            width: Constants.floatWindowWidth,
            height: Constants.floatWindowMinHeight
        )
        let origin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        window?.setFrame(NSRect(origin: origin, size: windowSize), display: true)
    }
}

// MARK: - ReciteEngineDelegate

extension FloatWindowController: ReciteEngineDelegate {
    func engineDidAdvanceToWord(_ word: WordEntry) {
        let mode = AppSettings.shared.reciteMode
        let isFav = WordbookService.shared.isFavorite(sourceWord: word.sourceWord)
        contentViewContainer.showWord(
            word: word,
            mode: mode,
            isFavorite: isFav
        )
    }

    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int) {
        // 可选：显示 Section 切换提示
    }

    func engineDidCompleteAll() {
        contentViewContainer.showCompleted()
        // 保存位置
        saveWindowPosition()
    }
}

// MARK: - NSRect 辅助

private extension NSRect {
    /// 按缩放因子向中心收缩
    func shrink(by factor: CGFloat) -> NSRect {
        let newWidth = width * factor
        let newHeight = height * factor
        let dx = (width - newWidth) / 2
        let dy = (height - newHeight) / 2
        return NSRect(x: origin.x + dx, y: origin.y + dy, width: newWidth, height: newHeight)
    }
}
