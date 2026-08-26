import XCTest
import CoreData
@testable import HoverWord

/// 悬浮窗动效集成测试
///
/// 覆盖：动效定位 tag 契约、首词直接显示、切词经动效系统后文本归位、
/// 无效动效 ID 回退默认、预览通知演示与恢复、预览暂停回调。
/// 计时型动效（打字机）驱动异步等待，避免依赖窗口环境下的 CA 时序。
final class FloatContentTransitionIntegrationTests: XCTestCase {

    private var containerView: FloatContentView!
    private var savedTransitionId: String!
    private var savedParameters: TransitionParameters!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        savedTransitionId = AppSettings.shared.selectedTransitionId
        savedParameters = AppSettings.shared.transitionParameters
        containerView = FloatContentView()
    }

    override func tearDown() {
        AppSettings.shared.selectedTransitionId = savedTransitionId
        AppSettings.shared.transitionParameters = savedParameters
        containerView = nil
        // 测试构造的词条均为未保存的插入对象，回滚避免泄漏进共享 context 影响其他用例
        DataStack.shared.viewContext.rollback()
        super.tearDown()
    }

    // MARK: - 辅助

    private func makeEntry(_ word: String, phonetic: String? = nil) -> WordEntry {
        let entry = WordEntry(context: DataStack.shared.viewContext)
        entry.wordId = "transition-it-\(word)"
        entry.sourceWord = word
        entry.phonetic = phonetic
        entry.meaning1 = "释义"
        return entry
    }

    private var wordLabel: NSTextField? {
        containerView.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField
    }

    private var phoneticLabel: NSTextField? {
        containerView.viewWithTag(Constants.transitionPhoneticLabelTag) as? NSTextField
    }

    // MARK: - tag 契约

    /// 动效通过 viewWithTag 定位标签，接线缺失时所有动效静默降级，此用例守住该契约
    func testTransitionTagContract() {
        XCTAssertNotNil(wordLabel, "单词标签必须设置动效定位 tag")
        XCTAssertNotNil(phoneticLabel, "音标标签必须设置动效定位 tag")
    }

    // MARK: - 切词

    /// 首个单词无旧内容可过渡，直接显示
    func testFirstWordShowsImmediately() {
        containerView.showWord(word: makeEntry("apple"), mode: .memoryFeedback, isFavorite: false)
        XCTAssertEqual(wordLabel?.stringValue, "apple")
    }

    /// 切词走动效系统，完成后文本归位为新词（动效失败回退也保证此结果）
    func testSwitchWordEndsWithNewWord() {
        containerView.showWord(word: makeEntry("apple"), mode: .memoryFeedback, isFavorite: false)
        AppSettings.shared.selectedTransitionId = "typewriter"

        let exp = expectation(description: "动效完成后文本归位")
        containerView.showWord(word: makeEntry("go"), mode: .memoryFeedback, isFavorite: false)
        // 打字机按字符调度（2 字符 × 默认 60ms），延迟到动画结束后断言
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertEqual(self.wordLabel?.stringValue, "go")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    /// 无效动效 ID 回退默认动效，切换仍正常完成
    func testInvalidEffectIdFallsBackToDefault() {
        containerView.showWord(word: makeEntry("apple"), mode: .memoryFeedback, isFavorite: false)
        AppSettings.shared.selectedTransitionId = "nonexistent-effect"

        let exp = expectation(description: "回退默认动效完成切换")
        containerView.showWord(word: makeEntry("banana"), mode: .memoryFeedback, isFavorite: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            XCTAssertEqual(self.wordLabel?.stringValue, "banana")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - 预览

    /// 预览：暂停背记 → 示例单词演示 → 恢复当前背记单词
    func testPreviewRestoresCurrentWordAndPausesEngine() {
        containerView.showWord(
            word: makeEntry("apple", phonetic: "/ˈæpəl/"),
            mode: .memoryFeedback,
            isFavorite: false
        )
        AppSettings.shared.selectedTransitionId = "typewriter"

        var pauseEvents: [Bool] = []
        containerView.onPreviewStateChanged = { pauseEvents.append($0) }

        NotificationCenter.default.post(
            name: .previewTransitionEffect,
            object: nil,
            userInfo: [
                "effectId": "typewriter",
                "parameters": TransitionParameters()
            ] as [String: Any]
        )

        let exp = expectation(description: "预览完成后恢复当前词")
        // 打字机演示 hello → world（5 字符 × 60ms），完成后同步恢复
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            XCTAssertEqual(self.wordLabel?.stringValue, "apple")
            XCTAssertEqual(self.phoneticLabel?.stringValue, "/ˈæpəl/")
            XCTAssertEqual(pauseEvents, [true, false], "预览应先暂停再恢复背记")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
    }
}
