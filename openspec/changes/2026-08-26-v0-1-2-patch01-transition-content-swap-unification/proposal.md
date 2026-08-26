---
baseline_version: "v0-1-2"
change_sub_version: "v0-1-2-patch01"
---

## Why

动效系统落地 review 发现：内容切换（换词 + 换音标）逻辑散落在 9 个动效实现里，且两组时机不一致——ClassicFade/CardFlip/PageFlip/NoTransition 在动画中点换词时同步换音标；Typewriter/BounceIn/LetterMorph/LiquidMerge/BlackHole 只换词不换音标，旧音标在整个动画期间残留，动画结束由 `applyWordContent` 兜底时才瞬间跳变。9 处近似重复的"换词 + 音标显隐"代码也随动效数量持续累积，新动效极可能再次漏掉音标。

根因是职责错位：内容切换是视图层职责（哪个标签显示什么内容由 FloatContentView 决定），动效只应负责"如何动画"。当前协议却把内容切换隐式交给了每个动效自己实现。

## What Changes

### 架构归一

1. **协议签名变更**：`WordTransitionEffect.animate` 增加 `swapContent: () -> Void` 中点回调参数——动效动画进行到旧内容不可辨（翻转侧立、缩放为零、淡出完毕等）的时点调用一次，由调用方完成新内容落位
2. **内容切换收归视图层**：`FloatContentView` 实现统一的 swapContent 闭包（单词 + 音标 + 显隐逻辑），切词与预览两个调用点分别构造后传入动效
3. **动效瘦身**：9 个动效删除各自的换词/换音标代码（含 `viewWithTag(音标)` 查找），只保留动画编排，在原"中点换词"位置改为调用 `swapContent()`
4. **音标参与动画对齐**：Typewriter（无中点语义，在开始打字前调用）、BounceIn（弹入前）、LetterMorph/LiquidMerge/BlackHole（中点）统一经 swapContent 完成音标同步，消除残留跳变

### 不变的约定

- 动效定位契约仍为 `viewWithTag(Constants.transitionWordLabelTag/PhoneticLabelTag)`，但音标查找收归视图层后动效仅需单词标签（音标动画所需的 layer 由 swapContent 闭包内一并处理或经参数传出）
- `completion` 回调时机与代际守卫语义不变；`applyWordContent` 仍为最终兜底
- 用户可见行为：音标随动画同步切换（而非结束后跳变），其余动效表现不变

## Capabilities

### Modified Capabilities

- `word-transition-effects`：协议增加 swapContent 中点回调；动效不再自行换词换音标；音标更新时机统一

## Impact

### 文件变更

- **修改**：
  - `Services/Transitions/WordTransitionEffect.swift`（协议签名 + 契约注释）
  - `Services/Transitions/Effects/*.swift`（9 个动效删除内容切换代码，中点改调 swapContent）
  - `Features/FloatingWindow/FloatContentView.swift`（统一 swapContent 实现；切词/预览调用点适配）

### 风险与回归面

- 协议签名变化波及全部动效与两个调用点，需完整回归 9 个动效的切换与预览
- 迁移期保持 `completion` 归位链路不变，风险集中在"中点内容落位"一步

### 验证标准

- 所有动效：单词与音标在同一动画节点同步切换，无音标残留跳变
- 打字机在逐字符开始前音标已就位
- 预览路径（当前词演示）行为与切词路径一致
