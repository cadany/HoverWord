## Context

`ReciteEngine` 依赖 `WordbookService.getEntries(for:sectionIndex:)` 获取 Section 内词条。当前 `getEntries` 按 `wordId`（UUID 字符串）排序，UUID 每次导入随机生成，排序结果天然无序。导致 `ReciteEngine.rebuildWordOrder()` 生成的顺序索引 `[0, 1, 2, ...]` 指向的是 UUID 排序后的数组，「顺序播放」模式下单词展示顺序与「随机播放」无异。

核心修复：新增 `orderIndex` 字段记录导入时的文件行序，查询时按 `orderIndex` 排序。

## Goals / Non-Goals

**Goals:**
- 修复「顺序播放」模式，使其按导入文件行序展示单词
- Core Data 模型版本升级时启用轻量迁移，不丢失存量数据
- 存量数据（无 orderIndex）回退按 `sourceWord` 字母序排序，保证确定性

**Non-Goals:**
- 不实现「按字母序导入」（保持文件行序为唯一顺序来源）
- 不编写一次性回填脚本为存量数据生成精确 orderIndex
- 不修改 `ReciteEngine` 代码（引擎逻辑正确，问题在数据层）

## Decisions

### D1: 新增模型版本 vs 直接修改现有模型
**决定**：新建 `HoverWord v2.xcdatamodel`，保留 v1 作为历史版本。
**理由**：标准 Core Data 迁移流程。直接修改 v1 会导致已有 store 无法加载。

### D2: orderIndex 语义：全局递增 vs Section 内递增
**决定**：全局递增。`orderIndex = index`（from `enumerated()`），不取模 sectionSize。
**理由**：实现简单；同一 Section 内相对顺序与全局顺序一致；跨 Section 比较时语义清晰。

### D3: 平局排序字段
**决定**：次要排序字段为 `sourceWord`（字母升序）。
**理由**：`sourceWord` 在 Section 内近似唯一（同一单词不会导入两次）；字母序对用户可读；不依赖 `wordId`（UUID）的随机性。

### D4: 存量数据迁移策略
**决定**：轻量迁移填充 `orderIndex = 0`，不编写回填脚本。
**理由**：v0.1 阶段用户量小，重新导入词库即可获得精确顺序。回填脚本增加复杂度（需按 Section 分组 + 分配序号），收益有限。

### D5: Favorite → WordEntry 转换的 orderIndex
**决定**：收藏夹转换路径不写 orderIndex（使用默认值 0），收藏夹查询按 `collectedAt` 排序已保证顺序。
**理由**：收藏夹的「顺序」由收藏时间决定，与文件行序无关。`favoriteToWordEntry` 创建的游离 WordEntry 不参与 `getEntries` 的 orderIndex 排序路径。

## Risks / Trade-offs

| 风险 | 缓解 |
|---|---|
| 存量数据 orderIndex 全为 0，回退字母序可能与用户预期不同 | 用户重新导入即可恢复；v0.1 阶段可接受 |
| 轻量迁移在某些极端场景（store 损坏）可能失败 | `DataStack` 已有 `fatalError` 兜底；开发阶段问题可早发现 |
| 新增模型版本后 Xcode 需手动设置当前版本 | 在 tasks 中明确步骤 |
