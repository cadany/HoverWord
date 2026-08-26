import AppKit

/// 单词切换动效协议
///
/// 所有动效必须实现此协议，提供统一的接口供动效系统调用。
/// 动效本身无状态，只是"如何动画"的算法，推荐用结构体实现。
///
/// ## 职责边界（重要）
/// 动效只负责"如何动画"；新内容落位由调用方经 `swapContent` 回调完成，
/// 动效 SHALL NOT 自行向单词/音标标签写入内容。
protocol WordTransitionEffect: Sendable {
    /// 动效唯一标识（用于存储和查找）
    var id: String { get }

    /// 动效显示名称（本地化）
    ///
    /// 实现须为计算属性并经 `L10n.t` 实时查词：注册表实例全局缓存，
    /// 存储属性会把首次构造时的语言冻结，切换界面语言后不更新。
    var displayName: String { get }

    /// 动效所属分类
    var category: TransitionCategory { get }

    /// 可调参数列表（空数组表示无参数可调）
    ///
    /// 含显示名的实现须为计算属性：参数名在构造时查词，
    /// 需每次访问重建数组以跟随界面语言。
    var adjustableParameters: [TransitionParameter] { get }

    /// 执行动画
    ///
    /// - Parameters:
    ///   - oldContent: 旧内容（切换前）
    ///   - newContent: 新内容（切换后）
    ///   - containerView: 容器视图（悬浮窗内容视图）
    ///   - parameters: 用户配置的参数值
    ///   - swapContent: 中点内容落位回调——在旧内容视觉不可辨的时点
    ///     （翻转侧立、缩放为零、淡出完成、逐字符开始前等）恰好调用一次，
    ///     由调用方完成新词与音标的写入（幂等）
    ///   - completion: 动画完成回调（必须调用）
    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        swapContent: @escaping () -> Void,
        completion: @escaping () -> Void
    )
}

// MARK: - 显式动画构造

/// 动效专用显式动画便捷构造
///
/// macOS 上 layer-backed NSView 的图层由 AppKit 托管，CATransaction 内直接给
/// `layer.transform` / `layer.opacity` 赋值不会产生隐式动画（仅瞬间改值）。
/// 因此动效统一走显式动画：用 `fromValue`/`toValue` 驱动呈现，
/// 并在添加动画的同一事务里把模型值落到该阶段终态，动画移除后图层自然停留。
/// 多分量变换（旋转 + 缩放等）用 `transform.rotation.y`、`transform.scale` 等
/// 子键路径分别驱动，Core Animation 会自动合成。
extension CABasicAnimation {
    /// 构造单值显式动画
    ///
    /// - Parameters:
    ///   - keyPath: 动画键路径（如 "transform.rotation.y"、"opacity"）
    ///   - from: 起始值
    ///   - to: 结束值
    ///   - duration: 时长（秒）
    ///   - timing: 缓动曲线
    convenience init(
        keyPath: String,
        from: Any,
        to: Any,
        duration: TimeInterval,
        timing: CAMediaTimingFunctionName
    ) {
        self.init(keyPath: keyPath)
        fromValue = from
        toValue = to
        self.duration = duration
        timingFunction = CAMediaTimingFunction(name: timing)
    }
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
