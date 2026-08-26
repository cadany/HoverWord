import AppKit

/// 液体融合动效（Liquid Merge）
///
/// ## 效果描述
/// 模拟液体融合效果。旧内容融化收缩至中心点消失，新内容从中心"滴落"展开出现。
/// 营造流体般的柔滑过渡感。
///
/// ## 技术实现
/// - **缩放**: scale 从 1.0 → 0.0（收缩消失），0.0 → 1.0（展开出现）
/// - **透明度**: 同时配合 opacity 变化，增强融化感
/// - **缓动**: 收缩使用 ease-in（加速消失），展开使用 ease-out（减速出现）
/// - **时长**: 0.4s（两个阶段各 0.2s）
/// - **动画驱动**: 显式 `CABasicAnimation`（layer-backed 视图无隐式动画，见协议扩展说明）
///
/// ## 分类
/// `.immersive`（沉浸类）— 营造氛围和沉浸感
///
/// ## 可调参数
/// 无。此动效设计为固定参数。
///
/// ## 性能特性
/// - 仅使用 transform（scale）+ opacity，GPU 加速
/// - 适合所有单词长度
///
/// ## 注意事项
/// - 当前实现仅动画化单词标签，注音标签未参与动画
struct LiquidMergeEffect: WordTransitionEffect {
    let id = "liquid-merge"
    var displayName: String {
        return L10n.t("settings.transition.effect.liquid-merge")
    }
    let category: TransitionCategory = .immersive

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        guard let wordLabel = containerView.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField,
              let wordLayer = wordLabel.layer else {
            completion()
            return
        }

        wordLabel.wantsLayer = true

        let halfDuration: TimeInterval = 0.2

        // 第一阶段：融化收缩至中心消失
        let shrinkOut = CABasicAnimation(keyPath: "transform.scale", from: 1.0, to: 0.0, duration: halfDuration, timing: .easeIn)
        let fadeOut = CABasicAnimation(keyPath: "opacity", from: 1.0, to: 0.0, duration: halfDuration, timing: .easeIn)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // 中点：换上新内容
            wordLabel.stringValue = newContent.word

            // 第二阶段：从中心滴落展开
            let expandIn = CABasicAnimation(keyPath: "transform.scale", from: 0.0, to: 1.0, duration: halfDuration, timing: .easeOut)
            let fadeIn = CABasicAnimation(keyPath: "opacity", from: 0.0, to: 1.0, duration: halfDuration, timing: .easeOut)

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLayer.add(expandIn, forKey: "transition.scale")
            wordLayer.add(fadeIn, forKey: "transition.opacity")
            // 模型终态：原尺寸 + 不透明
            wordLayer.transform = CATransform3DIdentity
            wordLayer.opacity = 1
            CATransaction.commit()
        }

        wordLayer.add(shrinkOut, forKey: "transition.scale")
        wordLayer.add(fadeOut, forKey: "transition.opacity")
        // 模型中点态：收缩至零 + 透明
        wordLayer.transform = CATransform3DMakeScale(0, 0, 1)
        wordLayer.opacity = 0
        CATransaction.commit()
    }
}
