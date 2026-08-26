import Foundation

/// 动效注册表
///
/// 管理所有可用动效的注册与发现。采用静态数组显式注册，
/// 新增动效只需在 `all` 数组中添加一行代码。
enum TransitionRegistry {

    /// 所有已注册的动效
    ///
    /// 新增动效只需在此数组中添加实例即可。
    /// NoTransitionEffect（无动效）置顶，与设置页下拉的置顶展示对应。
    static let all: [any WordTransitionEffect] = [
        NoTransitionEffect(),
        ClassicFadeEffect(),
        CardFlipEffect(),
        TypewriterEffect(),
        BounceInEffect(),
        PageFlipEffect(),
        LiquidMergeEffect(),
        BlackHoleEffect(),
        LetterMorphEffect()
    ]

    /// 根据 ID 获取动效
    ///
    /// - Parameter id: 动效唯一标识
    /// - Returns: 对应的动效实例，未找到时返回 nil
    static func effect(id: String) -> (any WordTransitionEffect)? {
        return all.first { $0.id == id }
    }

    /// 获取默认动效（经典淡入）
    ///
    /// - Returns: 默认动效实例
    static var defaultEffect: any WordTransitionEffect {
        return effect(id: Constants.defaultTransitionId) ?? ClassicFadeEffect()
    }

    /// 按分类分组获取动效
    ///
    /// - Returns: 字典，键为分类，值为该分类下的动效数组
    static func effectsByCategory() -> [TransitionCategory: [any WordTransitionEffect]] {
        var result: [TransitionCategory: [any WordTransitionEffect]] = [:]
        for effect in all {
            result[effect.category, default: []].append(effect)
        }
        return result
    }
}
