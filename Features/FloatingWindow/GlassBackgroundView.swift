import AppKit

/// 玻璃背景视图
///
/// NSVisualEffectView 子类，提供 Liquid Glass 视觉效果：
/// - macOS 14+：使用 .liquid 材质（完整 Liquid Glass）
/// - macOS 12-13：使用 .hudWindow 材质 + 1px 内描边降级
/// - 支持自定义背景色叠加（tint 层）
/// - 支持透明度控制（文字层始终保持 100% 不透明）
class GlassBackgroundView: NSVisualEffectView {

    // MARK: - 配置

    /// 自定义背景色（nil 表示纯玻璃，无 tint）
    private var tintColor: NSColor?

    /// tint 层的透明度（0-1）
    private var tintAlpha: CGFloat = Constants.defaultBackgroundOpacity

    /// tint 叠加层
    private let tintLayer = CALayer()

    /// 内描边层
    private let strokeLayer = CAShapeLayer()

    // MARK: - 初始化

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGlass()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlass()
    }

    // MARK: - 配置方法

    /// 设置自定义背景色
    func setTintColor(_ color: NSColor?) {
        tintColor = color
        updateTintLayer()
    }

    /// 设置整体透明度（0-1）
    func setAlpha(_ alpha: CGFloat) {
        tintAlpha = alpha
        alphaValue = alpha
        updateTintLayer()
    }

    /// 设置圆角半径
    func setCornerRadius(_ radius: CGFloat) {
        layer?.cornerRadius = radius
        strokeLayer.path = cornerPath(for: bounds, radius: radius)
    }

    // MARK: - 私有：设置

    private func setupGlass() {
        wantsLayer = true
        blendingMode = .behindWindow
        state = .active
        material = effectiveMaterial()
        // 不设置 appearance，让 NSVisualEffectView 自动跟随系统深色/浅色模式

        // Tint 层
        tintLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        tintLayer.frame = bounds
        layer?.addSublayer(tintLayer)

        // 内描边层
        strokeLayer.fillColor = NSColor.clear.cgColor
        strokeLayer.lineWidth = Constants.innerStrokeWidth
        strokeLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        layer?.addSublayer(strokeLayer)

        // 初始圆角（悬浮窗用 16px，设置窗口可设为 12px）
        setCornerRadius(Constants.floatWindowCornerRadius)
        updateStrokeColor()
    }

    /// 根据系统版本选择材质
    ///
    /// - macOS 14+：使用 `.underWindowBackground` 材质（更精致的磨砂质感，最接近 Liquid Glass 视觉效果）
    /// - macOS 12–13：使用 `.hudWindow` 材质 + 1px 内描边降级
    ///
    /// 注：ui-spec 中提到的 `.liquid` 枚举值在当前 macOS SDK 中不存在，
    /// 已替换为视觉效果最接近的 `.underWindowBackground`。
    private func effectiveMaterial() -> NSVisualEffectView.Material {
        if #available(macOS 14.0, *) {
            return .underWindowBackground
        } else {
            return .hudWindow
        }
    }

    // MARK: - 更新

    private func updateTintLayer() {
        guard let color = tintColor else {
            tintLayer.backgroundColor = NSColor.clear.cgColor
            return
        }
        tintLayer.backgroundColor = color.withAlphaComponent(tintAlpha).cgColor
    }

    private func updateStrokeColor() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let alpha: CGFloat = isDark ? Constants.darkInnerStrokeAlpha : Constants.lightInnerStrokeAlpha
        strokeLayer.strokeColor = NSColor.white.withAlphaComponent(alpha).cgColor
    }

    private func cornerPath(for rect: NSRect, radius: CGFloat) -> CGPath {
        let path = CGPath(
            roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        )
        return path
    }

    // MARK: - 布局

    override func layout() {
        super.layout()
        tintLayer.frame = bounds
        strokeLayer.frame = bounds
        strokeLayer.path = cornerPath(for: bounds, radius: layer?.cornerRadius ?? 0)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStrokeColor()
    }
}
