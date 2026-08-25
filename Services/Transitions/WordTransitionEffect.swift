import AppKit

/// 单词切换动效协议
///
/// 所有动效必须实现此协议，提供统一的接口供动效系统调用。
/// 动效本身无状态，只是"如何动画"的算法，推荐用结构体实现。
protocol WordTransitionEffect: Sendable {
    /// 动效唯一标识（用于存储和查找）
    var id: String { get }

    /// 动效显示名称（本地化）
    var displayName: String { get }

    /// 动效所属分类
    var category: TransitionCategory { get }

    /// 可调参数列表（空数组表示无参数可调）
    var adjustableParameters: [TransitionParameter] { get }

    /// 执行动画
    ///
    /// - Parameters:
    ///   - oldContent: 旧内容（切换前）
    ///   - newContent: 新内容（切换后）
    ///   - containerView: 容器视图（悬浮窗内容视图）
    ///   - parameters: 用户配置的参数值
    ///   - completion: 动画完成回调（必须调用）
    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    )
}

// MARK: - Default Implementations

extension WordTransitionEffect {
    /// 默认无可调参数
    var adjustableParameters: [TransitionParameter] {
        return []
    }

    /// 获取指定参数的值，不存在时返回默认值
    /// - Parameters:
    ///   - parameterId: 参数标识
    ///   - parameters: 参数字典
    /// - Returns: 参数值或默认值
    func parameterValue(for parameterId: String, in parameters: TransitionParameters) -> Double? {
        guard let param = adjustableParameters.first(where: { $0.id == parameterId }) else {
            return nil
        }
        return parameters.get(parameterId, defaultValue: param.defaultValue)
    }
}
