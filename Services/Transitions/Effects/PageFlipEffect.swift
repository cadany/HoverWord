import AppKit

/// 翻页动效（Page Flip）
///
/// ## 效果描述
/// 模拟翻书效果。旧内容沿右边缘翻转 90° 消失（像书页翻过去），
/// 新内容从 90° 翻转至 0° 出现（像新页翻过来）。营造阅读翻页的真实感。
///
/// ## 技术实现
/// - **翻转轴**: Y 轴，支点为右边缘
/// - **翻转角度**: 0° → 90°（翻出），90° → 0°（翻入）
/// - **支点实现**: 不改 `anchorPoint` —— Auto Layout 感知不到 layer 锚点变化，
///   动效期间布局 pass 仍按居中锚点反推 position，与动效写入的补偿值相互
///   错位，动效结束后单词偏移半个词宽被容器裁剪（显示不全）。
///   改为 `rotation.y` 与 `translation.x` 双动画同步合成：起止态与绕右缘
///   旋转精确一致，中间态平移为线性近似（精确值应随 θ 按 W/2·(1−cosθ)
///   变化），翻转中支点有轻微漂移，0.2s 快速动作内肉眼不可辨
/// - **换词时机**: 中点回调。先复位模型 transform、换词并同步布局
///   （`layoutSubtreeIfNeeded`）取得新词真实宽度后，再构造翻入动画，
///   消除宽度时序误差；布局发生在恒等变换下，不与动画冲突
/// - **缓动**: 翻出使用 ease-in，翻入使用 ease-out
/// - **动画驱动**: 显式 `CABasicAnimation`（layer-backed 视图无隐式动画，见协议扩展说明）
///
/// ## 分类
/// `.immersive`（沉浸类）— 营造氛围和沉浸感
///
/// ## 可调参数
/// 无。此动效设计为固定参数，时长固定为 0.4s（两个阶段各 0.2s）。
///
/// ## 性能特性
/// - 使用 3D transform，GPU 加速
/// - 适合所有单词长度
///
/// ## 注意事项
/// - 仅动画化单词标签，音标在中点同步换内容（无动画）
struct PageFlipEffect: WordTransitionEffect {
    let id = "page-flip"
    var displayName: String {
        return L10n.t("settings.transition.effect.page-flip")
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
        let edgeOnAngle = Double.pi / 2
        let oldWidth = Double(wordLayer.bounds.width)

        // 第一阶段：旧内容绕右缘翻出（旋转 + 同步平移合成，等价绕右缘支点）
        let flipOut = CABasicAnimation(keyPath: "transform.rotation.y", from: 0.0, to: edgeOnAngle, duration: halfDuration, timing: .easeIn)
        let slideOut = CABasicAnimation(keyPath: "transform.translation.x", from: 0.0, to: oldWidth / 2, duration: halfDuration, timing: .easeIn)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // 中点：先复位模型 transform（同一 runloop 内不渲染，无跳变），
            // 让换词后的同步布局发生在恒等变换下
            wordLayer.transform = CATransform3DIdentity

            wordLabel.stringValue = newContent.word
            if let phoneticLabel = containerView.viewWithTag(Constants.transitionPhoneticLabelTag) as? NSTextField {
                if let phonetic = newContent.phonetic {
                    phoneticLabel.stringValue = phonetic
                    phoneticLabel.isHidden = false
                } else {
                    phoneticLabel.isHidden = true
                }
            }
            containerView.layoutSubtreeIfNeeded()

            // 同步布局后 label 宽度已是新词宽度，翻入支点按新宽度构造
            let newWidth = Double(wordLayer.bounds.width)

            // 第二阶段：新内容绕（新宽度的）右缘翻回正面
            let flipIn = CABasicAnimation(keyPath: "transform.rotation.y", from: edgeOnAngle, to: 0.0, duration: halfDuration, timing: .easeOut)
            let slideIn = CABasicAnimation(keyPath: "transform.translation.x", from: newWidth / 2, to: 0.0, duration: halfDuration, timing: .easeOut)

            CATransaction.begin()
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLayer.add(flipIn, forKey: "transition.rotation")
            wordLayer.add(slideIn, forKey: "transition.translation")
            // 模型终态：正面原位（动画移除后停留于此）
            wordLayer.transform = CATransform3DIdentity
            CATransaction.commit()
        }

        wordLayer.add(flipOut, forKey: "transition.rotation")
        wordLayer.add(slideOut, forKey: "transition.translation")
        // 模型中点态：侧立 + 右移半宽（与翻出动画终态一致，动画移除后停留于此）
        wordLayer.transform = CATransform3DTranslate(
            CATransform3DMakeRotation(.pi / 2, 0, 1, 0),
            CGFloat(oldWidth / 2), 0, 0
        )
        CATransaction.commit()
    }
}
