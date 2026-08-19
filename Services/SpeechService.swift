import AVFoundation

/// 系统 TTS 发音服务
///
/// 基于 AVSpeechSynthesizer 封装，语言参数化设计（多语种架构预留）：
/// - 按语言选择具体系统语音（配置于 AppSettings.voiceNameByLanguage）
/// - 全局语速控制（AppSettings.speechRateMultiplier）
/// - 试听预览（preview）
/// - TTS 不可用时静默降级，不阻塞背记调度
class SpeechService: NSObject {

    static let shared = SpeechService()

    /// 语音信息（供设置 UI 展示与选择）
    struct VoiceInfo: Equatable {
        /// 系统展示名（如 Samantha）
        let name: String
        /// BCP-47 语言代码（如 en-US）
        let language: String
        /// 系统语音唯一标识
        let identifier: String
        /// 语音质量，供列表排序与 UI 标记
        let quality: VoiceQuality
    }

    /// 语音质量等级（rawValue 越大质量越高，排序直接用 Comparable）
    enum VoiceQuality: Int, Comparable {
        case `default` = 1
        case enhanced = 2
        case premium = 3

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        init(avQuality: AVSpeechSynthesisVoiceQuality) {
            switch avQuality {
            case .premium: self = .premium
            case .enhanced: self = .enhanced
            default: self = .default
            }
        }
    }

    // MARK: - 私有属性

    private let synthesizer = AVSpeechSynthesizer()
    private var cachedVoices: [AVSpeechSynthesisVoice] = []
    /// 上次语音列表枚举时间（节流基准，初始化时的首次枚举即起点）
    private var lastVoiceRefreshDate = Date.distantPast

    /// 当前播放是否为设置页试听（供播放状态通知区分来源：
    /// 悬浮窗自动/手动播报不携带试听标记，设置页据此避免误更新试听按钮）
    private(set) var isPreviewing = false

    /// 系统 novelty（趣味/特效）语音黑名单：无语言学习价值，从可选列表剔除
    private static let noveltyVoiceNames: Set<String> = [
        "Albert", "Bad News", "Bahh", "Bells", "Boing", "Bubbles", "Cellos",
        "Deranged", "Good News", "Hysterical", "Junior", "Pipe Organ",
        "Ralph", "Trinoids", "Whisper", "Zarvox",
    ]

    // MARK: - 初始化

    private override init() {
        super.init()
        synthesizer.delegate = self
        refreshVoices()
    }

    // MARK: - 公开接口

    /// 设置某语言使用的语音
    ///
    /// - Parameters:
    ///   - language: 语言代码（如 "en"）
    ///   - voiceName: 语音展示名（如 "Samantha"）
    func setVoice(for language: String, voiceName: String) {
        AppSettings.shared.voiceNameByLanguage[language] = voiceName
        stopSpeaking()
    }

    /// 设置变更后重新读取配置
    ///
    /// 无条件刷新语音列表，立即纳入新下载的系统语音。
    func applySettings() {
        refreshVoices()
        stopSpeaking()
    }

    /// 播放单词发音（悬浮窗自动播报 / ▶ 手动播报）
    ///
    /// - Parameters:
    ///   - word: 要发音的单词
    ///   - language: 语言代码（如 "en"）
    /// 若该语言无任何可用语音，静默跳过不抛错。
    func speak(_ word: String, language: String) {
        isPreviewing = false
        speakInternal(word, language: language)
    }

    /// 试听：使用当前选中语音 + 当前语速播放固定示例句
    func preview(language: String) {
        isPreviewing = true
        speakInternal(Constants.speechPreviewSentence, language: language)
    }

    /// 播放实现：isPreviewing 必须在调用前设置完毕，
    /// 使 stopSpeaking 触发的旧 utterance cancel 回调读取到新来源标记
    private func speakInternal(_ word: String, language: String) {
        stopSpeaking()

        // 播放前按需刷新语音列表：超时节流间隔才重新枚举，新下载语音无需重启即生效
        if Date().timeIntervalSince(lastVoiceRefreshDate) > Constants.voiceListRefreshInterval {
            refreshVoices()
        }

        // 该语言无任何可用语音：静默降级，不影响背记流程
        guard let voice = selectVoice(for: language) else { return }

        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Float(AppSettings.shared.speechRateMultiplier)
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }

    /// 停止当前发音
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    /// 指定语言的系统可用语音列表（供设置 UI 下拉展示）
    ///
    /// 按语言前缀过滤（如 "en" 匹配所有 en-* 语音）并剔除 novelty 趣味语音，
    /// 排序：用户当前选中语音置顶，其余按质量（premium > enhanced > default）+ 名称。
    func availableVoices(for language: String) -> [VoiceInfo] {
        let prefix = String(language.prefix(2))
        let selectedName = AppSettings.shared.voiceNameByLanguage[language]

        let voices = cachedVoices
            .filter { $0.language.hasPrefix(prefix) && !Self.noveltyVoiceNames.contains($0.name) }
            .map { Self.voiceInfo(from: $0) }

        return voices.sorted { a, b in
            let aSelected = (a.name == selectedName)
            let bSelected = (b.name == selectedName)
            if aSelected != bSelected { return aSelected }
            if a.quality != b.quality { return a.quality > b.quality }
            return a.name < b.name
        }
    }

    /// 指定语言可用的口音（locale 变体）列表，如 "en" → ["en-US", "en-GB", "en-AU"]
    ///
    /// 供口音快捷分段控件使用；已剔除仅含 novelty 语音的 locale，
    /// 主流口音（US/GB）置前，其余按 locale 代码字典序。
    func availableAccents(for language: String) -> [String] {
        let prefix = String(language.prefix(2))
        var locales = Set<String>()
        for voice in cachedVoices where voice.language.hasPrefix(prefix)
            && !Self.noveltyVoiceNames.contains(voice.name) {
            locales.insert(voice.language)
        }
        return locales.sorted { a, b in
            let aPriority = (a == "\(prefix)-US" || a == "\(prefix)-GB")
            let bPriority = (b == "\(prefix)-US" || b == "\(prefix)-GB")
            if aPriority != bPriority { return aPriority }
            return a < b
        }
    }

    /// 当前生效语音所属口音（locale），供分段控件回显选中态
    ///
    /// 选中语音不可用时返回系统默认语音的 locale，仍无则返回 nil。
    func currentAccent(for language: String) -> String? {
        if let voice = selectVoice(for: language) {
            return voice.language
        }
        return nil
    }

    /// 切换口音：将该语言的语音设置为指定 locale 的系统默认语音
    ///
    /// - Returns: 设置成功返回默认语音名，locale 无可用语音返回 nil
    @discardableResult
    func setAccent(_ locale: String, for language: String) -> String? {
        guard let voice = AVSpeechSynthesisVoice(language: locale) else { return nil }
        setVoice(for: language, voiceName: voice.name)
        return voice.name
    }

    /// AVSpeechSynthesisVoice → VoiceInfo
    private static func voiceInfo(from voice: AVSpeechSynthesisVoice) -> VoiceInfo {
        VoiceInfo(
            name: voice.name,
            language: voice.language,
            identifier: voice.identifier,
            quality: VoiceQuality(avQuality: voice.quality)
        )
    }

    // MARK: - 私有方法

    /// 刷新可用语音列表
    private func refreshVoices() {
        cachedVoices = AVSpeechSynthesisVoice.speechVoices()
        lastVoiceRefreshDate = Date()
    }

    /// 为指定语言选择语音
    ///
    /// 选择链：用户配置的语音名（精确匹配）→ 该语言系统默认（AVSpeechSynthesisVoice(language:)）
    /// → 同语言前缀首个语音；均无返回 nil（调用方静默跳过）。
    private func selectVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let prefix = String(language.prefix(2))

        // 1. 用户为该语言显式选中的语音（不可用时自然落入后续回退）
        if let selectedName = AppSettings.shared.voiceNameByLanguage[language],
           let exact = cachedVoices.first(where: { $0.name == selectedName && $0.language.hasPrefix(prefix) }) {
            return exact
        }

        // 2. 该语言的系统默认语音
        if let systemDefault = AVSpeechSynthesisVoice(language: language)
            ?? AVSpeechSynthesisVoice(language: prefix) {
            return systemDefault
        }

        // 3. 同语言前缀首个可用语音
        return cachedVoices.first { $0.language.hasPrefix(prefix) }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        postPlaybackStateChange(utterance: utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        postPlaybackStateChange(utterance: utterance)
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        postPlaybackStateChange(utterance: utterance)
    }

    /// 广播播放状态变化（主线程），供设置页试听按钮精确恢复。
    /// 携带播放语音的 locale（如 en-US）与来源标记 isPreview：
    /// - 连续试听时 stop 的 cancel 通知与新 utterance 的 start 通知竞态，UI 需靠 start 通知携带的语言回填状态
    /// - 悬浮窗自动/手动播报不携带试听标记，设置页据此避免误更新试听按钮
    private func postPlaybackStateChange(utterance: AVSpeechUtterance) {
        let isSpeaking = synthesizer.isSpeaking
        let isPreview = isPreviewing
        let voiceLanguage = utterance.voice?.language
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .speechPlaybackStateDidChange,
                object: nil,
                userInfo: [
                    "isSpeaking": isSpeaking,
                    "isPreview": isPreview,
                    "voiceLanguage": voiceLanguage ?? "",
                ]
            )
        }
    }
}
