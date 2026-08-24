import SwiftUI

/// 发音设置 Tab 视图
///
/// v0.1.1 配置项：自动播放开关、口音快捷分段（默认）、高级折叠区（具体语音选择 + 试听）、全局语速。
/// 语言分区数据源为启用中单词本的 sourceLang（启停/删除词本即时刷新，
/// 底层以 language code 为键，语种无关），无启用词本时回退英语分区。
struct SpeechSettingsView: View {
    @State private var autoPlay: Bool = true
    @State private var speechRate: Double = Constants.speechRateDefault
    /// 试听播放中的语言代码（配合语音播放状态通知精确恢复按钮）
    @State private var previewingLanguage: String?
    /// 各语言当前选中的口音 locale 与语音名（SwiftUI 状态驱动刷新，
    /// 写入时同步落 AppSettings.voiceNameByLanguage）
    @State private var selectedAccentByLanguage: [String: String] = [:]
    @State private var selectedVoiceByLanguage: [String: String] = [:]

    /// 参与设置的语言分区：启用中单词本的 sourceLang 去重；无启用词本时回退英语。
    /// 必须是 @State 而非计算属性——数据源是 Core Data 而非被观察状态，
    /// 计算属性只随其它 @State 变化重算，词本启停后分区列表会冻结在旧值
    @State private var activeLanguages: [String] = ["en"]

    /// 重算语言分区集合（onAppear 与词本启停/删除通知时调用）
    private func refreshActiveLanguages() {
        let languages = WordbookService.shared.getEnabledWordbooks()
            .map { $0.sourceLang }
        let unique = Array(Set(languages)).sorted()
        let newValue = unique.isEmpty ? ["en"] : unique
        if newValue != activeLanguages {
            activeLanguages = newValue
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                // 自动播放卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("speech.title"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(L10n.t("speech.autoPlay"))
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $autoPlay)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: autoPlay) { _, newValue in
                                guard AppSettings.shared.autoPlaySpeech != newValue else { return }
                                AppSettings.shared.autoPlaySpeech = newValue
                                AppSettings.shared.postAppearanceChange()
                            }
                    }
                }
                .glassCard()

                // 语言分区卡片：口音快捷 + 高级折叠语音选择
                ForEach(activeLanguages, id: \.self) { language in
                    languageSection(for: language)
                }

                // 语速卡片（全局，不分语言）
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("speech.rate"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Slider(
                            value: $speechRate,
                            in: Constants.speechRateMin...Constants.speechRateMax,
                            step: Constants.speechRateStep,
                            onEditingChanged: { editing in
                                // 拖动释放时自动试听，用当前语音 + 新语速即时感知效果
                                if !editing {
                                    previewFirstLanguage()
                                }
                            }
                        )
                        .onChange(of: speechRate) { _, newValue in
                            guard AppSettings.shared.speechRateMultiplier != newValue else { return }
                            AppSettings.shared.speechRateMultiplier = newValue
                            AppSettings.shared.postTimingChange()
                        }

                        Text(L10n.t("speech.rate.format", String(format: "%.1f", speechRate)))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                .glassCard()

                // 说明卡片
                Text(L10n.t("speech.footer"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                Spacer()
            }
            .padding(Constants.settingsContentPadding)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadSettings() }
        .onReceive(NotificationCenter.default.publisher(for: .wordbookEnablementDidChange)) { _ in
            // 词本启停/删除改变启用语言集合：即时刷新分区并回填新分区选中态
            //（覆盖设置页常驻、onAppear 不再触发的场景）
            refreshActiveLanguages()
            loadSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .wordbookLanguageDidChange)) { _ in
            // 词本语言对变更（导入自动识别 / 行内"语言…"编辑）：重算分区
            refreshActiveLanguages()
            loadSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .speechPlaybackStateDidChange)) { note in
            // 通知已切主线程。只响应试听来源的播放：悬浮窗自动/手动播报与试听共用
            // synthesizer，无来源过滤的话每次切词播报都会让试听按钮闪烁"停止"
            guard let isSpeaking = note.userInfo?["isSpeaking"] as? Bool,
                  let isPreview = note.userInfo?["isPreview"] as? Bool else { return }
            if isPreview {
                // 连续试听竞态下 cancel 通知可能先清空，靠 start 通知回填
                if isSpeaking, let voiceLanguage = note.userInfo?["voiceLanguage"] as? String,
                   let language = activeLanguages.first(where: { voiceLanguage.hasPrefix(String($0.prefix(2))) }) {
                    previewingLanguage = language
                } else if !isSpeaking {
                    previewingLanguage = nil
                }
            } else if previewingLanguage != nil {
                // 非试听播放到达时试听状态仍残留：试听已被打断，恢复按钮
                previewingLanguage = nil
            }
        }
    }

    // MARK: - 语言分区卡片

    private func languageSection(for language: String) -> some View {
        let accents = SpeechService.shared.availableAccents(for: language)
        let currentAccent = selectedAccentByLanguage[language] ?? SpeechService.shared.currentAccent(for: language) ?? accents.first ?? language

        return VStack(alignment: .leading, spacing: 12) {
            Text(sectionTitle(for: language))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            // 口音选择：标签 + 原生下拉 Picker（系统箭头在文本右侧，
            // 与下方"语音"下拉控件样式统一；自定义 Menu label 的箭头
            // 会被 macOS 提取到左侧或无法渲染，不可靠）
            HStack {
                Text(L10n.t("speech.accent"))
                    .font(.system(size: 13))
                Spacer()
                Picker("", selection: Binding(
                    get: { currentAccent },
                    set: { newAccent in
                        switchAccent(newAccent, for: language)
                    }
                )) {
                    ForEach(accents, id: \.self) { accent in
                        Text(accentTitle(for: accent)).tag(accent)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }

            // 高级折叠：具体语音选择（按当前口音过滤），标签展示当前生效语音
            VStack(alignment: .leading, spacing: 10) {
                DisclosureGroup(advancedLabel(for: language, accent: currentAccent)) {
                    voicePicker(for: language, accent: currentAccent)
                }
                .font(.system(size: 12))
                .tint(.secondary)
            }
        }
        .glassCard()
    }

    /// 高级区语音选择行：下拉（语音名 + 地区 + 音质标记）+ 试听/停止
    /// - Parameter accent: 当前选中的口音 locale，用于过滤语音列表
    @ViewBuilder
    private func voicePicker(for language: String, accent: String) -> some View {
        // 按口音过滤：只显示该口音（locale）下的语音
        let allVoices = SpeechService.shared.availableVoices(for: language)
        let voices = allVoices.filter { $0.language == accent }
        let selected = selectedVoiceByLanguage[language] ?? effectiveSelectedVoice(for: language, in: voices)
        let configuredUnavailable = isConfiguredVoiceUnavailable(for: language, in: voices)
        let isPreviewing = (previewingLanguage == language)

        VStack(alignment: .leading, spacing: 8) {
            if voices.isEmpty {
                // 该口音下无可用语音（极端情况：系统未下载该 locale 的语音）
                Text(L10n.t("speech.voice.empty"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 8) {
                    Text(L10n.t("speech.voice"))
                        .font(.system(size: 13))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { selected },
                        set: { newValue in saveVoice(newValue, for: language) }
                    )) {
                        ForEach(voices, id: \.identifier) { voice in
                            Text(voiceLabel(voice)).tag(voice.name)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()

                    Button {
                        isPreviewing ? stopPreview() : previewVoice(for: language)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isPreviewing ? "stop.fill" : "play.fill")
                                .font(.system(size: 9))
                            Text(L10n.t(isPreviewing ? "speech.voice.stop" : "speech.voice.preview"))
                                .font(.system(size: 12))
                        }
                    }
                    .glassButtonStyle()
                }

                // 配置语音不可用提示（回退系统默认生效中）
                if configuredUnavailable {
                    Text(L10n.t("speech.voice.unavailable"))
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 数据与行为

    private func loadSettings() {
        refreshActiveLanguages()
        autoPlay = AppSettings.shared.autoPlaySpeech
        speechRate = AppSettings.shared.speechRateMultiplier
        // 打开设置页时无条件刷新语音列表，纳入新下载的系统语音
        SpeechService.shared.applySettings()

        // 从实际生效配置回填选中态（配置语音不可用时展示回退后的语音）
        for language in activeLanguages {
            let voices = SpeechService.shared.availableVoices(for: language)
            selectedVoiceByLanguage[language] = effectiveSelectedVoice(for: language, in: voices)
            selectedAccentByLanguage[language] = SpeechService.shared.currentAccent(for: language)
        }
    }

    /// Picker 实际选中值：配置有效用配置值，否则展示 SpeechService 实际会用的语音
    private func effectiveSelectedVoice(for language: String, in voices: [SpeechService.VoiceInfo]) -> String {
        if let configured = AppSettings.shared.voiceNameByLanguage[language],
           voices.contains(where: { $0.name == configured }) {
            return configured
        }
        return voices.first?.name ?? ""
    }

    /// 配置的语音已不可用（需提示用户已回退系统默认）
    private func isConfiguredVoiceUnavailable(for language: String, in voices: [SpeechService.VoiceInfo]) -> Bool {
        guard let configured = AppSettings.shared.voiceNameByLanguage[language], !configured.isEmpty else {
            return false
        }
        return !voices.contains(where: { $0.name == configured })
    }

    /// 语音下拉选项文案：名称（地区）+ 非默认音质追加标记
    private func voiceLabel(_ voice: SpeechService.VoiceInfo) -> String {
        var label = "\(voice.name) (\(voice.language))"
        let qualityKey: String?
        switch voice.quality {
        case .premium: qualityKey = "speech.voice.quality.premium"
        case .enhanced: qualityKey = "speech.voice.quality.enhanced"
        case .default: qualityKey = nil
        }
        if let qualityKey {
            label += " · \(L10n.t(qualityKey))"
        }
        return label
    }

    /// 口音分段选项文案：优先词条（如 "美式"），未来语种缺词条时回退
    /// 系统本地化地区名（"zh-CN" → "中国大陆"），仍取不到时回退 locale 代码
    private func accentTitle(for accent: String) -> String {
        let key = "speech.accent.\(accent)"
        let title = L10n.t(key)
        if title != key { return title }
        if let region = accent.components(separatedBy: "-").last,
           let regionName = Locale(identifier: "zh_CN").localizedString(forRegionCode: region) {
            return regionName
        }
        return accent
    }

    /// 分区标题：优先取词条（如 "英语 (English)"），未来语种缺词条时回退
    /// 系统本地化语言名（"ja" → "日语 (Japanese)"），仍取不到时显示原始语言代码
    private func sectionTitle(for language: String) -> String {
        let key = "speech.language.\(language)"
        let title = L10n.t(key)
        if title != key { return title }
        let zhName = Locale(identifier: "zh_CN").localizedString(forLanguageCode: language)
        let enName = Locale(identifier: "en_US").localizedString(forLanguageCode: language)
        switch (zhName, enName) {
        case let (zh?, en?) where zh != en: return "\(zh) (\(en))"
        case let (name?, _): return name
        default: return language
        }
    }

    /// 高级折叠标签：展示当前生效语音名；口音下无可用语音时回退通用文案
    private func advancedLabel(for language: String, accent: String) -> String {
        let voices = SpeechService.shared.availableVoices(for: language).filter { $0.language == accent }
        let voiceName = selectedVoiceByLanguage[language] ?? voices.first?.name ?? ""
        guard !voiceName.isEmpty else { return L10n.t("speech.advanced") }
        return L10n.t("speech.advanced.format", voiceName)
    }

    private func saveVoice(_ voiceName: String, for language: String) {
        guard AppSettings.shared.voiceNameByLanguage[language] != voiceName else { return }
        SpeechService.shared.setVoice(for: language, voiceName: voiceName)
        AppSettings.shared.postAppearanceChange()

        // 同步选中态：语音 + 所属口音分段
        selectedVoiceByLanguage[language] = voiceName
        let voices = SpeechService.shared.availableVoices(for: language)
        selectedAccentByLanguage[language] = voices.first(where: { $0.name == voiceName })?.language
            ?? SpeechService.shared.currentAccent(for: language)
    }

    /// 口音分段切换：设置为该口音的系统默认语音，并同步高级区选中态
    private func switchAccent(_ accent: String, for language: String) {
        guard let defaultVoiceName = SpeechService.shared.setAccent(accent, for: language) else { return }
        AppSettings.shared.postAppearanceChange()
        selectedAccentByLanguage[language] = accent
        selectedVoiceByLanguage[language] = defaultVoiceName
    }

    private func previewVoice(for language: String) {
        previewingLanguage = language
        SpeechService.shared.preview(language: language)
    }

    private func stopPreview() {
        SpeechService.shared.stopSpeaking()
        previewingLanguage = nil
    }

    /// 语速滑块释放后的试听：播放中先停止再试听新语速
    private func previewFirstLanguage() {
        guard let language = activeLanguages.first else { return }
        previewVoice(for: language)
    }
}
