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
    @State private var phoneticFontSize: Double = Double(Constants.phoneticFontSize)
    @State private var phoneticVisibility: ContentVisibility = .always
    @State private var meaningVisibility: ContentVisibility = .always

    /// 可选字体族列表：static 只枚举一次。
    /// NSFontManager.availableFontFamilies 每次调用都查询字体服务，
    /// 实例 let 会在每次构造本视图（每次切换到外观页）时重复执行，造成主线程卡顿。
    private static let availableFonts: [String] = {
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
        case light
        case dark
        case green

        var id: String { rawValue }

        /// 本地化显示名
        var displayName: String {
            switch self {
            case .light: return L10n.t("appearance.theme.light")
            case .dark: return L10n.t("appearance.theme.dark")
            case .green: return L10n.t("appearance.theme.green")
            }
        }

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
                    Text(L10n.t("appearance.preset"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    HStack {
                        Text(L10n.t("appearance.theme"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $selectedTheme) {
                            ForEach(ThemeOption.allCases) { theme in
                                Text(theme.displayName).tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedTheme) { newTheme in applyTheme(newTheme) }
                    }
                }
                .glassCard()

                // 背景与文字卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("appearance.bgText"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(L10n.t("appearance.bgColor"))
                            .font(.system(size: 13))
                        Spacer()
                        ColorPicker("", selection: $customColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: customColor) { _ in saveAppearance() }
                    }

                    Divider()

                    HStack {
                        Text(L10n.t("appearance.textColor"))
                            .font(.system(size: 13))
                        Spacer()
                        ColorPicker("", selection: $textColor, supportsOpacity: false)
                            .labelsHidden()
                            .onChange(of: textColor) { _ in saveAppearance() }
                    }

                    Divider()

                    HStack {
                        Text(L10n.t("appearance.opacity"))
                            .font(.system(size: 13))
                        Slider(value: $backgroundOpacity, in: 0...1, step: 0.05)
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
                    Text(L10n.t("appearance.wordStyle"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(L10n.t("appearance.font"))
                            .font(.system(size: 13))
                        Spacer()
                        FontPickerField(selection: $wordFontName, fonts: Self.availableFonts)
                            .onChange(of: wordFontName) { _ in saveAppearance() }
                    }

                    Divider()

                    HStack {
                        Text(L10n.t("appearance.fontSize"))
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

                // 注音样式卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("appearance.phoneticStyle"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(L10n.t("appearance.fontSize"))
                            .font(.system(size: 13))
                        Slider(
                            value: $phoneticFontSize,
                            in: Constants.phoneticFontSizeMin...Constants.phoneticFontSizeMax,
                            step: 1
                        )
                        .onChange(of: phoneticFontSize) { _ in saveAppearance() }
                        Text("\(Int(phoneticFontSize))pt")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }

                    Divider()

                    HStack {
                        Text(L10n.t("appearance.displayMode"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $phoneticVisibility) {
                            ForEach(ContentVisibility.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                        .onChange(of: phoneticVisibility) { _ in saveAppearance() }
                    }
                }
                .glassCard()

                // 释义样式卡片
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("appearance.meaningStyle"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack {
                        Text(L10n.t("appearance.font"))
                            .font(.system(size: 13))
                        Spacer()
                        FontPickerField(selection: $meaningFontName, fonts: Self.availableFonts)
                            .onChange(of: meaningFontName) { _ in saveAppearance() }
                    }

                    Divider()

                    HStack {
                        Text(L10n.t("appearance.fontSize"))
                            .font(.system(size: 13))
                        Slider(value: $meaningFontSize, in: 10...24, step: 1)
                            .onChange(of: meaningFontSize) { _ in saveAppearance()}
                        Text("\(Int(meaningFontSize))pt")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }

                    Divider()

                    HStack {
                        Text(L10n.t("appearance.displayMode"))
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $meaningVisibility) {
                            ForEach(ContentVisibility.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)
                        .onChange(of: meaningVisibility) { _ in saveAppearance() }
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
        phoneticFontSize = AppSettings.shared.phoneticFontSize
        phoneticVisibility = AppSettings.shared.phoneticVisibility
        meaningVisibility = AppSettings.shared.meaningVisibility
        if let color = NSColor(hex: AppSettings.shared.textColorHex) {
            textColor = Color(color)
        } else {
            textColor = .black
        }
    }

    private func applyTheme(_ theme: ThemeOption) {
        // 主题未变化时跳过，避免 onAppear 加载触发冗余保存
        let newBg = theme.backgroundColor
        let newFg = theme.textColor
        guard customColor != newBg || textColor != newFg else { return }
        customColor = newBg
        textColor = newFg
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
        // 计算新值
        let newOpacity = backgroundOpacity
        let newWordFont = (wordFontName == "System Default") ? "" : wordFontName
        let newWordSize = wordFontSize
        let newMeaningFont = (meaningFontName == "System Default") ? "" : meaningFontName
        let newMeaningSize = meaningFontSize
        let newPhoneticSize = phoneticFontSize
        let newPhoneticVisibility = phoneticVisibility
        let newMeaningVisibility = meaningVisibility
        let newBgHex = hexString(from: customColor)
        let newFgHex = hexString(from: textColor)

        // 所有值均未变化时跳过保存与通知（防止 sidebar 切换触发 onChange）
        let s = AppSettings.shared
        guard s.backgroundOpacity != newOpacity
            || s.wordFontName != newWordFont
            || s.wordFontSize != newWordSize
            || s.meaningFontName != newMeaningFont
            || s.meaningFontSize != newMeaningSize
            || s.phoneticFontSize != newPhoneticSize
            || s.phoneticVisibility != newPhoneticVisibility
            || s.meaningVisibility != newMeaningVisibility
            || s.backgroundColorHex != newBgHex
            || s.textColorHex != newFgHex
        else { return }

        s.backgroundOpacity = newOpacity
        // "System Default" 与空字符串都存储为空字符串，渲染层自行映射
        s.wordFontName = newWordFont
        s.wordFontSize = newWordSize
        s.meaningFontName = newMeaningFont
        s.meaningFontSize = newMeaningSize
        s.phoneticFontSize = newPhoneticSize
        s.phoneticVisibility = newPhoneticVisibility
        s.meaningVisibility = newMeaningVisibility
        s.backgroundColorHex = newBgHex
        s.textColorHex = newFgHex
        s.postAppearanceChange()
    }
}

// MARK: - 字体选择器

/// 字体选择器：按钮 + popover 懒加载列表
///
/// 每行以对应字体渲染文字作为预览。列表用 LazyVStack，
/// 行仅在 popover 打开后按可视区域增量构建，
/// 避免菜单式 Picker 在建页时一次性实例化全部字体导致的卡顿。
private struct FontPickerField: View {
    @Binding var selection: String
    let fonts: [String]

    @State private var isPresented = false

    /// "System Default" 行使用系统字体，其余用字体本身渲染
    private func rowFont(_ font: String) -> Font? {
        font == "System Default" ? nil : .custom(font, size: 13)
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Text(selection)
                    .font(rowFont(selection))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 170, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(fonts, id: \.self) { font in
                        Button {
                            selection = font
                            isPresented = false
                        } label: {
                            HStack {
                                Text(font)
                                    .font(rowFont(font))
                                    .lineLimit(1)
                                Spacer()
                                if font == selection {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .medium))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: 280, height: 300)
        }
    }
}
