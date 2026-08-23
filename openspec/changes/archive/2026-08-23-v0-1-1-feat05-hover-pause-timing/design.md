# Design: 悬浮窗鼠标悬停暂停计时

## Context

探索结论（2026-08-23，方案 A）：pause/resume + 剩余时间。用户确认：不加开关（常开）、两模式均暂停。悬浮窗已有 `.mouseEnteredAndExited + .activeAlways` tracking area（驱动按钮浮现），事件源现成。

## Goals / Non-Goals

- Goals: 悬停暂停/离开恢复（剩余时长续计）、隐藏路径防卡死、暂停态切词保持暂停
- Non-Goals: 不加设置开关、不做"暂停中"视觉指示（极简；后续可迭代）、不改 Timer 架构

## Decisions

### D1: 引擎状态与接口

```swift
private var isHoverPaused = false          // 悬停暂停标志（跨切词保持）
private var pausedRemaining: TimeInterval? // 暂停时的剩余时长

func setHoverPaused(_ paused: Bool)
```

- **暂停**：`isHoverPaused = true`；若 Timer 活动中 → `pausedRemaining = fireDate.timeIntervalSinceNow` 并停表；若已无 Timer（暂停中切过词）→ 保持既有 remaining
- **恢复**：清 remaining 并按其值重新调度（下限 0.05s，避免极小值立即触发）
- 仅 `state == .playing` 时操作 Timer；标志本身无条件记录（引擎可能随时被 start/restart）

### D2: startTimer 尊重暂停态（关键边界）

`displayCurrentWord → startTimer` 是所有切词路径的汇点（timer 超时、认识/不认识、新 Section、重启恢复）。`startTimer` 开头检查 `isHoverPaused`：暂停 → 不调度、`pausedRemaining = 整段 stayDuration`；正常 → 照旧调度。这一处检查同时覆盖"暂停中手动切词"与"重启后鼠标仍在窗内"两个边界。

### D3: 通知链路

`FloatContentView`（既有 mouseEntered/Exited）→ 新增 `onHoverStateChanged: ((Bool) -> Void)?` 回调 → `FloatWindowController` 转发 `reciteEngine.setHoverPaused(_:)`。与既有 `onRightClick` 回调模式一致，不引新通知。

### D4: 隐藏路径强制恢复（防卡死）

窗口 orderOut 时 AppKit 不保证补发 mouseExited，`isMouseInside` 可能残留 true → 计时永久暂停。处理：`FloatWindowController` 的窗口隐藏路径（全屏自动隐藏、显隐切换）统一调用：
- `floatContentView.resetHoverState()`（isMouseInside = false，按钮/显隐模式 UI 归位）
- `reciteEngine.setHoverPaused(false)`

### D5: handleTimingChange 兼容

暂停态收到 `appTimingDidChange`（stayDuration 变更）：现有逻辑调 `startTimer()`，经 D2 自动走"暂停分支"更新 remaining 为新整段时长——无需额外代码，行为正确（新词按新时长计时）。

### D6: 进度持久化不变

暂停状态不持久化（App 重启后鼠标位置重新感知）；`saveProgress`/`restoreProgress` 不涉及 Timer。

## Risks / Trade-offs

- Timer.fireDate 精度为 runloop 毫秒级，剩余时长误差可忽略
- 极端时序：mouseExited 与 timerFired 同周期竞争——runloop 串行执行，无并发问题；若 timer 先触发切词，随后的 resume 按"新词整段"计时（经 startTimer 暂停分支已记录），语义正确

## Migration Plan

无数据/设置迁移。

## Open Questions

无。
