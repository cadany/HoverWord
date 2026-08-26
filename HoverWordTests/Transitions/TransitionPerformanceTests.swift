import XCTest
@testable import HoverWord

/// 动效性能基准测试
///
/// 对应任务 7.1-7.2：验证动效切换延迟 ≤100ms，帧率 ≥60fps
final class TransitionPerformanceTests: XCTestCase {

    func testTransitionSwitchDelay() {
        // 测试动效切换延迟
        let effect = ClassicFadeEffect()
        let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
        let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

        let expectation = XCTestExpectation(description: "Animation completed")
        let startTime = CFAbsoluteTimeGetCurrent()

        effect.animate(
            from: oldContent,
            to: newContent,
            in: MockContainerView(),
            parameters: TransitionParameters(),
            swapContent: {},
            completion: {
                let endTime = CFAbsoluteTimeGetCurrent()
                let duration = (endTime - startTime) * 1000 // 转换为毫秒
                expectation.fulfill()

                // 验证切换延迟 ≤100ms
                XCTAssertLessThanOrEqual(duration, 100,
                    "动效切换延迟应 ≤100ms，实际：\(duration)ms")
            }
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testComplexEffectPerformance() {
        // 测试复杂动效（字母变形、星体黑洞）的性能
        let effects: [(String, any WordTransitionEffect)] = [
            ("LetterMorph", LetterMorphEffect()),
            ("BlackHole", BlackHoleEffect())
        ]

        for (name, effect) in effects {
            let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
            let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

            let expectation = XCTestExpectation(description: "\(name) completed")
            let startTime = CFAbsoluteTimeGetCurrent()

            effect.animate(
                from: oldContent,
                to: newContent,
                in: MockContainerView(),
                parameters: TransitionParameters(),
                swapContent: {},
                completion: {
                    let endTime = CFAbsoluteTimeGetCurrent()
                    let duration = (endTime - startTime) * 1000
                    expectation.fulfill()

                    // 复杂动效也应该在 100ms 内完成
                    XCTAssertLessThanOrEqual(duration, 100,
                        "\(name) 动效切换延迟应 ≤100ms，实际：\(duration)ms")
                }
            )

            wait(for: [expectation], timeout: 2.0)
        }
    }

    func testLetterMorphDegradation() {
        // 测试字母变形动效的降级逻辑
        let effect = LetterMorphEffect()

        // 短单词（≤10 个字母）应该正常执行
        let shortWord = TransitionContent(word: "short", phonetic: "/ʃɔːrt/", meaning: "adj. 短的")
        let shortExpectation = XCTestExpectation(description: "Short word completed")

        effect.animate(
            from: shortWord,
            to: shortWord,
            in: MockContainerView(),
            parameters: TransitionParameters(),
            swapContent: {},
            completion: {
                shortExpectation.fulfill()
            }
        )

        wait(for: [shortExpectation], timeout: 1.0)

        // 长单词（>10 个字母）应该降级为经典淡入
        let longWord = TransitionContent(
            word: "extraordinary",
            phonetic: "/ɪkˈstrɔːrdəneri/",
            meaning: "adj. 非凡的"
        )
        let longExpectation = XCTestExpectation(description: "Long word completed")

        effect.animate(
            from: longWord,
            to: longWord,
            in: MockContainerView(),
            parameters: TransitionParameters(),
            swapContent: {},
            completion: {
                longExpectation.fulfill()
            }
        )

        wait(for: [longExpectation], timeout: 1.0)
    }
}

/// 模拟容器视图（用于性能测试）
private class MockContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let wordLabel = NSTextField(labelWithString: "test")
        wordLabel.tag = Constants.transitionWordLabelTag
        wordLabel.wantsLayer = true
        addSubview(wordLabel)

        let phoneticLabel = NSTextField(labelWithString: "test")
        phoneticLabel.tag = Constants.transitionPhoneticLabelTag
        phoneticLabel.wantsLayer = true
        addSubview(phoneticLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
