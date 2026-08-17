import AVFoundation

/// 系统 TTS 发音服务
///
/// 基于 AVSpeechSynthesizer 封装，提供：
/// - 单词发音播放（speak）
/// - 英式 / 美式发音切换
/// - TTS 不可用时静默降级
/// - 发音不阻塞背记调度
class SpeechService: NSObject {

    static let shared = SpeechService()

    /// 发音口音
    enum Accent: String {
        case british = "en-GB"
        case american = "en-US"
    }

    // MARK: - 私有属性

    private let synthesizer = AVSpeechSynthesizer()
    private var currentAccent: Accent = .american
    private var availableVoices: [AVSpeechSynthesisVoice] = []
    /// 上次语音列表枚举时间（节流基准，初始化时的首次枚举即起点）
    private var lastVoiceRefreshDate = Date.distantPast

    // MARK: - 初始化

    private override init() {
        super.init()
        synthesizer.delegate = self
        refreshVoices()
    }

    // MARK: - 公开接口

    /// 设置发音口音
    func setAccent(_ accent: Accent) {
        currentAccent = accent
        stopSpeaking()
    }

    /// 根据 AppSettings 的 useAmericanAccent 设置口音
    func applySettings() {
        let accent: Accent = AppSettings.shared.useAmericanAccent ? .american : .british
        setAccent(accent)
        // 设置口音时无条件刷新，立即纳入新下载的系统语音
        refreshVoices()
    }

    /// 播放单词发音
    ///
    /// - Parameter word: 要发音的单词
    /// 若 TTS 不可用，静默跳过不抛错。
    func speak(_ word: String) {
        stopSpeaking()

        // 播放前按需刷新语音列表：超时节流间隔才重新枚举，新下载语音无需重启即生效
        if Date().timeIntervalSince(lastVoiceRefreshDate) > Constants.voiceListRefreshInterval {
            refreshVoices()
        }

        let utterance = AVSpeechUtterance(string: word)

        // 选择对应口音的语音
        if let voice = selectVoice(for: currentAccent) {
            utterance.voice = voice
        }
        // 若无匹配语音，使用系统默认（AVSpeechSynthesizer 会自动 fallback）

        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }

    /// 停止当前发音
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - 私有方法

    /// 刷新可用语音列表
    private func refreshVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
        lastVoiceRefreshDate = Date()
    }

    /// 为指定口音选择最佳语音
    private func selectVoice(for accent: Accent) -> AVSpeechSynthesisVoice? {
        // 优先选择精确匹配（同语言 + 同地区）
        if let exact = availableVoices.first(where: { $0.language == accent.rawValue }) {
            return exact
        }

        // 退而选择同语言
        let languagePrefix = String(accent.rawValue.prefix(2))
        if let langMatch = availableVoices.first(where: { $0.language.hasPrefix(languagePrefix) }) {
            return langMatch
        }

        // 无匹配，返回 nil 让系统使用默认
        return nil
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 发音完成，无需额外处理
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        // 发音开始
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        // 发音被取消（如被新单词中断）
    }
}
