## 1. 通知定义

- [x] 1.1 在 `Shared/NotificationNames.swift` 中新增 `.appAppearanceDidChange` 和 `.appTimingDidChange` 通知定义

## 2. AppSettings 方法拆分

- [x] 2.1 在 `Models/AppSettings.swift` 中新增 `postAppearanceChange()` 方法（save + 发送 `.appAppearanceDidChange`）
- [x] 2.2 在 `Models/AppSettings.swift` 中新增 `postTimingChange()` 方法（save + 发送 `.appTimingDidChange`）

## 3. 设置视图通知切换

- [x] 3.1 `Features/Settings/AppearanceView.swift` 的 `saveAppearance()` 中 `postDidChange()` → `postAppearanceChange()`
- [x] 3.2 `Features/Settings/SpeechSettingsView.swift` 的两处 `postDidChange()` → `postAppearanceChange()`
- [x] 3.3 `Features/Settings/ReciteSettingsView.swift` 的 `saveStayDuration` 和 `fullscreenAutoHide` 的 `postDidChange()` → `postTimingChange()`

## 4. ReciteEngine 热更新计时器

- [x] 4.1 在 `Services/ReciteEngine.swift` 的 `init()` 中新增 `.appTimingDidChange` 通知监听
- [x] 4.2 新增 `handleTimingChange()` 方法：仅在 `.playing` 状态下调用 `startTimer()`

## 5. FloatContentView 通知切换

- [x] 5.1 `Features/FloatingWindow/FloatContentView.swift` 监听从 `.appSettingsDidChange` → `.appAppearanceDidChange`，方法名 `handleSettingsChange` → `handleAppearanceChange`

## 6. SwiftUI onChange 防抖（额外修复）

- [x] 6.1 `ReciteSettingsView` 各 save 方法添加 guard 检查，值未变则跳过保存与通知
- [x] 6.2 `AppearanceView.saveAppearance` 比较所有 7 个字段，全等则跳过；`applyTheme` 同样 guard
- [x] 6.3 `SpeechSettingsView.saveAccent` 与 autoPlay onChange 添加 guard 检查

## 7. 验证

- [x] 7.1 全量构建通过，38+ 个测试全部通过
- [x] 7.2 人工验证：切换设置 sidebar 不触发单词重置；修改外观/发音设置不触发单词重置；修改停留时长不触发单词重置；修改背记模式/播放顺序触发单词重置
