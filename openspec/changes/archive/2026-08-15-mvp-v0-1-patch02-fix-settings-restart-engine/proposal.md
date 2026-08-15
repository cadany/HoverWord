---
baseline_version: "mvp-v0-1"
change_sub_version: "mvp-v0-1-patch02"
---

## Why

当前所有设置变更（外观、发音、计时参数、背记规则）都发送同一个 `.appSettingsDidChange` 通知，`ReciteEngine` 收到后无条件重启引擎（重建队列、重置进度、回到第一个单词）。导致用户在设置窗口切换 sidebar、调整字体大小/透明度、切换发音类型时，悬浮窗的单词被重置，体验极不合理。

## What Changes

将单一的 `.appSettingsDidChange` 通知拆分为三个独立通知，各自只触发必要的响应：

| 通知 | 触发方 | 监听方 | 响应 |
|------|--------|--------|------|
| `.appSettingsDidChange` | ReciteSettingsView（背记模式/播放顺序/Section大小/走马灯轮次） | ReciteEngine | 重启引擎（重建队列） |
| `.appAppearanceDidChange` | AppearanceView、SpeechSettingsView | FloatContentView | 刷新外观样式 |
| `.appTimingDidChange` | ReciteSettingsView（停留时长/全屏自动隐藏） | ReciteEngine | 热更新计时器（不重置进度） |

## Capabilities

### New Capabilities

无

### Modified Capabilities

- **settings-window**：设置视图按设置类型发送不同通知
- **floating-window**：悬浮窗内容视图监听外观通知而非全局设置通知
- **recite-engine**：引擎区分结构设置变化（重启）与计时参数变化（热更新）

## Impact

- `Shared/NotificationNames.swift` — 新增 2 个通知定义
- `Models/AppSettings.swift` — 新增 `postAppearanceChange()`、`postTimingChange()` 方法
- `Features/Settings/AppearanceView.swift` — 改用 `postAppearanceChange()`
- `Features/Settings/SpeechSettingsView.swift` — 改用 `postAppearanceChange()`
- `Features/Settings/ReciteSettingsView.swift` — `stayDuration`/`fullscreenAutoHide` 改用 `postTimingChange()`
- `Services/ReciteEngine.swift` — 新增 `.appTimingDidChange` 监听，热更新计时器
- `Features/FloatingWindow/FloatContentView.swift` — 监听从 `.appSettingsDidChange` → `.appAppearanceDidChange`
