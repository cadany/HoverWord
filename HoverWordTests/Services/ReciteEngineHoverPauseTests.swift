import XCTest
import CoreData
@testable import HoverWord

/// 悬停暂停计時验证
///
/// 覆盖：暂停冻结切词、恢复按剩余时长继续、暂停中手动切词保持暂停、
/// 暂停中计时参数热更新不启动计时、引擎启动前记录暂停标志的场景。
final class ReciteEngineHoverPauseTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockHoverDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        setupTestData()

        engine = ReciteEngine()
        delegate = MockHoverDelegate()
        engine.delegate = delegate
        engine.clearProgress()

        AppSettings.shared.reciteMode = .memoryFeedback
        AppSettings.shared.playOrder = .sequential
        AppSettings.shared.stayDuration = 1
        AppSettings.shared.sectionSize = 10
    }

    override func tearDown() {
        engine.stop()
        engine.clearProgress()
        engine.setHoverPaused(false)
        clearAllData()
        engine = nil
        delegate = nil
        super.tearDown()
    }

    private func clearAllData() {
        let context = DataStack.shared.viewContext
        for entityName in ["WordEntry", "Wordbook", "Favorite"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            if let objects = try? context.fetch(request) {
                for object in objects { context.delete(object) }
            }
        }
        DataStack.shared.saveContext()
    }

    private func setupTestData() {
        let context = DataStack.shared.viewContext
        let wordbook = Wordbook(context: context)
        wordbook.wordbookId = "hover-pause-test-wb"
        wordbook.name = "悬停暂停测试"
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = true
        wordbook.isSystem = false
        wordbook.createdAt = Date()

        for (i, word) in ["alpha", "beta", "gamma"].enumerated() {
            let entry = WordEntry(context: context)
            entry.wordId = "hp-\(i)"
            entry.sourceWord = word
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = 0
            entry.wordbook = wordbook
        }
        DataStack.shared.saveContext()
    }

    // MARK: - 暂停与恢复

    /// 暂停后超时不切词，恢复后从暂停处继续切词
    func testPauseFreezesAndResumeContinues() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setHoverPaused(true)

        let exp = XCTestExpectation(description: "暂停期间不切词")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                           "暂停期间超过 stayDuration 也不应切词")
            self.engine.setHoverPaused(false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                XCTAssertNotEqual(self.engine.currentWord()?.wordId, firstWord,
                                  "恢复后应继续计时并切词")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 6.0)
    }

    /// 恢复按剩余时长而非整段重计：3s 词在 1s 时暂停（剩 ~2s），恢复后 2.4s 内应已切词
    func testResumeUsesRemainingTime() {
        AppSettings.shared.stayDuration = 3
        engine.start()
        let firstWord = engine.currentWord()?.wordId

        let exp = XCTestExpectation(description: "恢复按剩余时长")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.engine.setHoverPaused(true)   // 剩余 ~2s
            self.engine.setHoverPaused(false)  // 立即恢复

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                XCTAssertNotEqual(self.engine.currentWord()?.wordId, firstWord,
                                  "按剩余 ~2s 计时应已切词；若错误地整段重计（3s）此刻尚未切换")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 6.0)
    }

    /// 暂停中手动切词（认识/不认识）：新词保持暂停不启动计时
    func testManualAdvanceWhilePausedKeepsPaused() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setHoverPaused(true)
        engine.markKnown()

        let secondWord = engine.currentWord()?.wordId
        XCTAssertNotEqual(secondWord, firstWord, "markKnown 应立即切到下一词")

        let exp = XCTestExpectation(description: "新词保持暂停")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, secondWord,
                           "暂停中切到的新词不应启动计时")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    /// 暂停中停留时长热更新：不启动计时，仅更新记录值
    func testTimingChangeWhilePausedStaysPaused() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setHoverPaused(true)

        AppSettings.shared.stayDuration = 2
        AppSettings.shared.postTimingChange()

        let exp = XCTestExpectation(description: "热更新不启动计时")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                           "暂停中热更新时长不应启动计时器")
            self.engine.setHoverPaused(false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                XCTAssertNotEqual(self.engine.currentWord()?.wordId, firstWord,
                                  "恢复后按新时长（2s）应已切词")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 7.0)
    }

    /// 引擎启动前记录暂停标志：start 后首个词保持暂停（覆盖"重启保持暂停"场景）
    func testPauseFlagBeforeStart() {
        engine.setHoverPaused(true)
        engine.start()
        let firstWord = engine.currentWord()?.wordId

        let exp = XCTestExpectation(description: "启动后保持暂停")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                           "鼠标在窗内时引擎启动，首个词应保持暂停")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }
}

private class MockHoverDelegate: ReciteEngineDelegate {
    func engineDidAdvanceToWord(_ word: WordEntry) {}
    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int) {}
    func engineDidCompleteAll() {}
}
