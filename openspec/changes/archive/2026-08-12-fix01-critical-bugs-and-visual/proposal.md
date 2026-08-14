## Why

mvp-v0-1 集成验证阶段（Task 10）发现 2 个关键 Bug 和 10 项视觉/动效缺失。关键 Bug 影响核心背记功能正确性：首个单词被跳过导致用户漏词，"不认识"按钮无效导致记忆反馈模式退化为走马灯。视觉缺失中，深色模式完全失效（硬编码 `.aqua`）影响一半用户场景，其余 9 项动效缺失使交互体验与 UI spec 不符。

## What Changes

- 修复 ReciteEngine 首词跳过 Bug：`start()` / `advanceToNextSection()` / `advanceCarousel()` 中 `currentWordIndex=0` 后不应立即 `advanceToNextWord()` 递增索引
- 修复 markUnknown() 行为：标记"不认识"的单词不应加入 `feedbackSet`，使其在下一轮重试
- 修复深色模式：移除 `GlassBackgroundView` 硬编码的 `appearance = .aqua`，使系统外观自动适配生效
- 修复 FloatContentView 深色模式颜色：文字和按钮颜色根据 `effectiveAppearance` 动态切换浅色/深色值
- 补充单词切换 1px 垂直位移动效
- 补充按钮悬停底部滑入动效
- 补充按钮点击态动效（亮度降低 + 微缩，0.1s）
- 实现窗口显示/隐藏动效（淡入淡出 + 轻微缩放，0.2s）
- 实现完成状态切换过渡动效
- 实现设置应用过渡动效（0.2s）

## Capabilities

### New Capabilities

（无新增能力）

### Modified Capabilities

- `recite-engine`: 修复首词跳过 Bug、修复 markUnknown 无重试效果 Bug
- `floating-window`: 修复深色模式失效、补充单词切换/按钮/窗口/完成状态所有缺失动效
- `appearance`: FloatContentView 文字/按钮颜色深色模式适配

## Impact

- **代码**：修改 `ReciteEngine.swift`、`GlassBackgroundView.swift`、`FloatContentView.swift`、`FloatWindowController.swift`，共 4 个文件
- **API**：无变化
- **依赖**：无新增
- **系统**：无变化（仍支持 macOS 12.0+）
- **性能**：动效新增均为 CAAnimation，对性能无显著影响
- **测试**：需更新 ReciteEngine 单元测试覆盖 markKnown/markUnknown 差异化行为
