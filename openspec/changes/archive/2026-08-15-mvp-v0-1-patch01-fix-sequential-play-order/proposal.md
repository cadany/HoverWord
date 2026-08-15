---
baseline_version: "mvp-v0-1"
change_sub_version: "mvp-v0-1-patch01"
---

## Why

「顺序播放」模式下单词展示顺序实际为随机。根因：`WordbookService.getEntries(for:sectionIndex:)` 使用 `wordId`（UUID 字符串）作为排序字段，UUID 每次导入随机生成，排序结果天然无序。`ReciteEngine.rebuildWordOrder()` 生成的顺序索引 `[0, 1, 2, ...]` 指向的是 UUID 排序后的数组，因此「顺序播放」与「随机播放」在用户感知上无差异。

## What Changes

为 `WordEntry` 实体新增 `orderIndex: Int32` 字段，记录词条在导入文件中的原始行序：
- 导入时写入递增序号（`index` from `enumerated()`）
- 查询时按 `orderIndex` 排序（替代 `wordId`）
- 启用轻量迁移，为存量数据填充默认值 0

存量数据兼容策略：轻量迁移为旧词条填充 `orderIndex = 0`，同一 Section 内所有词条 orderIndex 相同时回退按 `sourceWord` 字母序排序，保证顺序确定。用户重新导入一次词库可获得精确的文件顺序。

## Capabilities

### New Capabilities

无

### Modified Capabilities

- **wordbook-storage**: `WordEntry` 实体新增 `orderIndex` 字段；`getEntries` 排序字段变更
- **recite-engine**: 无直接代码变更，但行为因 `getEntries` 排序改变而修正

## Impact

- **Core Data 模型**: 新增模型版本（v2），`WordEntry` 添加 `orderIndex` 属性
- **数据迁移**: DataStack 启用轻量迁移（`NSMigratePersistentStoresAutomaticallyOption` + `NSInferMappingModelAutomaticallyOption`）
- **导入服务**: `WordbookImportService.importEntries` 写入 `orderIndex`
- **查询服务**: `WordbookService.getEntries` 排序字段从 `wordId` 改为 `orderIndex`（辅以 `sourceWord` 作为平局排序）
- **存量数据**: 旧词条 orderIndex 均为 0，按 sourceWord 字母序回退；重新导入后恢复精确文件顺序
- **测试**: 需补充 `orderIndex` 写入与排序正确性的测试
