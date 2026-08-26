import AppKit

/// 经典淡入淡出动效（Classic Fade）
///
/// ## 效果描述
/// 极简风格的过渡动效。旧内容淡出并上移 1px，新内容从下方 1px 处淡入。
/// 这是默认动效，适合日常使用，视觉干扰最小。
///
/// ## 技术实现
/// - **时长**: 0.15s（`Constants.wordSwitchDuration`），分为两个阶段各 0.075s
/// - **缓动**: ease-out（先快后慢，符合自然运动规律）
/// - **位移**: 1px 垂直位移，提供方向感而不分散注意力
/// - **透明度**: 1 → 0 → 1 过渡
/// - **动画驱动**: 显式 `CABasicAnimation`（layer-backed 视图无隐式动画，见协议扩展说明）
///
/// ## 分类
/// `.minimal`（极简类）— 强调克制、低干扰
///
/// ## 可调参数
/// 无。此动效设计为固定参数，无需用户调整。
///
/// ## 性能特性
/// - 仅使用 transform + opacity，GPU 加速
/// - 无复杂计算，低端设备流畅运行
/// - 适合所有单词长度
struct ClassicFadeEffect: WordTransitionEffect {
    let id = "classic-fade"
    var displayName: String {
        return L10n.t("settings.transition.effect.classic-fade")
    }
    let category: TransitionCategory = .minimal

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        // 获取容器中的文字标签
        guard let wordLabel = containerView.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField,
              let phoneticLabel = containerView.viewWithTag(Constants.transitionPhoneticLabelTag) as? NSTextField,
              let wordLayer = wordLabel.layer,
              let phoneticLayer = phoneticLabel.layer else {
            // 找不到标签，直接完成
            completion()
            return
        }

        // 确保 layer 存在
        wordLabel.wantsLayer = true
        phoneticLabel.wantsLayer = true

        let halfDuration = Constants.wordSwitchDuration / 2

        // 第一阶段：旧内容淡出 + 上移 1px
        let fadeOut = CABasicAnimation(keyPath: "opacity", from: 1.0, to: 0.0, duration: halfDuration, timing: .easeOut)
        let moveOut = CABasicAnimation(keyPath: "transform.translation.y", from: 0.0, to: -1.0, duration: halfDuration, timing: .easeOut)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // 第二阶段：更新内容，新内容从下方 1px 淡入
            wordLabel.stringValue = newContent.word
            if let phonetic = newContent.phonetic {
                phoneticLabel.stringValue = phonetic
                phoneticLabel.isHidden = false
            } else {
                phoneticLabel.isHidden = true
            }

            let fadeIn = CABasicAnimation(keyPath: "opacity", from: 0.0, to: 1.0, duration: halfDuration, timing: .easeOut)
            let moveIn = CABasicAnimation(keyPath: "transform.translation.y", from: 1.0, to: 0.0, duration: halfDuration, timing: .easeOut)

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                completion()
            }
            for layer in [wordLayer, phoneticLayer] {
                layer.add(fadeIn, forKey: "transition.opacity")
                layer.add(moveIn, forKey: "transition.translation")
                // 模型终态：正常位置 + 不透明（动画移除后停留于此）
                layer.transform = CATransform3DIdentity
                layer.opacity = 1
            }
            CATransaction.commit()
        }

        for layer in [wordLayer, phoneticLayer] {
            layer.add(fadeOut, forKey: "transition.opacity")
            layer.add(moveOut, forKey: "transition.translation")
            // 模型中点态：上方 1px + 透明
            layer.transform = CATransform3DMakeTranslation(0, -1, 0)
            layer.opacity = 0
        }
        CATransaction.commit()
    }
}
