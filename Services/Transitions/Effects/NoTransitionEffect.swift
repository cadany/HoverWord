import AppKit

/// 无动效（None）
///
/// ## 效果描述
/// 不执行任何切换动画：新内容直接、瞬时地替换旧内容。
/// 供偏好零过渡的用户选择，也是性能最保守的路径（无任何图层操作）。
///
/// ## 技术实现
/// 调用 swapContent 落位新内容后立即回调 completion，与其它动效契约一致；
/// 外层的 applyWordContent 兜底为幂等操作。
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
        swapContent: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        // 直接落位新内容，无任何动画
        swapContent()
        completion()
    }
}
