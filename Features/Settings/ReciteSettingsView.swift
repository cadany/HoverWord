import SwiftUI

/// 背记规则设置 Tab 视图
///
/// 配置项：背记模式、走马灯轮次、展示顺序、停留时长、全屏自动隐藏。
struct ReciteSettingsView: View {
    @State private var reciteMode: ReciteMode = .memoryFeedback
    @State private var carouselLoops: Int = Constants.defaultCarouselLoops
    @State private var playOrder: PlayOrder = .sequential
    @State private var stayDuration: Double = Double(Constants.defaultStayDuration)
    @State private var fullscreenAutoHide: Bool = false

    var body: some View {
        Form {
            // 背记模式
            Section("背记模式") {
                Picker("模式", selection: $reciteMode) {
                    ForEach(ReciteMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: reciteMode) { newValue in
                    AppSettings.shared.reciteMode = newValue
                    AppSettings.shared.postDidChange()
                }
            }

            // 走马灯专属设置
            Section("走马灯设置") {
                HStack {
                    Text("单 Section 循环轮次")
                    Stepper(
                        value: $carouselLoops,
                        in: Constants.minCarouselLoops...Constants.maxCarouselLoops
                    ) {
                        TextField("", value: $carouselLoops, format: .number)
                            .frame(width: 60)
                            .onChange(of: carouselLoops) { _ in saveCarouselLoops() }
                    }
                }
                .disabled(reciteMode != .carousel)

                if reciteMode != .carousel {
                    Text("仅走马灯模式下可编辑")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // 展示顺序
            Section("展示顺序") {
                Picker("顺序", selection: $playOrder) {
                    ForEach(PlayOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: playOrder) { newValue in
                    AppSettings.shared.playOrder = newValue
                    AppSettings.shared.postDidChange()
                }
            }

            // 停留时长
            Section("单单词停留时长") {
                HStack {
                    Slider(value: $stayDuration, in: Double(Constants.minStayDuration)...Double(Constants.maxStayDuration), step: 1)
                        .onChange(of: stayDuration) { newValue in
                            saveStayDuration(Int(newValue))
                        }
                    TextField("", value: $stayDuration, format: .number)
                        .frame(width: 60)
                        .onChange(of: stayDuration) { _ in saveStayDuration(Int(stayDuration)) }
                    Text("秒")
                        .foregroundColor(.secondary)
                }
            }

            // 全屏自动隐藏
            Section("其他") {
                Toggle("全屏应用时自动隐藏悬浮窗", isOn: $fullscreenAutoHide)
                    .onChange(of: fullscreenAutoHide) { newValue in
                        AppSettings.shared.fullscreenAutoHide = newValue
                        AppSettings.shared.postDidChange()
                    }
            }
        }
        .padding()
        .onAppear { loadSettings() }
    }

    private func loadSettings() {
        reciteMode = AppSettings.shared.reciteMode
        carouselLoops = AppSettings.shared.carouselLoopCount
        playOrder = AppSettings.shared.playOrder
        stayDuration = Double(AppSettings.shared.stayDuration)
        fullscreenAutoHide = AppSettings.shared.fullscreenAutoHide
    }

    private func saveCarouselLoops() {
        AppSettings.shared.carouselLoopCount = min(
            Constants.maxCarouselLoops,
            max(Constants.minCarouselLoops, carouselLoops)
        )
        carouselLoops = AppSettings.shared.carouselLoopCount
        AppSettings.shared.postDidChange()
    }

    private func saveStayDuration(_ value: Int) {
        let clamped = min(Constants.maxStayDuration, max(Constants.minStayDuration, value))
        stayDuration = Double(clamped)
        AppSettings.shared.stayDuration = clamped
        AppSettings.shared.postDidChange()
    }
}
