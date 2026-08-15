import AppKit
import Combine

/// 全局配置模型
///
/// 采用 Codable struct 设计，通过 UserDefaults 存取（JSON 编码单值）。
/// 提供 stored properties 访问各配置项，变更时通过 Notification 广播。
///
/// 当前为骨架实现，包含所有 v0.1 配置字段与默认值。
class AppSettings {
    static let shared = AppSettings()

    private let storageKey = "HoverWordAppSettings"

    // MARK: - 背记规则

    /// 背记模式，默认记忆反馈模式
    var reciteMode: ReciteMode = .memoryFeedback

    /// 走马灯模式单 Section 循环轮次，取值 1-20，默认 3
    var carouselLoopCount: Int = Constants.defaultCarouselLoops

    /// 展示顺序，默认顺序播放
    var playOrder: PlayOrder = .sequential

    /// 单单词停留时长（秒），取值 1-60，默认 5
    var stayDuration: Int = Constants.defaultStayDuration

    /// 全屏自动隐藏开关，默认关闭
    var fullscreenAutoHide: Bool = false

    // MARK: - 单词本

    /// 单 Section 单词数，默认 20，最小值 1
    var sectionSize: Int = Constants.defaultSectionSize

    // MARK: - 外观

    /// 背景色（NSColor 不直接 Codable，存储为 RGBA 分量）
    var backgroundColorHex: String = "#FFFFFF"

    /// 背景透明度，取值 0-1，默认 0.9
    var backgroundOpacity: Double = Double(Constants.defaultBackgroundOpacity)

    /// 单词字体名称，空字符串表示系统默认字体
    var wordFontName: String = ""

    /// 单词字号，默认 14
    var wordFontSize: Double = Double(Constants.wordFontSize)

    /// 释义字体名称，空字符串表示系统默认字体
    var meaningFontName: String = ""

    /// 释义字号，默认 12
    var meaningFontSize: Double = Double(Constants.meaningFontSize)

    /// 文字颜色（hex），默认黑色
    var textColorHex: String = Constants.defaultTextColorHex

    // MARK: - 发音

    /// 自动播放开关，默认开启
    var autoPlaySpeech: Bool = true

    /// 发音类型：true=美式，false=英式，默认美式
    var useAmericanAccent: Bool = true

    // MARK: - 持久化

    private init() {}

    /// 从 UserDefaults 加载设置，若无历史配置则使用默认值
    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(StoredSettings.self, from: data) else {
            return
        }
        apply(stored: settings)
    }

    /// 将当前设置持久化到 UserDefaults
    func save() {
        let stored = StoredSettings(
            reciteMode: reciteMode,
            carouselLoopCount: carouselLoopCount,
            playOrder: playOrder,
            stayDuration: stayDuration,
            fullscreenAutoHide: fullscreenAutoHide,
            sectionSize: sectionSize,
            backgroundColorHex: backgroundColorHex,
            backgroundOpacity: backgroundOpacity,
            wordFontName: wordFontName,
            wordFontSize: wordFontSize,
            meaningFontName: meaningFontName,
            meaningFontSize: meaningFontSize,
            textColorHex: textColorHex,
            autoPlaySpeech: autoPlaySpeech,
            useAmericanAccent: useAmericanAccent
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// 通知背记规则已变更（影响队列结构，引擎需重启）
    func postDidChange() {
        save()
        NotificationCenter.default.post(name: .appSettingsDidChange, object: self)
    }

    /// 通知外观设置已变更（不影响队列，仅刷新 UI）
    func postAppearanceChange() {
        save()
        NotificationCenter.default.post(name: .appAppearanceDidChange, object: self)
    }

    /// 通知计时参数已变更（仅热更新计时器，不重置进度）
    func postTimingChange() {
        save()
        NotificationCenter.default.post(name: .appTimingDidChange, object: self)
    }

    // MARK: - Codable 内部模型

    private struct StoredSettings: Codable {
        var reciteMode: ReciteMode
        var carouselLoopCount: Int
        var playOrder: PlayOrder
        var stayDuration: Int
        var fullscreenAutoHide: Bool
        var sectionSize: Int
        var backgroundColorHex: String
        var backgroundOpacity: Double
        var wordFontName: String
        var wordFontSize: Double
        var meaningFontName: String
        var meaningFontSize: Double
        var textColorHex: String?
        var autoPlaySpeech: Bool
        var useAmericanAccent: Bool
    }

    private func apply(stored: StoredSettings) {
        reciteMode = stored.reciteMode
        carouselLoopCount = stored.carouselLoopCount
        playOrder = stored.playOrder
        stayDuration = stored.stayDuration
        fullscreenAutoHide = stored.fullscreenAutoHide
        sectionSize = stored.sectionSize
        backgroundColorHex = stored.backgroundColorHex
        backgroundOpacity = stored.backgroundOpacity
        // 向后兼容：旧版默认 "San Francisco" 等价于空字符串（系统默认）
        wordFontName = stored.wordFontName == "San Francisco" ? "" : stored.wordFontName
        wordFontSize = stored.wordFontSize
        meaningFontName = stored.meaningFontName == "San Francisco" ? "" : stored.meaningFontName
        meaningFontSize = stored.meaningFontSize
        // 向后兼容：旧用户无此字段时使用默认值
        textColorHex = stored.textColorHex ?? Constants.defaultTextColorHex
        autoPlaySpeech = stored.autoPlaySpeech
        useAmericanAccent = stored.useAmericanAccent
    }
}
