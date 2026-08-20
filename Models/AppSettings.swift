import AVFoundation
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

    /// 注音字号，默认 10
    var phoneticFontSize: Double = Double(Constants.phoneticFontSize)

    /// 注音显示模式，默认始终显示
    var phoneticVisibility: ContentVisibility = .always

    /// 释义显示模式，默认始终显示
    var meaningVisibility: ContentVisibility = .always

    /// 文字颜色（hex），默认黑色
    var textColorHex: String = Constants.defaultTextColorHex

    // MARK: - 发音

    /// 自动播放开关，默认开启
    var autoPlaySpeech: Bool = true

    /// 按语言键控的语音选择（language code → voice name）
    /// 语种无关设计：新增语种单词本时自动出现对应配置，无需改动数据层
    var voiceNameByLanguage: [String: String] = [:]

    /// 全局语速倍率（0.5 – 1.5），1.0 = 系统默认语速，作用于所有语言
    var speechRateMultiplier: Double = 1.0

    // MARK: - 通用

    /// 界面语言："system"（默认，跟随系统）/ "zh-Hans" / "en"
    var uiLanguage: String = L10n.systemLanguage

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
            phoneticFontSize: phoneticFontSize,
            phoneticVisibility: phoneticVisibility,
            meaningVisibility: meaningVisibility,
            textColorHex: textColorHex,
            autoPlaySpeech: autoPlaySpeech,
            voiceNameByLanguage: voiceNameByLanguage,
            speechRateMultiplier: speechRateMultiplier,
            uiLanguage: uiLanguage
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

    /// 通知界面语言已变更（主线程发送，UI 层立即刷新文案）
    func postLanguageChange() {
        save()
        NotificationCenter.default.post(name: .appLanguageDidChange, object: self)
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
        var phoneticFontSize: Double?
        var phoneticVisibility: ContentVisibility?
        var meaningVisibility: ContentVisibility?
        var textColorHex: String?
        var autoPlaySpeech: Bool
        var voiceNameByLanguage: [String: String]?
        var speechRateMultiplier: Double?
        /// v0.1 旧字段，仅用于一次性迁移读取，不再写入
        var useAmericanAccent: Bool?
        var uiLanguage: String?
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
        // 向后兼容：旧版本无注音/释义显示配置时使用默认值
        phoneticFontSize = stored.phoneticFontSize ?? Double(Constants.phoneticFontSize)
        phoneticVisibility = stored.phoneticVisibility ?? .always
        meaningVisibility = stored.meaningVisibility ?? .always
        // 向后兼容：旧用户无此字段时使用默认值
        textColorHex = stored.textColorHex ?? Constants.defaultTextColorHex
        autoPlaySpeech = stored.autoPlaySpeech
        speechRateMultiplier = stored.speechRateMultiplier ?? 1.0

        // 语音配置：优先读新字段；v0.1 老用户一次性迁移 useAmericanAccent
        var didMigrateVoiceConfig = false
        if let voices = stored.voiceNameByLanguage, !voices.isEmpty {
            voiceNameByLanguage = voices
        } else if let oldAmerican = stored.useAmericanAccent {
            voiceNameByLanguage = ["en": migratedEnglishVoice(preferAmerican: oldAmerican)]
            didMigrateVoiceConfig = true
        } else {
            voiceNameByLanguage = [:]
        }

        // 向后兼容：旧版本无界面语言字段时保持"跟随系统"
        uiLanguage = stored.uiLanguage ?? L10n.systemLanguage

        // 迁移即落盘：否则未改动设置的用户每次启动都会在主线程重复执行
        // migratedEnglishVoice 的 speechVoices() 枚举开销。
        // 须在全部字段回填完成后执行，避免中途快照覆盖其他 stored 值
        if didMigrateVoiceConfig {
            save()
        }
    }

    /// v0.1 → v0.1.1 一次性迁移：旧口音布尔 → 具体英语语音名
    ///
    /// 优先取目标语音（美式 Samantha / 英式 Daniel），
    /// 系统不存在时退而取该口音分区首个语音，均无则返回空串（由 SpeechService 走系统默认）。
    private func migratedEnglishVoice(preferAmerican: Bool) -> String {
        let englishVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
        let preferredLocale = preferAmerican ? "en-US" : "en-GB"
        let preferredName = preferAmerican ? "Samantha" : "Daniel"

        if englishVoices.contains(where: { $0.name == preferredName }) {
            return preferredName
        }
        if let first = englishVoices.first(where: { $0.language == preferredLocale })?.name {
            return first
        }
        return ""
    }
}
