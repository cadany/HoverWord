## Context

当前记忆反馈调度（[ReciteEngine.swift](file:///Users/cadany/Desktop/code/richops/HoverWord/Services/ReciteEngine.swift)）是"feedbackSet 二元集合 + Section 内无限轮次"：

```
sectionQueue: [(wordbookId, sectionIndex, entries)]
advanceMemoryFeedback():
  点认识 → feedbackSet.insert(wordId) → 切下一词
  点不认识 / 超时 → 不入集合 → 切下一词
  轮次走完 → 有未反馈词则新轮仅展示未反馈子集（无限循环）
            → 全反馈才 engineDidCompleteSection → 下一 Section
```

痛点：不认识无限重试卡死 Section；超时与不认识混同；feedbackSet 用完即弃；PRD（每词点过任一反馈即完成）与实现（全认识才完成）长期分歧。

用户已拍板：C2 一步到位（全局复习队列，推翻记忆反馈模式的 Section 流转主体）、✗改↺=「模糊」、超时=「不认识」、独立 ReviewState 实体、最大曝光次数可配置。

引擎既有横切能力（暂停三源合成、发音挂起、通知响应、走马灯调度、进度身份寻址）全部保留复用，本次只动记忆反馈分支。

## Goals / Non-Goals

**Goals**

- 反馈三态化（认识/模糊/不认识），掌握度跨会话留存（ReviewState）
- 记忆反馈模式调度主体改为全局复习队列：到期复习词优先、新词按 Section 分批
- 批次完成 = 全认识或达曝光阈值放行，根治无限卡死
- 走马灯模式零行为变化

**Non-Goals**

- 悬浮窗按键数量不增不减（仍 4 键），仅将原 ✗ 键图标改为 ↺、语义改为「模糊」；「不认识」无独立按键（停留超时自动记录）；不加进度展示
- 不做艾宾浩斯精确曲线（Leitner 5 盒已够 v0.1.2 粒度，PRD 中"记忆算法"属远期规划）
- 不做学习统计报表（cumulativeExposures 先存起来，消费方留待后续）
- 不清理孤儿 ReviewState（词库重导入 = 重置学习记录，数据量每词一条可忽略）
- 不动 PRD 文档以外的问题域（PRD 更新仅列为收尾核对项）

## Decisions

### D1：ReviewState 实体与读写服务

```
ReviewState (Core Data entity, 轻量迁移加表)
  wordId: String              // 唯一索引，对应 WordEntry.wordId
  boxLevel: Int16             // Leitner 盒级 1-5，默认 1
  dueAt: Date                 // 下次到期时间
  lastReviewedAt: Date?       // 最近反馈时间
  lastFeedbackRaw: Int16      // 0=none 1=known 2=vague 3=unknown
  cumulativeExposures: Int32  // 累计曝光（统计预留）
```

- 服务层 `ReviewStateService`：`state(for wordId)`（无则 nil）、`record(feedback:for wordId)`（取或建 + 原子更新 + save）、`dueStates(now)`（dueAt <= now 的记录集）。主上下文读写（引擎单线程消费，无需后台上下文）
- 反馈即落盘：每次 ✓/↺/超时即时 `record`，不等批次/会话结束——崩溃也不丢掌握度
- 不存 wordbookId：wordId 全局唯一，跨词本调度无需来源；来源词本停用后词条不在启用池，自然不参与调度
- 写入 Core Data 而非 UserDefaults：按词寻址、需要谓词查询（dueAt），量级万词级别，Core Data 是既有正解

### D2：会话内调度与跨会话调度分离（SRS 落地的关键简化）

SRS 间隔是天/小时级，而悬浮窗会话是分钟级——两者必须分开表达：

- **会话内**（内存）：用"延迟 N 词重现"表达重试节奏。点击 ↺（模糊）→ 延迟 2 词；超时（不认识）→ 延迟 3 词；认识 → 本会话通过。重现后再反馈按同样规则，曝光计数累加，达 `maxExposureRounds` 放行
- **跨会话**（ReviewState）：用 dueAt 表达复习节奏。每次反馈按盒级重算 dueAt，下次会话（引擎 start）取 dueAt <= now 的词优先入队

由此"间隔=基础×2^盒"只影响跨会话复习计划，会话内流畅性由延迟词数保证，两套参数互不干扰。

### D3：批次模型与 delegate 复用

- **批次构成**：到期复习词（dueAt 升序，超过 sectionSize 分多批）+ 新词补足至 sectionSize。新词判定 = 无 ReviewState 记录
- **批次内顺序**：到期词在前，新词在后（新词按 playOrder，批间新词按 sectionOrder 策略取 Section）
- **批次完成**：批内全部「认识」或全部放行（曝光达标）。完成后构建下一批
- **全队列完成**：无新词 + 无 due + 无待重现 → allComplete
- **delegate 不动**：批次完成复用 `engineDidCompleteSection(batchIndex, estimatedTotalBatches)`——FloatWindowController 既有消费方是空实现，协议稳定成本为零；`engineDidCompleteAll` 语义不变

### D4：SRS 参数定稿（Constants 落地）

反馈触发源（按钮 ↺ / 超时）已按用户拍板对调，调度处置随语义与之对应：

| 反馈 | 触发 | 盒级 | 会话延迟 | 跨会话间隔 |
|---|---|---|---|---|
| 认识 ✓ | 点击 ✓ | box = min(box+1, 5) | 本会话通过 | base(默认 1 天，可调 0.5/1/2 天) × 2^(box-1) → 默认 1/2/4/8/16 天 |
| 模糊 ↺ | 点击 ↺ | box 不变 | 延迟 2 词重现 | 4 小时 |
| 不认识（超时） | 停留超时自动 | box = 1 | 延迟 3 词重现 | 1 小时 |

不认识（超时）给 1 小时短间隔：当天内重启应用即重现；模糊给 4 小时介于两者。认识间隔的"基准天"随 `AppSettings.reviewBaseIntervalDays` 可调（仅作用认识路径，模糊/不认识固定 4h/1h）。常量进 `Constants`，后续调参不动引擎逻辑。

### D5：进度持久化 formatVersion

- 记忆反馈进度改用**专用新键**（`ReciteProgressBatchState`，Codable 存 UserDefaults），与走马灯既有键位隔离。当前版本 `formatVersion: 2`（v1 批次基线；v2 新增会话复习剩余预算，feat04 未发布过 v1，直接以 v2 落地）：`{ formatVersion: 2, batchWordIds: [String], wordStates: {wordId: state}, exposureCounts: {wordId: n}, index: Int, batchIndex: Int, reviewBudgetRemaining: Int? }`
- 引擎进入记忆反馈模式时清除旧记忆反馈键残留（`ReciteProgressFeedbackSet` / `ReciteProgressWordOrder` 等在记忆反馈路径不再读写）；`formatVersion` 缺失或解码失败 → 一次性失效清零（先例：旧索引寻址进度失效）
- 会话内"延迟重现计数"一并入进度，保证重启后恢复到确切单词且重试节奏不断
- 走马灯进度键位与格式不动
- **续背锚点在记忆反馈模式退役**：新词进度由 ReviewState 有无判定（有记录即非新词），中断重启天然延续，锚点机制仅走马灯保留。既有锚点键保留（走马灯用），记忆反馈路径不再读写

### D6：设置项与通知分类

- `AppSettings.maxExposureRounds: Int = 3`（1-10），`StoredSettings` 加可选字段 `maxExposureRounds: Int?`（旧配置 nil → 默认 3，向后兼容先例一致）
- 记忆反馈卡另增两参数（用户拍板补充，缓解"单参数卡过薄"）：`sessionReviewCap: Int = 0`（0-200，0=不限，会话级到期复习预算，随进度持久化）+ `reviewBaseIntervalDays: Double = 1.0`（0.5/1/2 天，仅作用认识间隔），均对应 `StoredSettings` 可选字段、向后兼容 nil → 默认
- 通知分类：属背记规则 → `postDidChange()`（重启引擎重置会话进度），ReviewState 不受影响
- 设置页采用**固定分区**（方案 C，用户拍板）：卡片自上而下按序为 Section 设置（公共）→ 背记模式 → 走马灯 → 记忆反馈；公共"Section 设置"卡只留 Section 词数 / Section 顺序 / Section 内展示顺序；"走马灯循环轮次"独立成卡（一行）、"记忆反馈"成为三行卡（曝光次数 + 会话复习上限 + 复习基础间隔），固定展示、非当前模式整卡禁用 + 0.5 透明度（走马灯卡保持一行，不补参）

### D7：PRD 分歧收口

三套完成语义并存（PRD"点过即算"、实现"无限重试到认识"、新方案"全认识或放行"）以 spec 新语义收口。PRD v0.1 的 L53 表格与 3.2.3 节描述已过时，收尾任务中核对更新 PRD（用户验证时人工确认措辞）。

### D8：「重新开始」与「重置学习记录」双入口（用户拍板：两个入口）

掌握度跨会话积累后，单一"重新开始"语义无法同时满足"换顺序重来"与"彻底重学"两种诉求：

- **重新开始**（`restart()`）：清除会话进度、按策略重排，**不碰 ReviewState**——既有入口语义收窄
- **重置学习记录**（新入口）：`ReviewStateService` 新增 `resetAll()`（批量删除全部记录），引擎暴露 `resetLearningRecord()`（清除 ReviewState + 会话进度 + 按策略重新开始）

入口落位与防误触：

- 仅记忆反馈模式"已学完"状态的右键菜单展示（与"重新开始"出现条件一致 + 模式限定），顺序：重新开始 → 重置学习记录 → 打开设置 → 退出程序；走马灯模式与非完成态不出现——避免背记中途误触毁掉学习史，也避免走马灯用户面对无意义的掌握度概念
- 点击先弹确认对话框（复用删除词本确认样式），提示"将清除全部单词掌握度记录且不可恢复"；取消无副作用
- 菜单项走既有 `FloatMenuTag` 分发模式（新增 tag），确认框由 `FloatWindowController` 承担（引擎不弹 UI）

## Risks / Trade-offs

| 风险 | 说明 | 处置 |
|---|---|---|
| **引擎重写回归面大** | 记忆反馈分支重写涉及进度持久化与恢复校验，既有 149 条测试中记忆反馈相关用例需适配 | 走马灯 / 暂停 / 静音 / 通知响应用例保持全绿作为回归底线；记忆反馈用例按新语义重写并在 tasks 中单列 |
| **due 词动态到期** | "已学完"展示期间 dueAt 陆续到达，引擎不自转（不轮询），需等下次 start | spec 已固化"已学完期间不自行重新调度"（Non-Goal：不做到期轮询唤醒）；用户重启应用或重新开始即触发复习 |
| **分心超时记为不认识** | 用户分心导致的超时会被记为「不认识」（最重处置，回盒 1），而非温和的「模糊」 | 设计意图（用户拍板"超时 = 不认识"）；要温和可主动点 ↺ 记为「模糊」；曝光阈值兜底，不会卡死 |
| **重导入即重置学习记录** | wordId 重生成导致 ReviewState 孤儿化 | 显式取舍（proposal 已点明）；不做孤儿清理，量级可忽略 |
| **批次与 Section 概念混用** | 记忆反馈模式下"Section 词数"被复用为批次大小，用户可能混淆 | UI 不暴露"批次"概念；设置文案维持"Section 词数"不变（同为分批粒度，语义自然延伸） |
| **收藏夹词条的 wordId 稳定性** | 取消收藏再收藏会生成新 favoriteId → 新 wordId，学习记录断档 | 显式取舍，量级极小；不做迁移 |
| **重置入口的模式限定** | "重置学习记录"仅记忆反馈模式"已学完"展示；走马灯模式背完（已学完）时无重置入口——走马灯本无掌握度，属预期；切回记忆反馈模式后入口恢复 | spec 显式限定 + tasks 手动验收覆盖 |
| **记忆反馈已学完后"重新开始"可能无感** | 保留掌握度的重新开始仅在有到期词时产生复习会话，无到期词时维持已学完展示 | spec 显式固化该行为（"已学完状态重新开始无到期词"场景），避免实现与验收困惑 |
