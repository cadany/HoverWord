---
baseline_version: "v0-1-1"
change_sub_version: "v0-1-1-patch02"
---

## Why

全项目深度代码 review（9492 行，双路子代理交叉验证）发现 12 项问题：4 项 Major（导入后收藏同步竞态导致已删词条持续被背诵；buildQueue N+1 查询在万级词库下每次设置变更触发 500+ 次主线程 fetch；全屏自动隐藏后 TTS 每 5 秒持续朗读违背低干扰原则；Core Data store 损坏时 fatalError 形成永久崩溃循环）与 8 项 Minor（孤儿收藏、语言字面量散落、死状态、陈旧注释、静默失败、错误类型误用、重复查询、文件超限）。1 项候选经验证为误报剔除（导入解析阻塞主线程）。

## What Changes

**Major 修复（4 项）**

- 收藏同步竞态：`syncFavoritesAfterImport` 改 async，`await context.perform` 收藏删除落库完成后再发 `favoritesDidChange`，引擎重建队列读到的一定为已删除后的收藏
- 队列构建 N+1：新增 `WordbookService.getAllEntriesGroupedBySection(for:)` 单次 fetch + 内存分组，`ReciteEngine.buildQueue` 改用之；万级词库从 501 次主线程 fetch 降为每词本 1 次，排序口径与原逐 Section 查询一致
- 全屏静音（**新功能，用户裁决方案**）：背记设置"其他"卡片新增"全屏隐藏时静音发音"开关（默认开启，未启用全屏隐藏时置灰）；引擎新增 `setSpeechSuppressed(_:)` 挂起标志——全屏隐藏悬浮窗时停止在播语音并挂起后续自动发音，切词进度照常流转保进度，恢复显示自动解除
- store 损坏自愈：`DataStack` 加载失败时 NSLog + 销毁 store 重建重试（词库丢失但应用可用），仍失败才 fatalError；改同步加载确保自愈在启动返回前完成

**Minor 修复（7 项，文件拆分 1 项经用户裁决跳过）**

- 删除词本清理孤儿收藏：`deleteWordbook` 级联删除前快照 sourceWord，无其他词本包含的收藏一并移除并补发通知（对齐 `deleteEntry` 语义）
- 语言字面量统一：4 处 `"en"`/`"zh-Hans"` 散落字面量改用 `Constants.defaultSourceLang/defaultTargetLang`
- 删除死状态 `wordsPlayedInCurrentLoop`（只写不读，4 处）
- 更新 `DataStack` "骨架实现、模型未创建"陈旧注释
- `AppSettings.load` 解码失败 NSLog 留诊断线索（不再与"无历史数据"混同静默）
- `ImportError.wordbookMissing` 专用 case，消灭"第 0 行格式错误"魔法行号
- 新增 `WordbookService.getStats(for:)` 合并查询，设置页列表刷新时收藏夹 count 从 2 次降 1 次

## Capabilities

### New Capabilities

（无新增能力）

### Modified Capabilities

- `recite-engine`: 队列构建改单次查询；新增全屏静音挂起（发音挂起不影响切词进度）
- `speech`: 全屏隐藏期间挂起自动发音，恢复显示后随下一个单词自然恢复
- `core-data`: store 加载失败自愈（销毁重建），仅重建仍失败才终止
- `wordbook`: 删除词本清理孤儿收藏；导入错误类型区分"词本不存在"；设置持久化解码失败留诊断日志；列表统计合并查询
- `settings-window`: 背记"其他"卡片新增全屏静音开关

## Impact

### 影响文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Services/WordbookService.swift` | 修改 | 竞态修复（await 时序）、`getAllEntriesGroupedBySection`、`deleteWordbook` 孤儿收藏清理、`getStats`、字面量统一 |
| `Services/ReciteEngine.swift` | 修改 | `buildQueue` 单次查询、`isSpeechSuppressed`/`setSpeechSuppressed`、删除死状态、字面量统一 |
| `Features/FloatingWindow/FloatWindowController.swift` | 修改 | 隐藏路径停止语音 + 挂起、显示路径解除挂起、字面量统一 |
| `Services/DataStack.swift` | 修改 | store 自愈 + 同步加载 + 陈旧注释更新 |
| `Models/AppSettings.swift` | 修改 | `muteSpeechInFullscreen` 字段（含向后兼容解码）、load 解码日志 |
| `Services/WordbookImportService.swift` | 修改 | `wordbookMissing` case |
| `Features/Settings/ReciteSettingsView.swift` | 修改 | 全屏静音 Toggle（联动置灰） |
| `Features/Settings/WordbookTabView.swift` | 修改 | refreshList 改用 `getStats` |
| `Resources/Localizable.xcstrings` | 修改 | `recite.muteInFullscreen` 中英词条 |

### 行为细节（review 阶段已确认）

- 全屏静音仅拦新播报不停引擎（进度不受影响），用户裁决"在背记的其它里边加一个'全屏时静音'的选项，默认勾选"
- 静音开关未启用全屏隐藏时置灰（依赖前置开关）
- `WordbookTabView` 695 行超 500 行规范，用户裁决跳过拆分，留档后续
- store 自愈的代价是词库丢失（设置不受影响，存 UserDefaults），spec 明示
