import Foundation

/// 界面文案本地化解析层
///
/// 所有界面文案通过 `t(_:)` 按 key 查词，语言由 `AppSettings.uiLanguage` 决定：
/// - 锁定语言（"zh-Hans" / "en"）→ 直接使用对应语言
/// - "system"（默认）→ 跟随 macOS 系统语言，中文系语言映射 zh-Hans，其余回退 en
///
/// 回退链：目标语言词条 → en 词条 → key 本身（开发期暴露缺词问题）。
/// 不使用 SwiftUI `Text(LocalizedStringKey)` 自动解析：它绑定进程启动语言，
/// 无法响应应用内即时切换；统一显式查词保证 SwiftUI 与 AppKit 行为一致。
///
/// 新增语种：补充 xcstrings 词条 + 在 `SupportedLanguage` 登记表加一行即可，
/// 解析层与设置页无需改动。
enum L10n {

    /// 界面语言取值：跟随系统（默认）
    static let systemLanguage = "system"

    /// 英语语言代码（词条缺失时的回退语言）
    static let englishLanguage = "en"

    // MARK: - 已支持语言登记表
    // 新增语种在此登记：代码（须与 xcstrings 词条语言一致）+ 显示名 key
    // 显示名词条以各自语言原文提供（语言名通常不翻译），en 侧同文兜底

    /// 语言登记项
    struct SupportedLanguage {
        let code: String
        let nameKey: String
    }

    /// 已支持语言列表（设置页选项数据源）
    static let supportedLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "zh-Hans", nameKey: "general.language.zh"),
        SupportedLanguage(code: "en", nameKey: "general.language.en"),
    ]

    // MARK: - 查词接口

    /// 查询当前语言文案
    ///
    /// - Parameter key: 词条 key（命名约定 `{模块}.{元素}.{用途}`）
    /// - Returns: 当前语言文案；缺失时回退英文词条，再缺失返回 key 本身
    static func t(_ key: String) -> String {
        let language = effectiveLanguage
        if let value = lookup(key, in: language), value != key {
            return value
        }
        if language != englishLanguage, let fallback = lookup(key, in: englishLanguage), fallback != key {
            return fallback
        }
        return key
    }

    /// 查询当前语言文案并格式化插值
    ///
    /// 词条值使用 printf 风格占位符（如 `%d`、`%@`）。
    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    /// 解析生效语言：锁定语言优先，"system" 时按系统语言映射
    static var effectiveLanguage: String {
        let preferred = AppSettings.shared.uiLanguage
        if preferred != systemLanguage {
            return preferred
        }
        guard let system = Locale.preferredLanguages.first else {
            return englishLanguage
        }
        return system.hasPrefix("zh") ? "zh-Hans" : englishLanguage
    }

    // MARK: - 私有：Bundle 解析

    private static var bundleCache: [String: Bundle] = [:]

    private static func lookup(_ key: String, in language: String) -> String? {
        guard let bundle = bundle(for: language) else { return nil }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static func bundle(for language: String) -> Bundle? {
        if let cached = bundleCache[language] {
            return cached
        }
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        bundleCache[language] = bundle
        return bundle
    }
}
