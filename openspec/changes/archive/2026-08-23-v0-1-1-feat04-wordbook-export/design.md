# Design: 单词本 TXT 导出

## Context

探索结论（2026-08-23）：导出与导入对称（同一 8 字段 Tab 分隔 TXT）、包含我的收藏、不加 BOM、入口进行内 `...` 菜单。用户已确认这三项决策。

## Goals / Non-Goals

- Goals: 对称 TXT 导出（普通词本 + 收藏快照）、行内菜单入口、NSSavePanel、round-trip 无损
- Non-Goals: 不做 CSV/其他格式、不做导出进度 UI、不做导出成功提示（极简）、不做词条多选导出

## Decisions

### D1: 导出格式与导入严格对称

- 每行：`sourceWord\tphonetic\tpos1\tmeaning1\tpos2\tmeaning2\tpos3\tmeaning3`，nil 字段输出空串，固定 8 列
- 换行 `\n`，UTF-8 无 BOM（导入 parse 不剥离 U+FEFF，加 BOM 会污染首行词条且二次导出累积）
- 导入端校验 `fields.count >= 4` + 词条/释义1 必填：导出内容天然满足（导入时已强制必填）

### D2: 收藏导出从快照还原，不经收藏转词条转换

直接读 `Favorite.wordDetail` JSON（含 8 字段）+ `sourceWord`，按 `collectedAt` 升序（与预览/背记顺序一致）。与 `favoriteToWordEntry` 的解码逻辑同源，但导出服务内独立轻量解码（避免为导出构造游离 NSManagedObject）。

### D3: 入口在行内 `...` 菜单（NSMenu）

feat03 的菜单是自绘 NSMenu（SwiftUI Menu 在 macOS 26 不渲染 label 的踩坑结论），导出直接加 NSMenuItem：

- 普通词本：导入 / **导出** / 重命名 / 分隔线 / 删除
- 收藏行：**仅导出**（此前收藏行无菜单，本变更后出现）
- 空词本（wordCount == 0）：导出项 `isEnabled = false`（对齐"空词本不能启用"先例，避免导出空文件）

### D4: NSSavePanel + 后台取数

- 主线程 `NSSavePanel.runModal()`，`allowedContentTypes = [.plainText]`，默认文件名 `<词本名>.txt`
- 文件名清洗：`/`、`:`、换行 → `-`（macOS Finder 对 `/` 与 `:` 敏感）
- 确认后 `Task` 中后台上下文取数序列化为 `Data`，主线程外完成拼串，`data.write(to:)` 写文件
- 失败（词本被删/磁盘错误）→ 主线程 alert（`wordbook.export.failed` + 系统错误描述）；成功无提示

### D5: 新建独立 WordbookExportService

对齐 `WordbookImportService` 先例（导入/导出各一个服务类），不往 WordbookService 里堆。静态方法、无状态。

## Risks / Trade-offs

- 释义字段若含 Tab/换行（导入端不禁止），导出重新导入会错位——这是导入格式的既有约束，非本变更引入；导出时按字段原样输出保证数据不丢
- 收藏快照 JSON 若损坏（解码失败）：跳过该条并 NSLog（与 favoriteToWordEntry 行为一致），导出其余

## Migration Plan

纯新增功能，无数据迁移。

## Open Questions

无（探索阶段已确认）。
