import XCTest
@testable import HoverWord

/// 全局设置持久化验证
///
/// 对应任务 2.6：首次启动使用默认设置、设置持久化重启后恢复。
final class AppSettingsTests: XCTestCase {

    private let testSuiteName = "HoverWordTestSettings"

    override func setUp() {
        super.setUp()
        // 清除测试用的 UserDefaults
        UserDefaults.standard.removePersistentDomain(forName: testSuiteName)
        UserDefaults.standard.synchronize()

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
        AppSettings.shared.useAmericanAccent = true
        AppSettings.shared.backgroundOpacity = Double(Constants.defaultBackgroundOpacity)
        AppSettings.shared.fullscreenAutoHide = false
        AppSettings.shared.save()
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: testSuiteName)
        UserDefaults.standard.synchronize()
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

    func testDefaultAccent() {
        XCTAssertTrue(AppSettings.shared.useAmericanAccent,
                      "默认发音应为美式")
    }

    func testDefaultBackgroundOpacity() {
        XCTAssertEqual(AppSettings.shared.backgroundOpacity,
                       Double(Constants.defaultBackgroundOpacity),
                       accuracy: 0.01,
                       "默认背景透明度应为 \(Constants.defaultBackgroundOpacity)")
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
        AppSettings.shared.useAmericanAccent = false
        AppSettings.shared.backgroundOpacity = 0.5

        // 保存
        AppSettings.shared.save()

        // 重置内存中的值
        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.carouselLoopCount = 3
        AppSettings.shared.stayDuration = 5

        // 重新加载
        AppSettings.shared.load()

        // 验证恢复
        XCTAssertEqual(AppSettings.shared.reciteMode, .carousel)
        XCTAssertEqual(AppSettings.shared.carouselLoopCount, 5)
        XCTAssertEqual(AppSettings.shared.playOrder, .shuffled)
        XCTAssertEqual(AppSettings.shared.stayDuration, 10)
        XCTAssertEqual(AppSettings.shared.sectionSize, 30)
        XCTAssertFalse(AppSettings.shared.autoPlaySpeech)
        XCTAssertFalse(AppSettings.shared.useAmericanAccent)
        XCTAssertEqual(AppSettings.shared.backgroundOpacity, 0.5, accuracy: 0.01)
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
