---
baseline_version: "mvp-v0-1"
change_sub_version: "mvp-v0-1-feat01"
---

## Why

悬浮窗是用户背记单词的核心交互界面。当前 v0.1 实现存在两个体验短板：
1. **"已学完"状态缺少右键入口**：用户在完成背记后，右键菜单仅包含"打开设置"和"退出程序"，无法直接重新开始背记，需要等待鼠标悬停浮现"重新开始"按钮，交互路径不够简洁。
2. **窗口尺寸固定不可调**：悬浮窗宽度固定 300px、不可手动缩放，当单词释义内容较长时可能被截断，用户无法根据屏幕空间和内容需要自由调整窗口大小。

## What Changes

- **扩展"已学完"状态右键菜单**：悬浮窗在背记全部完成（"已学完"）状态下，右键菜单 SHALL 新增"重新开始"菜单项，与"打开设置"和"退出程序"并列，点击后从第一个 Section 重新开始背记。
- **悬浮窗可拖拽边框缩放**：悬浮窗 SHALL 支持通过拖拽窗口边缘/角落调整大小，替换原有的固定 300px 宽度约束。设置最小/最大尺寸边界，缩放后窗口尺寸 SHALL 持久化记忆，重启后恢复。

## Capabilities

### New Capabilities
- `float-window-enhancements`: 悬浮窗增强能力，覆盖"已学完"状态右键菜单扩展（新增"重新开始"菜单项）与窗口边框拖拽缩放（可调节大小、尺寸记忆与恢复）。

### Modified Capabilities
（无）

## Impact

- **`FloatWindowController.swift`**：修改右键菜单构建逻辑，根据引擎状态动态添加"重新开始"菜单项；styleMask 添加 `.resizable`，设置 min/max size，修改位置记忆逻辑同时保存尺寸。
- **`FloatContentView.swift`**：布局需适配窗口尺寸动态变化，确保内容在不同宽度下正确排布（释义文本自动换行或截断）。
- **`GlassBackgroundView.swift`**：圆角裁剪需跟随窗口尺寸变化自适应。
- **`Constants.swift`**：新增窗口最小/最大宽度、最小/最大高度常量。
- **`ReciteEngine.swift`**：暴露 `isAllComplete` 状态属性供外部查询。
