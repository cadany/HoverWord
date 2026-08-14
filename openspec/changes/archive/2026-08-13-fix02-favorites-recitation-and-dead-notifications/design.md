## Context

`Favorite` 实体与 `Wordbook.entries`（`WordEntry` 有序集合）完全隔离，导致收藏夹单词本无法进入背记队列。同时 `NotificationNames.swift` 中有 11 个死通知（5 个从未 post/observe，6 个只 post 不 observe），doc 注释声称有不存在的监听方，增加维护者的认知负担。

本变更在不修改 Core Data 数据模型的前提下，通过服务层特判打通收藏夹背记链路，并清理全部死通知代码。

## Goals / Non-Goals

**Goals:**
- 收藏夹单词本可启用并参与背记，收藏词条能在悬浮窗正常展示和调度
- 删除全部 11 个死通知的定义及 post 调用
- 新增收藏夹背记链路的单元测试，确保无回归

**Non-Goals:**
- 不修改 Core Data 数据模型（xcdatamodel 不变）
- 不引入 Favorite ↔ Wordbook 关系
- 不为 `wordbookListDidChange` 等"只 post 不 observe"的通知补充监听方（当前无组件需要这些通知，未来需要时重新设计）

## Decisions

### D1: 收藏夹背记 — 服务层特判（方案 A）

在 `WordbookService` 中对 `isSystem == true` 且 `name == "我的收藏"` 的单词本做特殊分支：

| 方法 | 普通单词本 | 收藏夹单词本 |
|------|-----------|------------|
| `getEntryCount(for:)` | `WordEntry.count(wordbook.wordbookId)` | `Favorite.count()` |
| `getSectionCount(for:)` | `ceil(WordEntry.count / sectionSize)` | `ceil(Favorite.count / sectionSize)` |
| `getEntries(for:sectionIndex:)` | `WordEntry.fetch(wordbook, section)` | `Favorite.fetch(offset, limit)` → 解码 `wordDetail` JSON → 构造 `WordEntry` |

**选择理由：** 不改数据模型、不引入迁移、`ReciteEngine.buildQueue` 完全不需要改动（它消费 `WordEntry` 数组，透明兼容）。

**不选方案 B（物化视图）：** 需要在 `toggleFavorite`、`syncFavoritesAfterImport`、删除单词本等多处同步维护 `WordEntry` 副本，一致性风险高。

**不选方案 C（数据模型重构）：** 需要 xcdatamodel 变更 + 迁移，复杂度远超收益。

### D2: Favorite → WordEntry 转换

新增 `WordbookService.favoriteToWordEntry(_:)` 私有方法：
1. 从 `Favorite.wordDetail` 反序列化 JSON
2. 生成新的 `wordId`（UUID），设置 `sectionIndex`
3. 填充 `sourceWord`、`phonetic`、`pos1/2/3`、`meaning1/2/3`
4. 返回一个 **游离的** `WordEntry`（不写入 Core Data，仅用于引擎调度）

**注意：** 这个 `WordEntry` 不挂载到任何 `Wordbook.entries` 关系，仅作为数据载体传递给 `ReciteEngine`。

### D3: 死通知清理策略

- **5 个完全死的**（从未 post 也未 observe）：直接删除定义
  - `reciteModeDidChange`
  - `appearanceDidChange`
  - `speechSettingsDidChange`
  - `reciteEngineStateDidChange`
  - `reciteDidCompleteAll`

- **6 个只 post 不 observe 的**：删除定义 + 删除所有 post 调用点
  - `wordbookListDidChange`（WordbookService 5 处）
  - `favoriteStateDidChange`（WordbookService 2 处）
  - `settingsWindowWillHide` / `settingsWindowWillShow`（SettingsWindowController 2 处）
  - `floatWindowWillHideForFullscreen` / `floatWindowDidRestoreFromFullscreen`（AppDelegate 2 处）

### D4: WordbookTabView 收藏夹计数适配

`WordbookTabView` 显示单词本列表时，对收藏夹单词本的 `wordCount` 属性需从 `Favorite.count` 获取（而非 `WordEntry.count`）。checkbox 禁用条件也对应调整：收藏夹看收藏数量，普通单词本看词条数量。

## Risks / Trade-offs

| 风险 | 影响 | 缓解 |
|------|------|------|
| 收藏夹 `Favorite.wordDetail` JSON 解析失败 | 该词条无法背记 | `favoriteToWordEntry` 内 `try?` 容错，解析失败跳过该词条并 log |
| 游离 `WordEntry` 被误写入 Core Data | 收藏夹单词本出现幽灵词条 | 文档注释明确标注"不持久化"，方法返回前不调用 `context.insert` |
| 删除 `wordbookListDidChange` 后，未来需要通知列表刷新 | 需重新设计通知链路 | 当前 `WordbookTabView` 通过直接 reload 数据刷新，不依赖该通知 |
| `floatWindowWillHideForFullscreen` 被删除后，其他组件无法感知全屏隐藏事件 | 目前无组件监听 | 全屏隐藏逻辑由 `AppDelegate` 直接调用 `FloatWindowController` 方法完成，不走通知 |
