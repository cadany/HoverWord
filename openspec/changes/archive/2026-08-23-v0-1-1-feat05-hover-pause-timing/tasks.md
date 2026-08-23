## 1. 引擎层

- [x] 1.1 `ReciteEngine` 暂停状态与接口
  - 新增 `isHoverPaused: Bool`、`pausedRemaining: TimeInterval?` 私有状态
  - `setHoverPaused(_:)`：暂停时从 `timer.fireDate` 记录剩余并停表；恢复按剩余重调度（下限 0.05s）
  - `startTimer()` 开头检查暂停态：暂停 → 不调度、记录整段时长（覆盖暂停中切词/重启路径）

## 2. 悬浮窗接线

- [x] 2.1 `FloatContentView` 悬停回调
  - 新增 `onHoverStateChanged: ((Bool) -> Void)?`，mouseEntered/Exited 中调用
  - 新增 `resetHoverState()`（isMouseInside = false + UI 归位），供窗口隐藏路径调用
- [x] 2.2 `FloatWindowController` 转发与隐藏重置
  - 悬停回调 → `reciteEngine.setHoverPaused(_:)`
  - 窗口隐藏路径（全屏自动隐藏/显隐切换）调用 `resetHoverState()` + `setHoverPaused(false)`

## 3. 测试与验证

- [x] 3.1 新建 `HoverWordTests/Services/ReciteEngineHoverPauseTests.swift`
  - 暂停后计时器停止、恢复按剩余时长调度
  - 暂停中 markKnown 切词：新词计时器不启动
  - 暂停中 stayDuration 热更新不启动计时器
  - 非播放态 setHoverPaused 无计时器副作用
- [x] 3.2 构建 + 全量测试无回归
- [x] 3.3 手动验证（用户 2026-08-23 确认通过）：悬停悬浮窗单词不切换、离开后 ~剩余时长切换；记忆反馈/走马灯两模式；全屏自动隐藏不卡死；暂停中点认识切下一词仍保持暂停
