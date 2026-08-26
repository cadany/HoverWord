import AppKit

/// 无动效（None）
///
/// ## 效果描述
/// 不执行任何切换动画：新内容直接、瞬时地替换旧内容。
/// 供偏好零过渡的用户选择，也是性能最保守的路径（无任何图层操作）。
///
/// ## 技术实现
/// 直接将新内容写入标签后立即回调 completion，与其它动效的
/// "动效负责呈现新内容"契约一致；外层的 applyWordContent 兜底为幂等操作。
///
/// ## 分类
/// `.minimal`（仅作协议要求的占位归属；设置页将其单独置顶展示，
/// 不落入任何分类分组）
///
/// ## 可调参数
/// 无
struct NoTransitionEffect: WordTransitionEffect {
    let id = Constants.noneTransitionId
    var displayName: String {
        return L10n.t("settings.transition.effect.none")
    }
    let category: TransitionCategory = .minimal

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        guard let wordLabel = containerView.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField,
              let phoneticLabel = containerView.viewWithTag(Constants.transitionPhoneticLabelTag) as? NSTextField else {
            completion()
            return
        }

        // 直接呈现新内容，无任何动画
        wordLabel.stringValue = newContent.word
        if let phonetic = newContent.phonetic {
            phoneticLabel.stringValue = phonetic
            phoneticLabel.isHidden = false
        } else {
            phoneticLabel.isHidden = true
        }
        completion()
    }
}
