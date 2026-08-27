import XCTest
@testable import HoverWord

/// 动效协议实现测试
///
/// 对应任务 2.10：验证每个动效的 animate 方法正确调用 completion
/// 对应任务 4.1：验证每个动效调用 swapContent 恰好一次（在 completion 之前）
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
            swapContent: {},
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
            swapContent: {},
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
            swapContent: {},
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
            swapContent: {},
            completion: {
                expectation.fulfill()
            }
        )

        wait(for: [expectation], timeout: 1.0)
    }

    /// 所有注册动效 SHALL 在 completion 之前恰好调用一次 swapContent
    func testAllEffectsCallSwapContentExactlyOnce() {
        let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
        let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

        for effect in TransitionRegistry.all {
            var swapCount = 0
            let completionExpectation = XCTestExpectation(
                description: "\(effect.id) completion called"
            )

            effect.animate(
                from: oldContent,
                to: newContent,
                in: MockContainerView(),
                parameters: TransitionParameters(),
                swapContent: { swapCount += 1 },
                completion: {
                    // swap 先于 completion：完成时内容必须已落位恰好一次
                    XCTAssertEqual(
                        swapCount, 1,
                        "\(effect.id) 应在 completion 前恰好调用一次 swapContent"
                    )
                    completionExpectation.fulfill()
                }
            )

            wait(for: [completionExpectation], timeout: 2.0)
        }
    }

    /// 动效 SHALL NOT 向音标图层添加动画（音标呈现完全由视图层负责，
    /// 见协议"职责边界"）；单词图层动画应正常存在
    func testEffectsDoNotAnimatePhoneticLayer() {
        let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
        let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

        let effects: [any WordTransitionEffect] = [ClassicFadeEffect(), CardFlipEffect()]
        for effect in effects {
            let container = MockContainerView()
            guard let wordLayer = (container.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField)?.layer,
                  let phoneticLayer = (container.viewWithTag(Constants.transitionPhoneticLabelTag) as? NSTextField)?.layer else {
                XCTFail("\(effect.id) 测试容器缺少标签")
                return
            }

            effect.animate(
                from: oldContent,
                to: newContent,
                in: container,
                parameters: TransitionParameters(),
                swapContent: {},
                completion: {}
            )

            // 第一阶段动画在 animate 内同步添加：单词有、音标必须没有
            XCTAssertNotNil(
                wordLayer.animation(forKey: "transition.opacity") ?? wordLayer.animation(forKey: "transition.rotation"),
                "\(effect.id) 单词图层应有过渡动画"
            )
            XCTAssertNil(
                phoneticLayer.animation(forKey: "transition.opacity"),
                "\(effect.id) 不应向音标图层添加透明度动画"
            )
            XCTAssertNil(
                phoneticLayer.animation(forKey: "transition.rotation"),
                "\(effect.id) 不应向音标图层添加翻转动画"
            )
            XCTAssertNil(
                phoneticLayer.animation(forKey: "transition.translation"),
                "\(effect.id) 不应向音标图层添加位移动画"
            )
        }
    }

    /// 容器缺少契约标签时（guard 失败路径）SHALL 立即 completion 不崩溃，
    /// 内容落位由调用方 completion 兜底完成
    func testEffectsHandleMissingLabelsGracefully() {
        let oldContent = TransitionContent(word: "apple", phonetic: "/ˈæpəl/", meaning: "n. 苹果")
        let newContent = TransitionContent(word: "banana", phonetic: "/bəˈnænə/", meaning: "n. 香蕉")

        for effect in TransitionRegistry.all where !(effect is NoTransitionEffect) {
            let completionExpectation = XCTestExpectation(
                description: "\(effect.id) completion called without labels"
            )

            effect.animate(
                from: oldContent,
                to: newContent,
                in: NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 100)),
                parameters: TransitionParameters(),
                swapContent: {},
                completion: {
                    completionExpectation.fulfill()
                }
            )

            wait(for: [completionExpectation], timeout: 2.0)
        }
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
        // 添加模拟的 wordLabel（wantsLayer 保证动效 guard 到 layer 走真实动画路径）
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
