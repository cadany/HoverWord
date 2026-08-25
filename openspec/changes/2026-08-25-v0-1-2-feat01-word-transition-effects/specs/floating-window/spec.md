Change-Sub-Version: v0-1-2-feat01

## Purpose

（本文件仅记录对 floating-window 的修改，完整 spec 见主 specs 目录）

## MODIFIED Requirements

### Requirement: 单词内容展示
悬浮窗内内容 SHALL 采用横向四列布局：第 1 列展示单词（加粗左对齐，垂直居中），第 2 列展示音标（小号，无则隐藏），第 3 列展示词性 + 释义（常规字号左对齐，可换行，无截断上限），第 4 列展示操作按钮（横排，右对齐）。单词切换时 SHALL 调用动效系统执行用户选择的过渡动效。

#### Scenario: 完整词条展示
- **WHEN** 当前词条包含单词、音标和 3 组释义
- **THEN** 系统 SHALL 在第 1 列显示单词（加粗），第 2 列显示音标，第 3 列显示 3 组词性 + 释义

#### Scenario: 切换单词调用动效系统
- **WHEN** 从单词 A 切换至单词 B
- **THEN** 系统 SHALL 从 `TransitionRegistry` 获取用户选择的动效实例，调用其 `animate(from:to:in:completion:)` 方法执行过渡，而非使用硬编码的淡入淡出动画

#### Scenario: 动效执行失败回退
- **WHEN** 动效执行过程中发生错误
- **THEN** 系统 SHALL 立即完成切换，显示新单词，不阻塞背记流程
