## 1. 常量与文案

- [x] 1.1 修改 `Shared/Constants.swift`
  - 新增 `rowActionIconSize: CGFloat = 12`（行内操作图标字号）
  - 新增 `rowActionSpacing: CGFloat = 2`（操作区间距）
  - 实际另加 `rowActionHitSize: CGFloat = 22`（图标点击热区，12pt 图标裸点击目标过小）

- [x] 1.2 修改 `Resources/Localizable.xcstrings`
  - 新增 `wordbook.delete.confirm.title`（删除单词本 / Delete Wordbook）
  - 新增 `wordbook.delete.confirm.message`（确定要删除"%@"吗？包含 %d 个单词，此操作不可恢复。/ ...）
  - 菜单项与图标 tooltip 复用既有 `wordbook.toolbar.*` 词条

## 2. WordbookTabView 重构

- [x] 2.1 标题行加"新建"入口
  - 列表卡片标题 `Text` 改为 `HStack { Text; Spacer; Button(+) }`
  - `+` 图标按钮 `glassButtonStyle()` + `.help(wordbook.toolbar.new)`

- [x] 2.2 移除操作栏卡片
  - 删除列表下方的"操作栏卡片" `HStack`（新建/导入/重命名/预览/删除五按钮）及 `glassCard()`
  - 删除随之失效的 `isSystemSelected`（已无引用）

- [x] 2.3 `WordbookRow` 增加行内操作区
  - 新增可选回调 `onPreview / onImport / onRename / onDelete`（`(() -> Void)?`）
  - 操作区 `.overlay(alignment: .trailing)` 叠于文本 Button 行尾，`if isHovering || isSelected` 条件渲染 + `.transition(.opacity)`
  - 内容：`eye` 图标按钮（`.help` tooltip）+ `ellipsis` 菜单（导入/重命名/Divider/删除 destructive），`.menuStyle(.borderlessButton)` + `.menuIndicator(.hidden)`
  - 系统词本四个回调全 nil 时不渲染操作区

- [x] 2.4 操作回调接线（选中同步）
  - 每个操作入口先 `selection = wb.id`，再置 `showingPreviewPanel / showingImportPanel / showingRenamePanel`
  - 预览入口仅普通词本提供（对齐现状）

## 3. 删除确认

- [x] 3.1 新增 `pendingDeleteWordbook: WordbookInfo?` 状态
  - 删除菜单项：`selection = wb.id` + `pendingDeleteWordbook = wb`
  - `.alert` 挂在列表卡片子树（与外层导入失败 alert 分离，避免同节点多 alert 冲突），标题 + message（词本名/词数）+ 取消（cancel）/ 删除（destructive）
  - 确认：按 id fetch → `deleteWordbook` → `selection = nil` → `refreshList()` → 清空 pending
  - 替换原 `deleteSelected()` 直接删除逻辑

## 5. 用户反馈调整（预览图标 + 收藏夹预览）

- [x] 5.1 预览图标 `eye` → `list.bullet`（用户反馈 eye 丑）
- [x] 5.2 收藏夹开放预览入口
  - `WordbookService.getEntriesPaginated` 支持收藏夹：查 Favorite 按 collectedAt 升序分页，`favoriteToWordEntry` 转游离词条（原实现显式返回空）
  - `WordbookPreviewView` 只读模式（`wordbook.isSystem`）：纯文本展示、无删除按钮，分页/空状态不变；收藏词条编辑走源词本（快照自动同步），故不提供编辑/删除
  - `WordbookTabView` 收藏行 `onPreview` 不再置 nil
- [x] 5.3 补测试 `testFavoritesPaginatedPreview`（分页计数、三页无重复覆盖、游离态、快照字段解码）
- [x] 5.4 delta spec 同步：行内操作图标描述、收藏行预览入口、ADDED"收藏夹只读预览"、MODIFIED"单词本预览"
- [x] 5.5 菜单入口改为竖排三点：`ellipsis.vertical` 为 iOS 专属符号，macOS 上 `Image(systemName:)` 解析失败渲染为空（NSImage API 验证 MISSING），导致菜单按钮不可见；改用自绘三圆点（VStack+Circle，不依赖符号库）
- [x] 5.6 菜单控件方案变更：自绘三圆点放入 SwiftUI `Menu` label 后**依然不渲染**（用户截图证实）——根因是 `Menu` + 废弃的 `.menuStyle(.borderlessButton)` 在 macOS 26 上不渲染任何自定义 label（Image 亦然，菜单按钮从未显示过）。改为 **Button(.plain) + NSMenu 原生弹出**（导入/重命名/分隔线/删除红字），点击行为与 spec 一致

## 4. 验证

- [x] 4.1 构建 + 全量测试无回归（BUILD SUCCEEDED；79 个用例全部通过，0 失败）
- [x] 4.2 手动验证（用户 2026-08-23 确认：按钮显示、菜单弹出、颜色统一均通过）：
  - 悬停/选中浮现操作区，离开淡出；选中行常驻
  - 点 eye 打开该行词本预览；菜单导入/重命名作用于该行词本（非之前选中项）
  - 删除弹确认，取消不删，确认删除后列表刷新、选中清空
  - 我的收藏行无任何操作入口；空词本不能启用提示不受影响
  - 中英文界面文案正确

## 补充记录

- 实现中发现：`WordbookService.renameWordbook` 无系统词本守卫，旧工具栏上收藏夹可被"重命名"（改存储名但行内仍显示固定本地化名，属隐性脏写）。本变更收藏行隐藏全部操作，该路径不再可达；后续如恢复收藏重命名需求，应在 Service 层加守卫。

