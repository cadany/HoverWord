---
baseline_version: "v0-1-1"
change_sub_version: "v0-1-1-feat01"
---

## Why

当前应用 85 处界面文案硬编码中文（分布 18 个文件），英文用户完全不可用。项目规范要求多语种架构预留，本变更落地界面层多语言：先支持简体中文与英文，建立可持续的字符串管理机制，后续语种仅需补充词条文件。

mvp-v0-1 基线全部变更已归档，本变更为新主基线 v0-1-1 的第一个特性，应用 marketing 版本号同步升至 0.1.1。

## What Changes

- 新增界面语言设置项：设置窗口 sidebar 新增"通用"导航项（第 5 项），内含"界面语言"三选一（跟随系统 / 简体中文 / English），默认跟随系统
- 新增字符串本地化基建：Localizable.xcstrings 词条表（zh-Hans + en，约 85 条起步），L10n 解析层按语言设置选择 .lproj Bundle，"跟随系统"沿系统语言回退
- 全量替换硬编码文案：Settings 各视图、悬浮窗（AppKit）、服务层错误提示、枚举 displayName、右键菜单等 85 处改为 key 引用
- 切换立即生效：新增 `.appLanguageDidChange` 通知，SwiftUI 视图重渲染 + 悬浮窗手动刷新（复用现有通知刷新架构）
- 系统收藏夹显示名映射：`isSystem` 单词本界面显示名走词条表（"我的收藏"/"Favorites"），Core Data 存储名不变，查询逻辑（isSystem == YES）不受影响
- RTL 布局适配入口预留（跟随 SwiftUI 语义布局，不额外开发）

三项方案抉择（探索阶段已确认）：跟随系统 + 手动覆盖；Tab 命名"通用"；切换立即生效。

## Capabilities

### New Capabilities

- `ui-localization`: 界面语言设置、字符串本地化解析、语言切换即时刷新、系统单词本显示名映射

### Modified Capabilities

- `settings-window`: Sidebar 导航项由 4 个增至 5 个（新增"通用"），语言选择位于其中

## Impact

- **代码**：新增 L10n 服务与"通用"设置 Tab（约 3 个新文件）；修改 Settings 各视图、FloatContentView、FloatWindowController、WordbookImportService、WordbookService、ReciteMode、PlayOrder、SidebarItem、AppSettings、NotificationNames、Constants 等，预计 20+ 文件
- **数据**：AppSettings 新增 `uiLanguage` 字段（默认 "system"），Codable 向后兼容
- **依赖**：无新增（String Catalog 为 Xcode 15 原生能力）
- **系统**：project.pbxproj 的 knownRegions 增加 zh-Hans；Info.plist 无需本地化条目（无权限描述类字符串）
- **行为变更**：英文系统用户首次升级后界面从中文变为英文（跟随系统默认值）；已安装用户默认不受影响（中文词条为 zh-Hans 回退结果）
- **测试**：L10n 解析与语言回退单元测试；语言切换通知刷新测试；存量测试中依赖中文字面量的断言需同步调整
- **版本**：应用 marketing version 0.1.0 → 0.1.1
