## 1. Core Data 模型升级

- [x] 1.1 在 `Resources/HoverWord.xcdatamodeld` 下新建模型版本 `HoverWord v2.xcdatamodel`（基于 v1 复制），在 Xcode 中将 v2 设为当前版本
- [x] 1.2 在 v2 的 `WordEntry` 实体中添加 `orderIndex` 属性：类型 Integer 32，默认值 0，使用 scalar 值类型

## 2. 轻量迁移

- [x] 2.1 修改 `DataStack.swift` 的 `loadPersistentStores` 调用，添加迁移选项：`NSMigratePersistentStoresAutomaticallyOption: true` 和 `NSInferMappingModelAutomaticallyOption: true`

## 3. 导入服务写入 orderIndex

- [x] 3.1 修改 `WordbookImportService.importEntries`，在 `for (index, parsed) in entries.enumerated()` 循环内写入 `entry.orderIndex = Int32(index)`

## 4. 查询服务排序修正

- [x] 4.1 修改 `WordbookService.getEntries(for:sectionIndex:)`，将排序字段从 `wordId` 改为双字段排序：主排序 `orderIndex` 升序，次排序 `sourceWord` 升序（平局兜底）

## 5. 测试

- [x] 5.1 在 `WordbookImportServiceTests` 中补充测试：验证导入后词条 `orderIndex` 值与文件行序一致
- [x] 5.2 在 `WordbookServiceFavoritesTests`（或新建测试文件）中补充测试：验证 `getEntries` 返回结果按 `orderIndex` 排序

## 6. 验证

- [x] 6.1 全量构建通过，36+ 个测试全部通过
- [x] 6.2 人工验证：导入词库后切换「顺序播放」，单词按文件行序展示；切换「随机播放」，单词随机打乱
