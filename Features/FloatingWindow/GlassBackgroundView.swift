import AppKit

/// 玻璃背景视图
///
/// NSVisualEffectView 子类，提供玻璃视觉效果：
/// - macOS 14-25：使用 .underWindowBackground 材质（精致磨砂，最接近 Liquid Glass）
/// - macOS 12-13：使用 .hudWindow 材质 + 1px 内描边降级
/// 注：真正的 `.liquid` 材质仅存在于 SwiftUI（macOS 26+），AppKit 无此枚举值。
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

    /// 内描边渐变层
    ///
    /// 纵向渐变：顶部高光 → 底部收暗，模拟环境光自上而下的玻璃边缘反光
    ///（对齐 macOS 26 真玻璃的 specular 高光特征），由描边形状 mask 限制显示范围
    private let strokeGradientLayer = CAGradientLayer()

    /// 描边形状 mask：1px 描边环，只让渐变沿边缘显示
    private let strokeMaskLayer = CAShapeLayer()

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
        strokeMaskLayer.path = cornerPath(for: bounds, radius: radius)
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

        // 内描边：渐变层 + 描边形状 mask
        strokeMaskLayer.fillColor = NSColor.clear.cgColor
        // mask 按渲染输出取 alpha：描边环处不透明白色，其余透明
        strokeMaskLayer.strokeColor = NSColor.white.cgColor
        strokeMaskLayer.lineWidth = Constants.innerStrokeWidth
        strokeMaskLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        // NSView 默认非翻转坐标系（原点左下），y=1 为顶部
        strokeGradientLayer.startPoint = CGPoint(x: 0.5, y: 1)
        strokeGradientLayer.endPoint = CGPoint(x: 0.5, y: 0)
        strokeGradientLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        strokeGradientLayer.mask = strokeMaskLayer
        layer?.addSublayer(strokeGradientLayer)

        // 初始圆角（8pt，见 Constants.floatWindowCornerRadius；调用方可按需覆盖）
        setCornerRadius(Constants.floatWindowCornerRadius)
        updateStrokeGradient()
    }

    /// 根据系统版本选择材质
    ///
    /// 注：`.liquid` 仅存在于 SwiftUI（macOS 26+），AppKit 的 NSVisualEffectView.Material 不包含此值。
    /// AppKit 层面选用 `.underWindowBackground`（macOS 14+ 最精致的磨砂质感，最接近 Liquid Glass 视觉效果）。
    /// SwiftUI 层面（设置窗口等）在 macOS 26+ 使用 `.liquid` 获得真正的液态玻璃。
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

    private func updateStrokeGradient() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let topAlpha = isDark ? Constants.darkInnerStrokeTopAlpha : Constants.lightInnerStrokeTopAlpha
        let bottomAlpha = isDark ? Constants.darkInnerStrokeBottomAlpha : Constants.lightInnerStrokeBottomAlpha
        strokeGradientLayer.colors = [
            NSColor.white.withAlphaComponent(topAlpha).cgColor,
            NSColor.white.withAlphaComponent(bottomAlpha).cgColor
        ]
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
        strokeGradientLayer.frame = bounds
        strokeMaskLayer.frame = bounds
        strokeMaskLayer.path = cornerPath(for: bounds, radius: layer?.cornerRadius ?? 0)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStrokeGradient()
    }
}
