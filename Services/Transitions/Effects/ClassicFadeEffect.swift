import AppKit

/// 经典淡入淡出动效（Classic Fade）
///
/// ## 效果描述
/// 极简风格的过渡动效。旧内容淡出并向下位移 1px，新内容从上方 1px 处淡入。
/// 这是默认动效，适合日常使用，视觉干扰最小。
///
/// ## 技术实现
/// - **时长**: 0.15s（`Constants.wordSwitchDuration`），分为两个阶段各 0.075s
/// - **缓动**: ease-out（先快后慢，符合自然运动规律）
/// - **位移**: 1px 垂直位移，提供方向感而不分散注意力
/// - **透明度**: 0 → 1 线性过渡
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
    let displayName: String = {
        return L10n.t("settings.transition.effect.classic-fade")
    }()
    let category: TransitionCategory = .minimal

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        // 获取容器中的文字标签
        guard let wordLabel = containerView.viewWithTag(1001) as? NSTextField,
              let phoneticLabel = containerView.viewWithTag(1002) as? NSTextField else {
            // 找不到标签，直接完成
            completion()
            return
        }

        // 确保 layer 存在
        wordLabel.wantsLayer = true
        phoneticLabel.wantsLayer = true

        // 第一阶段：旧内容淡出 + 向下位移
        CATransaction.begin()
        CATransaction.setAnimationDuration(Constants.wordSwitchDuration / 2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock {
            // 第二阶段：更新内容，新内容从上方淡入
            wordLabel.stringValue = newContent.word
            if let phonetic = newContent.phonetic {
                phoneticLabel.stringValue = phonetic
                phoneticLabel.isHidden = false
            } else {
                phoneticLabel.isHidden = true
            }

            // 设置初始状态（上方 1px + 透明）
            CATransaction.begin()
            CATransaction.setAnimationDuration(0)
            wordLabel.layer?.transform = CATransform3DMakeTranslation(0, 1, 0)
            phoneticLabel.layer?.transform = CATransform3DMakeTranslation(0, 1, 0)
            wordLabel.layer?.opacity = 0
            phoneticLabel.layer?.opacity = 0
            CATransaction.commit()

            // 淡入 + 回到正常位置
            CATransaction.begin()
            CATransaction.setAnimationDuration(Constants.wordSwitchDuration / 2)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
            CATransaction.setCompletionBlock {
                completion()
            }
            wordLabel.layer?.transform = CATransform3DIdentity
            phoneticLabel.layer?.transform = CATransform3DIdentity
            wordLabel.layer?.opacity = 1
            phoneticLabel.layer?.opacity = 1
            CATransaction.commit()
        }

        wordLabel.layer?.transform = CATransform3DMakeTranslation(0, -1, 0)
        phoneticLabel.layer?.transform = CATransform3DMakeTranslation(0, -1, 0)
        wordLabel.layer?.opacity = 0
        phoneticLabel.layer?.opacity = 0
        CATransaction.commit()
    }
}
