import SwiftUI

// MARK: - 设计原则
//
// 1. 不支持 Liquid Glass 的 macOS 版本 → 使用系统默认控件（不添加任何额外背景/样式）
// 2. 支持 Liquid Glass 的 macOS 版本（26+）→ 全系交互控件使用原生 Liquid Glass
// 3. 所有版本都不人工手搓 Liquid Glass 风格；控件不支持则使用默认
//
// 因此本文件只提供版本感知的 extension，让调用方写一次代码自动适配。
// macOS 14-25 上所有修饰器均为 no-op，完全交给系统默认渲染。

// MARK: - Version-Aware Button Styles

extension View {

    /// 玻璃按钮样式：macOS 26+ 使用系统 `.glass`，低版本使用系统默认按钮
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glass)
        } else {
            self
        }
    }

    /// 突出的玻璃按钮：macOS 26+ 使用系统 `.glassProminent`
    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self
        }
    }
}

// MARK: - Liquid Glass Background（仅 macOS 26+）

/// 可选的液态玻璃背景：macOS 26+ 添加系统材质，低版本无任何操作（系统默认）
/// macOS 26+ 按 role 区分材质：sidebar 用 .thinMaterial，content/window 用 .regularMaterial
struct OptionalLiquidGlassBackground: ViewModifier {
    enum Role {
        case sidebar
        case content
        case window
    }
    let role: Role

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            switch role {
            case .sidebar:
                content.background(.thinMaterial)
            case .content, .window:
                content.background(.regularMaterial)
            }
        } else {
            content
        }
    }
}

extension View {
    func optionalLiquidGlassBackground(_ role: OptionalLiquidGlassBackground.Role) -> some View {
        modifier(OptionalLiquidGlassBackground(role: role))
    }
}

// MARK: - Liquid Glass Card（仅 macOS 26+）

/// 卡片分组样式
/// - macOS 26+：使用系统 `.glassEffect()` 渲染液态玻璃卡片
/// - macOS 14-25：无额外样式，仅 padding + frame（遵循原则 1：系统默认）
struct LiquidGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        // padding + frame 两个版本都需要，提到分支外避免重复
        let styled = content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        if #available(macOS 26, *) {
            styled.glassEffect(.regular, in: .rect(cornerRadius: Constants.settingsCardCornerRadius))
        } else {
            styled
        }
    }
}

extension View {
    func glassCard() -> some View {
        modifier(LiquidGlassCardModifier())
    }
}
