Change-Sub-Version: v0-1-feat01

## Purpose

定义悬浮窗内容（注音、释义）的显示模式配置能力，支持三态控制（always/hover/hidden），允许用户独立配置注音和释义的显示行为。

## ADDED Requirements

### Requirement: ContentVisibility 枚举定义
系统提供 `ContentVisibility` 枚举，包含三种显示模式：
- `always`：始终显示
- `hover`：鼠标悬停时显示
- `hidden`：始终隐藏

#### Scenario: 枚举值 Codable 序列化
- **WHEN** ContentVisibility 值被编码为 JSON
- **THEN** 输出为对应的 rawValue 字符串（"always" / "hover" / "hidden"）

#### Scenario: 枚举值 CaseIterable 遍历
- **WHEN** 遍历 ContentVisibility.allCases
- **THEN** 返回 [.always, .hover, .hidden] 三种状态

### Requirement: 注音显示模式配置
用户可在设置中配置注音的显示模式（ContentVisibility）。

#### Scenario: 默认显示模式
- **WHEN** 首次启动应用（无历史配置）
- **THEN** 注音显示模式默认为 `.always`

#### Scenario: 注音 always 模式
- **WHEN** 注音显示模式设置为 `.always`
- **THEN** 注音始终可见，不受鼠标状态影响

#### Scenario: 注音 hover 模式 - 鼠标进入
- **WHEN** 注音显示模式设置为 `.hover`
- **AND** 鼠标进入悬浮窗区域
- **THEN** 注音以淡入动画显示（alpha 从 0 到 1）

#### Scenario: 注音 hover 模式 - 鼠标离开
- **WHEN** 注音显示模式设置为 `.hover`
- **AND** 鼠标离开悬浮窗区域
- **THEN** 注音以淡出动画隐藏（alpha 从 1 到 0）

#### Scenario: 注音 hidden 模式
- **WHEN** 注音显示模式设置为 `.hidden`
- **THEN** 注音始终不可见（alpha = 0），不受鼠标状态影响

#### Scenario: 注音为 nil 时的行为
- **WHEN** 当前单词无注音数据（phonetic == nil）
- **THEN** 无论显示模式如何，注音区域保持透明（占位空间保留）

### Requirement: 释义显示模式配置
用户可在设置中配置释义的显示模式（ContentVisibility）。

#### Scenario: 默认显示模式
- **WHEN** 首次启动应用（无历史配置）
- **THEN** 释义显示模式默认为 `.always`

#### Scenario: 释义 always 模式
- **WHEN** 释义显示模式设置为 `.always`
- **THEN** 释义始终可见，不受鼠标状态影响

#### Scenario: 释义 hover 模式 - 鼠标进入
- **WHEN** 释义显示模式设置为 `.hover`
- **AND** 鼠标进入悬浮窗区域
- **THEN** 释义以淡入动画显示（alpha 从 0 到 1）

#### Scenario: 释义 hover 模式 - 鼠标离开
- **WHEN** 释义显示模式设置为 `.hover`
- **AND** 鼠标离开悬浮窗区域
- **THEN** 释义以淡出动画隐藏（alpha 从 1 到 0）

#### Scenario: 释义 hidden 模式
- **WHEN** 释义显示模式设置为 `.hidden`
- **THEN** 释义始终不可见（alpha = 0），不受鼠标状态影响

### Requirement: 显示模式持久化
显示模式配置保存到 UserDefaults，应用重启后恢复。

#### Scenario: 保存显示模式
- **WHEN** 用户在设置中修改注音/释义显示模式
- **THEN** 新值立即持久化到 UserDefaults

#### Scenario: 恢复显示模式
- **WHEN** 应用启动时加载配置
- **THEN** 从 UserDefaults 恢复之前保存的显示模式

#### Scenario: 旧版本迁移
- **WHEN** 从 v0.1 升级（StoredSettings 无 visibility 字段）
- **THEN** 默认使用 `.always`，保持原有行为

### Requirement: 布局稳定性
显示模式切换时保持窗口布局稳定，不产生尺寸跳动。

#### Scenario: hover 模式布局
- **WHEN** 注音/释义设置为 `.hover` 模式
- **AND** 鼠标进入/离开触发显隐变化
- **THEN** 窗口尺寸保持不变（通过 alphaValue 控制可见性，保留占位空间）
