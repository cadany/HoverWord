import XCTest
@testable import HoverWord

/// 全局设置持久化验证
///
/// 对应任务 2.6：首次启动使用默认设置、设置持久化重启后恢复。
final class AppSettingsTests: XCTestCase {

    /// 测试宿主与真实应用共享同一 UserDefaults 域（com.hoverword.app），
    /// key 须与 AppSettings.storageKey 保持一致
    private let settingsKey = "HoverWordAppSettings"
    private var originalSettingsData: Data?

    override func setUp() {
        super.setUp()
        // 备份用户真实配置，tearDown 原样还原（防止测试值污染真实设置）
        originalSettingsData = UserDefaults.standard.data(forKey: settingsKey)

        // 重置 AppSettings 单例到默认值
        resetAppSettingsToDefaults()
    }

    /// 重置 AppSettings 到默认值
    private func resetAppSettingsToDefaults() {
        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.carouselLoopCount = Constants.defaultCarouselLoops
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.stayDuration = Constants.defaultStayDuration
        AppSettings.shared.sectionSize = Constants.defaultSectionSize
        AppSettings.shared.autoPlaySpeech = true
        AppSettings.shared.voiceNameByLanguage = [:]
        AppSettings.shared.speechRateMultiplier = 1.0
        AppSettings.shared.backgroundOpacity = Double(Constants.defaultBackgroundOpacity)
        AppSettings.shared.fullscreenAutoHide = false
        AppSettings.shared.phoneticFontSize = Double(Constants.phoneticFontSize)
        AppSettings.shared.phoneticVisibility = .always
        AppSettings.shared.meaningVisibility = .always
        AppSettings.shared.save()
    }

    override func tearDown() {
        // 还原用户真实配置：有备份则写回，无备份（用户从未保存过设置）则删除 key
        if let data = originalSettingsData {
            UserDefaults.standard.set(data, forKey: settingsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: settingsKey)
        }
        // 同步内存单例，避免残留测试值影响同进程后续测试
        AppSettings.shared.load()
        originalSettingsData = nil
        super.tearDown()
    }

    // MARK: - 默认值验证

    func testDefaultReciteMode() {
        XCTAssertEqual(AppSettings.shared.reciteMode, .memoryFeedback,
                       "默认背记模式应为记忆反馈模式")
    }

    func testDefaultCarouselLoopCount() {
        XCTAssertEqual(AppSettings.shared.carouselLoopCount, Constants.defaultCarouselLoops,
                       "默认走马灯轮次应为 \(Constants.defaultCarouselLoops)")
    }

    func testDefaultPlayOrder() {
        XCTAssertEqual(AppSettings.shared.playOrder, .sequential,
                       "默认展示顺序应为顺序播放")
    }

    func testDefaultStayDuration() {
        XCTAssertEqual(AppSettings.shared.stayDuration, Constants.defaultStayDuration,
                       "默认停留时长应为 \(Constants.defaultStayDuration) 秒")
    }

    func testDefaultSectionSize() {
        XCTAssertEqual(AppSettings.shared.sectionSize, Constants.defaultSectionSize,
                       "默认 Section 大小应为 \(Constants.defaultSectionSize)")
    }

    func testDefaultAutoPlaySpeech() {
        XCTAssertTrue(AppSettings.shared.autoPlaySpeech,
                      "默认自动播放发音应开启")
    }

    func testDefaultSpeechConfig() {
        // 默认不指定具体语音（自动选择），语速为标准倍速
        XCTAssertTrue(AppSettings.shared.voiceNameByLanguage.isEmpty,
                      "默认语音配置应为空（自动选择）")
        XCTAssertEqual(AppSettings.shared.speechRateMultiplier, 1.0,
                       "默认语速倍率应为 1.0")
    }

    func testDefaultBackgroundOpacity() {
        XCTAssertEqual(AppSettings.shared.backgroundOpacity,
                       Double(Constants.defaultBackgroundOpacity),
                       accuracy: 0.01,
                       "默认背景透明度应为 \(Constants.defaultBackgroundOpacity)")
    }

    func testDefaultContentVisibility() {
        // 默认注音/释义始终显示，注音字号为常量默认值
        XCTAssertEqual(AppSettings.shared.phoneticVisibility, .always,
                       "默认注音显示模式应为 always")
        XCTAssertEqual(AppSettings.shared.meaningVisibility, .always,
                       "默认释义显示模式应为 always")
        XCTAssertEqual(AppSettings.shared.phoneticFontSize,
                       Double(Constants.phoneticFontSize),
                       accuracy: 0.01,
                       "默认注音字号应为 \(Constants.phoneticFontSize)")
    }

    // MARK: - 持久化验证

    func testSettingsSaveAndRestore() {
        // 修改设置
        AppSettings.shared.reciteMode = .carousel
        AppSettings.shared.carouselLoopCount = 5
        AppSettings.shared.playOrder = .shuffled
        AppSettings.shared.stayDuration = 10
        AppSettings.shared.sectionSize = 30
        AppSettings.shared.autoPlaySpeech = false
        AppSettings.shared.voiceNameByLanguage = ["en": "TestVoice"]
        AppSettings.shared.speechRateMultiplier = 1.5
        AppSettings.shared.backgroundOpacity = 0.5
        AppSettings.shared.phoneticFontSize = 12
        AppSettings.shared.phoneticVisibility = .hover
        AppSettings.shared.meaningVisibility = .hidden

        // 保存
        AppSettings.shared.save()

        // 重置内存中的值
        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.carouselLoopCount = 3
        AppSettings.shared.stayDuration = 5
        AppSettings.shared.phoneticVisibility = .always
        AppSettings.shared.meaningVisibility = .always

        // 重新加载
        AppSettings.shared.load()

        // 验证恢复
        XCTAssertEqual(AppSettings.shared.reciteMode, .carousel)
        XCTAssertEqual(AppSettings.shared.carouselLoopCount, 5)
        XCTAssertEqual(AppSettings.shared.playOrder, .shuffled)
        XCTAssertEqual(AppSettings.shared.stayDuration, 10)
        XCTAssertEqual(AppSettings.shared.sectionSize, 30)
        XCTAssertFalse(AppSettings.shared.autoPlaySpeech)
        XCTAssertEqual(AppSettings.shared.voiceNameByLanguage["en"], "TestVoice")
        XCTAssertEqual(AppSettings.shared.speechRateMultiplier, 1.5)
        XCTAssertEqual(AppSettings.shared.backgroundOpacity, 0.5, accuracy: 0.01)
        XCTAssertEqual(AppSettings.shared.phoneticFontSize, 12)
        XCTAssertEqual(AppSettings.shared.phoneticVisibility, .hover)
        XCTAssertEqual(AppSettings.shared.meaningVisibility, .hidden)
    }

    func testPostDidChangeSavesSettings() {
        AppSettings.shared.stayDuration = 15
        AppSettings.shared.postDidChange()

        // 重置后加载
        AppSettings.shared.stayDuration = 5
        AppSettings.shared.load()

        XCTAssertEqual(AppSettings.shared.stayDuration, 15,
                       "postDidChange() 应自动保存设置")
    }
}
