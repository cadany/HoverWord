import AppKit

/// 弹跳入场动效（Bounce In）
///
/// ## 效果描述
/// 新内容从下方弹入，带有弹簧物理效果。先快速上升，然后轻微过冲（overshoot）并回弹，
/// 最终稳定在目标位置。模拟真实世界的物理弹性运动。
///
/// ## 技术实现
/// - **弹簧动画**: 使用 `CASpringAnimation` 实现物理弹簧效果
///   - `mass`: 1.0（质量）
///   - `stiffness`: 100.0（刚度）
///   - `damping`: 10.0（阻尼，控制回弹衰减）
///   - `initialVelocity`: 0（初速度）
/// - **位移**: 初始位置在下方 20px × intensity
/// - **淡入**: 同时执行 0.3s 透明度动画
///
/// ## 分类
/// `.playful`（趣味类）— 增加趣味性和互动感
///
/// ## 可调参数
/// - **intensity**（弹性强度）: 0.5 - 2.0，默认 1.0
///   - 较低强度（0.5）：位移 10px，弹跳轻微，更克制
///   - 较高强度（2.0）：位移 40px，弹跳明显，更活泼
///
/// ## 性能特性
/// - 弹簧动画由 Core Animation 在 GPU 上执行，性能优异
/// - 同时执行 transform + opacity 动画
/// - 适合所有单词长度
///
/// ## 注意事项
/// - 当前实现仅动画化单词标签，注音标签未参与动画
/// - 弹簧参数（mass/stiffness/damping）固定，不可调
struct BounceInEffect: WordTransitionEffect {
    let id = "bounce-in"
    let displayName: String = {
        return L10n.t("settings.transition.effect.bounce-in")
    }()
    let category: TransitionCategory = .playful

    let adjustableParameters = [
        TransitionParameter(
            id: "intensity",
            displayName: L10n.t("settings.transition.parameter.intensity"),
            range: Constants.bounceInIntensityRange,
            defaultValue: Constants.bounceInDefaultIntensity,
            step: 0.1
        )
    ]

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        let intensity = parameters.get("intensity", defaultValue: Constants.bounceInDefaultIntensity)

        guard let wordLabel = containerView.viewWithTag(1001) as? NSTextField else {
            completion()
            return
        }

        wordLabel.wantsLayer = true

        // 淡出旧内容
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        CATransaction.setCompletionBlock {
            // 更新内容
            wordLabel.stringValue = newContent.word

            // 设置初始状态（下方 20px）
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            wordLabel.layer?.transform = CATransform3DMakeTranslation(0, -20 * intensity, 0)
            wordLabel.layer?.opacity = 0
            CATransaction.commit()

            // 弹簧动画弹入
            let springAnimation = CASpringAnimation(keyPath: "transform.translation.y")
            springAnimation.fromValue = -20 * intensity
            springAnimation.toValue = 0
            springAnimation.duration = 0.5
            springAnimation.mass = 1.0
            springAnimation.stiffness = 100.0
            springAnimation.damping = 10.0
            springAnimation.initialVelocity = 0

            let fadeAnimation = CABasicAnimation(keyPath: "opacity")
            fadeAnimation.fromValue = 0
            fadeAnimation.toValue = 1
            fadeAnimation.duration = 0.3

            CATransaction.begin()
            CATransaction.setAnimationDuration(0.5)
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLabel.layer?.add(springAnimation, forKey: "bounce")
            wordLabel.layer?.add(fadeAnimation, forKey: "fade")
            wordLabel.layer?.transform = CATransform3DIdentity
            wordLabel.layer?.opacity = 1
            CATransaction.commit()
        }
        wordLabel.layer?.opacity = 0
        CATransaction.commit()
    }
}
