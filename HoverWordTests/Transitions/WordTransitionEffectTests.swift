import XCTest
@testable import HoverWord

/// 动效协议实现测试
///
/// 对应任务 2.10：验证每个动效的 animate 方法正确调用 completion
final class WordTransitionEffectTests: XCTestCase {

    func testClassicFadeEffectCompletion() {
        let effect = ClassicFadeEffect()
        let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
        let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

        let expectation = XCTestExpectation(description: "Animation completion called")

        // 注意：由于动效需要在 NSView 上执行，这里只验证 completion 回调被调用
        // 实际的 UI 动画需要在集成测试中验证
        effect.animate(
            from: oldContent,
            to: newContent,
            in: MockContainerView(),
            parameters: TransitionParameters(),
            completion: {
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testCardFlipEffectCompletion() {
        let effect = CardFlipEffect()
        let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
        let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

        let expectation = XCTestExpectation(description: "Animation completion called")

        effect.animate(
            from: oldContent,
            to: newContent,
            in: MockContainerView(),
            parameters: TransitionParameters(),
            completion: {
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testTypewriterEffectCompletion() {
        let effect = TypewriterEffect()
        let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
        let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

        let expectation = XCTestExpectation(description: "Animation completion called")

        effect.animate(
            from: oldContent,
            to: newContent,
            in: MockContainerView(),
            parameters: TransitionParameters(),
            completion: {
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 2.0)
    }

    func testBounceInEffectCompletion() {
        let effect = BounceInEffect()
        let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
        let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

        let expectation = XCTestExpectation(description: "Animation completion called")

        effect.animate(
            from: oldContent,
            to: newContent,
            in: MockContainerView(),
            parameters: TransitionParameters(),
            completion: {
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 1.0)
    }

    func testEffectDisplayName() {
        // 验证所有动效都有显示名称
        for effect in TransitionRegistry.all {
            XCTAssertFalse(effect.displayName.isEmpty, "\(effect.id) 应该有显示名称")
        }
    }

    func testEffectParameters() {
        // 验证可调参数的动效
        let cardFlip = CardFlipEffect()
        XCTAssertFalse(cardFlip.adjustableParameters.isEmpty, "卡片翻转应该有可调参数")

        let classicFade = ClassicFadeEffect()
        XCTAssertTrue(classicFade.adjustableParameters.isEmpty, "经典淡入不应该有可调参数")
    }
}

/// 模拟容器视图（用于测试）
private class MockContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 添加模拟的 wordLabel
        let wordLabel = NSTextField(labelWithString: "test")
        wordLabel.tag = 1001
        addSubview(wordLabel)

        let phoneticLabel = NSTextField(labelWithString: "test")
        phoneticLabel.tag = 1002
        addSubview(phoneticLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
