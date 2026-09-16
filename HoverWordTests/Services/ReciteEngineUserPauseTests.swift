import XCTest
import CoreData
@testable import HoverWord

/// 用户暂停（右键菜单"暂停背记 / 继续背记"）验证
///
/// 覆盖：暂停冻结切词、恢复按剩余时长继续、与悬停暂停的来源合成与冻结时长不衰减、
/// 暂停中手动切词、暂停中引擎重启后仍可恢复、非 playing 态解除不启动计时。
final class ReciteEngineUserPauseTests: XCTestCase {

    private var engine: ReciteEngine!
    private var delegate: MockUserPauseDelegate!

    override func setUp() {
        super.setUp()
        DataStack.shared.initialize()
        clearAllData()
        setupTestData()

        engine = ReciteEngine()
        delegate = MockUserPauseDelegate()
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
        engine.setUserPaused(false)
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
        wordbook.wordbookId = "user-pause-test-wb"
        wordbook.name = "用户暂停测试"
        wordbook.sourceLang = "en"
        wordbook.targetLang = "zh-Hans"
        wordbook.isEnabled = true
        wordbook.isSystem = false
        wordbook.createdAt = Date()

        for (i, word) in ["alpha", "beta", "gamma"].enumerated() {
            let entry = WordEntry(context: context)
            entry.wordId = "up-\(i)"
            entry.sourceWord = word
            entry.meaning1 = "释义\(i)"
            entry.sectionIndex = 0
            entry.wordbook = wordbook
        }
        DataStack.shared.saveContext()
    }

    // MARK: - 基础冻结与恢复

    /// 用户暂停后超时不切词，解除后继续切词
    func testUserPauseFreezesAndResumeContinues() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setUserPaused(true)
        XCTAssertTrue(engine.isUserPausedActive)

        let exp = XCTestExpectation(description: "暂停期间不切词")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                           "用户暂停期间超过 stayDuration 也不应切词")
            self.engine.setUserPaused(false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                XCTAssertNotEqual(self.engine.currentWord()?.wordId, firstWord,
                                  "解除后应继续计时并切词")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 6.0)
    }

    /// 解除按剩余时长而非整段重计：3s 词在 1s 时暂停（剩 ~2s），解除后 2.4s 内应已切词
    func testUserResumeUsesRemainingTime() {
        AppSettings.shared.stayDuration = 3
        engine.start()
        let firstWord = engine.currentWord()?.wordId

        let exp = XCTestExpectation(description: "解除按剩余时长")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.engine.setUserPaused(true)   // 剩余 ~2s
            self.engine.setUserPaused(false)  // 立即解除

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                XCTAssertNotEqual(self.engine.currentWord()?.wordId, firstWord,
                                  "按剩余 ~2s 计时应已切词；若错误地整段重计（3s）此刻尚未切换")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 6.0)
    }

    // MARK: - 与悬停暂停的来源合成

    /// 用户暂停不被悬停暂停的解除误消除
    func testUserPauseSurvivesHoverResume() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setHoverPaused(true)
        engine.setUserPaused(true)
        engine.setHoverPaused(false)   // 鼠标离开：瞬时源解除，用户源仍在

        let exp = XCTestExpectation(description: "用户暂停保持")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                           "悬停解除不应连带解除用户暂停")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    /// 悬停暂停进行中叠加用户暂停：来源身份不得被吞，且冻结时长不随墙钟衰减
    ///
    /// 3s 词、1s 时鼠标进窗（入账 remaining ≈ 2s 并停表）、2s 时叠加用户暂停后鼠标出窗、
    /// 3s 时解除用户暂停。停表期间 remaining 是冻结值，故 3s 解除后仍应按 ≈ 2s 起表（t≈5 切词）。
    /// 判别点在 t≈4.4：若第二源被"合并值未变即跳过"吞掉，则 2s 鼠标出窗就会按 2s 起表 → t≈4.0 切词，
    /// 此时应已切换；正确实现下 t≈4.4 仍保持冻结。
    func testUserPauseAddedDuringHoverKeepsFreezeAndRemaining() {
        AppSettings.shared.stayDuration = 3
        engine.start()
        let firstWord = engine.currentWord()?.wordId

        let exp = XCTestExpectation(description: "叠加来源不被吞")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.engine.setHoverPaused(true)   // 停表，remaining ≈ 2s（冻结值）

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.engine.setUserPaused(true)   // 合并值 true → true，仅记录来源
                self.engine.setHoverPaused(false) // 瞬时源解除，用户源仍在 → 保持冻结

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                                   "用户暂停生效期间不得切词")
                    self.engine.setUserPaused(false)   // t≈3.0，按冻结的 remaining ≈ 2s 起表

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {   // t≈4.4
                        XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                                       "冻结期间 remaining 不衰减：t≈4.4 距解除仅 1.4s，"
                                     + "若第二源被吞则 2s 时已按 remaining 起表并在 t≈4.0 切词")
                        exp.fulfill()
                    }
                }
            }
        }
        wait(for: [exp], timeout: 9.0)

        // 恢复后仍应正常切词（按冻结的 ≈2s，t≈5.0）
        let resumeExp = XCTestExpectation(description: "冻结解除后按 remaining 切词")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            XCTAssertNotEqual(self.engine.currentWord()?.wordId, firstWord,
                              "t≈5.6 应已按 remaining ≈ 2s 完成切词")
            resumeExp.fulfill()
        }
        wait(for: [resumeExp], timeout: 4.0)
    }

    /// 用户暂停解除但鼠标仍在窗内：继续保持暂停，待悬停解除后才恢复
    func testUserResumeKeepsPausedWhileHovering() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setHoverPaused(true)
        engine.setUserPaused(true)
        engine.setUserPaused(false)   // 解除用户源，瞬时源仍在

        let exp = XCTestExpectation(description: "悬停暂停仍在")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                           "鼠标仍在窗内时应保持暂停")
            self.engine.setHoverPaused(false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                XCTAssertNotEqual(self.engine.currentWord()?.wordId, firstWord,
                                  "两源均解除后应恢复计时")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 6.0)
    }

    // MARK: - 暂停中的其他路径

    /// 用户暂停中手动切词：新词保持暂停不启动计时
    func testManualAdvanceWhileUserPausedKeepsPaused() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setUserPaused(true)
        engine.markKnown()

        let secondWord = engine.currentWord()?.wordId
        XCTAssertNotEqual(secondWord, firstWord, "markKnown 应立即切到下一词")

        let exp = XCTestExpectation(description: "新词保持暂停")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, secondWord,
                           "用户暂停中切到的新词不应启动计时")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5.0)
    }

    /// 用户暂停中停留时长热更新：不启动计时，记录值刷为新时长
    func testTimingChangeWhileUserPausedStaysPaused() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setUserPaused(true)

        AppSettings.shared.stayDuration = 2
        AppSettings.shared.postTimingChange()

        let exp = XCTestExpectation(description: "热更新不启动计时")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, firstWord,
                           "用户暂停中热更新时长不应启动计时器")
            self.engine.setUserPaused(false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                XCTAssertNotEqual(self.engine.currentWord()?.wordId, firstWord,
                                  "恢复后按新时长（2s）应已切词")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 7.0)
    }

    /// 用户暂停中引擎重启：重启后的词保持暂停，解除后能正常恢复（不悬空、不立即抢切）
    func testEngineRestartWhileUserPausedThenResume() {
        engine.start()
        let firstWord = engine.currentWord()?.wordId
        engine.setUserPaused(true)
        engine.stop()
        engine.start()   // 模拟规则变更 / 词本启停引发的引擎重启

        let restartedWord = engine.currentWord()?.wordId
        let exp = XCTestExpectation(description: "重启后保持暂停并可恢复")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            XCTAssertEqual(self.engine.currentWord()?.wordId, restartedWord,
                           "重启后的单词应保持暂停（首词同为 \(firstWord ?? "nil")）")
            self.engine.setUserPaused(false)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                XCTAssertNotEqual(self.engine.currentWord()?.wordId, restartedWord,
                                  "解除后应按重启入账的整段时长恢复计时，不得永久停住")
                exp.fulfill()
            }
        }
        wait(for: [exp], timeout: 6.0)
    }

    /// 非 playing 态解除用户暂停：仅清标志，不启动计时
    func testResumeWhileIdleDoesNotStartTimer() {
        engine.setUserPaused(true)
        engine.setUserPaused(false)
        XCTAssertFalse(engine.isUserPausedActive, "标志应已清除")
        XCTAssertNil(engine.currentWord(), "空闲态不应有当前单词")

        let exp = XCTestExpectation(description: "空闲态不切词")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            XCTAssertEqual(self.engine.state, .idle, "空闲态解除暂停不应改变引擎状态")
            XCTAssertNil(self.engine.currentWord())
            exp.fulfill()
        }
        wait(for: [exp], timeout: 4.0)
    }
}

private class MockUserPauseDelegate: ReciteEngineDelegate {
    func engineDidAdvanceToWord(_ word: WordEntry) {}
    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int) {}
    func engineDidCompleteAll() {}
}
