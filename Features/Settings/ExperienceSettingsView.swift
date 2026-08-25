import SwiftUI

/// 体验设置 Tab 视图
///
/// 配置项：单词切换动效选择、动效参数调整、预览功能。
/// 动效按分类（简约/趣味/沉浸）分组展示。
struct ExperienceSettingsView: View {
    @State private var selectedTransitionId: String = Constants.defaultTransitionId
    @State private var transitionParameters: TransitionParameters = TransitionParameters()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                // 动效选择卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("experience.transition.title"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    // 下拉列表选择动效（按分类分组）
                    Menu {
                        ForEach(TransitionCategory.allCases, id: \.self) { category in
                            let effects = TransitionRegistry.all.filter { $0.category == category }
                            if !effects.isEmpty {
                                Section(category.displayName) {
                                    ForEach(effects, id: \.id) { effect in
                                        Button(action: {
                                            selectedTransitionId = effect.id
                                            saveSettings()
                                        }) {
                                            HStack {
                                                Text(effect.displayName)
                                                if selectedTransitionId == effect.id {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentEffectDisplayName())
                                .font(.system(size: 13))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.05))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()

                    // 预览按钮
                    Button(action: {
                        if let effect = TransitionRegistry.effect(id: selectedTransitionId) {
                            previewEffect(effect)
                        }
                    }) {
                        Text(L10n.t("experience.preview"))
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .glassCard()

                // 参数调整卡片（仅当选中动效有可调参数时显示）
                if let effect = TransitionRegistry.effect(id: selectedTransitionId),
                   !effect.adjustableParameters.isEmpty {
                    parameterAdjustmentCard(for: effect)
                }

                Spacer()
            }
            .padding(Constants.settingsContentPadding)
        }
        .hiddenScrollBackground()
        .onAppear { loadSettings() }
    }

    /// 获取当前选中动效的显示名称
    private func currentEffectDisplayName() -> String {
        if let effect = TransitionRegistry.effect(id: selectedTransitionId) {
            return effect.displayName
        }
        return L10n.t("settings.transition.effect.classic-fade")
    }

    /// 参数调整卡片
    private func parameterAdjustmentCard(for effect: any WordTransitionEffect) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("experience.parameters.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            ForEach(effect.adjustableParameters, id: \.id) { param in
                parameterSlider(for: param)
            }
        }
        .glassCard()
    }

    /// 参数滑块
    private func parameterSlider(for param: TransitionParameter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(param.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)

                Spacer()

                Text(formatParameterValue(transitionParameters.get(param.id, defaultValue: param.defaultValue), for: param))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Slider(
                value: Binding(
                    get: { transitionParameters.get(param.id, defaultValue: param.defaultValue) },
                    set: { newValue in
                        transitionParameters.setClamped(param.id, newValue, range: param.range)
                        saveSettings()
                    }
                ),
                in: param.range,
                step: param.step
            )
        }
        .padding(.vertical, 4)
    }

    /// 格式化参数值显示
    private func formatParameterValue(_ value: Double, for param: TransitionParameter) -> String {
        // 根据参数类型格式化
        if param.id.contains("duration") || param.id.contains("interval") {
            // 时间参数，显示为秒，保留 2 位小数
            return String(format: "%.2fs", value)
        } else if param.id.contains("intensity") {
            // 强度参数，显示为倍数，保留 1 位小数
            return String(format: "%.1fx", value)
        } else {
            // 默认显示 2 位小数
            return String(format: "%.2f", value)
        }
    }

    /// 预览动效
    private func previewEffect(_ effect: any WordTransitionEffect) {
        // 发送预览通知，悬浮窗会监听并执行一次动效演示
        NotificationCenter.default.post(
            name: .previewTransitionEffect,
            object: nil,
            userInfo: [
                "effectId": effect.id,
                "parameters": transitionParameters
            ]
        )
    }

    /// 加载设置
    private func loadSettings() {
        selectedTransitionId = AppSettings.shared.selectedTransitionId
        transitionParameters = AppSettings.shared.transitionParameters
    }

    /// 保存设置
    private func saveSettings() {
        AppSettings.shared.selectedTransitionId = selectedTransitionId
        AppSettings.shared.transitionParameters = transitionParameters
        AppSettings.shared.save()
        // 通知外观变更（动效属于体验设置，但影响悬浮窗行为）
        NotificationCenter.default.post(name: .appAppearanceDidChange, object: nil)
    }
}
