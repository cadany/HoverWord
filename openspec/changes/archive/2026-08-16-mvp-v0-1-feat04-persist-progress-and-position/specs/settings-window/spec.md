Change-Sub-Version: mvp-v0-1-feat04

## ADDED Requirements

### Requirement: 单词本预览
单词本管理 Tab SHALL 提供"预览"按钮，点击后弹出 Sheet 展示选中单词本内的词条列表。每条词条显示单词、音标、词性 + 释义。支持内联编辑（点击字段直接修改）和按钮删除（每行一个删除按钮）。列表分页展示，每页 100 条。

#### Scenario: 打开预览
- **WHEN** 用户选中某单词本并点击"预览"按钮
- **THEN** 系统 SHALL 弹出 Sheet，展示该单词本内所有词条的分页列表

#### Scenario: 词条列表展示
- **WHEN** 预览 Sheet 打开
- **THEN** 系统 SHALL 以表格形式展示每条词条的单词、音标、词性 + 释义，每页最多 100 条，底部提供分页控件

#### Scenario: 内联编辑词条
- **WHEN** 用户在预览列表中点击某词条的单词 / 音标 / 词性 / 释义字段
- **THEN** 该字段 SHALL 变为可编辑状态，用户修改后按回车或失焦时自动保存

#### Scenario: 删除词条
- **WHEN** 用户点击某词条行的删除按钮
- **THEN** 系统 SHALL 删除该词条并刷新列表，若删除后列表为空则显示空状态提示

#### Scenario: 空单词本预览
- **WHEN** 用户对无词条的单词本点击"预览"
- **THEN** 预览 Sheet SHALL 显示"该单词本暂无词条"的空状态提示

#### Scenario: 分页导航
- **WHEN** 单词本包含超过 100 条词条
- **THEN** 预览 Sheet SHALL 显示分页控件，用户可翻页浏览所有词条
