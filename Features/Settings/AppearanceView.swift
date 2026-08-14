import SwiftUI

/// 外观设置 Tab 视图
///
/// 配置项：预设主题、背景色、透明度、单词/释义字体字号。
/// 含悬浮窗实时预览区域。
struct AppearanceView: View {
    @State private var selectedTheme: ThemeOption = .light
    @State private var customColor: Color = .white
    @State private var textColor: Color = .black
    @State private var backgroundOpacity: Double = Double(Constants.defaultBackgroundOpacity)
    @State private var wordFontName: String = "System Default"
    @State private var wordFontSize: Double = Double(Constants.wordFontSize)
    @State private var meaningFontName: String = "System Default"
    @State private var meaningFontSize: Double = Double(Constants.meaningFontSize)

    /// 可选字体列表
    private let availableFonts: [String] = {
        let defaults = ["System Default"]
        let extras = NSFontManager.shared.availableFontFamilies.filter { family in
            // 过滤掉过于花哨的字体，保留常见中英文字体
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

    enum ThemeOption: String, CaseIterable {
        case light = "浅色"
        case dark = "深色"
        case green = "护眼绿"

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
        HStack(spacing: 16) {
            // 左侧：设置项
            Form {
                // 预设主题
                Section("预设主题") {
                    Picker("主题", selection: $selectedTheme) {
                        ForEach(ThemeOption.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTheme) { newValue in
                        applyTheme(newValue)
                    }
                }

                // 背景设置
                Section("背景设置") {
                    ColorPicker("背景色", selection: $customColor, supportsOpacity: false)
                        .onChange(of: customColor) { _ in saveAppearance() }

                    ColorPicker("文字颜色", selection: $textColor, supportsOpacity: false)
                        .onChange(of: textColor) { _ in saveAppearance() }

                    HStack {
                        Text("透明度")
                        Slider(value: $backgroundOpacity, in: 0...1)
                            .onChange(of: backgroundOpacity) { _ in saveAppearance() }
                        Text("\(Int(backgroundOpacity * 100))%")
                            .frame(width: 40)
                    }
                }

                // 文字样式
                Section("单词样式") {
                    Picker("字体", selection: $wordFontName) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font).font(.custom(font, size: 13))
                        }
                    }
                    .onChange(of: wordFontName) { _ in saveAppearance() }

                    HStack {
                        Text("字号")
                        Slider(value: $wordFontSize, in: 16...48, step: 1)
                            .onChange(of: wordFontSize) { _ in saveAppearance() }
                        Text("\(Int(wordFontSize))px")
                            .frame(width: 45)
                    }
                }

                Section("释义样式") {
                    Picker("字体", selection: $meaningFontName) {
                        ForEach(availableFonts, id: \.self) { font in
                            Text(font).font(.custom(font, size: 13))
                        }
                    }
                    .onChange(of: meaningFontName) { _ in saveAppearance() }

                    HStack {
                        Text("字号")
                        Slider(value: $meaningFontSize, in: 10...24, step: 1)
                            .onChange(of: meaningFontSize) { _ in saveAppearance() }
                        Text("\(Int(meaningFontSize))px")
                            .frame(width: 45)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)

            // 右侧：实时预览
            FloatPreviewView(
                backgroundColor: customColor,
                textColor: textColor,
                opacity: backgroundOpacity,
                wordFontSize: wordFontSize,
                meaningFontSize: meaningFontSize
            )
            .frame(width: 240, height: 300)
        }
        .padding()
        .onAppear { loadAppearance() }
    }

    private func loadAppearance() {
        backgroundOpacity = AppSettings.shared.backgroundOpacity
        wordFontName = AppSettings.shared.wordFontName.isEmpty ? "System Default" : AppSettings.shared.wordFontName
        wordFontSize = AppSettings.shared.wordFontSize
        meaningFontName = AppSettings.shared.meaningFontName.isEmpty ? "System Default" : AppSettings.shared.meaningFontName
        meaningFontSize = AppSettings.shared.meaningFontSize
        // 加载文字颜色
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

    private func saveAppearance() {
        AppSettings.shared.backgroundOpacity = backgroundOpacity
        AppSettings.shared.wordFontName = wordFontName == "System Default" ? "" : wordFontName
        AppSettings.shared.wordFontSize = wordFontSize
        AppSettings.shared.meaningFontName = meaningFontName == "System Default" ? "" : meaningFontName
        AppSettings.shared.meaningFontSize = meaningFontSize
        // 保存背景色
        let nsColor = NSColor(customColor)
        let rgba = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        AppSettings.shared.backgroundColorHex = String(
            format: "#%02X%02X%02X",
            Int(rgba.redComponent * 255),
            Int(rgba.greenComponent * 255),
            Int(rgba.blueComponent * 255)
        )
        // 保存文字颜色
        let nsTextColor = NSColor(textColor)
        let textRGBA = nsTextColor.usingColorSpace(.deviceRGB) ?? nsTextColor
        AppSettings.shared.textColorHex = String(
            format: "#%02X%02X%02X",
            Int(textRGBA.redComponent * 255),
            Int(textRGBA.greenComponent * 255),
            Int(textRGBA.blueComponent * 255)
        )
        AppSettings.shared.postDidChange()
    }
}

/// 悬浮窗实时预览视图
///
/// 迷你版悬浮窗外观，横向四列布局（单词 | 音标 | 释义 | 按钮横排），实时反映外观设置变化。
struct FloatPreviewView: View {
    let backgroundColor: Color
    let textColor: Color
    let opacity: Double
    let wordFontSize: Double
    let meaningFontSize: Double

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // 第 1 列：单词
            Text("apple")
                .font(.system(size: wordFontSize, weight: .semibold))
                .foregroundColor(textColor)

            // 第 2 列：音标
            Text("/ˈæpl/")
                .font(.system(size: 10))
                .foregroundColor(textColor.opacity(0.65))

            // 第 3 列：释义
            VStack(alignment: .leading, spacing: 2) {
                Text("n. 苹果")
                    .font(.system(size: meaningFontSize))
                    .foregroundColor(textColor)
                Text("adj. 苹果的")
                    .font(.system(size: meaningFontSize))
                    .foregroundColor(textColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 第 4 列：按钮横排
            HStack(spacing: 4) {
                Button("♡") {}
                    .buttonStyle(.plain)
                Button("认识") {}
                    .buttonStyle(.plain)
                Button("不认识") {}
                    .buttonStyle(.plain)
            }
            .font(.system(size: 9))
            .foregroundColor(textColor)
            .opacity(0.6)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor.opacity(opacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.2), value: backgroundColor)
        .animation(.easeOut(duration: 0.2), value: textColor)
        .animation(.easeOut(duration: 0.2), value: opacity)
        .animation(.easeOut(duration: 0.2), value: wordFontSize)
        .animation(.easeOut(duration: 0.2), value: meaningFontSize)
    }
}
