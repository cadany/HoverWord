import Foundation

/// 动效参数字典
///
/// 存储动效的可调参数值，支持 Codable 持久化到 UserDefaults。
/// 提供类型安全的 get/set 方法，以及参数值 clamp 逻辑。
struct TransitionParameters: Codable, Sendable {
    /// 参数值存储
    private var values: [String: Double]

    /// 初始化空参数字典
    init() {
        self.values = [:]
    }

    /// 从字典初始化
    init(_ dictionary: [String: Double]) {
        self.values = dictionary
    }

    /// 获取参数值
    /// - Parameter key: 参数标识
    /// - Returns: 参数值，不存在时返回 nil
    func get(_ key: String) -> Double? {
        return values[key]
    }

    /// 获取参数值，不存在时返回默认值
    /// - Parameters:
    ///   - key: 参数标识
    ///   - defaultValue: 默认值
    /// - Returns: 参数值或默认值
    func get(_ key: String, defaultValue: Double) -> Double {
        return values[key] ?? defaultValue
    }

    /// 设置参数值
    /// - Parameters:
    ///   - key: 参数标识
    ///   - value: 参数值
    mutating func set(_ key: String, _ value: Double) {
        values[key] = value
    }

    /// 设置参数值并 clamp 到有效范围
    /// - Parameters:
    ///   - key: 参数标识
    ///   - value: 参数值
    ///   - range: 有效范围
    /// - Returns: clamp 后的实际值
    @discardableResult
    mutating func setClamped(_ key: String, _ value: Double, range: ClosedRange<Double>) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        values[key] = clamped
        return clamped
    }

    /// 检查参数是否存在
    /// - Parameter key: 参数标识
    /// - Returns: 是否存在
    func contains(_ key: String) -> Bool {
        return values[key] != nil
    }

    /// 移除参数
    /// - Parameter key: 参数标识
    mutating func remove(_ key: String) {
        values.removeValue(forKey: key)
    }

    /// 移除所有参数
    mutating func removeAll() {
        values.removeAll()
    }

    /// 所有参数键值对
    var allValues: [String: Double] {
        return values
    }

    /// 参数数量
    var count: Int {
        return values.count
    }
}

// MARK: - Equatable

extension TransitionParameters: Equatable {
    static func == (lhs: TransitionParameters, rhs: TransitionParameters) -> Bool {
        return lhs.values == rhs.values
    }
}
