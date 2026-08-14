import SwiftUI

/// 发音设置 Tab 视图
///
/// 配置项：自动播放开关、发音类型（英式/美式）。
struct SpeechSettingsView: View {
    @State private var autoPlay: Bool = true
    @State private var useAmerican: Bool = true

    var body: some View {
        Form {
            Section("发音设置") {
                Toggle("切换单词时自动播放发音", isOn: $autoPlay)
                    .onChange(of: autoPlay) { newValue in
                        AppSettings.shared.autoPlaySpeech = newValue
                        AppSettings.shared.postDidChange()
                    }

                Picker("发音类型", selection: $useAmerican) {
                    Text("英式发音").tag(false)
                    Text("美式发音").tag(true)
                }
                .pickerStyle(.radioGroup)
                .onChange(of: useAmerican) { newValue in
                    AppSettings.shared.useAmericanAccent = newValue
                    SpeechService.shared.applySettings()
                    AppSettings.shared.postDidChange()
                }
            }

            Section {
                Text("发音基于系统语音引擎，离线可用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            autoPlay = AppSettings.shared.autoPlaySpeech
            useAmerican = AppSettings.shared.useAmericanAccent
        }
    }
}
