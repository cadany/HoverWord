import SwiftUI

/// 发音设置 Tab 视图
///
/// 配置项：自动播放开关、发音类型（英式/美式）。
/// 遵循设计原则：macOS 26+ 使用原生 Liquid Glass，低版本使用系统默认控件。
struct SpeechSettingsView: View {
    @State private var autoPlay: Bool = true
    @State private var useAmerican: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                // 发音设置卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("发音设置")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("切换单词时自动播放发音")
                            .font(.system(size: 13))
                        Spacer()
                        Toggle("", isOn: $autoPlay)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: autoPlay) { newValue in
                                guard AppSettings.shared.autoPlaySpeech != newValue else { return }
                                AppSettings.shared.autoPlaySpeech = newValue
                                AppSettings.shared.postAppearanceChange()
                            }
                    }

                    Divider()

                    HStack {
                        Text("发音类型")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $useAmerican) {
                            Text("英式").tag(false)
                            Text("美式").tag(true)
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: useAmerican) { _ in saveAccent() }
                    }
                }
                .glassCard()

                // 说明卡片
                Text("发音基于系统语音引擎，离线可用")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()

                Spacer()
            }
            .padding(Constants.settingsContentPadding)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadSettings() }
    }

    private func loadSettings() {
        autoPlay = AppSettings.shared.autoPlaySpeech
        useAmerican = AppSettings.shared.useAmericanAccent
    }

    private func saveAccent() {
        guard AppSettings.shared.useAmericanAccent != useAmerican else { return }
        AppSettings.shared.useAmericanAccent = useAmerican
        SpeechService.shared.applySettings()
        AppSettings.shared.postAppearanceChange()
    }
}
