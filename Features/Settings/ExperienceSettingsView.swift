import SwiftUI

/// 体验设置 Tab 视图
///
/// 配置项：单词切换动效选择、动效参数调整、预览功能。
/// 动效按分类（简约/趣味/沉浸）在下拉中分组展示。
/// 控件风格与发音页一致：标签 + 原生下拉 Picker + 玻璃质感预览按钮。
struct ExperienceSettingsView: View {
    @State private var selectedTransitionId: String = Constants.defaultTransitionId
    @State private var transitionParameters: TransitionParameters = TransitionParameters()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                // 动效选择卡片：原生下拉（按分类分组）+ 预览按钮
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("experience.transition.title"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        // 左侧标签 + 右侧控件组，结构与发音页语音行一致
                        Text(L10n.t("experience.transition.type"))
                            .font(.system(size: 13))

                        Spacer()

                        // 置顶"无"选项 + 按分类分组；"无"不落入分类分组
                        Picker("", selection: $selectedTransitionId) {
                            Text(TransitionRegistry.effect(id: Constants.noneTransitionId)?.displayName ?? "")
                                .tag(Constants.noneTransitionId)

                            ForEach(TransitionCategory.allCases, id: \.self) { category in
                                let effects = TransitionRegistry.all.filter {
                                    $0.category == category && $0.id != Constants.noneTransitionId
                                }
                                if !effects.isEmpty {
                                    Section(category.displayName) {
                                        ForEach(effects, id: \.id) { effect in
                                            Text(effect.displayName).tag(effect.id)
                                        }
                                    }
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                        .onChange(of: selectedTransitionId) { _, newValue in
                            guard AppSettings.shared.selectedTransitionId != newValue else { return }
                            saveSettings()
                        }

                        Button {
                            previewCurrentEffect()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text(L10n.t("experience.preview"))
                                    .font(.system(size: 12))
                            }
                        }
                        .glassButtonStyle()
                    }
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
        .scrollContentBackground(.hidden)
        .onAppear { loadSettings() }
    }

    // MARK: - 子视图

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

    /// 参数滑块行：标签左 + 当前值右（12pt 等宽右对齐 50pt，与其它页滑块行一致）
    private func parameterSlider(for param: TransitionParameter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(param.displayName)
                    .font(.system(size: 13))

                Spacer()

                Text(formatParameterValue(transitionParameters.get(param.id, defaultValue: param.defaultValue), for: param))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
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

    // MARK: - 数据与行为

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

    /// 预览当前选中的动效
    private func previewCurrentEffect() {
        // 发送预览通知，悬浮窗会监听并执行一次动效演示
        NotificationCenter.default.post(
            name: .previewTransitionEffect,
            object: nil,
            userInfo: [
                "effectId": selectedTransitionId,
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
