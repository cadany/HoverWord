import AppKit

/// 星体黑洞动效（Black Hole）
///
/// ## 效果描述
/// 模拟宇宙黑洞效果。旧内容的字母被"吸入"中心黑洞消失（旋转 + 缩小），
/// 新内容的字母从中心"喷发"而出（旋转 + 放大）。营造神秘而震撼的视觉效果。
///
/// ## 技术实现
/// - **旋转**: 绕 Z 轴旋转 360°（2π 弧度）
/// - **缩放**: scale 从 1.0 → 0.0（吸入消失），0.0 → 1.0（喷发出现）
/// - **透明度**: 同时配合 opacity 变化
/// - **缓动**: 吸入使用 ease-in（加速吸入），喷发使用 ease-out（减速出现）
/// - **时长**: 0.5s（两个阶段各 0.25s）
///
/// ## 分类
/// `.immersive`（沉浸类）— 营造氛围和沉浸感
///
/// ## 可调参数
/// 无。此动效设计为固定参数。
///
/// ## 性能特性
/// - 使用 3D transform（rotation + scale），GPU 加速
/// - 变换矩阵组合计算开销极低
/// - 适合所有单词长度
///
/// ## 注意事项
/// - 当前实现是简化版：整体缩放 + 旋转，非逐字母动画
/// - 理想的逐字母动画需要为每个字母创建独立的 CALayer
/// - 当前实现已足够流畅，逐字母版本会显著增加复杂度和性能开销
/// - 当前实现仅动画化单词标签，注音标签未参与动画
struct BlackHoleEffect: WordTransitionEffect {
    let id = "black-hole"
    let displayName: String = {
        return L10n.t("settings.transition.effect.black-hole")
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

        // 第一阶段：旋转缩小消失
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock {
            // 更新内容
            wordLabel.stringValue = newContent.word

            // 设置初始状态（旋转 + 缩放为 0）
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            var transform = CATransform3DMakeRotation(.pi, 0, 0, 1)
            transform = CATransform3DScale(transform, 0, 0, 1)
            wordLabel.layer?.transform = transform
            wordLabel.layer?.opacity = 0
            CATransaction.commit()

            // 第二阶段：旋转展开出现
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLabel.layer?.transform = CATransform3DIdentity
            wordLabel.layer?.opacity = 1
            CATransaction.commit()
        }

        var transform = CATransform3DMakeRotation(.pi, 0, 0, 1)
        transform = CATransform3DScale(transform, 0, 0, 1)
        wordLabel.layer?.transform = transform
        wordLabel.layer?.opacity = 0
        CATransaction.commit()
    }
}
