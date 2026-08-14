import SwiftUI

/// 背记规则设置 Tab 视图
///
/// 配置项：背记模式、Section 设置（每组词数 + 走马灯循环轮次）、展示顺序、停留时长、全屏自动隐藏。
/// 遵循设计原则：macOS 26+ 使用原生 Liquid Glass，低版本使用系统默认控件。
struct ReciteSettingsView: View {
    @State private var reciteMode: ReciteMode = .memoryFeedback
    @State private var carouselLoops: Int = Constants.defaultCarouselLoops
    @State private var sectionSize: Int = Constants.defaultSectionSize
    @State private var playOrder: PlayOrder = .sequential
    @State private var stayDuration: Double = Double(Constants.defaultStayDuration)
    @State private var fullscreenAutoHide: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                // 背记模式卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text("背记模式")
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

                // Section 设置卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("Section 设置")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    // 每组词数
                    HStack {
                        Text("每组词数")
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

                    // 走马灯循环轮次（非走马灯模式禁用）
                    HStack {
                        Text("走马灯循环轮次")
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
                    .opacity(reciteMode == .carousel ? 1.0 : 0.5)
                }
                .glassCard()

                // 展示顺序卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text("展示顺序")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Picker("", selection: $playOrder) {
                        ForEach(PlayOrder.allCases, id: \.self) { order in
                            Text(order.displayName).tag(order)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .onChange(of: playOrder) { _ in savePlayOrder() }
                }
                .glassCard()

                // 停留时长卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text("单单词停留时长")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack {
                        Slider(value: $stayDuration, in: Double(Constants.minStayDuration)...Double(Constants.maxStayDuration), step: 1)
                            .onChange(of: stayDuration) { newValue in
                                saveStayDuration(Int(newValue))
                            }
                        Text("\(Int(stayDuration)) 秒")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                .glassCard()

                // 其他设置卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text("其他")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Toggle("全屏应用时自动隐藏悬浮窗", isOn: $fullscreenAutoHide)
                        .onChange(of: fullscreenAutoHide) { newValue in
                            AppSettings.shared.fullscreenAutoHide = newValue
                            AppSettings.shared.postDidChange()
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
        sectionSize = AppSettings.shared.sectionSize
        playOrder = AppSettings.shared.playOrder
        stayDuration = Double(AppSettings.shared.stayDuration)
        fullscreenAutoHide = AppSettings.shared.fullscreenAutoHide
    }

    private func saveReciteMode() {
        AppSettings.shared.reciteMode = reciteMode
        AppSettings.shared.postDidChange()
    }

    private func savePlayOrder() {
        AppSettings.shared.playOrder = playOrder
        AppSettings.shared.postDidChange()
    }

    private func saveCarouselLoops() {
        AppSettings.shared.carouselLoopCount = min(
            Constants.maxCarouselLoops,
            max(Constants.minCarouselLoops, carouselLoops)
        )
        carouselLoops = AppSettings.shared.carouselLoopCount
        AppSettings.shared.postDidChange()
    }

    private func saveSectionSize() {
        AppSettings.shared.sectionSize = max(Constants.minSectionSize, sectionSize)
        sectionSize = AppSettings.shared.sectionSize
        AppSettings.shared.postDidChange()
    }

    private func saveStayDuration(_ value: Int) {
        let clamped = min(Constants.maxStayDuration, max(Constants.minStayDuration, value))
        stayDuration = Double(clamped)
        AppSettings.shared.stayDuration = clamped
        AppSettings.shared.postDidChange()
    }
}
