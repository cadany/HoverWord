Change-Sub-Version: v0-1-feat01

## Purpose

定义外观设置 UI 重构：将原卡片重新组织为 4 个区域（悬浮窗口、单词、注音、释义），新增注音字号和显示模式配置控件。

## MODIFIED Requirements

### Requirement: 外观设置卡片重组
外观设置页面由 4 个独立卡片组成，每个卡片管理一组相关配置。

#### Scenario: 卡片顺序
- **WHEN** 用户打开外观设置页面
- **THEN** 卡片按以下顺序显示：
  1. 悬浮窗口（背景色、文字颜色、透明度）
  2. 单词（字体、字号）
  3. 注音（字号、显示模式）
  4. 释义（字体、字号、显示模式）

#### Scenario: 卡片样式
- **WHEN** 渲染外观设置卡片
- **THEN** 使用 `.glassCard()` 修饰器，遵循 Liquid Glass 设计规范

### Requirement: 悬浮窗口卡片
管理悬浮窗背景与文字外观配置。

#### Scenario: 背景色配置
- **WHEN** 用户修改背景色
- **THEN** 悬浮窗背景色立即更新

#### Scenario: 文字颜色配置
- **WHEN** 用户修改文字颜色
- **THEN** 悬浮窗所有文字颜色立即更新（包括注音）

#### Scenario: 透明度配置
- **WHEN** 用户修改背景透明度
- **THEN** 悬浮窗背景透明度立即更新

### Requirement: 单词卡片
管理单词字体与字号配置。

#### Scenario: 单词字体选择
- **WHEN** 用户选择单词字体
- **THEN** 悬浮窗单词以新字体渲染

#### Scenario: 单词字号调整
- **WHEN** 用户调整单词字号（16-48pt）
- **THEN** 悬浮窗单词以新字号渲染

### Requirement: 注音卡片
管理注音字号与显示模式配置。

#### Scenario: 注音字号调整
- **WHEN** 用户调整注音字号（8-14pt）
- **THEN** 悬浮窗注音以新字号渲染

#### Scenario: 注音显示模式切换
- **WHEN** 用户切换注音显示模式（Segmented Control）
- **THEN** 悬浮窗立即应用新的显示规则

#### Scenario: 显示模式 Segmented Control
- **WHEN** 渲染注音显示模式控件
- **THEN** 使用 Segmented Control，选项为：总是显示 / 悬停显示 / 隐藏

### Requirement: 释义卡片
管理释义字体、字号与显示模式配置。

#### Scenario: 释义字体选择
- **WHEN** 用户选择释义字体
- **THEN** 悬浮窗释义以新字体渲染

#### Scenario: 释义字号调整
- **WHEN** 用户调整释义字号（10-24pt）
- **THEN** 悬浮窗释义以新字号渲染

#### Scenario: 释义显示模式切换
- **WHEN** 用户切换释义显示模式（Segmented Control）
- **THEN** 悬浮窗立即应用新的显示规则

#### Scenario: 显示模式 Segmented Control
- **WHEN** 渲染释义显示模式控件
- **THEN** 使用 Segmented Control，选项为：总是显示 / 悬停显示 / 隐藏

### Requirement: 设置保存与通知
配置变更保存到 AppSettings 并发送外观变更通知。

#### Scenario: 保存注音配置
- **WHEN** 用户修改注音字号或显示模式
- **THEN** 调用 `AppSettings.shared.postAppearanceChange()`

#### Scenario: 保存释义配置
- **WHEN** 用户修改释义字体、字号或显示模式
- **THEN** 调用 `AppSettings.shared.postAppearanceChange()`

#### Scenario: 避免冗余保存
- **WHEN** 配置值未发生变化（如 sidebar 切换触发 onAppear）
- **THEN** 跳过保存与通知
