---
baseline_version: "v0-1-2"
change_sub_version: "v0-1-2-fix02"
---

## Why

fix01 修复了切词后注音持续显示的问题，但暴露出行为层面的 spec 违规：注音显示模式为"悬停显示（鼠标在外）"或"隐藏"时，切词动效进行中（约 0.15-0.5s）注音随动效短暂闪现，动效结束才恢复隐藏。content-visibility 主 spec 明确要求「注音 SHALL 始终不可见（alpha = 0），不受鼠标状态影响」——"始终"应覆盖动效期间。

**根因**：9 个内置动效中仅「经典淡入」与「卡片翻转」两个把音标图层纳入显式动画数组（`for layer in [wordLayer, phoneticLayer]`），动画的 fromValue 从 1 出发、模型终态也落 1，导致隐藏中的音标在动效期间被强制呈现。其余 7 个动效只动画单词图层，音标经 swapContent 换文本、alpha 保持 0，无闪现。

## What Changes

**方案 C（用户确认，见 design.md 选项对比）——音标动画彻底收归视图层：**

1. 经典淡入与卡片翻转移除音标图标的动画参与：guard 简化为仅查找单词标签、动画数组/模型终态写入/中点 transform 复位全部只针对单词图层——与其余 7 个动效行为统一（9 个动效均不再动画音标）
2. 音标的呈现完全由视图层负责：文本在 `swapContent` 中点瞬时切换（`makeContentSwap` 现状已如此，无需改动）、可见性全程由 `updatePhoneticVisibility`/`applyAlpha` 按配置维护——动效不再触碰音标图层，fix01 所修的脱钩根源随之消除
3. `WordTransitionEffect` 协议文档注释固化契约：动效 SHALL NOT 动画或改写音标图层

**视觉行为变化（用户已接受，架构清晰优先）**：注音可见（"始终显示"/"悬停显示"且鼠标在内）时，经典淡入/卡片翻转的音标不再随单词淡入/翻转，改为在动效中点瞬时切换——与其余 7 个动效的既有行为一致。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `word-transition-effects` — 新增「动效与注音可见性协同」requirement：动效 SHALL NOT 动画注音，注音可见性全程由视图层维护

## Impact

**受影响文件：**
- `Services/Transitions/Effects/ClassicFadeEffect.swift` — 移除音标动画参与（guard/数组/模型写入）
- `Services/Transitions/Effects/CardFlipEffect.swift` — 同上（含中点 transform 复位）
- `Services/Transitions/WordTransitionEffect.swift` — 协议文档注释固化音标契约
- `HoverWordTests/Transitions/WordTransitionEffectTests.swift` — 新增两动效不向音标图层添加动画的测试

**不受影响：**
- 其余 7 个动效（本就不动画音标，行为统一后无差异）
- `FloatContentView`（音标文本落位与可见性维护均已在视图层，无需改动）
- 动效协议签名、注册表、设置 UI
