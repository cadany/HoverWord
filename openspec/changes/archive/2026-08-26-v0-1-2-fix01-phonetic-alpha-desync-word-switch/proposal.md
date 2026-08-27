---
baseline_version: "v0-1-2"
change_sub_version: "v0-1-2-fix01"
---

## Why

用户验证动效功能时发现：注音显示模式为"悬停显示"或"隐藏"时，切换单词后注音直接保持显示状态，违反 content-visibility 既有 spec 的「注音 hover/hidden 模式下 SHALL 保持不可见（alpha = 0）」要求（该 spec 明确"始终不可见，不受鼠标状态影响"）。

**根因**（feat01 动效显式动画引入的回归）：

动效系统为驱动动画直接改写 `layer.opacity`（显式动画的模型终态落位），绕过了 AppKit 的 `NSView.alphaValue` 内部缓存，造成两者脱钩：

1. hover/hidden 模式下切词前，`alphaValue` 缓存 = 0（注音不可见，正确）
2. 动效在同一事务把 `layer.opacity` 落到 1（动画终态），缓存仍停留在 0
3. 动效完成回调 `updatePhoneticVisibility(animated: false)` 再设 `alphaValue = 0`，AppKit 判定"值未变化"（缓存本来就是 0）→ **跳过对 layer 的写入**
4. `layer.opacity` 停留在 1 → 注音持续显示，直到鼠标进出悬浮窗（alphaValue 目标值发生实际变化）才恢复

## What Changes

`FloatContentView.applyAlpha(_:to:animated:)` 的非动画路径在设置 `view.alphaValue` 后显式同步 `view.layer?.opacity`，绕过 AppKit 的去重跳写，保证呈现层与配置一致：

- 修复范围覆盖注音与释义两条路径（`updatePhoneticVisibility` / `updateMeaningVisibility` 共用 `applyAlpha`，释义存在同样的脱钩隐患，一并修复）
- 动画路径（hover 进出触发）不变：值有实际变化时 AppKit 正常写 layer，无脱钩问题

## Capabilities

### New Capabilities

无。

### Modified Capabilities

无——修复恢复 content-visibility 既有 spec 的合规性，规格本身无变更。

## Impact

**受影响文件：**
- `Features/FloatingWindow/FloatContentView.swift` — `applyAlpha` 非动画路径同步 layer.opacity（约 4 行）

**不受影响：**
- 动效系统（协议/动效实现/注册表）不变
- content-visibility 设置 UI 不变
- hover 进出的动画显隐路径不变

## 已知关联问题（本 change 不处理，待用户决策）

动效进行中（约 0.15-0.5s）注音随动效短暂闪现（如经典淡入带着注音一起淡入），动效结束即恢复隐藏。这是动效协议不感知内容可见性配置所致，修复需改协议（传入可见性上下文或让注标不参与动画），超出本 fix 范围。
