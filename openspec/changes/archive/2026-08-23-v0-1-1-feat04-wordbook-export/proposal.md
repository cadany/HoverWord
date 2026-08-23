---
baseline_version: "v0-1-1"
change_sub_version: "v0-1-1-feat04"
---

## Why

单词本数据目前只能进不能出：导入后无法导出备份/迁移，换机或备份只能依赖 Core Data 文件。导出与导入格式对称（同一 TXT 格式），可直接重新导入还原，形成数据闭环。同时"我的收藏"支持导出，补上收藏备份能力。

## What Changes

1. **TXT 导出服务**：新建 `WordbookExportService`，与导入格式完全对称——每行一个词条，Tab 分隔 8 字段（源词条/注音/词性1/释义1/词性2/释义2/词性3/释义3），空字段输出空字符串，UTF-8 无 BOM，换行符 `\n`
2. **收藏导出**：系统收藏夹从 `Favorite.wordDetail` 快照还原 8 字段导出（按收藏时间升序，与预览排序一致）
3. **导出入口**：行内 `...` 菜单新增"导出"项——普通词本菜单为 导入/导出/重命名/分隔线/删除；**收藏行出现仅含"导出"的菜单**（此前收藏行无任何菜单）；空词本导出项禁用
4. **保存面板**：NSSavePanel，默认文件名 `<词本名>.txt`（清洗 `/`、`:` 等非法字符），覆盖保存走系统确认；后台上下文取数写文件，失败弹 alert
5. **往返无损**：导出文件可直接经现有导入功能还原（round-trip 一致）

## Capabilities

### New Capabilities

无（导出逻辑归属 wordbook 能力的新增 Requirement）

### Modified Capabilities

- `wordbook`: 新增"TXT 词库导出"Requirement
- `settings-window`: 单词本管理 Tab 的行内菜单场景更新（菜单项新增导出；收藏行出现导出菜单）

## Impact

### 影响文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Services/WordbookExportService.swift` | 新增 | 导出序列化（普通词本按 orderIndex；收藏按 collectedAt 快照还原）、文件名清洗 |
| `Features/Settings/WordbookTabView.swift` | 修改 | `WordbookRow` 增加 onExport 回调与菜单项；`exportWordbook(_:)` NSSavePanel 流程；exportError alert |
| `Resources/Localizable.xcstrings` | 修改 | 新增 `wordbook.toolbar.export`、`wordbook.export.failed` 词条（zh-Hans/en）；词本不存在复用 `wordbook.error.notFound` |
| `HoverWordTests/Services/WordbookExportServiceTests.swift` | 新增 | 往返一致性、收藏导出、排序、文件名清洗测试 |

### 设计要点（探索阶段已确认的决策）

- 纯 UTF-8 不加 BOM：保证重新导入无损（导入 parse 不剥离 U+FEFF，加 BOM 会污染首行）
- 换行 `\n`、固定 8 列（空字段空串）：导入端 `fields.count >= 4` 校验通过，往返无损
- 大词库在后台上下文取数（对齐导入的事务模式）；10000 条拼串毫秒级
- 导出成功不弹提示（极简低干扰），仅失败时 alert

### 测试覆盖

- 普通/收藏词本导出字段与顺序
- 导出 → 导入 round-trip 字段一致
- 文件名非法字符清洗
