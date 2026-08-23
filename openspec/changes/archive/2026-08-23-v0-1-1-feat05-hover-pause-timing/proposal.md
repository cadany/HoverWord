---
baseline_version: "v0-1-1"
change_sub_version: "v0-1-1-feat05"
---

## Why

悬浮窗切词由固定时长 Timer 驱动，用户正盯着某个单词看（鼠标悬停在悬浮窗内）时会被强制切到下一词，打断阅读。鼠标在悬浮窗内时应暂停计时、离开后从剩余时长继续，让"看"的节奏由用户控制。

## What Changes

1. **引擎暂停/恢复接口**：`ReciteEngine.setHoverPaused(_:)`——暂停时记录剩余时长并停表，恢复时按剩余时长重新调度
2. **两模式均生效**：记忆反馈与走马灯共用同一 Timer 驱动，暂停对两模式一致生效（超时判定/轮次推进均冻结）
3. **无设置开关**：默认常开，不新增配置项（用户确认）
4. **悬浮窗接线**：`FloatContentView` 既有 mouseEntered/Exited（驱动按钮浮现的 tracking area）扩展通知控制器，控制器转发引擎
5. **隐藏路径强制恢复**：窗口 orderOut/全屏自动隐藏时 mouseExited 不保证触发，需在隐藏路径上重置悬停状态并恢复计时，防止背记永久卡住
6. **暂停中交互**：暂停期间点"认识/不认识"切词，新词保持暂停态（记录整段时长不启动计时）；stayDuration 热更新在暂停态仅更新记录值

## Capabilities

### Modified Capabilities

- `recite-engine`: 新增"悬停暂停计时"Requirement（暂停/恢复语义、边界行为）
- `floating-window`: 鼠标进出事件新增引擎暂停通知职责

## Impact

### 影响文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Services/ReciteEngine.swift` | 修改 | `isHoverPaused`/`pausedRemaining` 状态、`setHoverPaused`、`startTimer` 尊重暂停态、`handleTimingChange` 兼容 |
| `Features/FloatingWindow/FloatContentView.swift` | 修改 | mouseEntered/Exited 增加 `onHoverStateChanged` 回调 |
| `Features/FloatingWindow/FloatWindowController.swift` | 修改 | 回调转发引擎；窗口隐藏路径强制 `setHoverPaused(false)` |
| `HoverWordTests/Services/ReciteEngineHoverPauseTests.swift` | 新增 | 暂停/恢复、暂停中切词、计时热更新测试 |

### 行为细节（探索阶段已确认）

- 恢复从**剩余时长**继续（非整段重计）
- 拖拽悬浮窗（按住 = 在窗内）持续暂停，属合理行为不特判
- 引擎重启（设置/词本变更）期间若鼠标在窗内，重启后首个词保持暂停
- App 退出保存进度不受影响（进度不涉及 Timer）

### 测试覆盖

- 暂停后 Timer 停止、恢复后按剩余时长调度
- 暂停中 markKnown 切词：新词不启动计时
- stayDuration 热更新在暂停态不启动计时
- 全量回归（既有 85 用例）
