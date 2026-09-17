## Context

引擎已有一套暂停机制：`ReciteEngine.isHoverPaused` 单标志 + `pausedRemaining` 剩余时长记账，由 `setHoverPaused(_:)` 驱动，`startTimer()` 在暂停态走"整段时长入账、不启动计时"分支。窗口控制器侧已是**多源 OR 合成**：

```
FloatWindowController                       ReciteEngine
  isHoverPaused ──┐                           isHoverPaused ← setHoverPaused(合成值)
  isPreviewPaused ┼─▶ syncEnginePauseState()   pausedRemaining ← 进入时记录 / 解除时消费
                  │  （当前：hover || preview）  startTimer() 暂停分支（重启/手动切词入账）
  【新增】isUserPaused ┘
```

发音侧另有独立通道 `setSpeechSuppressed(_:)`（全屏静音用，只挂起播报、不冻结计时）。

现有代码在暂停上已经埋下两处必须注意的事实：

1. `setHoverPaused` 开头有 `guard isHoverPaused != paused else { return }` —— **值未变即整体跳过**，且该标志是单一布尔、不记录来源。若把用户暂停塞进同一个标志（或在控制器侧三源 OR 后整体下发），"鼠标在窗内时发起用户暂停"会因 `true → true` 被吞掉：来源身份丢失，随后鼠标出窗把合并值翻回 `false`，计时器照常重启，用户暂停形同未点。
2. `showWindowWithAnimation()` 无条件 `engine.setSpeechSuppressed(false)`（[FloatWindowController.swift](file:///Users/cadany/Desktop/code/richops/HoverWord/Features/FloatingWindow/FloatWindowController.swift#L245-246)）—— 与用户暂停的"挂起发音"共用同一个标志位。

## Goals / Non-Goals

**Goals**

- 用户暂停成为第三类暂停来源，语义与悬停暂停对齐（冻结 + 剩余时长续计），但**不随鼠标位置、不随窗口隐藏而消失**
- 暂停期间挂起发音（停在播 + 屏蔽自动播报），解除后恢复
- 复用现有 `pausedRemaining` 记账与 `startTimer()` 暂停分支，不新增第二套计时状态机
- 零新增设置项、零持久化

**Non-Goals**

- 不做暂停的视觉指示（角标/透明度/文案），已与用户确认取舍
- 不做热键（`keyEquivalent`），留作后续独立增强
- 不改悬停暂停、预览暂停的既有语义与全部既有 Scenario
- 不改 `engine.stop()/start()` 的续背语义（本方案不走这条路径）

## Decisions

### D1：用户暂停落在引擎侧，作为第二个命名来源

引擎新增 `isUserPaused` 与 `setUserPaused(_:)`，把 `isHoverPaused` 更名语义化为 `isTransientPaused`（悬停/预览等瞬时来源），合并判定收敛到一个私有方法：

```swift
private var isHoverPaused = false   // 瞬时来源（悬停 / 预览），改名保持外部方法名不变
private var isUserPaused = false    // 用户主动暂停
private var isPaused: Bool { isHoverPaused || isUserPaused }

/// 合并两个来源后统一施加计时副作用
private func applyPauseState(wasPaused: Bool) {
    guard state == .playing else { return }
    if isPaused, !wasPaused {
        if let activeTimer = timer {
            pausedRemaining = max(activeTimer.fireDate.timeIntervalSinceNow, 0)
            stopTimer()
        } else if pausedRemaining == nil {
            pausedRemaining = TimeInterval(AppSettings.shared.stayDuration)
        }
    } else if !isPaused, wasPaused, let remaining = pausedRemaining {
        pausedRemaining = nil
        scheduleTimer(after: max(remaining, 0.05))
    }
}
```

关键点：**每个来源各自守自己的标志位，计时副作用只在合并值的迁移边沿施加**，不能用"合并值没变就 return"做整体守卫（见 Context 事实 1）。补充一条既有语义：停表期间 `pausedRemaining` 是**冻结值、不随墙钟衰减**，故第二源在 `true → true` 边沿上无需也无法重新入账（活动计时已不存在），只需保证合并值仍为 `true` 时不恢复调度。而"暂停期间手动切词 / 引擎重启"会让 `startTimer()` 的暂停分支把 `pausedRemaining` 刷成新词的整段时长，因此恢复分支必须无条件读取当前记录值，不能以"哪一路解除"为触发前提。

`setHoverPaused(_:)` 保持既有对外签名与语义（改内部实现走 `applyPauseState`），`setUserPaused(_:)` 同构：

| 调用 | 标志 | 立即停语音 | 挂起发音 |
|---|---|---|---|
| `setHoverPaused(true/false)` | `isHoverPaused` | 否 | 否 |
| `setUserPaused(true)` | `isUserPaused` | 是 | 是（置 `true`） |
| `setUserPaused(false)` | `isUserPaused` | 否 | 是（置 `false`，仅当静音未生效） |

控制器侧 `syncEnginePauseState()` 只负责把 hover / preview 两个瞬时源合成后送进 `setHoverPaused`，用户暂停单独走 `setUserPaused`，**不并入 OR**——避免"三源合成值 `true→true` 被守卫吞掉"这类问题重演，也让隐藏路径能精确只重置瞬时源。

### D2：暂停与静音共用挂起标志，恢复侧按静音优先

发音挂起不新增第二个标志，复用 `isSpeechSuppressed`，规则：

- 发起用户暂停：`SpeechService.shared.stopSpeaking()` + `setSpeechSuppressed(true)`
- 解除用户暂停：仅当 `AppSettings.shared.muteSpeechInFullscreen` 未生效或窗口当前可见时置 `false`
- `showWindowWithAnimation()` 的无条件 `setSpeechSuppressed(false)` **必须加保护**：`if !engine.isResumablePauseActive { ... }`（引擎暴露只读判定），否则"暂停中进全屏再退出"会静默恢复朗读，与 spec 的静音优先 Scenario 冲突

### D3：隐藏路径保持用户暂停（与悬停暂停刻意不同）

`hideWindowWithAnimation()` 继续 `isHoverPaused = false; syncEnginePauseState()`，新增的用户暂停标志**不参与重置**。由于 `applyPauseState` 只在 `playing` 态操作计时器，隐藏期间引擎仍冻结在当前词，行为即"暂停被完整挂起"。这是已确认的产品取舍（无视觉提示），spec 里以显式 Scenario 固化。

### D4：菜单与状态

`FloatMenuTag` 新增 `pauseResume = 103`；菜单构建顺序 `重新开始`（仅 `allComplete`）→ `暂停背记 / 继续背记`（非 `allComplete`）→ `打开设置` → `退出程序`，文案由控制器自身的 `isUserPaused` 决定（无需回读引擎）。`engine.restart()`（重新开始）路径上先 `setUserPaused(false)` 再重启，避免重启后首个词冻住。

### D5：命名与文案

`float.menu.pause` = 「暂停背记」/ "Pause Recitation"，`float.menu.resume` = 「继续背记」/ "Resume Recitation"。选用"暂停/继续"而非"暂停/开始"，与 `start()` 的"重新起一轮"语义划清边界。

## Risks / Trade-offs

| 风险 | 说明 | 处置 |
|---|---|---|
| **边沿判定回归** | 合并守卫改成迁移边沿后，悬停暂停既有路径（含 85 条既有用例）行为需回归 | `ReciteEngineHoverPauseTests` 全量保留，另加"hover 先真、user 后真"的组合用例 |
| **静音与暂停互相覆盖** | 共用 `isSpeechSuppressed` 是耦合点，D2 的保护若漏改 `showWindowWithAnimation` 即出现"退出全屏后暂停中却朗读" | 列为实现必查项 + 一条专门用例覆盖"暂停 × 全屏隐藏再恢复" |
| **解除后悬空** | 若 `pausedRemaining` 缺失且无活动计时，恢复分支不启动计时 → 永久停住 | 恢复分支保留 `?? stayDuration` 兜底；引擎重启路径由 `startTimer()` 入账保证有值 |
| **用户以为窗口卡死** | 无视觉提示是已确认取舍；隐藏期间无法右键更是双重盲区 | 仅在 spec 显式记录；若后续投诉，视觉提示与热键作为独立 change 追加 |
| **记忆反馈模式下暂停中推进进度** | 暂停中 `✓/✗` 仍可切词并保存进度，属既有暂停行为 | 保持与悬停暂停一致，不特判 |
