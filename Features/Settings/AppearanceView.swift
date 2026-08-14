import SwiftUI

/// 外观设置 Tab 视图
///
/// 配置项：预设主题、背景色、文字颜色、透明度、单词/释义字体字号。
/// 遵循设计原则：macOS 26+ 使用原生 Liquid Glass，低版本使用系统默认控件。
struct AppearanceView: View {
    @State private var selectedTheme: ThemeOption = .light
    @State private var customColor: Color = .white
    @State private var textColor: Color = .black
    @State private var backgroundOpacity: Double = Double(Constants.defaultBackgroundOpacity)
    @State private var wordFontName: String = "System Default"
    @State private var wordFontSize: Double = Double(Constants.wordFontSize)
    @State private var meaningFontName: String = "System Default"
    @State private var meaningFontSize: Double = Double(Constants.meaningFontSize)

    private let availableFonts: [String] = {
        let defaults = ["System Default"]
        let extras = NSFontManager.shared.availableFontFamilies.filter { family in
            let lowercased = family.lowercased()
            return lowercased.contains("hei") || lowercased.contains("song")
                || lowercased.contains("kai") || lowercased.contains("yuan")
                || lowercased.contains("sans") || lowercased.contains("serif")
                || lowercased.contains("mono") || lowercased.contains("arial")
                || lowercased.contains("times") || lowercased.contains("helvetica")
                || lowercased.contains("pingfang") || lowercased.contains("stkaiti")
                || lowercased.contains("stheiti") || lowercased.contains("noto")
                || lowercased.contains("source")
        }
        return defaults + extras.sorted()
    }()

    enum ThemeOption: String, CaseIterable, Identifiable {
        case light = "浅色"
        case dark = "深色"
        case green = "护眼绿"

        var id: String { rawValue }

        var backgroundColor: Color {
            switch self {
            case .light: return .white
            case .dark: return Color(white: 0.15)
            case .green: return Color(red: 0.85, green: 0.95, blue: 0.85)
            }
        }

        var textColor: Color {
            switch self {
            case .light: return .black
            case .dark: return .white
            case .green: return Color(red: 0.18, green: 0.35, blue: 0.18)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                // 预设主题卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text("预设主题")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack {
                        Text("主题")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $selectedTheme) {
                            ForEach(ThemeOption.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedTheme) { newTheme in
                            applyTheme(newTheme)
                        }
                    }
                }
                .glassCard()

                // 背景与文字卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("背景与文字")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("背景色")
                            .font(.system(size: 13))
                        Spacer()
                        ColorPicker("", selection: $customColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: customColor) { _ in saveAppearance() }
                    }

                    Divider()

                    HStack {
                        Text("文字颜色")
                            .font(.system(size: 13))
                        Spacer()
                        ColorPicker("", selection: $textColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: textColor) { _ in saveAppearance() }
                    }

                    Divider()

                    HStack {
                        Text("透明度")
                            .font(.system(size: 13))
                        Slider(value: $backgroundOpacity, in: 0...1)
                            .onChange(of: backgroundOpacity) { _ in saveAppearance() }
                        Text("\(Int(backgroundOpacity * 100))%")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .glassCard()

                // 单词样式卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("单词样式")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("字体")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $wordFontName) {
                            ForEach(availableFonts, id: \.self) { font in
                                Text(font).font(.custom(font, size: 12)).tag(font)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: wordFontName) { _ in saveAppearance() }
                    }

                    Divider()

                    HStack {
                        Text("字号")
                            .font(.system(size: 13))
                        Slider(value: $wordFontSize, in: 16...48, step: 1)
                            .onChange(of: wordFontSize) { _ in saveAppearance() }
                        Text("\(Int(wordFontSize))pt")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .glassCard()

                // 释义样式卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text("释义样式")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text("字体")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $meaningFontName) {
                            ForEach(availableFonts, id: \.self) { font in
                                Text(font).font(.custom(font, size: 12)).tag(font)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: meaningFontName) { _ in saveAppearance() }
                    }

                    Divider()

                    HStack {
                        Text("字号")
                            .font(.system(size: 13))
                        Slider(value: $meaningFontSize, in: 10...24, step: 1)
                            .onChange(of: meaningFontSize) { _ in saveAppearance() }
                        Text("\(Int(meaningFontSize))pt")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .glassCard()

                Spacer()
            }
            .padding(Constants.settingsContentPadding)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadAppearance() }
    }

    // MARK: - Data

    private func loadAppearance() {
        backgroundOpacity = AppSettings.shared.backgroundOpacity
        // 向后兼容：旧版默认 "San Francisco" 等价于 "System Default"
        let storedWordFont = AppSettings.shared.wordFontName
        wordFontName = (storedWordFont.isEmpty || storedWordFont == "San Francisco") ? "System Default" : storedWordFont
        wordFontSize = AppSettings.shared.wordFontSize
        let storedMeaningFont = AppSettings.shared.meaningFontName
        meaningFontName = (storedMeaningFont.isEmpty || storedMeaningFont == "San Francisco") ? "System Default" : storedMeaningFont
        meaningFontSize = AppSettings.shared.meaningFontSize
        if let color = NSColor(hex: AppSettings.shared.textColorHex) {
            textColor = Color(color)
        } else {
            textColor = .black
        }
    }

    private func applyTheme(_ theme: ThemeOption) {
        customColor = theme.backgroundColor
        textColor = theme.textColor
        saveAppearance()
    }

    /// Color → NSColor → deviceRGB hex 字符串转换
    private func hexString(from color: Color) -> String {
        let ns = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        return String(
            format: "#%02X%02X%02X",
            Int(ns.redComponent * 255),
            Int(ns.greenComponent * 255),
            Int(ns.blueComponent * 255)
        )
    }

    private func saveAppearance() {
        AppSettings.shared.backgroundOpacity = backgroundOpacity
        // "System Default" 与空字符串都存储为空字符串，渲染层自行映射
        AppSettings.shared.wordFontName = (wordFontName == "System Default") ? "" : wordFontName
        AppSettings.shared.wordFontSize = wordFontSize
        AppSettings.shared.meaningFontName = (meaningFontName == "System Default") ? "" : meaningFontName
        AppSettings.shared.meaningFontSize = meaningFontSize
        AppSettings.shared.backgroundColorHex = hexString(from: customColor)
        AppSettings.shared.textColorHex = hexString(from: textColor)
        AppSettings.shared.postDidChange()
    }
}
