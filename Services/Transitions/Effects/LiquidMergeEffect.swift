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
///
/// ## 分类
/// `.immersive`（沉浸类）— 营造氛围和沉浸感
///
/// ## 可调参数
/// 无。此动效设计为固定参数。
///
/// ## 性能特性
/// - 仅使用 transform（scale）+ opacity，GPU 加速
/// - 无复杂计算，性能优异
/// - 适合所有单词长度
///
/// ## 注意事项
/// - 注释中提到"轻微模糊"但代码未实现 blur 效果
/// - 可通过 `CIFilter` 或 `NSVisualEffectView` 添加高斯模糊增强液体感
/// - 当前实现仅动画化单词标签，注音标签未参与动画
struct LiquidMergeEffect: WordTransitionEffect {
    let id = "liquid-merge"
    let displayName: String = {
        return L10n.t("settings.transition.effect.liquid-merge")
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

        // 第一阶段：收缩消失
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock {
            // 更新内容
            wordLabel.stringValue = newContent.word

            // 设置初始状态（缩放为 0）
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            wordLabel.layer?.transform = CATransform3DMakeScale(0, 0, 1)
            wordLabel.layer?.opacity = 0
            CATransaction.commit()

            // 第二阶段：展开出现
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.2)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLabel.layer?.transform = CATransform3DIdentity
            wordLabel.layer?.opacity = 1
            CATransaction.commit()
        }
        wordLabel.layer?.transform = CATransform3DMakeScale(0, 0, 1)
        wordLabel.layer?.opacity = 0
        CATransaction.commit()
    }
}
