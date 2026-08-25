## Context

HoverWord 当前的单词切换使用硬编码的淡入淡出 + 1px 垂直位移动效（0.15s ease-out）。虽然轻量，但缺乏设计感和个性化空间。本次变更构建一个可扩展的动效系统，提供 8 个创意动效供用户选择，部分动效支持参数微调，并在设置中提供预览功能。

技术栈约束：
- macOS 14+，AppKit + SwiftUI 混合
- 核心动画使用 Core Animation（CALayer、CASpringAnimation、CAEmitterLayer）
- 悬浮窗内容视图 `FloatContentView` 为纯 AppKit（NSView + NSStackView）
- 设置界面使用 SwiftUI

## Goals / Non-Goals

### Goals
1. **可扩展架构**：新增动效只需实现协议 + 注册一行代码，无需改动现有代码
2. **8 个高质量内置动效**：覆盖简约、趣味、沉浸三种风格
3. **部分参数可调**：关键动效提供 1-2 个参数的用户自定义
4. **预览功能**：设置中点击预览，悬浮窗实际演示
5. **性能无损**：所有动效满足 ≤100ms 切换延迟、≥60fps 约束

### Non-Goals
- 不做随机模式（用户明确选择）
- 不做用户自制动效（架构预留但本期不实现）
- 不做动效的复杂编辑器（如关键帧、时间轴）
- 不做季节限定/节日动效（架构可扩展，本期不实现）

## Decisions

### D1: 动效协议采用值类型还是引用类型？

**选择：协议 + 结构体实现（值类型）**

理由：
- 动效本身无状态，只是"如何动画"的算法
- 结构体更轻量，无引用计数开销
- 符合 Swift 的值语义偏好

```swift
protocol WordTransitionEffect {
    var id: String { get }
    var displayName: String { get }
    var category: TransitionCategory { get }
    var adjustableParameters: [TransitionParameter] { get }
    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    )
}
```

### D2: 动效注册采用静态数组还是动态发现？

**选择：静态数组显式注册**

理由：
- 动效数量有限（8 个内置），无需动态发现
- 显式注册更清晰，IDE 可跳转
- 避免运行时反射的复杂性和性能开销

```swift
enum TransitionRegistry {
    static let all: [any WordTransitionEffect] = [
        ClassicFadeEffect(),
        CardFlipEffect(),
        TypewriterEffect(),
        BounceInEffect(),
        PageFlipEffect(),
        LiquidMergeEffect(),
        BlackHoleEffect(),
        LetterMorphEffect()
    ]
    
    static func effect(id: String) -> (any WordTransitionEffect)? {
        all.first { $0.id == id }
    }
}
```

### D3: 动效参数存储结构

**选择：字典存储，类型安全封装**

```swift
struct TransitionParameters: Codable {
    private var values: [String: Double] = [:]
    
    mutating func set(_ key: String, _ value: Double) { ... }
    func get(_ key: String) -> Double? { ... }
}
```

理由：
- 不同动效参数不同，字典灵活
- 封装一层保证类型安全
- Codable 直接支持 UserDefaults 持久化

### D4: 动画实现层面

**选择：Core Animation（CALayer + CATransaction）**

理由：
- 悬浮窗 `FloatContentView` 已是 AppKit，直接操作 layer
- Core Animation 性能最优，GPU 加速
- 支持复杂变换（3D、弹簧、粒子）
- 与现有动效实现方式一致

对于特殊效果：
- 打字机：NSTextField 逐字符更新 + CATransaction 淡入
- 弹跳：CASpringAnimation
- 液体融合：CAEmitterLayer（粒子）+ scale/opacity
- 星体黑洞：每个字母独立 layer，CAKeyframeAnimation 路径
- 字母变形：旧字母 scale down + 新字母 scale up 叠加

### D5: 预览实现

**选择：复用动效协议，传入示例内容**

```swift
// ExperienceSettingsView.swift
func previewEffect(_ effect: any WordTransitionEffect) {
    // 通知悬浮窗执行一次动效演示
    NotificationCenter.default.post(
        name: .previewTransitionEffect,
        object: nil,
        userInfo: ["effect": effect]
    )
}
```

理由：
- 不重复实现动画逻辑
- 预览和实际使用完全一致
- 通知解耦设置窗口和悬浮窗

### D6: 设置界面位置

**选择：新建"体验" Tab（SwiftUI）**

理由：
- 动效设置逻辑独立，不属于外观
- 为未来其他体验设置（如音效、触感）预留空间
- 与现有 Tab 结构一致（单词本、背记规则、外观、发音、体验）

### D7: 文件组织

```
Services/Transitions/
├── WordTransitionEffect.swift       # 协议定义
├── TransitionRegistry.swift         # 注册表
├── TransitionCategory.swift         # 分类枚举
├── TransitionParameter.swift        # 参数定义
├── TransitionParameters.swift       # 参数字典
├── TransitionContent.swift          # 过渡内容模型
└── Effects/
    ├── ClassicFadeEffect.swift
    ├── CardFlipEffect.swift
    ├── TypewriterEffect.swift
    ├── BounceInEffect.swift
    ├── PageFlipEffect.swift
    ├── LiquidMergeEffect.swift
    ├── BlackHoleEffect.swift
    └── LetterMorphEffect.swift
```

理由：
- 按功能模块组织，与项目架构一致
- Effects 子目录便于扩展
- 每个动效独立文件，职责清晰

## Risks / Trade-offs

### R1: 复杂动效性能风险
- **风险**：字母变形、星体黑洞等复杂动效可能掉帧
- **缓解**：
  - 所有动效使用 Core Animation，GPU 加速
  - 字母变形限制字母数量（超过 10 个字母降级为淡入淡出）
  - 粒子效果限制粒子数量
  - 提供性能测试基准

### R2: 动效数量增长后的可维护性
- **风险**：8 个动效 × 参数组合，测试矩阵大
- **缓解**：
  - 协议约束，新增动效不影响已有
  - 每个动效独立单元测试
  - 预览功能用于手动验证

### R3: 预览与背记流程的冲突
- **风险**：预览期间恰好触发自动切换
- **缓解**：
  - 预览时暂停背记引擎（复用 hover 暂停机制）
  - 预览完成后恢复

### R4: 参数持久化的向前兼容
- **风险**：新版本调整参数范围，旧值无效
- **缓解**：
  - 参数读取时 clamp 到有效范围
  - 无效值回退默认
