import AppKit

/// 星体黑洞动效（Black Hole）
///
/// ## 效果描述
/// 模拟宇宙黑洞效果。旧内容被"吸入"中心黑洞消失（旋转 + 收缩 + 变暗），
/// 新内容从中心"喷发"而出（同向旋转 + 放大 + 显影）。营造神秘而震撼的视觉效果。
///
/// ## 技术实现
/// - **旋转**: 绕 Z 轴累计旋转 360°（两阶段各 π，同向连续旋出）
/// - **缩放**: scale 从 1.0 → 0.0（吸入消失），0.0 → 1.0（喷发出现）
/// - **透明度**: 同步 opacity 变化
/// - **缓动**: 吸入使用 ease-in（加速吸入），喷发使用 ease-out（减速出现）
/// - **时长**: 0.5s（两个阶段各 0.25s）
/// - **动画驱动**: 显式 `CABasicAnimation`，旋转与缩放用 transform 子键路径分别驱动后自动合成
///
/// ## 分类
/// `.immersive`（沉浸类）— 营造氛围和沉浸感
///
/// ## 可调参数
/// 无。此动效设计为固定参数。
///
/// ## 性能特性
/// - 仅使用 transform（rotation + scale）+ opacity，GPU 加速
/// - 适合所有单词长度
///
/// ## 注意事项
/// - 当前实现是简化版：整体缩放 + 旋转，非逐字母动画
/// - 当前实现仅动画化单词标签，注音标签未参与动画
struct BlackHoleEffect: WordTransitionEffect {
    let id = "black-hole"
    var displayName: String {
        return L10n.t("settings.transition.effect.black-hole")
    }
    let category: TransitionCategory = .immersive

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        swapContent: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        guard let wordLabel = containerView.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField,
              let wordLayer = wordLabel.layer else {
            completion()
            return
        }

        wordLabel.wantsLayer = true

        let halfDuration: TimeInterval = 0.25

        // 第一阶段：旋转吸入（自旋 + 收缩 + 变暗）
        let spinOut = CABasicAnimation(keyPath: "transform.rotation.z", from: 0.0, to: Double.pi, duration: halfDuration, timing: .easeIn)
        let shrinkOut = CABasicAnimation(keyPath: "transform.scale", from: 1.0, to: 0.0, duration: halfDuration, timing: .easeIn)
        let fadeOut = CABasicAnimation(keyPath: "opacity", from: 1.0, to: 0.0, duration: halfDuration, timing: .easeIn)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // 中点：吸入消失（视觉不可辨），落位新内容（词 + 音标同步）
            swapContent()

            // 第二阶段：喷发而出（继续同向旋出 + 放大 + 显影）
            let spinIn = CABasicAnimation(keyPath: "transform.rotation.z", from: Double.pi, to: Double.pi * 2, duration: halfDuration, timing: .easeOut)
            let expandIn = CABasicAnimation(keyPath: "transform.scale", from: 0.0, to: 1.0, duration: halfDuration, timing: .easeOut)
            let fadeIn = CABasicAnimation(keyPath: "opacity", from: 0.0, to: 1.0, duration: halfDuration, timing: .easeOut)

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLayer.add(spinIn, forKey: "transition.rotation")
            wordLayer.add(expandIn, forKey: "transition.scale")
            wordLayer.add(fadeIn, forKey: "transition.opacity")
            // 模型终态：正面原尺寸 + 不透明（2π 旋转与恒等变换等价）
            wordLayer.transform = CATransform3DIdentity
            wordLayer.opacity = 1
            CATransaction.commit()
        }

        wordLayer.add(spinOut, forKey: "transition.rotation")
        wordLayer.add(shrinkOut, forKey: "transition.scale")
        wordLayer.add(fadeOut, forKey: "transition.opacity")
        // 模型中点态：旋入半圈 + 收缩至零 + 透明
        var inhaled = CATransform3DMakeRotation(.pi, 0, 0, 1)
        inhaled = CATransform3DScale(inhaled, 0, 0, 1)
        wordLayer.transform = inhaled
        wordLayer.opacity = 0
        CATransaction.commit()
    }
}
