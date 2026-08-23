## 1. 导出服务

- [x] 1.1 新建 `Services/WordbookExportService.swift`
  - `export(wordbookId:) async throws -> Data`：后台上下文取数；普通词本按 orderIndex 升序读 WordEntry；收藏夹按 collectedAt 升序读 Favorite 并解码 wordDetail 快照（损坏跳过 + NSLog）
  - 行格式：8 字段 Tab 分隔（nil → 空串），`\n` 连接，UTF-8 无 BOM
  - `sanitizedFileName(from:)`：`/`、`:`、换行 → `-`
  - 词本不存在抛错（复用 `wordbook.error.notFound` 文案）

## 2. UI 接线

- [x] 2.1 `WordbookTabView` / `WordbookRow` 增加导出回调与菜单项
  - `WordbookRow` 增加 `onExport: (() -> Void)?`；菜单条件加入 onExport
  - NSMenu 顺序：导入 / 导出 / 重命名 / 分隔线 / 删除；导出项 `isEnabled = wordbook.wordCount > 0`
  - 收藏行：仅导出（onExport 非 nil，其余 nil）
- [x] 2.2 `exportWordbook(_:)` 保存面板流程
  - NSSavePanel（plainText、默认文件名清洗后的 `<词本名>.txt`、可建目录）
  - 确认后 Task 后台导出 + 写文件；失败主线程 alert（`wordbook.export.failed`），成功无提示
  - exportError alert 挂在与既有 alerts 不同的子节点

## 3. 文案

- [x] 3.1 `Localizable.xcstrings` 新增 `wordbook.toolbar.export`（导出/Export）、`wordbook.export.failed`（导出失败/Export Failed）

## 4. 测试与验证

- [x] 4.1 新建 `HoverWordTests/Services/WordbookExportServiceTests.swift`
  - 普通词本导出字段/顺序正确
  - 导出 → ImportService.parse round-trip 字段一致
  - 收藏导出按 collectedAt 快照还原
  - 文件名清洗
- [x] 4.2 构建 + 全量测试无回归
- [x] 4.3 手动验证（用户 2026-08-23 确认通过）：普通/收藏词本导出 → 重新导入还原一致；空词本导出项禁用；默认文件名正确
