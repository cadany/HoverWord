## Context

当前 85 处界面文案硬编码中文（Settings 视图 61、悬浮窗 12、服务层错误提示 10、枚举/常量 7），无任何本地化基建（无 .xcstrings/.lproj，knownRegions 仅 Base+en）。悬浮窗为 AppKit 实现，设置窗为 SwiftUI，两者刷新机制不同。AppSettings 已有 Codable 持久化与通知广播模式，FloatContentView 已有通知监听刷新先例（`.appAppearanceDidChange`）。

## Goals / Non-Goals

**Goals:**

- 界面文案中英文双语支持，默认跟随系统、可手动锁定
- 切换立即生效，无需重启
- String Catalog 统一管理词条，新增语种仅需补词条 + 语言选项
- 系统收藏夹显示名本地化且不影响数据与查询
- 存量用户升级无感（默认跟随系统时中文系统仍显示中文）

**Non-Goals:**

- 不引入第三/第四语种词条（机制就绪即可）
- 不做 RTL 语种的实际适配验证（仅预留语义布局约束）
- 不做单词内容（sourceWord/释义）的翻译——那是词库数据，与界面语言正交
- 不做发音口音与界面语言的联动（发音设置保持独立）
- 不本地化 NSLog 日志（开发者内部分析用，保持现状）

## Decisions

### Decision 1: 语言模式 — 跟随系统 + 手动覆盖（探索阶段已确认）

`AppSettings.uiLanguage: String`，取值 `"system"`（默认）/ `"zh-Hans"` / `"en"`。解析优先级：锁定语言 > 系统语言（`Locale.preferredLanguages` 首选）> en。存储层沿用现有单值 JSON Codable 模式，旧配置无此字段时解码为默认值，向后兼容。

语言列表数据驱动：设置页选项由 `SupportedLanguage` 登记表（代码 + 显示名 key）生成，L10n 按 `uiLanguage` 字符串查 `.lproj`。**新增语种的完整清单 = 补一组 xcstrings 词条 + 登记表加一行**，解析层、设置页结构、刷新链路均零改动。

**替代方案：** 仅应用内切换（不尊重系统语言，对英文新用户不友好）；仅跟随系统（无法满足"导航栏设置入口"的产品诉求，已否决）。

### Decision 2: 字符串机制 — String Catalog + 轻量 L10n 解析层

词条源用 `Localizable.xcstrings`（Xcode 15 原生，双语起步，自动同步 key）。新建 `Shared/L10n.swift` 提供两个入口：

- `L10n.t("key")` — 静态查词。按 `AppSettings.uiLanguage` 解析目标 `Bundle(path: Bundle.main.path(forResource: lang, ofType: "lproj"))`，缺失回退 en，再缺失回退 key 本身（开发期可见问题）
- `L10n.t("key", args…)` — 带插值，走 `String(format:)`

不采用 SwiftUI `Text(LocalizedStringKey)` 自动解析——它绑定进程启动语言，无法响应应用内即时切换；统一显式走 L10n 保证两套 UI 框架行为一致。

**替代方案：** 手写枚举字典（无工具链支持、丢 xcstrings 的翻译管理能力）；Swizzle Bundle.main（侵入全局、影响第三方/系统框架行为，风险不可控）。

### Decision 3: 刷新链路 — 语言环境对象 + 通知

SwiftUI 侧：新建 `LanguageManager`（ObservableObject），持 `currentLanguage`；设置窗根视图 `.environmentObject` 注入，语言切换时更新并触发全树重渲染。AppKit 侧：`FloatContentView` / `FloatWindowController` 监听新通知 `.appLanguageDidChange`（沿用 `.appAppearanceDidChange` 模式）刷新文案缓存。右键菜单为即时构造，天然取新语言。

**替代方案：** 仅通知不加 ObservableObject（SwiftUI 各视图需逐个监听刷新，样板代码多）；重启应用生效（体验差，已否决）。

### Decision 4: 系统收藏夹显示名 — isSystem 判定 + 词条映射

列表渲染处对 `isSystem == true` 的单词本显示 `L10n.t("wordbook.favorites.name")`，其余显示存储名。`WordbookService.isFavoritesWordbook` 现有 `name == Constants.favoritesWordbookName` 判定改为仅 `isSystem` 判定（名字不再作为判定条件，避免显示名本地化后误判）。Core Data 记录不迁移。

### Decision 5: 落地策略 — 一次性全量替换

85 处字符串按文件分批替换（Settings → 悬浮窗 → 服务层 → 枚举），同一变更内完成，不做"半本地化"中间态。key 命名约定：`{模块}.{元素}.{用途}`（如 `float.button.know`、`import.error.emptyFile`）。

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|---------|
| 85 处替换遗漏导致中英混杂 | 替换后全局扫描 `[一-龥]` 字符串字面量（排除注释/日志/词条表）作为完成门槛 |
| xcstrings 在 CI/命令行构建下的编译行为差异 | 本项目以 Xcode 构建为主，xcstrings 原生支持；如异常降级为双 .strings 文件（机制不变） |
| 语言切换时悬浮窗刷新时序（AppKit 手动刷新） | 复用既有通知模式；文案在需要渲染时才查词（不缓存旧语言字符串），刷新即正确 |
| 存量测试断言依赖中文字面量 | 同步调整断言为查词结果或语义断言 |
| `isFavoritesWordbook` 判定条件变化影响既有行为 | 判定仅去除 name 条件、保留 isSystem，全量测试回归验证 |
| 英文系统存量用户升级后界面突变英文 | 预期行为（跟随系统默认值），proposal 已声明该行为变更 |
