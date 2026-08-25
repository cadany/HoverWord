import AppKit

/// 卡片翻转动效（Card Flip）
///
/// ## 效果描述
/// 模拟实体卡片翻转。旧内容沿 Y 轴翻转 180° 消失，新内容从背面翻转出现。
/// 带有轻微透视变形，增强 3D 立体感。
///
/// ## 技术实现
/// - **翻转轴**: Y 轴（水平翻转）
/// - **翻转角度**: 0° → 90°（旧内容消失），90° → 0°（新内容出现）
/// - **透视**: `m34 = -1.0 / 500.0`，提供近大远小的立体效果
/// - **缓动**: 翻出使用 ease-in，翻入使用 ease-out
///
/// ## 分类
/// `.playful`（趣味类）— 增加趣味性和互动感
///
/// ## 可调参数
/// - **duration**（翻转时长）: 0.2s - 0.5s，默认 0.35s
///   - 较短时长（0.2s）：快速干脆，适合高效背记
///   - 较长时长（0.5s）：更明显的翻转效果，视觉享受
///
/// ## 性能特性
/// - 使用 3D transform，GPU 加速
/// - 透视矩阵计算开销极低
/// - 适合所有单词长度
struct CardFlipEffect: WordTransitionEffect {
    let id = "card-flip"
    let displayName: String = {
        return L10n.t("settings.transition.effect.card-flip")
    }()
    let category: TransitionCategory = .playful

    /// 可调参数：翻转速度
    let adjustableParameters = [
        TransitionParameter(
            id: "duration",
            displayName: L10n.t("settings.transition.parameter.duration"),
            range: Constants.cardFlipDurationRange,
            defaultValue: Constants.cardFlipDefaultDuration,
            step: 0.05
        )
    ]

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        let duration = parameters.get("duration", defaultValue: Constants.cardFlipDefaultDuration)

        guard let wordLabel = containerView.viewWithTag(1001) as? NSTextField,
              let phoneticLabel = containerView.viewWithTag(1002) as? NSTextField else {
            completion()
            return
        }

        wordLabel.wantsLayer = true
        phoneticLabel.wantsLayer = true

        // 设置透视
        var perspective = CATransform3DIdentity
        perspective.m34 = -1.0 / 500.0

        // 第一阶段：旧内容翻转 90°（消失）
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration / 2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock {
            // 更新内容
            wordLabel.stringValue = newContent.word
            if let phonetic = newContent.phonetic {
                phoneticLabel.stringValue = phonetic
                phoneticLabel.isHidden = false
            } else {
                phoneticLabel.isHidden = true
            }

            // 设置初始状态（翻转 90°，不可见）
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            let initialTransform = CATransform3DMakeRotation(.pi / 2, 0, 1, 0)
            wordLabel.layer?.transform = initialTransform
            phoneticLabel.layer?.transform = initialTransform
            CATransaction.commit()

            // 第二阶段：新内容从 90° 翻转到 0°
            CATransaction.begin()
            CATransaction.setAnimationDuration(duration / 2)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLabel.layer?.transform = CATransform3DIdentity
            phoneticLabel.layer?.transform = CATransform3DIdentity
            CATransaction.commit()
        }

        let flipTransform = CATransform3DMakeRotation(.pi / 2, 0, 1, 0)
        wordLabel.layer?.transform = flipTransform
        phoneticLabel.layer?.transform = flipTransform
        CATransaction.commit()
    }
}
