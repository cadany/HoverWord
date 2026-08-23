---
baseline_version: "v0-1-1"
change_sub_version: "v0-1-1-feat03"
---

## Why

当前单词本操作是"先在列表选中词本，再到列表下方的操作栏点按钮"的两步交互，操作对象依赖全局选中状态，按钮禁用逻辑分散。将操作按钮移到词本行的右侧（悬停/选中时浮现），操作直接绑定所在行，一步完成，符合 macOS 列表惯例（备忘录/提醒事项风格），空闲时零视觉噪声。

此外，删除单词本目前**没有任何确认**（`deleteSelected()` 直接执行），词本及其全部词条立即丢失且不可恢复。操作按钮行内化后误触概率上升，需同步补充删除确认。

## What Changes

1. **行内操作按钮**：行悬停或选中时，行右侧淡入操作区：
   - `eye` 预览图标按钮（直接入口，高频操作）
   - `...`（ellipsis）菜单收纳其余操作：导入 / 重命名 / 删除（删除为 destructive 红字，前有 Divider）
2. **操作按词本类型裁剪**：普通词本 = 预览 + 导入 + 重命名 + 删除；系统词本（我的收藏）= 无任何操作入口（feat04 导出落地后收藏行将出现导出入口）
3. **点操作即选中该行**：点击行内任意操作时同步 `selection`，与 checkbox 点选行为的既有惯例一致
4. **新建按钮迁移**：操作栏卡片移除，"新建"移至列表卡片标题行右侧 `+` 图标按钮
5. **删除确认 alert**：点删除 → 弹确认对话框（标题 + 词本名与词数提示 + 取消/删除），确认后才执行删除

## Capabilities

### Modified Capabilities

- `settings-window`: 单词本管理 Tab 的"操作栏"场景改为"行内操作"场景，新增新建入口与删除确认场景

## Impact

### 影响文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Features/Settings/WordbookTabView.swift` | 修改 | 移除操作栏卡片；标题行加 `+`；`WordbookRow` 加行内操作区（overlay trailing）；删除确认 alert 与 `pendingDeleteWordbook` 状态；操作回调先同步 selection |
| `Shared/Constants.swift` | 修改 | 新增 `rowActionIconSize`、`rowActionSpacing` 常量 |
| `Resources/Localizable.xcstrings` | 修改 | 新增删除确认标题/正文词条（zh-Hans/en），菜单项复用既有 `wordbook.toolbar.*` 词条 |

### 交互细节

- 操作区用 `.overlay(alignment: .trailing)` 叠在行尾（不嵌套进行选中 Button 内部，避免 SwiftUI 嵌套按钮手势冲突），`transition(.opacity)` + 既有 0.15s 行悬停动画
- 显隐条件：`isHovering || isSelected`（选中行常驻，保证键盘/可发现性）
- 收藏行所有操作回调为 nil → 不渲染操作区

### 测试覆盖

- 构建通过 + 既有测试无回归（本变更纯 UI 层，无引擎/数据逻辑改动）
