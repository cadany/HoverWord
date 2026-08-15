## Context

当前 `ReciteEngine.handleSettingsChange()` 监听 `.appSettingsDidChange` 并无条件调用 `stopTimer(); start()`，重建队列并重置进度。所有设置视图（外观、发音、背记规则）都调用 `AppSettings.postDidChange()` 发送同一个通知，导致任何设置变更都会重启引擎。

## Goals / Non-Goals

**Goals:**
- 外观/发音设置变更不重启引擎，只刷新悬浮窗外观
- 计时参数（停留时长）变更只热更新计时器，不重置进度
- 背记规则（模式/顺序/Section/轮次）变更仍重启引擎

**Non-Goals:**
- 不改变各设置视图的 UI 交互逻辑
- 不改变 `ReciteEngine` 的队列构建和单词调度算法

## Decisions

### D1: 通知拆分策略
**决定**：新增 `.appAppearanceDidChange` 和 `.appTimingDidChange` 两个通知，保留 `.appSettingsDidChange` 仅用于背记规则。
**理由**：三个通知职责清晰，各监听方只需关注自己关心的通知类型。

### D2: AppSettings 方法拆分
**决定**：在 `AppSettings` 中新增 `postAppearanceChange()` 和 `postTimingChange()` 方法，各自保存并发送对应通知。
**理由**：与现有 `postDidChange()` 保持一致的 API 风格，设置视图只需切换调用方法。

### D3: ReciteEngine 热更新计时器
**决定**：新增 `handleTimingChange()` 方法，仅在 `.playing` 状态下调用 `startTimer()` 重启计时器，不调用 `start()` 重建队列。
**理由**：`startTimer()` 内部已调用 `stopTimer()`，会重新计算计时器间隔。无需重建队列或重置进度。

### D4: FloatContentView 通知切换
**决定**：将监听从 `.appSettingsDidChange` 改为 `.appAppearanceDidChange`，方法名从 `handleSettingsChange` 改为 `handleAppearanceChange`。
**理由**：悬浮窗外观只应响应外观设置变更，不应响应背记规则变更（背记规则变更由引擎通过 delegate 推进单词）。

### D5: SwiftUI onChange 防抖
**决定**：在各设置视图的保存方法中使用 guard 检查值是否真正改变，未改变则提前返回不发通知。具体实现：
- `ReciteSettingsView` 的各 save 方法（saveReciteMode/savePlayOrder 等）：`guard AppSettings.shared.xxx != newValue else { return }`
- `AppearanceView.saveAppearance()`：比较所有 7 个外观字段，全部相等则跳过保存和通知
- `AppearanceView.applyTheme()`：比较新旧背景色/文字颜色，相同则跳过
- `SpeechSettingsView.saveAccent()`：比较 useAmericanAccent 是否变化
- `SpeechSettingsView` 的 autoPlay onChange：内联 guard 检查
**理由**：相比 `isLoaded` 标志方案，guard 检查更精确——直接判断"值是否真的变了"，而不依赖"视图是否加载完毕"的间接推断。SwiftUI 在 sidebar 切换时重新创建 detail view，`onAppear` 中加载设置到 `@State` 会触发 `.onChange`，但此时 @State 值与 AppSettings 中已存储的值相同，guard 自然拦截。该方案无需额外状态变量，代码更简洁、语义更清晰。

## Risks / Trade-offs

| 风险 | 缓解 |
|---|---|
| 未来新增设置类型时可能遗漏通知分类 | 在 `NotificationNames.swift` 中已明确文档化各通知的触发方和监听方 |
| `stayDuration` 热更新时当前单词已展示超过新时长的边界情况 | `startTimer()` 直接使用新值重新计时，当前单词立即开始新倒计时，行为可预期 |
