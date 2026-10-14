import SwiftUI

/// 背记规则设置 Tab 视图
///
/// 配置项：背记模式、Section 设置（每组词数 + 走马灯循环轮次）、展示顺序、停留时长、全屏自动隐藏。
/// 遵循设计原则：macOS 26+ 使用原生 Liquid Glass，低版本使用系统默认控件。
struct ReciteSettingsView: View {
    @State private var reciteMode: ReciteMode = .memoryFeedback
    @State private var carouselLoops: Int = Constants.defaultCarouselLoops
    @State private var maxExposureRounds: Int = Constants.defaultMaxExposureRounds
    @State private var sessionReviewCap: Int = Constants.defaultSessionReviewCap
    @State private var reviewBaseIntervalDays: Double = Constants.defaultReviewBaseIntervalDays
    @State private var sectionSize: Int = Constants.defaultSectionSize
    @State private var playOrder: PlayOrder = .sequential
    @State private var sectionOrder: SectionOrder = .sequential
    @State private var stayDuration: Double = Double(Constants.defaultStayDuration)
    @State private var fullscreenAutoHide: Bool = false
    @State private var muteSpeechInFullscreen: Bool = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                // Section 设置卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("recite.section"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    // Section 词数
                    HStack {
                        Text(L10n.t("recite.sectionSize"))
                            .font(.system(size: 13))
                        Spacer()
                        Stepper(
                            value: $sectionSize,
                            in: Constants.minSectionSize...Constants.maxSectionSize
                        ) {
                            Text("\(sectionSize)")
                                .frame(width: 40, alignment: .trailing)
                        }
                        .onChange(of: sectionSize) { _ in saveSectionSize() }
                    }

                    // Section 顺序（Section 之间）：左标签 + 右分段选择
                    HStack {
                        Text(L10n.t("recite.sectionOrder"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $sectionOrder) {
                            ForEach(SectionOrder.allCases, id: \.self) { order in
                                Text(order.shortDisplayName).tag(order)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .onChange(of: sectionOrder) { _ in saveSectionOrder() }
                    }

                    // Section 内展示顺序：左标签 + 右分段选择
                    HStack {
                        Text(L10n.t("recite.playOrder"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $playOrder) {
                            ForEach(PlayOrder.allCases, id: \.self) { order in
                                Text(order.displayName).tag(order)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .onChange(of: playOrder) { _ in savePlayOrder() }
                    }
                }
                .glassCard()

                // 背记模式卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("recite.mode"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("", selection: $reciteMode) {
                        ForEach(ReciteMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: reciteMode) { _ in saveReciteMode() }
                }
                .glassCard()

                // 走马灯专属卡：循环轮次（仅走马灯模式可交互）
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("recite.carousel"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(L10n.t("recite.carouselLoops"))
                            .font(.system(size: 13))
                        Spacer()
                        Stepper(
                            value: $carouselLoops,
                            in: Constants.minCarouselLoops...Constants.maxCarouselLoops
                        ) {
                            Text("\(carouselLoops)")
                                .frame(width: 40, alignment: .trailing)
                        }
                        .disabled(reciteMode != .carousel)
                        .onChange(of: carouselLoops) { _ in saveCarouselLoops() }
                    }
                }
                .glassCard()
                .disabled(reciteMode != .carousel)
                .opacity(reciteMode == .carousel ? 1.0 : 0.5)

                // 记忆反馈专属卡：单词最大曝光次数（仅记忆反馈模式可交互）
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("recite.memoryFeedback"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(L10n.t("recite.maxExposureRounds"))
                            .font(.system(size: 13))
                        Spacer()
                        Stepper(
                            value: $maxExposureRounds,
                            in: Constants.minMaxExposureRounds...Constants.maxMaxExposureRounds
                        ) {
                            Text("\(maxExposureRounds)")
                                .frame(width: 40, alignment: .trailing)
                        }
                        .disabled(reciteMode != .memoryFeedback)
                        .onChange(of: maxExposureRounds) { _ in saveMaxExposureRounds() }
                    }

                    // 会话复习词上限：0 = 不限
                    HStack {
                        Text(L10n.t("recite.sessionReviewCap"))
                            .font(.system(size: 13))
                        Spacer()
                        Stepper(
                            value: $sessionReviewCap,
                            in: Constants.minSessionReviewCap...Constants.maxSessionReviewCap
                        ) {
                            Text(sessionReviewCap == 0 ? L10n.t("recite.unlimited") : "\(sessionReviewCap)")
                                .frame(width: 50, alignment: .trailing)
                        }
                        .disabled(reciteMode != .memoryFeedback)
                        .onChange(of: sessionReviewCap) { _ in saveSessionReviewCap() }
                    }

                    // 复习基础间隔：0.5 / 1 / 2 天
                    HStack {
                        Text(L10n.t("recite.reviewBaseInterval"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $reviewBaseIntervalDays) {
                            ForEach(Constants.reviewBaseIntervalOptions, id: \.self) { days in
                                Text(String(format: "%g %@", days, L10n.t("recite.dayUnit"))).tag(days)
                            }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                        .disabled(reciteMode != .memoryFeedback)
                        .onChange(of: reviewBaseIntervalDays) { _ in saveReviewBaseInterval() }
                    }
                }
                .glassCard()
                .disabled(reciteMode != .memoryFeedback)
                .opacity(reciteMode == .memoryFeedback ? 1.0 : 0.5)

                // 停留时长卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("recite.stayDuration"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $stayDuration, in: Double(Constants.minStayDuration)...Double(Constants.maxStayDuration), step: 1)
                            .onChange(of: stayDuration) { newValue in
                                saveStayDuration(Int(newValue))
                            }
                        Text(L10n.t("recite.seconds.format", Int(stayDuration)))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                .glassCard()

                // 其他设置卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("recite.other"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Toggle(L10n.t("recite.fullscreenHide"), isOn: $fullscreenAutoHide)
                        .onChange(of: fullscreenAutoHide) { newValue in
                            guard AppSettings.shared.fullscreenAutoHide != newValue else { return }
                            AppSettings.shared.fullscreenAutoHide = newValue
                            AppSettings.shared.postTimingChange()
                        }
                    // 仅在启用全屏隐藏时生效：隐藏期间挂起自动发音，进度不受影响
                    Toggle(L10n.t("recite.muteInFullscreen"), isOn: $muteSpeechInFullscreen)
                        .disabled(!fullscreenAutoHide)
                        .opacity(fullscreenAutoHide ? 1.0 : 0.5)
                        .onChange(of: muteSpeechInFullscreen) { newValue in
                            guard AppSettings.shared.muteSpeechInFullscreen != newValue else { return }
                            AppSettings.shared.muteSpeechInFullscreen = newValue
                            AppSettings.shared.postTimingChange()
                        }
                }
                .glassCard()

                Spacer()
            }
            .padding(Constants.settingsContentPadding)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadSettings() }
    }

    // MARK: - Helpers

    private func loadSettings() {
        reciteMode = AppSettings.shared.reciteMode
        carouselLoops = AppSettings.shared.carouselLoopCount
        maxExposureRounds = AppSettings.shared.maxExposureRounds
        sessionReviewCap = AppSettings.shared.sessionReviewCap
        reviewBaseIntervalDays = AppSettings.shared.reviewBaseIntervalDays
        sectionSize = AppSettings.shared.sectionSize
        playOrder = AppSettings.shared.playOrder
        sectionOrder = AppSettings.shared.sectionOrder
        stayDuration = Double(AppSettings.shared.stayDuration)
        fullscreenAutoHide = AppSettings.shared.fullscreenAutoHide
        muteSpeechInFullscreen = AppSettings.shared.muteSpeechInFullscreen
    }

    private func saveReciteMode() {
        guard AppSettings.shared.reciteMode != reciteMode else { return }
        AppSettings.shared.reciteMode = reciteMode
        AppSettings.shared.postDidChange()
    }

    private func savePlayOrder() {
        guard AppSettings.shared.playOrder != playOrder else { return }
        AppSettings.shared.playOrder = playOrder
        AppSettings.shared.postDidChange()
    }

    private func saveSectionOrder() {
        guard AppSettings.shared.sectionOrder != sectionOrder else { return }
        AppSettings.shared.sectionOrder = sectionOrder
        AppSettings.shared.postDidChange()
    }

    private func saveCarouselLoops() {
        let newValue = min(Constants.maxCarouselLoops, max(Constants.minCarouselLoops, carouselLoops))
        carouselLoops = newValue
        guard AppSettings.shared.carouselLoopCount != newValue else { return }
        AppSettings.shared.carouselLoopCount = newValue
        AppSettings.shared.postDidChange()
    }

    private func saveMaxExposureRounds() {
        let newValue = min(Constants.maxMaxExposureRounds, max(Constants.minMaxExposureRounds, maxExposureRounds))
        maxExposureRounds = newValue
        guard AppSettings.shared.maxExposureRounds != newValue else { return }
        AppSettings.shared.maxExposureRounds = newValue
        AppSettings.shared.postDidChange()
    }

    private func saveSessionReviewCap() {
        let newValue = min(Constants.maxSessionReviewCap, max(Constants.minSessionReviewCap, sessionReviewCap))
        sessionReviewCap = newValue
        guard AppSettings.shared.sessionReviewCap != newValue else { return }
        AppSettings.shared.sessionReviewCap = newValue
        AppSettings.shared.postDidChange()
    }

    private func saveReviewBaseInterval() {
        guard AppSettings.shared.reviewBaseIntervalDays != reviewBaseIntervalDays else { return }
        AppSettings.shared.reviewBaseIntervalDays = reviewBaseIntervalDays
        AppSettings.shared.postDidChange()
    }

    private func saveSectionSize() {
        let newValue = max(Constants.minSectionSize, sectionSize)
        sectionSize = newValue
        guard AppSettings.shared.sectionSize != newValue else { return }
        AppSettings.shared.sectionSize = newValue
        AppSettings.shared.postDidChange()
    }

    private func saveStayDuration(_ value: Int) {
        let clamped = min(Constants.maxStayDuration, max(Constants.minStayDuration, value))
        stayDuration = Double(clamped)
        guard AppSettings.shared.stayDuration != clamped else { return }
        AppSettings.shared.stayDuration = clamped
        AppSettings.shared.postTimingChange()
    }
}
