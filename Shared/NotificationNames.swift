import Foundation

/// 全局通知名称定义
///
/// 集中管理应用内所有 NSNotification.Name，避免字符串散落各处。
/// 通知用于跨模块广播低频事件（设置变更、单词本启用状态变更等），
/// 高频事件（单词切换等）使用 delegate protocol。
extension Notification.Name {

    // MARK: - 设置相关

    /// 全局设置已变更（任何设置项修改后发送）
    ///
    /// 监听方：ReciteEngine（重置进度）、FloatContentView（刷新外观）
    static let appSettingsDidChange = Notification.Name("appSettingsDidChange")

    /// 设置窗口获得焦点（每次从后台切回或重新唤起时发送）
    ///
    /// 监听方：WordbookTabView（刷新列表，确保显示最新数据）
    static let settingsWindowDidBecomeKey = Notification.Name("settingsWindowDidBecomeKey")

    // MARK: - 单词本相关

    /// 单词本启用状态已变更
    ///
    /// ReciteEngine 收到后重建队列并重置进度
    static let wordbookEnablementDidChange = Notification.Name("wordbookEnablementDidChange")
}
