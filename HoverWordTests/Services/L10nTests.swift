import XCTest
@testable import HoverWord

/// L10n 本地化解析验证
///
/// 验证锁定语言解析、系统语言映射边界、词条缺失回退、插值格式化，
/// 以及语言切换通知发出后查词结果即时变化（即时刷新链路的基础）。
final class L10nTests: XCTestCase {

    /// 测试宿主与真实应用共享同一 UserDefaults 域（com.hoverword.app），
    /// postLanguageChange() 会触发 save() 落盘，须备份还原防止污染真实设置；
    /// key 须与 AppSettings.storageKey 保持一致
    private let settingsKey = "HoverWordAppSettings"
    private var originalSettingsData: Data?

    override func setUp() {
        super.setUp()
        // 备份用户真实配置，tearDown 原样还原
        originalSettingsData = UserDefaults.standard.data(forKey: settingsKey)
    }

    override func tearDown() {
        // 还原用户真实配置：有备份则写回，无备份（用户从未保存过设置）则删除 key
        if let data = originalSettingsData {
            UserDefaults.standard.set(data, forKey: settingsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: settingsKey)
        }
        // 同步内存单例，避免残留测试语言影响同进程后续测试
        AppSettings.shared.load()
        originalSettingsData = nil
        super.tearDown()
    }

    // MARK: - 锁定语言解析

    func testLockedEnglishLookup() {
        AppSettings.shared.uiLanguage = "en"
        XCTAssertEqual(L10n.t("sidebar.wordbook"), "Wordbook")
        XCTAssertEqual(L10n.effectiveLanguage, "en")
    }

    func testLockedChineseLookup() {
        AppSettings.shared.uiLanguage = "zh-Hans"
        XCTAssertEqual(L10n.t("sidebar.wordbook"), "单词本")
        XCTAssertEqual(L10n.effectiveLanguage, "zh-Hans")
    }

    /// 锁定语言优先于系统语言
    func testLockedLanguageOverridesSystem() {
        AppSettings.shared.uiLanguage = "en"
        XCTAssertEqual(L10n.effectiveLanguage, "en",
                       "锁定英文时无论系统语言如何都应解析为 en")
    }

    // MARK: - 跟随系统

    func testSystemLanguageMapsToSupported() {
        AppSettings.shared.uiLanguage = L10n.systemLanguage
        XCTAssertTrue(
            ["zh-Hans", "en"].contains(L10n.effectiveLanguage),
            "跟随系统时生效语言必须是已提供词条的语言之一"
        )
    }

    // MARK: - 回退

    func testMissingKeyFallsBackToKeyItself() {
        AppSettings.shared.uiLanguage = "zh-Hans"
        XCTAssertEqual(L10n.t("no.such.key.exists"), "no.such.key.exists",
                       "词条缺失时应显示 key 本身（开发期暴露缺词）")
    }

    // MARK: - 插值

    func testFormatInterpolationEnglish() {
        AppSettings.shared.uiLanguage = "en"
        XCTAssertEqual(L10n.t("preview.page.format", 2, 5), "Page 2 of 5")
    }

    func testFormatInterpolationChinese() {
        AppSettings.shared.uiLanguage = "zh-Hans"
        XCTAssertEqual(L10n.t("preview.page.format", 2, 5), "第 2 / 5 页")
    }

    // MARK: - 语言切换即时生效

    func testLookupChangesImmediatelyAfterNotification() {
        AppSettings.shared.uiLanguage = "en"
        AppSettings.shared.postLanguageChange()
        XCTAssertEqual(L10n.t("float.completed"), "All Done")

        AppSettings.shared.uiLanguage = "zh-Hans"
        AppSettings.shared.postLanguageChange()
        XCTAssertEqual(L10n.t("float.completed"), "已学完")
    }

    // MARK: - 登记表

    func testSupportedLanguagesRegistry() {
        XCTAssertEqual(L10n.supportedLanguages.map { $0.code }, ["zh-Hans", "en"],
                       "v0.1.1 登记表应包含简体中文与英文")
        // 每个登记项的显示名词条必须存在（查词结果不等于 key 本身）
        for language in L10n.supportedLanguages {
            XCTAssertNotEqual(L10n.t(language.nameKey), language.nameKey,
                              "语言 \(language.code) 的显示名词条缺失")
        }
    }
}
