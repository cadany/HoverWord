import AppKit

/// 字母变形动效（Letter Morph）
///
/// ## 效果描述
/// 模拟字母形变效果。旧字母通过缩放过渡到新字母，而非简单的消失和出现。
/// 旧字母先缩小（scale down），新字母同时从放大状态恢复正常（scale up），
/// 形成"变形"的视觉连续感。
///
/// ## 技术实现
/// - **第一阶段**: 旧内容 scale 1.0 → 0.5（缩小 50%）
/// - **第二阶段**: 更新内容，新内容 scale 1.5 → 1.0（从放大 150% 恢复正常）
/// - **透明度**: 配合 opacity 变化，增强变形感
/// - **缓动**: 缩小使用 ease-in，展开使用 ease-out
/// - **时长**: 0.4s（两个阶段各 0.2s）
///
/// ## 分类
/// `.immersive`（沉浸类）— 营造氛围和沉浸感
///
/// ## 可调参数
/// 无。此动效设计为固定参数。
///
/// ## 性能特性
/// - 使用 3D transform（scale），GPU 加速
/// - 无复杂计算，性能优异
///
/// ## 降级逻辑
/// **重要**: 当单词长度超过 10 个字母时，自动降级为经典淡入动效。
/// - 原因：长单词的字母变形可能导致视觉混乱
/// - 阈值: `Constants.letterMorphMaxLetterCount`（默认 10）
/// - 降级动效: `ClassicFadeEffect`
/// - 性能考量：长单词的缩放动画可能占用更多 GPU 资源
///
/// ## 注意事项
/// - 当前实现是简化版：整体缩放，非逐字母变形
/// - 理想的逐字母变形需要为每个字母创建独立的 CALayer
/// - 当前实现已足够流畅，逐字母版本会显著增加复杂度
/// - 当前实现仅动画化单词标签，注音标签未参与动画
struct LetterMorphEffect: WordTransitionEffect {
    let id = "letter-morph"
    let displayName: String = {
        return L10n.t("settings.transition.effect.letter-morph")
    }()
    let category: TransitionCategory = .immersive

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        // 字母数量超限，降级为经典淡入
        if newContent.word.count > Constants.letterMorphMaxLetterCount {
            ClassicFadeEffect().animate(
                from: oldContent,
                to: newContent,
                in: containerView,
                parameters: parameters,
                completion: completion
            )
            return
        }

        guard let wordLabel = containerView.viewWithTag(1001) as? NSTextField else {
            completion()
            return
        }

        wordLabel.wantsLayer = true

        // 第一阶段：旧内容缩小
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock {
            // 更新内容
            wordLabel.stringValue = newContent.word

            // 设置初始状态（放大）
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            wordLabel.layer?.transform = CATransform3DMakeScale(1.5, 1.5, 1)
            wordLabel.layer?.opacity = 0
            CATransaction.commit()

            // 第二阶段：新内容从放大恢复正常
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
        wordLabel.layer?.transform = CATransform3DMakeScale(0.5, 0.5, 1)
        wordLabel.layer?.opacity = 0
        CATransaction.commit()
    }
}
