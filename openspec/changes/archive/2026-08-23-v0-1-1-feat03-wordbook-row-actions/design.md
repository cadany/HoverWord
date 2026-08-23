# Design: 单词本行内操作 + 删除确认

## Context

探索结论（2026-08-23 会话）：操作栏两步交互 → 行内一步交互；方案 B（悬停/选中浮现，`eye` 直达 + `...` 菜单收纳其余）；删除无确认是既有风险点，行内化后必须补。

## Goals / Non-Goals

- Goals: 行内操作、新建入口迁移、删除确认、操作按词本类型裁剪
- Non-Goals: 不做导出（feat04）、不改预览/导入/重命名自身逻辑与 Sheet、不做多选、不做拖拽排序

## Decisions

### D1: 操作区用 overlay 而非 HStack 尾插

- 嵌套进 `Button(.plain)` label 内部不可行（SwiftUI 内层按钮手势被外层吃掉）
- HStack 尾插会改变行选中高亮背景的覆盖范围，且行宽跳变更明显
- **选定**: 在文本 Button 上加 `.overlay(alignment: .trailing)`，操作区浮于行尾空白区（Spacer 区域），不引起布局跳动；显隐用 `opacity` transition + 行既有的 `isHovering` 动画（0.15s easeOut）
- 隐藏时不参与点击（条件渲染，`if showActions`）

### D2: 显隐条件 = 悬停 OR 选中

- 仅悬停：选中行无操作入口，键盘/可发现性差
- 仅选中：悬停非选中行无反馈，不符合 macOS 惯例
- **选定**: `isHovering || isSelected`，两者任一满足即显示

### D3: 操作回调全部可选，nil 即隐藏

`WordbookRow` 增加 `onPreview/onImport/onRename/onDelete` 四个 `(() -> Void)?`。
- 普通词本：全传
- 系统词本：全 nil（对齐现状：收藏不可导入/重命名/删除，预览也禁用）→ 操作区整体不渲染
- feat04 导出落地时给收藏行补 `onExport` 即可，无需改结构

### D4: 点操作先同步 selection

既有导入/重命名/预览逻辑全部基于 `selection` 状态取目标词本（`handleImport`、`selectedWordbookObject`、rename sheet 的 onAppear）。统一约定：**每个操作回调入口先 `selection = wb.id` 再触发面板**，避免重构数据流。与 checkbox 点选同步选中的既有惯例（`binding(for:)`）一致。

### D5: 删除确认用 alert + destructive 按钮

- 状态: `pendingDeleteWordbook: WordbookInfo?`，非 nil 即弹 alert（与 `importError` 相同的 Binding 模式）
- alert: 标题（删除单词本）+ message（词本名 + 词数 + 不可恢复提示）+ 取消（cancel role）/ 删除（destructive role）
- 确认后按 id fetch → `deleteWordbook` → `selection = nil` → `refreshList()`（沿用 `deleteSelected()` 的处理链）

### D6: "新建" 迁至列表卡片标题行右侧

- `HStack { Text(标题) Spacer Button(+) }`，`+` 用 `glassButtonStyle()` + `.help()` tooltip（复用 `wordbook.toolbar.new` 词条）
- 下方操作栏卡片整体移除

### D7: 图标与菜单样式（v2，踩坑修订）

- 预览: `Image(systemName: "list.bullet")`，`.buttonStyle(.plain)`，`.help(wordbook.toolbar.preview)`
- 菜单入口: **Button(.plain) + 自绘三圆点 label（VStack+Circle）+ NSMenu 原生弹出**（`popUp(positioning:at:in:)` 鼠标位置）
- 踩坑记录（macOS 26.6 验证）：
  - `ellipsis.vertical` 为 iOS 专属符号，macOS SF Symbols 不存在（NSImage API 返回 nil），`Image(systemName:)` 渲染为空
  - SwiftUI `Menu` + `.menuStyle(.borderlessButton)`（macOS 14 起已废弃）+ 任意自定义 label（Image 或自绘视图）在本环境**均不渲染**，按钮完全空白
  - Button(.plain) + 自定义 label 渲染可靠（预览按钮验证）
- 菜单项复用既有 `wordbook.toolbar.import/rename/delete` 词条，删除项红色文字（NSAttributedString）+ 前置分隔线
- 点击热区 `Constants.rowActionHitSize`（22pt），圆点 3pt

## Risks / Trade-offs

- eye 图标无文字标注，靠 `.help()` tooltip 兜底（菜单项均有文字，主要操作可发现性可接受）
- 收藏行暂无任何操作（视觉上悬停无反馈），feat04 导出落地后消除
- `menuIndicator`/`borderlessButton` 在 macOS 12+ 可用，当前部署目标 14.0 无兼容问题

## Migration Plan

纯 UI 变更，无数据/设置迁移。

## Open Questions

无（探索阶段已确认方案 B + 删除确认）。
