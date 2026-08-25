import AppKit

/// 翻页动效（Page Flip）
///
/// ## 效果描述
/// 模拟翻书效果。旧内容沿右边缘翻转 90° 消失（像书页翻过去），
/// 新内容从 90° 翻转至 0° 出现（像新页翻过来）。营造阅读翻页的真实感。
///
/// ## 技术实现
/// - **翻转轴**: 右边缘（anchorPoint 设为 (1.0, 0.5)）
/// - **翻转角度**: 0° → 90°（翻出），90° → 0°（翻入）
/// - **旋转轴**: Y 轴（垂直翻转）
/// - **缓动**: 翻出使用 ease-in，翻入使用 ease-out
///
/// ## 分类
/// `.immersive`（沉浸类）— 营造氛围和沉浸感
///
/// ## 可调参数
/// 无。此动效设计为固定参数，时长固定为 0.4s（两个阶段各 0.2s）。
///
/// ## 性能特性
/// - 使用 3D transform，GPU 加速
/// - 锚点变换仅计算一次，开销极低
/// - 适合所有单词长度
///
/// ## 注意事项
/// - 当前实现未添加阴影效果（注释中提到但代码未实现）
/// - 可通过在翻转过程中动态调整 shadow 增强真实感
/// - 当前实现仅动画化单词标签，注音标签未参与动画
struct PageFlipEffect: WordTransitionEffect {
    let id = "page-flip"
    let displayName: String = {
        return L10n.t("settings.transition.effect.page-flip")
    }()
    let category: TransitionCategory = .immersive

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        guard let wordLabel = containerView.viewWithTag(1001) as? NSTextField else {
            completion()
            return
        }

        wordLabel.wantsLayer = true

        // 设置锚点在右边缘
        wordLabel.layer?.anchorPoint = CGPoint(x: 1.0, y: 0.5)

        // 第一阶段：翻出
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock {
            // 更新内容
            wordLabel.stringValue = newContent.word

            // 设置初始状态
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            wordLabel.layer?.transform = CATransform3DMakeRotation(.pi / 2, 0, 1, 0)
            CATransaction.commit()

            // 第二阶段：翻入
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.2)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLabel.layer?.transform = CATransform3DIdentity
            CATransaction.commit()
        }
        wordLabel.layer?.transform = CATransform3DMakeRotation(.pi / 2, 0, 1, 0)
        CATransaction.commit()
    }
}
