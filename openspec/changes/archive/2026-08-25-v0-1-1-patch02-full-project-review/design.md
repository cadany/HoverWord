# Design: 全项目 review 修复（竞态/性能/全屏静音/自愈）

## Context

全项目深度 review（双路子代理独立验证 13 项候选，12 项确认 1 项误报剔除）暴露四类 Major 问题：通知早于落库的竞态、主线程 N+1 查询、全屏隐藏后 TTS 打扰、store 损坏永久崩溃。修复方案均经用户裁决（全屏静音走设置开关方案）。

## Goals / Non-Goals

- Goals: 消除竞态与崩溃循环、队列构建降为每词本 1 次查询、全屏期间静音但保进度、Minor 一致性问题一并清理
- Non-Goals: 不拆分超限文件（用户裁决跳过）、不给 Core Data 模型加索引（避免新模型版本）、不重构引擎状态机

## Decisions

### D1: 竞态修复——await 时序而非延迟通知

`syncFavoritesAfterImport` 改 async：`await context.perform {...}` 天然等待后台队列执行完毕，落库完成后 `await MainActor.run` 发通知。对比 `DispatchQueue.main.asyncAfter` 延迟方案：无竞态窗口、时序由结构保证而非延时猜测；对比合并到单一通知：语义清晰，收藏/内容两类通知职责不变。原注释声称的"主队列 FIFO 保证 content 通知最后到达"经证伪——它只保证两个通知间的顺序，不保证通知晚于收藏落库。

### D2: N+1 修复——单次 fetch + 内存分组，不加模型索引

`getAllEntriesGroupedBySection` 单次取词本全部词条（sort: sectionIndex → orderIndex → sourceWord，与原 `getEntries` 口径一致），内存按 sectionIndex 分桶。备选的模型加索引（wordbookId/sectionIndex indexes）需新建模型版本 + 迁移，收益重叠——单次查询后索引仅加速 WHERE，不再有 N 次往返，故不引入模型版本。收藏夹路径：一次取全部 Favorite 按 sectionSize 分桶，`sectionIndex` 由分桶位置推导（与原分页查询 offset 语义一致）。

### D3: 全屏静音——挂起标志，不停引擎

引擎 `isSpeechSuppressed` 标志仅在 `displayCurrentWord` 的自动发音分支拦截，Timer/轮次/进度全部照常。对比停引擎方案（`engine.stop()`）：停引擎丢状态、恢复需 restart 或复杂恢复逻辑；挂起方案显示恢复后下一个单词自然恢复发音，零恢复成本。开关依赖"全屏自动隐藏"（未启用时置灰），默认开启。手动点喇叭按钮不受挂起影响（用户显式操作优先）。

### D4: store 自愈——销毁重建，明示数据代价

加载失败 → `destroyPersistentStore` → 二次 `loadPersistentStores`，仍失败才 fatalError。改 `shouldAddStoreAsynchronously = false` 同步加载，确保自愈在 `initialize()` 返回前完成（否则 viewContext 可能在未加载 store 的容器上工作）。代价：词库丢失（设置在 UserDefaults 不受影响）。触发概率低（store 损坏/迁移失败罕见），但原 fatalError 模式一旦触发即永久崩溃循环，用户无法自愈。

### D5: 孤儿收藏——快照 + 既有谓词复用

`deleteWordbook` 在 `context.delete` 前快照全部 sourceWord（级联删除后不可再查），复用 `anyOtherWordbookContains` + `removeFavorites` 与 `deleteEntry`/导入同步完全同构的清理语义，补发 `favoritesDidChange`。

## Risks / Trade-offs

- store 自愈丢词库：罕见场景下的可用性 > 数据保留，spec 明示；NSLog 留诊断线索
- 全屏静音默认开启改变既有行为（原先隐藏后继续朗读）：默认值经用户裁决；偏好自动发音的用户可关
- 单次全量 fetch 万级词库内存瞬时峰值 ~10MB 级（WordEntry 轻量字段），远低于 100MB 约束；换来 500 次 fetch 往返消除
- `getStats` 对普通词本仍是两次查询（count + max sectionIndex）：进一步合并需聚合查询或全量 fetch，词本数小收益低，不做

## Migration Plan

`muteSpeechInFullscreen` 以 Optional 解码向后兼容（旧存储无此字段 → 默认 true），无数据迁移。其余修复均为行为修正，无存量数据影响。

## Open Questions

无。
