import AppKit

/// 字母变形动效（Letter Morph）
///
/// ## 效果描述
/// 模拟字母形变效果。旧字母通过缩放过渡到新字母，而非简单的消失和出现。
/// 旧字母先缩小（scale down），新字母同时从放大状态恢复正常（scale up），
/// 形成"变形"的视觉连续感。
///
/// ## 技术实现
/// - **第一阶段**: 旧内容 scale 1.0 → 0.5（缩小 50%）+ 淡出
/// - **第二阶段**: 更新内容，新内容 scale 1.5 → 1.0（从放大 150% 恢复正常）+ 淡入
/// - **缓动**: 缩小使用 ease-in，展开使用 ease-out
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
/// ## 降级逻辑
/// **重要**: 当单词长度超过 10 个字母时，自动降级为经典淡入动效。
/// - 原因：长单词的字母变形可能导致视觉混乱
/// - 阈值: `Constants.letterMorphMaxLetterCount`（默认 10）
/// - 降级动效: `ClassicFadeEffect`
///
/// ## 注意事项
/// - 当前实现是简化版：整体缩放，非逐字母变形
/// - 当前实现仅动画化单词标签，注音标签未参与动画
struct LetterMorphEffect: WordTransitionEffect {
    let id = "letter-morph"
    var displayName: String {
        return L10n.t("settings.transition.effect.letter-morph")
    }
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

        guard let wordLabel = containerView.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField,
              let wordLayer = wordLabel.layer else {
            completion()
            return
        }

        wordLabel.wantsLayer = true

        let halfDuration: TimeInterval = 0.2

        // 第一阶段：旧内容缩小
        let shrinkOut = CABasicAnimation(keyPath: "transform.scale", from: 1.0, to: 0.5, duration: halfDuration, timing: .easeIn)
        let fadeOut = CABasicAnimation(keyPath: "opacity", from: 1.0, to: 0.0, duration: halfDuration, timing: .easeIn)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // 中点：换上新内容
            wordLabel.stringValue = newContent.word

            // 第二阶段：新内容从放大状态恢复正常
            let settleIn = CABasicAnimation(keyPath: "transform.scale", from: 1.5, to: 1.0, duration: halfDuration, timing: .easeOut)
            let fadeIn = CABasicAnimation(keyPath: "opacity", from: 0.0, to: 1.0, duration: halfDuration, timing: .easeOut)

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLayer.add(settleIn, forKey: "transition.scale")
            wordLayer.add(fadeIn, forKey: "transition.opacity")
            // 模型终态：原尺寸 + 不透明
            wordLayer.transform = CATransform3DIdentity
            wordLayer.opacity = 1
            CATransaction.commit()
        }

        wordLayer.add(shrinkOut, forKey: "transition.scale")
        wordLayer.add(fadeOut, forKey: "transition.opacity")
        // 模型中点态：缩小至半 + 透明
        wordLayer.transform = CATransform3DMakeScale(0.5, 0.5, 1)
        wordLayer.opacity = 0
        CATransaction.commit()
    }
}
