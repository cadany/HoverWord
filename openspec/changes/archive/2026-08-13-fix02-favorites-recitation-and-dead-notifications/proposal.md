---
baseline_version: "mvp-v0-1"
change_sub_version: "mvp-v0-1-fix02"
---

## Why

v0.1 集成联调阶段记录了两个遗留问题，影响功能完整性与代码可维护性：

1. **收藏夹单词本无法启用背记**：用户收藏的单词无法作为独立背记来源，PRD 中"收藏夹单词本参与背记"功能完全不可用。根因是 `Favorite` 实体与 `Wordbook.entries`（`WordEntry`）完全隔离——`getEntryCount`/`getSectionCount`/`getEntries`/`ReciteEngine.buildQueue` 整条链路只查询 `WordEntry`，收藏夹的 `Favorite` 记录无法被引擎消费。
2. **通知名称大面积死代码**：`NotificationNames.swift` 定义 14 个通知，仅 2 个完整连通（`appSettingsDidChange`、`wordbookEnablementDidChange`）。5 个从未 post 也未 observe，6 个只 post 不 observe（对着空气广播），doc 注释还声称有不存在的监听方，误导维护者。

## What Changes

### 收藏夹单词本背记（方案 A：服务层特判）

不改 Core Data 数据模型，在 `WordbookService` 和 `ReciteEngine` 中对 `isSystem == true` 的收藏夹单词本做特殊分支：
- `getEntryCount(for:)` — 当 wordbook 为收藏夹时，查询 `Favorite` 实体数量
- `getSectionCount(for:)` — 当 wordbook 为收藏夹时，按全局 section 大小从 `Favorite` 数量计算
- `getEntries(for:sectionIndex:)` — 当 wordbook 为收藏夹时，查询 `Favorite` 并转换为 `WordEntry` 兼容数据（从 `wordDetail` JSON 反序列化）
- `ReciteEngine.buildQueue()` — 无需改动，它消费 `WordbookService` 返回的 `WordEntry` 数组
- `WordbookTabView` — 收藏夹单词本的 wordCount 显示和 checkbox 禁用逻辑需适配 `Favorite` 计数

### 死通知清理

- 删除 5 个完全死代码的通知定义：`reciteModeDidChange`、`appearanceDidChange`、`speechSettingsDidChange`、`reciteEngineStateDidChange`、`reciteDidCompleteAll`
- 删除 6 个只 post 不 observe 的通知定义及其 post 调用点：`wordbookListDidChange`（WordbookService 5 处）、`favoriteStateDidChange`（WordbookService 2 处）、`settingsWindowWillHide/Show`（SettingsWindowController 2 处）、`floatWindowWillHideForFullscreen`/`floatWindowDidRestoreFromFullscreen`（AppDelegate 2 处）

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `wordbook` — 收藏夹单词本的计数、启用、背记消费链路打通
- `recite-engine` — 无行为变更，但依赖的 `WordbookService` 接口返回收藏夹数据后需确保队列构建正确（实际上 `buildQueue` 消费 `WordEntry` 数组，不需要改动）

## Impact

**受影响文件：**
- `Services/WordbookService.swift` — 收藏夹特判逻辑 + 删除死通知 post
- `Utils/NotificationNames.swift` — 删除 11 个死通知定义
- `Controllers/SettingsWindowController.swift` — 删除 settingsWindowWillHide/Show post
- `App/AppDelegate.swift` — 删除 floatWindowWillHide/Restore post
- `Views/Settings/WordbookTabView.swift` — 收藏夹 wordCount 显示适配
- `HoverWordTests/WordbookServiceTests.swift` — 新增收藏夹背记链路测试

**不受影响：**
- Core Data 数据模型（xcdatamodel）不变
- `ReciteEngine.swift` 不需要改动（消费 `WordEntry` 数组，透明兼容）
- 悬浮窗 UI、设置窗口 UI 外观不变
