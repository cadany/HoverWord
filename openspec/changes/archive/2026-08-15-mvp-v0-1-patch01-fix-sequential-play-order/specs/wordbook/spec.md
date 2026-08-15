Change-Sub-Version: mvp-v0-1-patch01

## MODIFIED Requirements

### Requirement: TXT 词库全量覆盖导入
系统 SHALL 支持导入 UTF-8 编码的 .txt 文件，采用全量覆盖逻辑：导入成功后清空该单词本原有全部单词，替换为新导入内容。导入时 SHALL 为每个词条写入 `orderIndex` 字段，值等于该词条在文件中的行序（从 0 起递增），用于保留文件原始顺序。

#### Scenario: 成功导入合法词库
- **WHEN** 用户选择一个格式正确的 UTF-8 .txt 文件导入某单词本
- **THEN** 系统 SHALL 清空该单词本原有词条，写入新词条，自动按全局"单 Section 单词数"拆分 Section，每个词条的 `orderIndex` 等于其在文件中的行序（从 0 起递增），并显示导入后的单词总数与 Section 数量

#### Scenario: 重复导入覆盖原有数据
- **WHEN** 用户对已有词条的单词本再次导入新词库
- **THEN** 系统 SHALL 完全替换原有词条，新词条的 `orderIndex` 从 0 重新递增，与原有 orderIndex 无关

#### Scenario: 导入空文件
- **WHEN** 用户导入一个内容为空的 .txt 文件
- **THEN** 系统 SHALL 清空该单词本原有词条，导入后单词总数为 0

## ADDED Requirements

### Requirement: 词条查询按导入顺序排序
系统 SHALL 在查询单词本指定 Section 的词条时，按 `orderIndex` 升序排序。当多个词条 `orderIndex` 相同时（存量数据迁移场景），SHALL 以 `sourceWord` 字母序作为次要排序，保证结果确定性。

#### Scenario: 查询 Section 词条顺序
- **WHEN** 系统查询某 Section 内的词条列表
- **THEN** 返回的词条 SHALL 按 `orderIndex` 升序排列，与导入时的文件行序一致

#### Scenario: 存量数据平局排序
- **WHEN** 系统查询的词条中，多个词条的 `orderIndex` 均为 0（轻量迁移默认值）
- **THEN** 系统 SHALL 对这些词条按 `sourceWord` 字母升序排列，保证每次查询结果一致

### Requirement: Core Data 轻量迁移
系统 SHALL 在 Core Data 模型版本升级时启用轻量迁移（`NSMigratePersistentStoresAutomaticallyOption` + `NSInferMappingModelAutomaticallyOption`），自动为存量 `WordEntry` 填充 `orderIndex` 默认值 0。

#### Scenario: 模型版本升级自动迁移
- **WHEN** 应用启动时检测到 Core Data store 使用旧版模型
- **THEN** 系统 SHALL 使用轻量迁移自动升级 store，存量词条的 `orderIndex` 填充为 0，不丢失任何数据
