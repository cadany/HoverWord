Change-Sub-Version: mvp-v0-1-feat05

## Purpose

本次变更在悬浮窗的交互层做两处打磨：新增手动播报按钮让用户可以重复听当前单词发音；将"认识 / 不认识"文字按钮替换为图标按钮，与收藏 ♡/♥ 保持视觉语言一致。

## ADDED Requirements

### Requirement: 悬浮窗手动播报按钮

悬浮窗 SHALL 在鼠标 hover 状态下展示一个播报按钮（Unicode `▶` U+25B6），点击后重新播放当前单词的发音。该按钮在**记忆反馈模式**与**走马灯模式**下均显示。当悬浮窗处于"已学完"状态时，不显示任何操作按钮（包括播报）。

#### Scenario: 记忆反馈模式下点击播报
- **WHEN** 悬浮窗处于记忆反馈模式，鼠标 hover，当前单词为 "apple"
- **THEN** 窗口底部 SHALL 显示按钮序列 `[ ♡ ] [ ▶ ] [ ✓ ] [ ✗ ]`；点击 `▶` SHALL 调用 `SpeechService.speak("apple", language: currentWordbook.sourceLang)` 重新播放发音

#### Scenario: 走马灯模式下点击播报
- **WHEN** 悬浮窗处于走马灯模式，鼠标 hover
- **THEN** 窗口底部 SHALL 显示按钮序列 `[ ♡ ] [ ▶ ]`；点击 `▶` SHALL 重新播放当前单词发音

#### Scenario: 发音进行中再次点击播报
- **WHEN** 当前单词正在发音，用户再次点击 `▶`
- **THEN** 系统 SHALL 停止当前发音并从头重新播放（复用 `SpeechService.speak` 的 `stopSpeaking → speak` 语义）

#### Scenario: 已学完状态
- **WHEN** 悬浮窗显示"已学完"，鼠标 hover
- **THEN** SHALL 不显示任何操作按钮，包括 `▶`

### Requirement: 播报按钮视觉反馈

点击 `▶` 按钮 SHALL 触发一次性脉冲动画：`opacity 1.0 → 0.5 → 1.0` 配合 `scale 1.0 → 0.92 → 1.0`，总时长 0.15s，ease-out 缓动。该动画复用现有按钮点击动效样式，与其他按钮（♡ / ✓ / ✗）手感一致。

#### Scenario: 点击播报触发脉冲
- **WHEN** 用户点击 `▶` 按钮
- **THEN** 按钮 SHALL 在 0.15s 内完成一次 opacity + scale 脉冲，动画结束后恢复常态

#### Scenario: 非持续播放态指示
- **WHEN** 发音正在播放
- **THEN** 按钮 SHALL 不显示"正在播放"的持续视觉指示（不引入实时状态同步），仅在点击瞬间反馈

## MODIFIED Requirements

### Requirement: 反馈模式按钮改为图标（替代 v0.1 文字按钮）

悬浮窗在记忆反馈模式下，原本显示文字按钮"认识" / "不认识"，v0.1.1 SHALL 改为 Unicode 图标 `✓`（U+2713）/ `✗`（U+2717）。图标 SHALL 与 ♡ / ♥ / ▶ 采用相同的视觉风格：单色 Unicode 字符、相同字号、相同按钮尺寸与背景 alpha、相同的 hover / press 动效。

#### Scenario: 反馈模式按钮显示
- **WHEN** 悬浮窗处于记忆反馈模式，鼠标 hover
- **THEN** 窗口底部 SHALL 显示按钮序列 `[ ♡ ] [ ▶ ] [ ✓ ] [ ✗ ]`，所有按钮均为 Unicode 字符图标风格

#### Scenario: 图标按钮 toolTip
- **WHEN** 鼠标悬停在 `✓` 按钮上 1-2 秒
- **THEN** macOS 系统 SHALL 显示 toolTip 文本 "认识"
- **WHEN** 鼠标悬停在 `✗` 按钮上 1-2 秒
- **THEN** macOS 系统 SHALL 显示 toolTip 文本 "不认识"

#### Scenario: 点击语义保持不变
- **WHEN** 用户点击 `✓`
- **THEN** SHALL 触发与 v0.1 "认识"按钮完全相同的逻辑（标记已知，切换下一单词）
- **WHEN** 用户点击 `✗`
- **THEN** SHALL 触发与 v0.1 "不认识"按钮完全相同的逻辑（标记未知，切换下一单词）

### Requirement: 走马灯模式按钮序列扩展

走马灯模式下，v0.1 仅显示 `[ ♡ ]`，v0.1.1 SHALL 扩展为 `[ ♡ ] [ ▶ ]`，新增的 `▶` 按钮行为与记忆反馈模式一致。

#### Scenario: 走马灯模式 hover 态
- **WHEN** 悬浮窗处于走马灯模式，鼠标 hover
- **THEN** SHALL 显示 `[ ♡ ] [ ▶ ]` 两个图标按钮
