import Foundation

/// 动效可调参数描述
///
/// 定义单个参数的元数据：标识、显示名称、取值范围、默认值。
/// 用于设置界面动态生成 UI 控件。
struct TransitionParameter: Identifiable, Sendable {
    /// 参数唯一标识（用于存储和查找）
    let id: String
    /// 参数显示名称（本地化）
    let displayName: String
    /// 参数取值范围
    let range: ClosedRange<Double>
    /// 参数默认值
    let defaultValue: Double
    /// 参数步进值（滑块步进）
    let step: Double

    /// 初始化参数描述
    /// - Parameters:
    ///   - id: 参数唯一标识
    ///   - displayName: 显示名称
    ///   - range: 取值范围
    ///   - defaultValue: 默认值
    ///   - step: 步进值，默认 0.01
    init(
        id: String,
        displayName: String,
        range: ClosedRange<Double>,
        defaultValue: Double,
        step: Double = 0.01
    ) {
        precondition(range.contains(defaultValue), "Default value must be within range")
        self.id = id
        self.displayName = displayName
        self.range = range
        self.defaultValue = defaultValue
        self.step = step
    }
}
