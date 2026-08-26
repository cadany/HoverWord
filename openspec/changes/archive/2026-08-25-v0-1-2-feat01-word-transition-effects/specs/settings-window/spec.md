Change-Sub-Version: v0-1-2-feat01

## Purpose

（本文件仅记录对 settings-window 的修改，完整 spec 见主 specs 目录）

## MODIFIED Requirements

### Requirement: 设置窗口 Tab 结构
设置窗口 SHALL 包含以下 Tab：单词本、背记规则、外观、发音、体验。体验 Tab 承载单词切换动效设置，为未来其他体验类设置预留空间。

#### Scenario: 默认 Tab 列表
- **WHEN** 用户打开设置窗口
- **THEN** Sidebar SHALL 显示 5 个 Tab：单词本、背记规则、外观、发音、体验

#### Scenario: 体验 Tab 内容
- **WHEN** 用户选择"体验" Tab
- **THEN** 内容区 SHALL 显示体验设置视图 `ExperienceSettingsView`，包含动效选择与参数配置

#### Scenario: 体验 Tab 图标
- **WHEN** 渲染体验 Tab 的 Sidebar 项
- **THEN** SHALL 使用 SF Symbols 的 "wand.and.stars" 图标（或语义相近的图标）
