import AppKit
import CoreData

/// 悬浮窗内容视图
///
/// 横向四列布局：
/// - 第 1 列：单词（加粗左对齐），垂直居中
/// - 第 2 列：音标（小号，无则隐藏），垂直居中
/// - 第 3 列：词性 + 释义（左对齐，随窗口高度自动换行）
/// - 第 4 列：操作按钮横排，右对齐
///
/// 交互：
/// - 鼠标悬停时浮现操作按钮（模式相关）
/// - 完成状态显示"已学完"与"重新开始"按钮
class FloatContentView: NSView {

    // MARK: - 回调

    var onKnowTap: (() -> Void)?
    var onUnknownTap: (() -> Void)?
    var onFavoriteTap: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?

    // MARK: - UI 组件

    private let glassBackground = GlassBackgroundView()
    /// 根容器：横向四列
    private let rootStack = NSStackView()
    /// 第 1 列：单词
    private let wordLabel = NSTextField(labelWithString: "")
    /// 第 2 列：音标
    private let phoneticLabel = NSTextField(labelWithString: "")
    /// 第 3 列：释义，多行 NSTextField，随窗口高度换行
    private let meaningLabel = NSTextField(labelWithString: "")
    /// 第 4 列：按钮横排，右对齐
    private let buttonStack = NSStackView()

    private let favoriteButton = NSButton()
    private let knowButton = NSButton()
    private let unknownButton = NSButton()
    private let completedLabel = NSTextField(labelWithString: L10n.t("float.completed"))

    // MARK: - 状态

    private var isMouseInside = false
    /// 当前是否展示"已学完"状态（影响 mouseEntered 时显示的按钮集合）
    private var isShowingCompleted = false
    private var currentMode: ReciteMode = .memoryFeedback
    /// 缓存当前词条，用于 resize 时重新渲染释义
    private var currentWordEntry: WordEntry?

    /// 当前是否为深色模式
    private var isDarkMode: Bool {
        effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    // MARK: - 初始化

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupGlass()
        setupContent()
        setupButtons()
        setupTrackingArea()
        applyAppearanceSettings()
        updateTextColors()

        // 监听外观设置变更
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppearanceChange),
            name: .appAppearanceDidChange,
            object: nil
        )

        // 监听界面语言变更（刷新按钮标题与完成态文案，单词内容不受影响）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: .appLanguageDidChange,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTextColors()
    }

    @objc private func handleAppearanceChange() {
        // 设置变更使用过渡动效
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.settingsApplyDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.applyAppearanceSettings()
            self.updateTextColors()
        })
    }

    @objc private func handleLanguageChange() {
        refreshLocalizedTexts()
    }

    /// 按当前界面语言刷新静态文案（按钮标题、完成态文字）
    private func refreshLocalizedTexts() {
        knowButton.title = L10n.t("float.button.know")
        unknownButton.title = L10n.t("float.button.unknown")
        completedLabel.stringValue = L10n.t("float.completed")
    }

    /// 根据当前系统外观更新文字和按钮颜色
    private func updateTextColors() {
        let buttonAlpha = isDarkMode ? Constants.darkButtonDefaultAlpha : Constants.lightButtonDefaultAlpha
        // 文字颜色从 AppSettings 读取
        let baseColor = NSColor(hex: AppSettings.shared.textColorHex)
            ?? (isDarkMode ? NSColor.white : NSColor.black)
        let buttonColor = NSColor.white

        // 单词标签
        wordLabel.textColor = baseColor

        // 音标标签（使用基础色 alpha 0.65，保持层级差异）
        phoneticLabel.textColor = baseColor.withAlphaComponent(0.65)

        // 已学完标签
        completedLabel.textColor = baseColor

        // 释义标签
        meaningLabel.textColor = baseColor

        // 按钮背景色
        let bgColor = buttonColor.withAlphaComponent(buttonAlpha).cgColor
        favoriteButton.layer?.backgroundColor = bgColor
        knowButton.layer?.backgroundColor = bgColor
        unknownButton.layer?.backgroundColor = bgColor
    }

    private func applyAppearanceSettings() {
        // 更新背景透明度
        glassBackground.setAlpha(CGFloat(AppSettings.shared.backgroundOpacity))

        // 更新背景色
        let hex = AppSettings.shared.backgroundColorHex
        if let color = NSColor(hex: hex) {
            glassBackground.setTintColor(color)
        }

        // 更新单词字体
        let wordSize = CGFloat(AppSettings.shared.wordFontSize)
        let wordFont: NSFont
        if let name = Optional(AppSettings.shared.wordFontName), !name.isEmpty,
           let font = NSFont(name: name, size: wordSize) {
            wordFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        } else {
            wordFont = NSFont.systemFont(ofSize: wordSize, weight: .semibold)
        }
        wordLabel.font = wordFont

        // 更新音标字体（音标字号不可配置，直接使用默认值）
        phoneticLabel.font = NSFont.systemFont(ofSize: Constants.phoneticFontSize, weight: .regular)

        // 更新释义字体
        let meaningSize = CGFloat(AppSettings.shared.meaningFontSize)
        let meaningFont: NSFont
        if let name = Optional(AppSettings.shared.meaningFontName), !name.isEmpty,
           let font = NSFont(name: name, size: meaningSize) {
            meaningFont = font
        } else {
            meaningFont = NSFont.systemFont(ofSize: meaningSize, weight: .regular)
        }
        meaningLabel.font = meaningFont

        // 字体变更后重新评估释义行数
        updateMeaningLines()

        // 触发布局更新
        needsLayout = true
    }

    // MARK: - 布局

    private func setupGlass() {
        glassBackground.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glassBackground)
        NSLayoutConstraint.activate([
            glassBackground.topAnchor.constraint(equalTo: topAnchor),
            glassBackground.bottomAnchor.constraint(equalTo: bottomAnchor),
            glassBackground.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassBackground.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        glassBackground.setCornerRadius(Constants.floatWindowCornerRadius)
        glassBackground.setAlpha(CGFloat(AppSettings.shared.backgroundOpacity))
    }

    private func setupContent() {
        // 根容器：横向四列，垂直居中
        rootStack.orientation = .horizontal
        rootStack.alignment = .centerY
        // 默认间距 8pt（单词-音标之间）
        rootStack.spacing = Constants.wordToPhoneticSpacing
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        // 根容器不决定窗口的最小尺寸，让窗口自由 resize
        rootStack.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
        rootStack.setContentHuggingPriority(.fittingSizeCompression, for: .vertical)
        addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: Constants.floatWindowPaddingVertical),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Constants.floatWindowPaddingVertical),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Constants.floatWindowPaddingHorizontal),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Constants.floatWindowPaddingHorizontal)
        ])

        // 第 1 列：单词标签
        wordLabel.font = NSFont.systemFont(ofSize: Constants.wordFontSize, weight: .semibold)
        wordLabel.alignment = .left
        wordLabel.lineBreakMode = .byTruncatingTail
        wordLabel.maximumNumberOfLines = 1
        wordLabel.textColor = NSColor.black
        wordLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        wordLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        rootStack.addArrangedSubview(wordLabel)

        // 第 2 列：音标标签
        phoneticLabel.font = NSFont.systemFont(ofSize: Constants.phoneticFontSize, weight: .regular)
        phoneticLabel.alignment = .left
        phoneticLabel.textColor = NSColor.black.withAlphaComponent(0.65)
        phoneticLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        phoneticLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        rootStack.addArrangedSubview(phoneticLabel)

        // 音标之后间距切换到 16pt（音标-释义之间）
        rootStack.setCustomSpacing(Constants.phoneticToMeaningSpacing, after: phoneticLabel)

        // 第 3 列：释义，多行 NSTextField，垂直居中
        meaningLabel.font = NSFont.systemFont(ofSize: Constants.meaningFontSize, weight: .regular)
        meaningLabel.alignment = .left
        meaningLabel.lineBreakMode = .byWordWrapping
        meaningLabel.maximumNumberOfLines = 0  // 始终允许多行，宽度不足时自然换行
        meaningLabel.textColor = NSColor.black
        // 释义列：水平低 hugging 占据剩余宽度，垂直低 hugging 保证 rootStack .centerY 对齐生效
        meaningLabel.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
        meaningLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        meaningLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        meaningLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        // 用低优先级约束覆盖 intrinsicContentSize，防止释义长文本把窗口撑大
        let meaningWidthConstraint = meaningLabel.widthAnchor.constraint(equalToConstant: 0)
        meaningWidthConstraint.priority = .fittingSizeCompression
        meaningWidthConstraint.isActive = true
        rootStack.addArrangedSubview(meaningLabel)

        // 释义之后间距切换到 16pt（释义-按钮之间）
        rootStack.setCustomSpacing(Constants.meaningToButtonSpacing, after: meaningLabel)

        // 第 4 列：按钮横排（在 setupButtons 中填充）
    }

    private func setupButtons() {
        buttonStack.orientation = .horizontal
        buttonStack.spacing = Constants.buttonSpacing
        buttonStack.alignment = .centerY
        // 按钮组保持紧凑尺寸，不被拉伸
        buttonStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        buttonStack.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        // 收藏按钮
        configureButton(favoriteButton, title: "♡", action: #selector(favoriteTapped))
        favoriteButton.target = self

        // 认识按钮
        configureButton(knowButton, title: L10n.t("float.button.know"), action: #selector(knowTapped))
        knowButton.target = self

        // 不认识按钮
        configureButton(unknownButton, title: L10n.t("float.button.unknown"), action: #selector(unknownTapped))
        unknownButton.target = self

        buttonStack.addArrangedSubview(favoriteButton)
        buttonStack.addArrangedSubview(knowButton)
        buttonStack.addArrangedSubview(unknownButton)

        rootStack.addArrangedSubview(buttonStack)

        // 默认隐藏所有按钮
        setButtonsHidden(true)
    }

    private func configureButton(_ button: NSButton, title: String, action: Selector) {
        button.title = title
        button.bezelStyle = .rounded
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: Constants.buttonFontSize, weight: .medium)
        button.action = action
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.backgroundColor = NSColor.white.withAlphaComponent(Constants.lightButtonDefaultAlpha).cgColor
    }

    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            // activeAlways：悬浮窗为 nonactivatingPanel，永远不是 key window，
            // 用 activeInKeyWindow 会导致 mouseEntered 永不触发，按钮永远不出现。
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }

    // MARK: - 鼠标追踪

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        // 按当前状态显示对应按钮（完成态无按钮，此调用为空操作）
        setButtonsHidden(false)
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        animateButtonsOut()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }

    // MARK: - 按钮显隐

    private func setButtonsHidden(_ hidden: Bool) {
        let buttons = activeButtons()
        let animated = !hidden

        if hidden {
            // 隐藏：直接淡出
            for btn in buttons { btn.isHidden = true }
            return
        }

        // 显示：先设置初始状态（下方 4px + 透明），再动画到正常位置
        for btn in buttons {
            btn.isHidden = false
            btn.alphaValue = 0
            btn.layer?.transform = CATransform3DMakeTranslation(0, -4, 0)
        }

        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(Constants.buttonFadeDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            for btn in buttons {
                btn.alphaValue = 1
                btn.layer?.transform = CATransform3DIdentity
            }
            CATransaction.commit()
        } else {
            for btn in buttons {
                btn.alphaValue = 1
                btn.layer?.transform = CATransform3DIdentity
            }
        }
    }

    /// 当前状态下参与显隐控制的按钮集合（完成状态无操作按钮，重开入口由右键菜单提供）
    private func activeButtons() -> [NSButton] {
        return isShowingCompleted ? [] : visibleButtons()
    }

    /// 根据当前背记模式返回应显示的按钮列表
    private func visibleButtons() -> [NSButton] {
        switch currentMode {
        case .memoryFeedback:
            return [favoriteButton, knowButton, unknownButton]
        case .carousel:
            return [favoriteButton]
        }
    }

    private func animateButtonsIn() {
        setButtonsHidden(false)
    }

    private func animateButtonsOut() {
        setButtonsHidden(true)
    }

    // MARK: - 按钮动作

    @objc private func knowTapped() {
        animateButtonClick(knowButton)
        onKnowTap?()
    }

    @objc private func unknownTapped() {
        animateButtonClick(unknownButton)
        onUnknownTap?()
    }

    @objc private func favoriteTapped() {
        animateButtonClick(favoriteButton)
        onFavoriteTap?()
    }

    /// 按钮点击态动效：微缩 + 亮度降低，0.1s 后恢复
    private func animateButtonClick(_ button: NSButton) {
        guard let layer = button.layer else { return }

        CATransaction.begin()
        CATransaction.setAnimationDuration(Constants.buttonClickDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setAnimationDuration(Constants.buttonClickDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            layer.transform = CATransform3DIdentity
            layer.opacity = 1.0
            CATransaction.commit()
        }
        layer.transform = CATransform3DMakeScale(
            Constants.buttonClickScale, Constants.buttonClickScale, 1
        )
        layer.opacity = 0.7
        CATransaction.commit()
    }

    // MARK: - 窗口尺寸变化响应

    /// 监听视图尺寸变化，动态调整释义区行数
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        updateMeaningLines()
    }

    /// 释义始终允许多行显示，宽度不足时自然换行。
    /// maximumNumberOfLines 始终为 0，此方法保留用于未来可能的扩展。
    private func updateMeaningLines() {
        // 始终允许多行，无需动态调整
    }

    // MARK: - 公开：显示单词

    func showWord(word: WordEntry, mode: ReciteMode, isFavorite: Bool) {
        currentMode = mode
        currentWordEntry = word
        isShowingCompleted = false

        // 更新内容
        wordLabel.stringValue = word.sourceWord
        updatePhonetic(word.phonetic)
        updateMeanings(word: word)

        // 显示正常内容，隐藏完成状态
        completedLabel.isHidden = true
        wordLabel.isHidden = false
        phoneticLabel.isHidden = (word.phonetic == nil)
        meaningLabel.isHidden = false
        meaningLabel.alphaValue = 1

        // 更新收藏状态
        updateFavoriteState(isFavorite: isFavorite)

        // 根据模式更新按钮
        if isMouseInside {
            setButtonsHidden(false)
        } else {
            setButtonsHidden(true)
        }

        // 切换动效：淡入淡出 + 1px 垂直位移
        wordLabel.wantsLayer = true
        phoneticLabel.wantsLayer = true

        // 从上方 1px 开始淡入
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        wordLabel.layer?.transform = CATransform3DMakeTranslation(0, 1, 0)
        phoneticLabel.layer?.transform = CATransform3DMakeTranslation(0, 1, 0)
        wordLabel.layer?.opacity = 0
        phoneticLabel.layer?.opacity = 0
        CATransaction.commit()

        // 淡入 + 回到正常位置
        CATransaction.begin()
        CATransaction.setAnimationDuration(Constants.wordSwitchDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        wordLabel.layer?.transform = CATransform3DIdentity
        phoneticLabel.layer?.transform = CATransform3DIdentity
        wordLabel.layer?.opacity = 1
        phoneticLabel.layer?.opacity = 1
        CATransaction.commit()
    }

    /// 显示完成状态（带动画过渡）
    func showCompleted() {
        isShowingCompleted = true
        currentWordEntry = nil
        // 先淡出单词内容
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Constants.transitionDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            wordLabel.animator().alphaValue = 0
            phoneticLabel.animator().alphaValue = 0
            meaningLabel.animator().alphaValue = 0
        }, completionHandler: {
            // 隐藏单词内容，显示"已学完"
            self.wordLabel.isHidden = true
            self.phoneticLabel.isHidden = true
            self.meaningLabel.isHidden = true
            self.completedLabel.isHidden = false
            self.completedLabel.alphaValue = 0

            // 隐藏普通按钮
            self.knowButton.isHidden = true
            self.unknownButton.isHidden = true
            self.favoriteButton.isHidden = true

            // 淡入"已学完"文字
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = Constants.transitionDuration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.completedLabel.animator().alphaValue = 1
            })
        })
    }

    /// 更新收藏按钮状态
    func updateFavoriteState(isFavorite: Bool) {
        favoriteButton.title = isFavorite ? "♥" : "♡"
    }

    // MARK: - 私有：内容更新

    private func updatePhonetic(_ phonetic: String?) {
        if let p = phonetic, !p.isEmpty {
            phoneticLabel.stringValue = p
            phoneticLabel.isHidden = false
        } else {
            phoneticLabel.isHidden = true
        }
    }

    /// 将词条所有非空释义用 " / " 拼接，渲染到 meaningLabel。
    /// 宽度不足时由 NSTextField 自动换行。
    private func updateMeanings(word: WordEntry) {
        let pairs: [(String?, String?)] = [
            (word.pos1, word.meaning1),
            (word.pos2, word.meaning2),
            (word.pos3, word.meaning3)
        ]
        let formatted: [String] = pairs.compactMap { pos, meaning in
            guard let meaning = meaning, !meaning.isEmpty else { return nil }
            if let pos = pos, !pos.isEmpty {
                return "\(pos) \(meaning)"
            }
            return meaning
        }

        meaningLabel.stringValue = formatted.joined(separator: " / ")
    }
}
