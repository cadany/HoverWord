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

    /// 单词本内容已变更（词条更新 / 词条删除 / 词库导入完成）
    ///
    /// userInfo 携带变更所属单词本的 wordbookId（键 "wordbookId"），
    /// 仅在变更成功落盘后发送，无实际变更（如 wordId 不存在）不发送。
    /// ReciteEngine 与 favoritesDidChange 共用同一处理入口：
    /// 来源单词本启用且引擎处于播放 / Section 完成态时保存进度并重建队列，
    /// 其余情况忽略。必须在主线程发送。
    static let wordbookContentDidChange = Notification.Name("wordbookContentDidChange")

    /// 收藏内容已变更（新增 / 移除收藏、导入后的收藏夹同步）
    ///
    /// ReciteEngine 收到后仅在收藏夹单词本启用时重建队列，
    /// 未启用收藏夹时队列不受影响，忽略此通知。
    /// 必须在主线程发送（后台上下文写入完成后需切回主线程再 post）。
    static let favoritesDidChange = Notification.Name("favoritesDidChange")

    /// 界面语言已变更
    ///
    /// 监听方：设置窗口 SwiftUI 树（经 LanguageManager 重渲染）、
    /// FloatContentView（刷新按钮/完成态文案）
    /// 触发方：通用设置页语言切换。必须在主线程发送。
    static let appLanguageDidChange = Notification.Name("appLanguageDidChange")

    /// 单词本语言对（sourceLang/targetLang）已变更
    ///
    /// 监听方：SpeechSettingsView（重算发音语言分区）
    /// 触发方：导入后自动识别回写、行内"语言…"编辑保存。必须在主线程发送。
    static let wordbookLanguageDidChange = Notification.Name("wordbookLanguageDidChange")

    /// 发音播放状态已变化（开始 / 结束 / 被打断）
    ///
    /// userInfo：isSpeaking（Bool，回调时刻 synthesizer 状态）、
    /// isPreview（Bool，是否为设置页试听播放）、voiceLanguage（String，播放语音 locale）。
    /// 监听方：SpeechSettingsView（试听按钮状态精确恢复，替代固定延时；
    /// 仅响应 isPreview == true 的通知，悬浮窗自动/手动播报不更新试听按钮）
    /// 触发方：SpeechService 的 AVSpeechSynthesizer 回调（已切主线程发送）。
    static let speechPlaybackStateDidChange = Notification.Name("speechPlaybackStateDidChange")

    /// 预览转场动效（设置页面点击预览时发送）
    ///
    /// userInfo：effectId（String）、parameters（TransitionParameters）。
    /// 监听方：FloatContentView（执行一次预览动效）。
    /// 触发方：ExperienceSettingsView 预览按钮。
    static let previewTransitionEffect = Notification.Name("previewTransitionEffect")
}
