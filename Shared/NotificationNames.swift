import Foundation

/// 全局通知名称定义
///
/// 集中管理应用内所有 NSNotification.Name，避免字符串散落各处。
/// 通知用于跨模块广播低频事件（设置变更、单词本启用状态变更等），
/// 高频事件（单词切换等）使用 delegate protocol。
extension Notification.Name {

    // MARK: - 设置相关

    /// 背记规则设置已变更（影响背记队列的结构设置修改后发送）
    ///
    /// 监听方：ReciteEngine（重置进度）
    /// 触发方：ReciteSettingsView 中背记模式、播放顺序、Section 大小、走马灯轮次
    static let appSettingsDidChange = Notification.Name("appSettingsDidChange")

    /// 外观设置已变更（不影响背记队列的视觉设置修改后发送）
    ///
    /// 监听方：FloatContentView（刷新外观）
    /// 触发方：AppearanceView、SpeechSettingsView
    static let appAppearanceDidChange = Notification.Name("appAppearanceDidChange")

    /// 计时参数已变更（仅影响计时器，不影响队列结构）
    ///
    /// 监听方：ReciteEngine（热更新计时器，不重置进度）
    /// 触发方：ReciteSettingsView 中停留时长、全屏自动隐藏
    static let appTimingDidChange = Notification.Name("appTimingDidChange")

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
