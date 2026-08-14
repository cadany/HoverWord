## Context

mvp-v0-1 验证阶段发现 2 个关键 Bug 和 10 项视觉/动效缺失。Bug 影响核心功能正确性（首词跳过、markUnknown 无效），视觉缺失影响用户体验（深色模式失效、动效不完整）。需要在不影响已完成功能的前提下修复。

## Goals / Non-Goals

**Goals:**
- 修复 ReciteEngine 两个关键逻辑 Bug，使首词正常展示、markUnknown 产生重试效果
- 修复深色模式：移除硬编码 appearance，文字/按钮颜色根据系统外观动态适配
- 补全所有缺失动效：单词切换 1px 位移、按钮滑入、点击反馈、窗口显隐、状态切换、设置过渡
- 所有修改通过现有单元测试 + 新增测试

**Non-Goals:**
- 不改变 Core Data 模型或导入流程
- 不修复验证中提到的非关键问题（死代码通知名称、收藏夹单词本启用背记）
- 不改变 UI spec 中已定义的设计参数

## Decisions

### Decision 1: ReciteEngine 首词跳过修复 — 引入 `displayCurrentWord()` 方法

**方案：** 将 `advanceToNextWord()` 拆分为两步：
- `advanceToNextWord()` 仅负责递增索引 + 边界检测 + 轮次管理
- 新增 `displayCurrentWord()` 负责触发 delegate 回调 + 启动 timer

在 `start()` / `advanceToNextSection()` / `rebuildWordOrder()` 后的首次展示场景，调用 `displayCurrentWord()` 而不是 `advanceToNextWord()`，避免 index 0 被跳过。

**替代方案：** 给 `advanceToNextWord()` 加 `displayOnly` 参数——但增加函数复杂度，不如拆分清晰。

### Decision 2: markUnknown 修复 — 不加入 feedbackSet

**方案：** `markUnknown()` 与 `markKnown()` 的关键区别：
- `markKnown()`: 加入 `feedbackSet`（标记为已反馈，不再出现）
- `markUnknown()`: 不加入 `feedbackSet`（保持未反馈状态，下一轮重试）

两者都调用 `advanceToNextWord()` 切换到下一单词。

**边界处理：** 如果 Section 内所有单词都标记了"不认识"（feedbackSet 为空），`advanceMemoryFeedback` 的轮次结束检测（`allFeedback` 判断）需要额外处理——当所有单词都未反馈时，一轮结束后应视为 Section 完成（避免死循环）。实际上当前的 `allFeedback` 检查的是 `feedbackSet.contains($0.wordId)` 对所有 entry，如果全部 markUnknown，feedbackSet 为空，allFeedback 为 false，会进入新轮次但 currentWordOrder 与原来相同——这是正确行为，用户将持续看到这些单词直到标记认识或超时。

### Decision 3: 深色模式修复 — 移除硬编码 appearance + 动态颜色

**GlassBackgroundView:**
- 删除 `appearance = NSAppearance(named: .aqua)` 这一行，让 NSVisualEffectView 默认跟随系统外观
- `viewDidChangeEffectiveAppearance()` 已有实现，会自动更新内描边颜色

**FloatContentView:**
- 新增 `isDarkMode` 计算属性，基于 `effectiveAppearance` 判断
- 新增 `updateTextColors()` 方法，根据 isDarkMode 切换文字/按钮颜色
- 在 `setupContent()` 后调用 `updateTextColors()`
- 重写 `viewDidChangeEffectiveAppearance()`，调用 `updateTextColors()`
- 释义行 `addMeaningRow` 中的颜色也需动态适配

### Decision 4: 动效补全 — CAAnimation + NSAnimationContext

**单词切换 1px 位移：**
- 在 `showWord()` 的淡出阶段，对 wordLabel/phoneticLabel 同时动画 `frame.origin.y -= 1`
- 淡入阶段从 `y += 1` 回到正常位置
- 使用 `animator().frame` 或 CABasicAnimation

**按钮悬停滑入：**
- `setButtonsHidden(false)` 时，先设置按钮初始 `frame.origin.y -= 4`（4px 偏移）+ `alphaValue = 0`
- 动画目标：`frame.origin.y` 回到正常 + `alphaValue = 1`
- 时长 0.15s ease-out

**按钮点击态：**
- 在 `knowTapped` / `unknownTapped` / `favoriteTapped` 中触发
- 使用 `NSAnimationContext` 动画 `layer?.opacity` 降低 + `layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1)`
- 时长 0.1s，completionHandler 恢复原状

**窗口显示/隐藏：**
- 在 `FloatWindowController.showWindow()` 中，先设 `alphaValue = 0` + `frame` 微缩，再动画到正常
- 隐藏（`orderOut` 前）类似处理
- 使用 `Constants.windowFadeDuration` (0.2s)

**完成状态切换：**
- `showCompleted()` 中用 `NSAnimationContext` 包裹，先淡出单词内容，再淡入"已学完"

**设置应用过渡：**
- `handleSettingsChange()` 中的 `applyAppearanceSettings()` 调用用 `NSAnimationContext` 包裹
- 使用 `Constants.settingsApplyDuration` (0.2s)

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|---------|
| 首词跳过修复可能影响走马灯模式的轮次计数 | 新增单元测试覆盖走马灯首词展示 |
| markUnknown 修复后 Section 可能永远无法完成（全部不认识） | 这是预期行为：用户持续看到不认识的单词直到标记认识。停留超时不加入 feedbackSet 也是同一逻辑 |
| 移除 `appearance = .aqua` 可能影响 tint 层在浅色模式下的表现 | 实测验证：NSVisualEffectView 默认跟随系统，tint 层颜色由用户选择，两者正交 |
| CAAnimation 的 frame 动画可能与 Auto Layout 冲突 | 使用 `layer?.position` 代替 frame 动画，或使用 `animator().frame` 走 NSAnimationContext |
| 窗口显隐动效在 `.nonactivatingPanel` 上可能表现异常 | 面板的 alphaValue 动画独立于窗口服务器，应正常工作；如异常则降级为仅 alpha 过渡 |
