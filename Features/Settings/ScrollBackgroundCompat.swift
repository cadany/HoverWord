import SwiftUI

/// 隐藏 ScrollView 背景的修饰器（兼容 macOS 12+）
///
/// macOS 13+ 使用 `.scrollContentBackground(.hidden)`，
/// macOS 12 不支持该 API，直接返回原内容。
struct HiddenScrollBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 13.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

extension View {
    /// 隐藏 ScrollView 背景（兼容 macOS 12+）
    func hiddenScrollBackground() -> some View {
        modifier(HiddenScrollBackgroundModifier())
    }
}
