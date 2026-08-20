Change-Sub-Version: v0-1-feat01

## Purpose

定义悬浮窗内容显示的交互变更：注音颜色改善、注音字号可配置、鼠标悬停时注音/释义显隐控制。

## MODIFIED Requirements

### Requirement: 注音颜色对比度提升
注音文字颜色 alpha 值从 0.65 提升至 0.85，增强可读性。

#### Scenario: 浅色模式下注音颜色
- **WHEN** 系统处于浅色模式
- **AND** 用户设置文字颜色为黑色（#000000）
- **THEN** 注音文字颜色为 `black.withAlphaComponent(0.85)`

#### Scenario: 深色模式下注音颜色
- **WHEN** 系统处于深色模式
- **AND** 用户设置文字颜色为白色（#FFFFFF）
- **THEN** 注音文字颜色为 `white.withAlphaComponent(0.85)`

#### Scenario: 自定义文字颜色下的注音颜色
- **WHEN** 用户设置自定义文字颜色（如红色 #FF0000）
- **THEN** 注音文字颜色为该颜色的 0.85 alpha 变体

### Requirement: 注音字号可配置
用户可在设置中配置注音字号，范围 8-14pt，默认 10pt。

#### Scenario: 默认注音字号
- **WHEN** 首次启动应用（无历史配置）
- **THEN** 注音字号默认为 10pt

#### Scenario: 修改注音字号
- **WHEN** 用户在设置中修改注音字号为 12pt
- **THEN** 悬浮窗注音立即以新字号渲染

#### Scenario: 注音字号范围限制
- **WHEN** 用户尝试设置注音字号
- **THEN** 可选范围为 8pt 到 14pt，步进 1pt

#### Scenario: 注音字号持久化
- **WHEN** 用户修改注音字号
- **THEN** 新值保存到 UserDefaults，应用重启后恢复

### Requirement: 鼠标悬停触发内容显隐
悬浮窗鼠标追踪区域扩展，支持注音/释义的 hover 模式显隐控制。

#### Scenario: 鼠标进入触发 hover 内容显示
- **WHEN** 鼠标进入悬浮窗区域
- **AND** 注音或释义的显示模式为 `.hover`
- **THEN** 对应的隐藏内容以淡入动画显示

#### Scenario: 鼠标离开触发 hover 内容隐藏
- **WHEN** 鼠标离开悬浮窗区域
- **AND** 注音或释义的显示模式为 `.hover`
- **THEN** 对应的内容以淡出动画隐藏

#### Scenario: 显示模式切换时立即生效
- **WHEN** 用户在设置中修改显示模式
- **THEN** 悬浮窗立即应用新的显示规则（若当前鼠标在窗口内，hover 内容显示；否则隐藏）

### Requirement: 外观设置变更响应
悬浮窗监听外观设置变更通知，应用新的注音字号、显示模式。

#### Scenario: 收到外观变更通知
- **WHEN** 收到 `.appAppearanceDidChange` 通知
- **THEN** 重新应用注音字号和显示模式配置

#### Scenario: 带过渡动效的设置应用
- **WHEN** 收到外观变更通知
- **THEN** 使用 `NSAnimationContext` 过渡动效（0.2s ease-out）应用新配置
