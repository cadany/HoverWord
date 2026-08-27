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
    var onSpeakTap: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?
    /// 鼠标进出悬浮窗（true=进入，false=离开），控制器转发引擎暂停/恢复计时
    var onHoverStateChanged: ((Bool) -> Void)?
    /// 动效预览开始/结束（true=开始并暂停背记，false=结束并恢复），控制器转发引擎计时控制
    var onPreviewStateChanged: ((Bool) -> Void)?

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
    private let speakButton = NSButton()
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
    /// 切词/预览动画代际标记：新一轮动画使旧动画滞后的 completion 失效，
    /// 避免覆盖新内容（同 FloatWindowController.visibilityAnimationToken 模式）
    private var transitionGeneration = 0
    /// 是否正在播放设置页发起的动效预览
    private var isPreviewing = false
    /// 动效执行前的初始图层锚点（PageFlip 等动效会改写锚点，结束后需复位）
    private var initialWordLabelAnchor = CGPoint.zero
    private var initialPhoneticLabelAnchor = CGPoint.zero

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
        // 动效要求标签 layer-backed；先开启并记录初始锚点，动效结束后复位用
        wordLabel.wantsLayer = true
        phoneticLabel.wantsLayer = true
        initialWordLabelAnchor = wordLabel.layer?.anchorPoint ?? .zero
        initialPhoneticLabelAnchor = phoneticLabel.layer?.anchorPoint ?? .zero
        applyAppearanceSettings()
        updateTextColors()
        // 初始化即应用显示模式（无动画，避免启动闪烁）
        updatePhoneticVisibility(animated: false)
        updateMeaningVisibility(animated: false)

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

        // 监听动效预览（设置页点击预览时，用示例单词演示一次）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreviewTransition),
            name: .previewTransitionEffect,
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
        // 显示模式变更立即应用（不依赖上面的动效分组，用自身淡入淡出）
        updatePhoneticVisibility()
        updateMeaningVisibility()
    }

    @objc private func handleLanguageChange() {
        refreshLocalizedTexts()
    }

    /// 按当前界面语言刷新静态文案（toolTip 与完成态文字）
    ///
    /// 按钮常态为图标字符（✓ ✗ ▶ ♡），不随语言变化；
    /// 本地化语义只体现在 toolTip 与"已学完"文案
    private func refreshLocalizedTexts() {
        knowButton.toolTip = L10n.t("float.button.know")
        unknownButton.toolTip = L10n.t("float.button.unknown")
        speakButton.toolTip = L10n.t("float.button.speak")
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

        // 音标标签（次级文字透明度，保持层级差异同时保证可读性）
        phoneticLabel.textColor = baseColor.withAlphaComponent(Constants.secondaryTextAlpha)

        // 已学完标签
        completedLabel.textColor = baseColor

        // 释义标签
        meaningLabel.textColor = baseColor

        // 按钮背景色
        let bgColor = buttonColor.withAlphaComponent(buttonAlpha).cgColor
        favoriteButton.layer?.backgroundColor = bgColor
        speakButton.layer?.backgroundColor = bgColor
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
        completedLabel.font = wordFont

        // 更新音标字体（字号可在外观设置中配置）
        phoneticLabel.font = NSFont.systemFont(
            ofSize: CGFloat(AppSettings.shared.phoneticFontSize),
            weight: .regular
        )

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
        // tag 是动效实现的定位契约（viewWithTag 查找），改动前先看 Services/Transitions/
        wordLabel.tag = Constants.transitionWordLabelTag
        wordLabel.font = NSFont.systemFont(ofSize: Constants.wordFontSize, weight: .semibold)
        wordLabel.alignment = .left
        wordLabel.lineBreakMode = .byTruncatingTail
        wordLabel.maximumNumberOfLines = 1
        wordLabel.textColor = NSColor.black
        wordLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        wordLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        rootStack.addArrangedSubview(wordLabel)

        // 第 2 列：音标标签
        phoneticLabel.tag = Constants.transitionPhoneticLabelTag
        phoneticLabel.font = NSFont.systemFont(ofSize: Constants.phoneticFontSize, weight: .regular)
        phoneticLabel.alignment = .left
        phoneticLabel.textColor = NSColor.black.withAlphaComponent(Constants.secondaryTextAlpha)
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

        // 完成态用独立覆盖层而非 rootStack 第五列：完成时其余四列全部隐藏，
        // stack 布局已无意义，居中约束不随列显隐塌缩（PRD 3.2.5）
        completedLabel.isHidden = true
        completedLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(completedLabel)
        NSLayoutConstraint.activate([
            completedLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            completedLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
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

        // 播报按钮：重听当前单词发音
        configureButton(speakButton, title: "▶", action: #selector(speakTapped))
        speakButton.toolTip = L10n.t("float.button.speak")
        speakButton.target = self

        // 认识按钮（图标 + toolTip 补足语义）
        configureButton(knowButton, title: "✓", action: #selector(knowTapped))
        knowButton.toolTip = L10n.t("float.button.know")
        knowButton.target = self

        // 不认识按钮
        configureButton(unknownButton, title: "✗", action: #selector(unknownTapped))
        unknownButton.toolTip = L10n.t("float.button.unknown")
        unknownButton.target = self

        buttonStack.addArrangedSubview(favoriteButton)
        buttonStack.addArrangedSubview(speakButton)
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
        // hover 显示模式：悬停淡入
        updatePhoneticVisibility()
        updateMeaningVisibility()
        // 悬停暂停计时
        onHoverStateChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        animateButtonsOut()
        // hover 显示模式：离开淡出
        updatePhoneticVisibility()
        updateMeaningVisibility()
        // 恢复计时（从剩余时长继续）
        onHoverStateChanged?(false)
    }

    /// 重置悬停状态为"鼠标不在窗内"（窗口隐藏路径调用）
    ///
    /// orderOut 时 AppKit 不保证补发 mouseExited，isMouseInside 残留 true 会
    /// 导致计时永久暂停；隐藏前统一调用本方法归位 UI 并通知引擎恢复计时
    func resetHoverState() {
        guard isMouseInside else { return }
        isMouseInside = false
        animateButtonsOut()
        updatePhoneticVisibility()
        updateMeaningVisibility()
        onHoverStateChanged?(false)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }

    // MARK: - 注音/释义显示模式

    /// 显示模式对应的目标 alpha（hover 模式依赖鼠标是否在悬浮窗内）
    private func visibilityAlpha(for mode: ContentVisibility) -> CGFloat {
        switch mode {
        case .always: return 1
        case .hidden: return 0
        case .hover: return isMouseInside ? 1 : 0
        }
    }

    /// 按配置更新注音显示
    ///
    /// 仅用 alpha 过渡、保留占位空间（不用 isHidden），
    /// 避免模式切换或单词切换时窗口宽度跳动。
    private func updatePhoneticVisibility(animated: Bool = true) {
        let target = visibilityAlpha(for: AppSettings.shared.phoneticVisibility)
        applyAlpha(target, to: phoneticLabel, animated: animated)
    }

    /// 按配置更新释义显示（策略同注音）
    private func updateMeaningVisibility(animated: Bool = true) {
        let target = visibilityAlpha(for: AppSettings.shared.meaningVisibility)
        applyAlpha(target, to: meaningLabel, animated: animated)
    }

    private func applyAlpha(_ alpha: CGFloat, to view: NSView, animated: Bool) {
        guard animated else {
            view.alphaValue = alpha
            // 动效直接改写 layer.opacity 会绕过 AppKit 的 alphaValue 缓存，
            // 随后设置相同值时被去重跳过 layer 写入，导致 hover/hidden 模式
            // 下切词后音标持续显示；此处显式同步 layer 保证呈现与配置一致
            view.layer?.opacity = Float(alpha)
            return
        }
        CATransaction.begin()
        CATransaction.setAnimationDuration(Constants.buttonFadeDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        view.alphaValue = alpha
        CATransaction.commit()
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
            return [favoriteButton, speakButton, knowButton, unknownButton]
        case .carousel:
            return [favoriteButton, speakButton]
        }
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

    @objc private func speakTapped() {
        animateButtonClick(speakButton)
        onSpeakTap?()
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

    // MARK: - 公开：显示单词

    func showWord(word: WordEntry, mode: ReciteMode, isFavorite: Bool) {
        currentMode = mode
        isShowingCompleted = false

        // 预览被真实切词打断：让出显示权并恢复引擎计时
        if isPreviewing {
            isPreviewing = false
            onPreviewStateChanged?(false)
        }

        // 非动效部分立即更新（完成态文案、释义、收藏、按钮）
        completedLabel.isHidden = true
        wordLabel.isHidden = false
        meaningLabel.isHidden = false
        updateMeanings(word: word)
        // 释义按显示模式决定初始可见性（hover 且鼠标在外时保持隐藏）
        meaningLabel.alphaValue = visibilityAlpha(for: AppSettings.shared.meaningVisibility)
        updateFavoriteState(isFavorite: isFavorite)

        // 根据模式更新按钮
        if isMouseInside {
            setButtonsHidden(false)
        } else {
            setButtonsHidden(true)
        }

        // 单词/音标的文本更新交由动效驱动，完成回调统一归位
        wordLabel.wantsLayer = true
        phoneticLabel.wantsLayer = true

        let previousEntry = currentWordEntry
        currentWordEntry = word
        transitionGeneration += 1
        let generation = transitionGeneration

        // 首个单词无旧内容可过渡，直接显示（避免启动闪烁）
        guard let previousEntry else {
            applyWordContent(word)
            return
        }

        // ID 无效时回退默认动效；动效内部失败（如找不到标签）会立即回调 completion，
        // 由 applyWordContent 兜底完成切换，不阻塞背记流程
        let effect = TransitionRegistry.effect(id: AppSettings.shared.selectedTransitionId)
            ?? TransitionRegistry.defaultEffect
        let newContent = TransitionContent.from(wordEntry: word)
        effect.animate(
            from: TransitionContent.from(wordEntry: previousEntry),
            to: newContent,
            in: self,
            parameters: AppSettings.shared.transitionParameters,
            swapContent: makeContentSwap(for: newContent)
        ) { [weak self] in
            // 代际守卫：期间发生新一轮切词/预览则放弃归位；
            // 完成态守卫：动画期间被"重新开始"接管时不得覆盖新内容
            guard let self, generation == self.transitionGeneration, !self.isShowingCompleted else { return }
            self.applyWordContent(word)
        }
    }

    /// 构造动效中点内容落位闭包：新词 + 音标一次性写入（幂等）
    ///
    /// 动效在旧内容视觉不可辨的时点调用该闭包完成新内容切换；
    /// 打字机等自管单词呈现的动效在闭包执行后自行接管标签内容
    private func makeContentSwap(for content: TransitionContent) -> () -> Void {
        return { [weak self] in
            guard let self else { return }
            self.wordLabel.stringValue = content.word
            self.updatePhonetic(content.phonetic)
        }
    }

    /// 将词条文本无动画地落到单词/音标标签，并复位动效残留的图层状态
    ///
    /// 动效完成回调统一走这里（也兜底动效 guard 失败立即完成的路径），
    /// 确保最终文本正确、变换/锚点归位、注音透明度回到显示模式设定值。
    private func applyWordContent(_ word: WordEntry) {
        wordLabel.stringValue = word.sourceWord
        updatePhonetic(word.phonetic)
        resetTransitionLayerState()
        updatePhoneticVisibility(animated: false)
    }

    /// 复位动效可能残留的图层状态（变换/不透明度/锚点）
    private func resetTransitionLayerState() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0)
        wordLabel.layer?.transform = CATransform3DIdentity
        phoneticLabel.layer?.transform = CATransform3DIdentity
        wordLabel.layer?.opacity = 1
        phoneticLabel.layer?.opacity = 1
        wordLabel.layer?.anchorPoint = initialWordLabelAnchor
        phoneticLabel.layer?.anchorPoint = initialPhoneticLabelAnchor
        CATransaction.commit()
    }

    // MARK: - 动效预览

    /// 播放一次设置页发起的动效演示：暂停背记 → 单词过渡 → 恢复当前内容
    ///
    /// 用当前正在显示的单词演示（from/to 同词，动画照放不影响观看效果）；
    /// 刚启动等无当前词时回退内置示例词对。
    @objc private func handlePreviewTransition(_ notification: Notification) {
        guard !isPreviewing,
              let userInfo = notification.userInfo,
              let effectId = userInfo["effectId"] as? String,
              let effect = TransitionRegistry.effect(id: effectId) else { return }
        let parameters = (userInfo["parameters"] as? TransitionParameters)
            ?? AppSettings.shared.transitionParameters

        isPreviewing = true
        onPreviewStateChanged?(true)

        // 完成态下临时切回单词内容演示，结束后恢复"已学完"
        let wasCompleted = isShowingCompleted
        if wasCompleted {
            completedLabel.isHidden = true
            wordLabel.isHidden = false
            meaningLabel.isHidden = false
        }

        transitionGeneration += 1
        let generation = transitionGeneration

        // 优先当前词：走 applyWordContent 保证图层状态干净（中断中的动效
        // 可能残留透明度/变换）；释义/注音临时全量显示
        var oldContent: TransitionContent
        var newContent: TransitionContent
        if let currentEntry = currentWordEntry {
            applyWordContent(currentEntry)
            updateMeanings(word: currentEntry)
            meaningLabel.alphaValue = 1
            phoneticLabel.alphaValue = 1

            let content = TransitionContent.from(wordEntry: currentEntry)
            oldContent = content
            newContent = content
        } else {
            // 回退示例词对：先呈现示例旧词，保证"from → to"完整可见
            let oldMeaning = L10n.t("experience.preview.example.old.meaning")
            wordLabel.stringValue = Constants.transitionPreviewOldWord
            updatePhonetic(Constants.transitionPreviewOldPhonetic)
            meaningLabel.stringValue = oldMeaning
            meaningLabel.alphaValue = 1
            phoneticLabel.alphaValue = 1

            oldContent = TransitionContent(
                word: Constants.transitionPreviewOldWord,
                phonetic: Constants.transitionPreviewOldPhonetic,
                meaning: oldMeaning
            )
            newContent = TransitionContent(
                word: Constants.transitionPreviewNewWord,
                phonetic: Constants.transitionPreviewNewPhonetic,
                meaning: L10n.t("experience.preview.example.new.meaning")
            )
        }

        effect.animate(
            from: oldContent,
            to: newContent,
            in: self,
            parameters: parameters,
            swapContent: makeContentSwap(for: newContent)
        ) { [weak self] in
            // 预览被切词打断（代际失效或标志清除）时不做恢复
            guard let self, self.isPreviewing, generation == self.transitionGeneration else { return }
            self.isPreviewing = false
            self.onPreviewStateChanged?(false)
            self.restoreAfterPreview(wasCompleted: wasCompleted)
        }
    }

    /// 预览结束后恢复演示前的真实内容
    private func restoreAfterPreview(wasCompleted: Bool) {
        if wasCompleted {
            wordLabel.isHidden = true
            phoneticLabel.isHidden = true
            meaningLabel.isHidden = true
            completedLabel.isHidden = false
        } else if let entry = currentWordEntry {
            applyWordContent(entry)
            updateMeanings(word: entry)
            meaningLabel.alphaValue = visibilityAlpha(for: AppSettings.shared.meaningVisibility)
        } else {
            // 引擎尚未展示任何单词（如刚启动）：清空演示残留
            wordLabel.stringValue = ""
            updatePhonetic(nil)
            meaningLabel.stringValue = ""
            resetTransitionLayerState()
        }
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
            // 动画期间可能已被 showWord 接管（如淡出未结束即点"重新开始"），
            // 回调无法取消，靠状态守卫避免隐藏新内容
            guard self.isShowingCompleted else { return }
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
            self.speakButton.isHidden = true

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
