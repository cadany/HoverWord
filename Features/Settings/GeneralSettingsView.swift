import SwiftUI
import Combine

/// 界面语言环境对象
///
/// 语言切换时更新 `current` 触发设置窗口 SwiftUI 树整体重渲染
///（根视图以 `.id(current)` 强制重建），同时通过通知刷新悬浮窗等 AppKit 界面。
final class LanguageManager: ObservableObject {

    /// 当前语言取值（AppSettings.uiLanguage 的镜像，用于驱动视图刷新）
    @Published private(set) var current: String

    init() {
        current = AppSettings.shared.uiLanguage
    }

    /// 切换界面语言并广播变更
    func setLanguage(_ language: String) {
        guard language != current else { return }
        AppSettings.shared.uiLanguage = language
        current = language
        AppSettings.shared.postLanguageChange()
    }
}

/// 通用设置页
///
/// 承载全局类设置，v0.1.1 仅包含"界面语言"。
/// 语言选项数据源为 `L10n.supportedLanguages` 登记表，新增语种无需改本页。
struct GeneralSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("general.language"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(L10n.t("general.language"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker(L10n.t("general.language"), selection: Binding(
                            get: { languageManager.current },
                            set: { languageManager.setLanguage($0) }
                        )) {
                            Text(L10n.t("general.language.system")).tag(L10n.systemLanguage)
                            ForEach(L10n.supportedLanguages, id: \.code) { language in
                                Text(L10n.t(language.nameKey)).tag(language.code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
                .glassCard()

                Spacer()
            }
            .padding(Constants.settingsContentPadding)
        }
        .scrollContentBackground(.hidden)
    }
}
