import XCTest
@testable import HoverWord

/// 动效注册表测试
///
/// 对应任务 1.7：TransitionRegistry 查找功能验证
final class TransitionRegistryTests: XCTestCase {

    func testDefaultTransitionExists() {
        // 默认动效应该存在
        let defaultEffect = TransitionRegistry.effect(id: Constants.defaultTransitionId)
        XCTAssertNotNil(defaultEffect, "默认动效 \(Constants.defaultTransitionId) 应该存在")
        XCTAssertEqual(defaultEffect?.id, Constants.defaultTransitionId)
    }

    func testAllTransitionsRegistered() {
        // 所有 9 个内置动效（含"无"动效）都应该注册
        let allEffects = TransitionRegistry.all
        XCTAssertEqual(allEffects.count, 9, "应该有 9 个内置动效")

        // 验证每个动效都有唯一的 id
        let ids = allEffects.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "所有动效 id 应该唯一")
    }

    func testNoneTransitionRegisteredFirst() {
        // "无"动效应置顶注册（下拉首项）
        XCTAssertEqual(TransitionRegistry.all.first?.id, "none", "无动效应位于注册表首位")
    }

    func testEffectLookupById() {
        // 测试通过 id 查找动效
        let effect = TransitionRegistry.effect(id: "card-flip")
        XCTAssertNotNil(effect)
        XCTAssertEqual(effect?.id, "card-flip")
        // displayName 使用本地化，只验证不为空
        XCTAssertFalse(effect?.displayName.isEmpty ?? true, "displayName 不应为空")
    }

    func testNonexistentEffectReturnsNil() {
        // 查找不存在的动效应该返回 nil
        let effect = TransitionRegistry.effect(id: "nonexistent-effect")
        XCTAssertNil(effect)
    }

    func testEffectCategories() {
        // 验证动效分类正确
        let minimalEffects = TransitionRegistry.effectsByCategory()[.minimal] ?? []
        let playfulEffects = TransitionRegistry.effectsByCategory()[.playful] ?? []
        let immersiveEffects = TransitionRegistry.effectsByCategory()[.immersive] ?? []

        // 经典淡入属于简约
        XCTAssertTrue(minimalEffects.contains { $0.id == "classic-fade" })

        // 卡片翻转属于趣味
        XCTAssertTrue(playfulEffects.contains { $0.id == "card-flip" })

        // 翻页属于沉浸
        XCTAssertTrue(immersiveEffects.contains { $0.id == "page-flip" })
    }
}
