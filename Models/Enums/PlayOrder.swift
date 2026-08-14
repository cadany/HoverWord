import Foundation

/// 播放顺序枚举
///
/// 仅在单个 Section 内部生效，Section 之间的先后顺序固定不变。
enum PlayOrder: String, Codable, CaseIterable {
    /// 顺序播放：按词条原始顺序展示
    case sequential

    /// 随机播放：每一轮循环重新打乱单词顺序
    case shuffled

    /// 用户可读的显示名称
    var displayName: String {
        switch self {
        case .sequential: return "顺序播放"
        case .shuffled: return "随机播放"
        }
    }
}
