## 1. 动效基础设施

- [x] 1.1 创建 `Services/Transitions/TransitionCategory.swift`，定义分类枚举（.minimal / .playful / .immersive）
- [x] 1.2 创建 `Services/Transitions/TransitionParameter.swift`，定义参数描述模型（id、displayName、range、defaultValue）
- [x] 1.3 创建 `Services/Transitions/TransitionParameters.swift`，定义参数字典结构（Codable，支持 get/set/clamp）
- [x] 1.4 创建 `Services/Transitions/TransitionContent.swift`，定义过渡内容模型（word、phonetic、meanings，用于动效输入）
- [x] 1.5 创建 `Services/Transitions/WordTransitionEffect.swift`，定义动效协议（id、displayName、category、adjustableParameters、animate 方法）
- [x] 1.6 创建 `Services/Transitions/TransitionRegistry.swift`，实现注册表（静态数组、effect(id:) 查找）
- [x] 1.7 编写动效基础设施的单元测试（参数 clamp、注册表查找）

## 2. 内置动效实现

- [x] 2.1 实现 `ClassicFadeEffect.swift`（经典淡入，复用现有逻辑，0.15s ease-out + 1px 位移）
- [x] 2.2 实现 `CardFlipEffect.swift`（卡片翻转，Y 轴 180° 3D 翻转，可调速度参数 0.2s-0.5s）
- [x] 2.3 实现 `TypewriterEffect.swift`（打字机，逐字符出现，可调字符间隔参数 30ms-100ms）
- [x] 2.4 实现 `BounceInEffect.swift`（弹跳入场，CASpringAnimation，可调弹性强度参数 0.5-2.0）
- [x] 2.5 实现 `PageFlipEffect.swift`（翻页效果，沿右边缘翻转 90°，带阴影）
- [x] 2.6 实现 `LiquidMergeEffect.swift`（液体融合，scale + opacity + 轻微模糊）
- [x] 2.7 实现 `BlackHoleEffect.swift`（星体黑洞，字母向中心吸入/从中心喷出，带旋转）
- [x] 2.8 实现 `LetterMorphEffect.swift`（字母变形，旧字母 scale down + 新字母 scale up 叠加）
- [x] 2.9 在 `TransitionRegistry` 中注册所有 8 个动效
- [x] 2.10 为每个动效编写单元测试（验证 animate 方法调用 completion）

## 3. 数据持久化

- [x] 3.1 在 `AppSettings.swift` 中添加 `selectedTransitionId: String` 字段（默认 "classic-fade"）
- [x] 3.2 在 `AppSettings.swift` 中添加 `transitionParameters: TransitionParameters` 字段
- [x] 3.3 实现 `AppSettings` 中动效配置的 UserDefaults 读写
- [x] 3.4 实现参数值 clamp 逻辑（读取时校验范围，无效值回退默认）
- [x] 3.5 编写 AppSettings 动效配置的持久化测试

## 4. 悬浮窗集成

- [ ] 4.1 重构 `FloatContentView.showWord` 方法，提取当前动效逻辑为独立的 transition 调用
- [ ] 4.2 在 `FloatContentView` 中注入动效执行逻辑（从 TransitionRegistry 获取用户选择的动效）
- [ ] 4.3 实现动效执行失败的 fallback（catch 错误，立即显示新单词）
- [ ] 4.4 添加 `.previewTransitionEffect` 通知监听，支持预览功能
- [ ] 4.5 在预览时暂停背记引擎（复用 hover 暂停机制）
- [ ] 4.6 编写悬浮窗动效集成的集成测试

## 5. 设置界面

- [x] 5.1 创建 `Features/Settings/ExperienceSettingsView.swift`（SwiftUI），实现动效选择列表
- [x] 5.2 在 `ExperienceSettingsView` 中实现动效分类展示（按 category 分组）
- [x] 5.3 在 `ExperienceSettingsView` 中实现参数调整 UI（滑块/选择器，根据动效的 adjustableParameters 动态生成）
- [x] 5.4 在 `ExperienceSettingsView` 中实现 [预览] 按钮，发送 `.previewTransitionEffect` 通知
- [ ] 5.5 在 `SettingsWindowController.swift` 中添加"体验" Tab（SF Symbols "wand.and.stars" 图标）
- [x] 5.6 在 `NotificationNames.swift` 中添加 `.previewTransitionEffect` 通知名
- [ ] 5.7 编写设置界面的 UI 测试（动效选择、参数调整、预览触发）

## 6. 常量与配置

- [x] 6.1 在 `Constants.swift` 中添加动效相关常量（默认时长、参数范围、预览示例单词）
- [x] 6.2 为每个动效定义默认参数值常量

## 7. 性能验证

- [x] 7.1 编写动效性能基准测试（切换延迟 ≤100ms，帧率 ≥60fps）
- [x] 7.2 在低端机器上验证复杂动效（字母变形、星体黑洞）的性能
- [x] 7.3 实现字母数量超限降级逻辑（超过 10 个字母降级为经典淡入）

## 8. 文档与示例

- [ ] 8.1 更新 README.md，说明动效系统的扩展方式（如何实现新动效）
- [x] 8.2 为每个内置动效添加注释，说明效果描述和参数含义
