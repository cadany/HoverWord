import AppKit

/// 全局常量定义
///
/// 集中管理 UI spec 中的 px 值、颜色不透明度、动效时长等参数。
/// 所有可配置数值均在此定义，便于全局调整与主题切换。
enum Constants {

    // MARK: - 悬浮窗尺寸

    /// 悬浮窗默认宽度（pt）
    static let floatWindowWidth: CGFloat = 300

    /// 悬浮窗最小宽度（pt）
    static let floatWindowMinWidth: CGFloat = 300

    /// 悬浮窗最大宽度（pt）
    static let floatWindowMaxWidth: CGFloat = 1200

    /// 悬浮窗最小高度（pt）
    static let floatWindowMinHeight: CGFloat = 30

    /// 悬浮窗最大高度（pt）
    static let floatWindowMaxHeight: CGFloat = 800

    /// 悬浮窗水平内边距（pt）
    static let floatWindowPaddingHorizontal: CGFloat = 4

    /// 悬浮窗垂直内边距（pt）
    static let floatWindowPaddingVertical: CGFloat = 2

    /// 悬浮窗圆角半径（pt）
    static let floatWindowCornerRadius: CGFloat = 8

    // MARK: - 设置窗口

    /// 设置窗口默认宽度（pt）
    static let settingsWindowWidth: CGFloat = 720

    /// 设置窗口默认高度（pt）
    static let settingsWindowHeight: CGFloat = 560

    /// 设置窗口最小宽度（pt）
    static let settingsWindowMinWidth: CGFloat = 640

    /// 设置窗口最小高度（pt）
    static let settingsWindowMinHeight: CGFloat = 480

    /// 设置窗口 sidebar 宽度（pt）
    static let settingsSidebarWidth: CGFloat = 200

    /// 设置窗口内容区圆角半径（pt）
    static let settingsCardCornerRadius: CGFloat = 12

    /// 设置窗口卡片分组间距（pt）
    static let settingsCardSpacing: CGFloat = 12

    /// 设置窗口内容区内边距（pt）
    static let settingsContentPadding: CGFloat = 20

    /// Sidebar hover 态 ease-out 时长（秒）
    static let sidebarHoverDuration: TimeInterval = 0.15

    // MARK: - 字体层级（默认值）

    /// 核心单词字号
    static let wordFontSize: CGFloat = 14

    /// 音标字号
    static let phoneticFontSize: CGFloat = 10

    /// 注音字号可配置范围（外观设置滑块）
    static let phoneticFontSizeMin: Double = 8
    static let phoneticFontSizeMax: Double = 14

    /// 次级文字（注音）透明度：保证浅色背景可读性，同时保持与主文字的层级差异
    static let secondaryTextAlpha: CGFloat = 0.85

    /// 词性 + 释义字号
    static let meaningFontSize: CGFloat = 12

    /// 按钮文字字号
    static let buttonFontSize: CGFloat = 13

    // MARK: - 间距

    /// 单词与音标列之间水平间距（pt）
    static let wordToPhoneticSpacing: CGFloat = 8

    /// 音标列与释义列之间水平间距（pt）
    static let phoneticToMeaningSpacing: CGFloat = 16

    /// 释义列与按钮区之间水平间距（pt）
    static let meaningToButtonSpacing: CGFloat = 16

    /// 释义行间距（pt）
    static let meaningLineSpacing: CGFloat = 6

    /// 操作按钮区与内容区底部间距（pt）
    static let buttonAreaTopSpacing: CGFloat = 16

    /// 按钮内部左右内边距（pt）
    static let buttonPaddingHorizontal: CGFloat = 12

    /// 按钮高度（pt）
    static let buttonHeight: CGFloat = 28

    /// 按钮之间间距（pt）
    static let buttonSpacing: CGFloat = 8

    // MARK: - 动效时长

    /// 通用状态切换 ease-out 时长（秒）
    static let transitionDuration: TimeInterval = 0.15

    /// 单词切换动效时长（秒）
    static let wordSwitchDuration: TimeInterval = 0.15

    /// 按钮浮现动效时长（秒）
    static let buttonFadeDuration: TimeInterval = 0.15

    /// 按钮点击态动效时长（秒）
    static let buttonClickDuration: TimeInterval = 0.1

    /// 按钮点击态缩放比例
    static let buttonClickScale: CGFloat = 0.95

    /// 窗口显隐动效时长（秒）
    static let windowFadeDuration: TimeInterval = 0.2

    /// 设置修改视觉过渡时长（秒）
    static let settingsApplyDuration: TimeInterval = 0.2

    // MARK: - 颜色（浅色模式）

    /// 浅色模式主文字不透明度
    static let lightPrimaryTextAlpha: CGFloat = 0.85

    /// 浅色模式辅助文字（音标）不透明度
    static let lightSecondaryTextAlpha: CGFloat = 0.55

    /// 浅色模式按钮默认填充不透明度
    static let lightButtonDefaultAlpha: CGFloat = 0.20

    /// 浅色模式按钮悬停填充不透明度
    static let lightButtonHoverAlpha: CGFloat = 0.40

    /// 浅色模式内描边渐变不透明度（顶部高光 → 底部收暗，模拟环境光自上而下的玻璃边缘反光）
    static let lightInnerStrokeTopAlpha: CGFloat = 0.45
    static let lightInnerStrokeBottomAlpha: CGFloat = 0.20

    // MARK: - 颜色（深色模式）

    /// 深色模式主文字不透明度
    static let darkPrimaryTextAlpha: CGFloat = 0.90

    /// 深色模式辅助文字不透明度
    static let darkSecondaryTextAlpha: CGFloat = 0.60

    /// 深色模式按钮默认填充不透明度
    static let darkButtonDefaultAlpha: CGFloat = 0.15

    /// 深色模式按钮悬停填充不透明度
    static let darkButtonHoverAlpha: CGFloat = 0.30

    /// 深色模式内描边渐变不透明度（顶部高光 → 底部收暗）
    static let darkInnerStrokeTopAlpha: CGFloat = 0.30
    static let darkInnerStrokeBottomAlpha: CGFloat = 0.10

    // MARK: - 玻璃材质

    /// 内描边宽度（pt）
    static let innerStrokeWidth: CGFloat = 1.0

    /// 默认背景透明度
    static let defaultBackgroundOpacity: CGFloat = 0.90

    // MARK: - 默认设置值

    /// 默认单 Section 单词数
    static let defaultSectionSize: Int = 20

    /// 词本语言对默认值（检测低置信度/无结果/新建词本的回退）
    static let defaultSourceLang = "en"
    static let defaultTargetLang = "zh-Hans"

    /// 词本语言编辑下拉的可选语种注册表（BCP-47 代码，显示名走系统 Locale 本地化）。
    /// 仅约束 UI 选项，不约束语言检测结果的存储（语种无关）
    static let supportedWordLanguages: [String] = [
        "en", "fr", "es", "de", "it", "pt", "ru", "ja", "ko", "zh-Hans", "zh-Hant"
    ]

    /// 语言检测样本条数（取词本前 N 条源词/释义拼接送检；单词检测不可靠，需多样本）
    static let languageDetectionSampleCount = 20

    /// 语言检测置信度阈值，低于该值回退默认语言对。
    /// 实测校准（注册表约束后）：噪声误判峰值 0.63（英语基础词→it），
    /// 真实检测 0.88-0.99，取 0.7 分隔
    static let languageDetectionConfidenceThreshold = 0.7

    /// 默认文字颜色（hex）
    static let defaultTextColorHex: String = "#000000"

    /// 默认单单词停留时长（秒）
    static let defaultStayDuration: Int = 5

    /// 默认走马灯循环轮次
    static let defaultCarouselLoops: Int = 3

    /// 单词停留时长最小值（秒）
    static let minStayDuration: Int = 1

    /// 单词停留时长最大值（秒）
    static let maxStayDuration: Int = 60

    /// 走马灯轮次最小值
    static let minCarouselLoops: Int = 1

    /// 走马灯轮次最大值
    static let maxCarouselLoops: Int = 20

    /// Section 单词数最小值
    static let minSectionSize: Int = 1

    /// Section 单词数最大值
    static let maxSectionSize: Int = 500

    // MARK: - 转场动效

    /// 默认转场动效 ID
    static let defaultTransitionId: String = "classic-fade"

    /// BounceIn 动效强度取值范围
    static let bounceInIntensityRange: ClosedRange<Double> = 0.5...2.0

    /// BounceIn 动效默认强度
    static let bounceInDefaultIntensity: Double = 1.0

    /// CardFlip 动效时长取值范围（秒）
    static let cardFlipDurationRange: ClosedRange<Double> = 0.2...0.5

    /// CardFlip 动效默认时长（秒）
    static let cardFlipDefaultDuration: Double = 0.35

    /// Typewriter 动效字符间隔取值范围（秒）
    static let typewriterIntervalRange: ClosedRange<Double> = 0.03...0.1

    /// Typewriter 动效默认字符间隔（秒）
    static let typewriterDefaultInterval: Double = 0.06

    /// LetterMorph 动效字母数量阈值（超过此值回退为淡入）
    static let letterMorphMaxLetterCount: Int = 10

    /// 转场动效定位 tag：单词标签（动效实现通过 viewWithTag 查找，缺一不可）
    static let transitionWordLabelTag: Int = 1001

    /// 转场动效定位 tag：音标标签
    static let transitionPhoneticLabelTag: Int = 1002

    /// 动效预览示例内容（hello → world，演示一次完整过渡）
    static let transitionPreviewOldWord = "hello"
    static let transitionPreviewOldPhonetic = "/həˈloʊ/"
    static let transitionPreviewNewWord = "world"
    static let transitionPreviewNewPhonetic = "/wɜːrld/"

    // MARK: - 性能约束

    /// 后台常驻内存上限（MB）
    static let maxMemoryMB: Int = 100

    /// 单词切换延迟上限（ms）
    static let maxSwitchDelayMS: Int = 100

    /// 10000 条单词导入耗时上限（秒）
    static let maxImportDurationSec: Int = 3

    /// 导入性能测试样本量
    static let importBenchmarkCount: Int = 10000

    // MARK: - 发音服务

    /// 语音列表刷新节流间隔（秒）
    ///
    /// speak 前距上次枚举超过该时长才重新枚举系统语音，
    /// 避免高频切词路径上 speechVoices() 的磁盘/服务开销。
    static let voiceListRefreshInterval: TimeInterval = 60

    // MARK: - 发音设置

    /// 语速倍率最小值（0.5x = 半速慢放）
    static let speechRateMin: Double = 0.5

    /// 语速倍率最大值（1.5x）
    static let speechRateMax: Double = 1.5

    /// 语速滑块步进
    static let speechRateStep: Double = 0.1

    /// 语速默认倍率（1.0x = 系统默认语速）
    static let speechRateDefault: Double = 1.0

    /// 试听示例句（足够长以体现语音的节奏与连读特征）
    static let speechPreviewSentence = "Hello, this is a preview."

    // MARK: - 单词本预览

    /// 预览行号列宽度（pt）
    static let previewLineNumberColumnWidth: CGFloat = 50

    // MARK: - 单词本列表行内操作

    /// 行内操作图标字号（pt）
    static let rowActionIconSize: CGFloat = 12

    /// 行内操作点击热区边长（pt）
    static let rowActionHitSize: CGFloat = 22

    /// 行内操作按钮间距（pt）
    static let rowActionSpacing: CGFloat = 2

    /// 行内操作图标统一前景色不透明度（预览符号与竖三点共用，
    /// 显式 primary+opacity 避免语义色 .secondary 在符号与形状上解析不一致）
    static let rowActionIconAlpha: Double = 0.55

    // MARK: - 系统收藏夹

    /// 系统收藏夹单词本名称
    static let favoritesWordbookName = "我的收藏"

    // MARK: - 悬浮窗右键菜单 tag

    /// 悬浮窗右键菜单项 tag
    enum FloatMenuTag {
        static let restart = 100
        static let openSettings = 101
        static let quit = 102
    }
}

// MARK: - NSColor Hex 扩展

extension NSColor {
    /// 从 hex 字符串初始化颜色（如 "#FF0000"）
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
