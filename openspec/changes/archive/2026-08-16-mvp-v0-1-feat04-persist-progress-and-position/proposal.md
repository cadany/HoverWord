---
baseline_version: "mvp-v0-1"
change_sub_version: "mvp-v0-1-feat04"
---

## Why

当前版本存在两个体验问题：
1. **悬浮窗位置恢复不完整**：窗口拖拽移动后位置不被保存，重启后恢复到旧位置（只监听了 resize，没监听 move）。
2. **背记进度不跨启动**：每次启动应用，ReciteEngine 都从第一个单词重新开始，用户上次学到的位置丢失。

此外，用户希望能在设置窗口中预览单词本内的具体词条（单词 / 音标 / 词性 / 释义），并支持内联编辑和删除操作。

## What Changes

**Part A: 悬浮窗位置恢复 bug 修复**
- FloatWindowController 新增监听 `NSWindow.didMoveNotification`
- 窗口拖拽移动结束后自动保存位置到 UserDefaults
- 重启后正确恢复到上次的位置和尺寸

**Part B: 背记进度持久化**
- UserDefaults 存储当前进度：Section 索引、单词索引、已反馈集合
- ReciteEngine 启动时检测历史进度并恢复
- 进度与当前单词本 / Section 配置不匹配时安全回退到从头开始
- 进度保存时机：单词切换时、Section 完成时、app 退出时

**Part C: 单词本预览**
- 单词本管理 Tab 新增"预览"按钮
- 点击后弹出 Sheet，展示选中单词本的词条列表
- 每条显示：单词、音标、词性 + 释义
- 内联编辑（点击直接修改词条字段）
- 按钮删除（每行一个删除按钮）
- 分页展示，每页 100 条

## Capabilities

### New Capabilities

- **wordbook-preview** — 单词本预览功能（设置窗口）
- **progress-persistence** — 背记进度跨启动持久化（ReciteEngine + UserDefaults）

### Modified Capabilities

- **floating-window** — 新增窗口移动事件监听，修复位置恢复 bug

## Impact

- **修改文件**：FloatWindowController.swift、ReciteEngine.swift、WordbookTabView.swift、WordbookService.swift、AppSettings.swift
- **新增文件**：WordbookPreviewView.swift（单词本预览 Sheet）
- **数据层**：UserDefaults 新增 progress 相关 key，不影响 Core Data schema
- **测试**：需新增进度保存/恢复的单元测试，以及单词本预览的 UI 测试
