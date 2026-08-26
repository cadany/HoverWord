import AppKit

/// 卡片翻转动效（Card Flip）
///
/// ## 效果描述
/// 模拟实体卡片翻转。旧内容沿 Y 轴翻转 90° 消失，新内容从背面翻转出现。
///
/// ## 技术实现
/// - **翻转轴**: Y 轴（水平翻转），支点为标签中心
/// - **翻转角度**: 0° → 90°（旧内容侧立消失），90° → 0°（新内容翻回正面）
/// - **缓动**: 翻出使用 ease-in，翻入使用 ease-out
/// - **动画驱动**: 显式 `CABasicAnimation`（layer-backed 视图无隐式动画，见协议扩展说明）
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
/// - 适合所有单词长度
struct CardFlipEffect: WordTransitionEffect {
    let id = "card-flip"
    var displayName: String {
        return L10n.t("settings.transition.effect.card-flip")
    }
    let category: TransitionCategory = .playful

    /// 可调参数：翻转速度
    var adjustableParameters: [TransitionParameter] {
        return [
            TransitionParameter(
                id: "duration",
                displayName: L10n.t("settings.transition.parameter.duration"),
                range: Constants.cardFlipDurationRange,
                defaultValue: Constants.cardFlipDefaultDuration,
                step: 0.05
            )
        ]
    }

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        let duration = parameters.get("duration", defaultValue: Constants.cardFlipDefaultDuration)

        guard let wordLabel = containerView.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField,
              let phoneticLabel = containerView.viewWithTag(Constants.transitionPhoneticLabelTag) as? NSTextField,
              let wordLayer = wordLabel.layer,
              let phoneticLayer = phoneticLabel.layer else {
            completion()
            return
        }

        wordLabel.wantsLayer = true
        phoneticLabel.wantsLayer = true

        let halfDuration = duration / 2
        let edgeOnAngle = Double.pi / 2
        let edgeOnTransform = CATransform3DMakeRotation(.pi / 2, 0, 1, 0)

        // 第一阶段：旧内容翻至侧立（正对视角时宽度为 0，视觉上消失）
        let flipOut = CABasicAnimation(keyPath: "transform.rotation.y", from: 0.0, to: edgeOnAngle, duration: halfDuration, timing: .easeIn)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // 中点：先复位模型 transform（同一 runloop 内不渲染，无跳变），
            // 让换词触发的布局发生在恒等变换下，避免 layer frame 推导异常
            wordLayer.transform = CATransform3DIdentity
            phoneticLayer.transform = CATransform3DIdentity

            // 换上新内容，音标按有无显隐
            wordLabel.stringValue = newContent.word
            if let phonetic = newContent.phonetic {
                phoneticLabel.stringValue = phonetic
                phoneticLabel.isHidden = false
            } else {
                phoneticLabel.isHidden = true
            }
            containerView.layoutSubtreeIfNeeded()

            // 第二阶段：新内容从侧立翻回正面
            let flipIn = CABasicAnimation(keyPath: "transform.rotation.y", from: edgeOnAngle, to: 0.0, duration: halfDuration, timing: .easeOut)

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                completion()
            }
            for layer in [wordLayer, phoneticLayer] {
                layer.add(flipIn, forKey: "transition.rotation")
                // 模型终态：正面
                layer.transform = CATransform3DIdentity
            }
            CATransaction.commit()
        }

        for layer in [wordLayer, phoneticLayer] {
            layer.add(flipOut, forKey: "transition.rotation")
            // 模型中点态：侧立
            layer.transform = edgeOnTransform
        }
        CATransaction.commit()
    }
}
