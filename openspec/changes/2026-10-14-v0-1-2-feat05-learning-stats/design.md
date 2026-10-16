# Design: 学习统计 Tab

## 上下文

feat04 落地 ReviewState（boxLevel/dueAt/lastReviewedAt/lastFeedbackRaw/cumulativeExposures）后掌握度数据只服务调度，无可视化。本设计在设置窗口新增统计 Tab，读侧消费既有数据，悬浮窗零改动（用户定稿：绝对纯净）。

## Decisions

### D1 主视图跟随全局模式（方案 2）

主区块由 `AppSettings.reciteMode` 决定：记忆反馈 → 掌握度卡；走马灯 → 背记进度卡。另一维度降级为折叠汇总行。

理由：回答用户「我现在学得怎么样」；冻结数据并列展示会被误读为实时；与设置页既有「界面反映当前模式」交互语言一致（背记规则 Tab 模式联动禁用卡的先例）；卡片轻量。

### D2 状态 A：掌握度（记忆反馈模式）

- **掌握度总览卡**：启用词本范围内聚合——三态堆叠条（已掌握 boxLevel≥5 / 进行中 1-4 / 未学 无记录）+ 图例计数 + 两指标块：待复习（dueAt ≤ now 词数，警示色）、累计曝光（Σ cumulativeExposures）
- **词本掌握卡**（每启用词本一张）：词本名 + 词数 + 已学完徽标（全部词 boxLevel≥5 时显示，复用引擎判定语义）；三态堆叠条 + 图例；meta 行「最近学习 〈相对时间〉 · 待复习 N」（待复习为 0 时不显示该段）
- **走马灯历史折叠行**：无 ReviewState 记录的启用词本显示一行「〈词本名〉 · N 词 · 历史背记进度：上次背完 Section X / 共 Y」（数据来自续背锚点）；既无掌握度又无锚点时显示「未开始」

### D3 状态 B：背记进度（走马灯模式）

- **背记进度卡**（单卡）：进度条 = 合流 Section 队列进度（复用 `currentSectionPosition()` 的 `(index, total)`，跨词本连续计数）+「已完成 N / 共 M 个 Section」；引擎处于有效走马灯位置时另显示「正在背：Section N+1 · 第 X / Y 词」明细行；副标题「已启用 K 个词本 · 合流 M 个 Section」
- **实时刷新**：走马灯推进属高频事件（NotificationNames 约定高频不广播通知），统计页经 `TimelineView` 每秒轮询引擎只读快照 `CarouselProgressSnapshot`（经 FloatWindowController 透出，不暴露引擎实例）——词级推进、Section 切换、引擎重启归零、一轮完成绕回均在 1 秒内自动反映；空态卡仅在引擎无有效位置时显示，避免背记进行中误导「还没有进度」（2026-10-15 用户验收反馈迭代：大半天推进后统计仍显示打开时刻快照 0/300，根因为刷新缺失而非引擎缺陷——引擎存档证明位置在 Section 15）
- **锚点行**：「上次背完：〈词本名〉 · Section N」——词本名按续背锚点 `SectionIdentity(wordbookId)` 反查 Core Data 得到；单选词本时统一显示词本名（用户定稿，不省略）
- **锚点状态判定矩阵**（与引擎 restore 同源，见 D4）：

| 锚点 | 反查结果 | 显示 |
| --- | --- | --- |
| nil | — | 空态卡「还没有背记进度 / 背完一个 Section 后，这里会显示进度」 |
| 有 | 词本不存在 | 「上次背完的词本已删除」 |
| 有 | 词本存在但未启用 | 「上次背完的词本已停用」 |
| 有 | 词本启用且 Section 有效 | 「上次背完：〈词本名〉 · Section N」 |
| 有 | 词本启用但 Section 无词条 | 归入空态（与引擎失效回退一致） |

- **历史掌握度折叠行**：有 ReviewState 记录的词本显示「〈词本名〉 · 历史掌握度：已掌握 X · 进行中 Y · 未学 Z」

### D4 锚点判定与引擎同源

引擎 `start()` 的 restore 路径已实现锚点解码 → 队列定位 → 失效清除。统计页若另写判定必然漂移。本变更在 `ReciteEngine` 抽出**只读**锚点状态查询（输入：锚点 + 当前启用词库；输出：枚举 `none / valid(wordbookName, sectionIndex) / wordbookMissing / wordbookDisabled / sectionInvalid`），restore 失效判定与统计页共同调用；统计页只读，SHALL NOT 清除锚点、SHALL NOT 写引擎状态（清除仍由引擎 restore 路径负责）。

### D5 口径说明 popover

页标题旁 `?` 按钮 → popover。内容（定稿文案，用户侧无实现隐喻，「盒」禁用）：

- 已掌握：累计 5 次复习点「认识」，即完全记住
- 进行中：已开始背记，还没达到 5 次「认识」
- 未学：尚未在记忆反馈模式下背过
- 待复习：距下次复习的间隔已到，下次背记优先出现
- 说明：每次点「认识」都会拉长下次复习的间隔（最长 16 天）；点「模糊」间隔不变；超时或不认识会缩短间隔。已掌握的词仍会定期重现巩固，悬浮窗对所有词显示一致，重现属正常巩固
- 数据边界：掌握度数据仅在记忆反馈模式下产生与更新

### D6 待复习口径（定稿）

待复习 = ReviewState 中 `dueAt ≤ 当前时间` 且词条属于当前启用词库的词数——与引擎全局复习队列取数口径（`dueStates(at:)`）完全一致，所见即引擎所为。不采用「今日到期」（含未来到期词，与队列对不上）。

### D7 数据与刷新

- `ReviewStateService` 新增聚合查询 `masterySummary(wordbookIds:)`：单次 fetch 全量 ReviewState + 词本词条 wordId 集合，内存 join 出每词本/总览三态计数、待复习、累计曝光、最近学习；1 万词毫秒级，满足性能硬约束
- 新通知 `reviewStateDidChange`：`record()` 与 `resetAll()` 落盘后发送；统计 Tab 监听 + `onAppear` 主动刷新
- 聚合范围 = 当前启用词本（含收藏夹启用时）；停用词本不进总览
- 统计路径只读：SHALL NOT 写 ReviewState / 进度 / 锚点

### D8 实现载体

`Features/Settings/StatsView.swift` 新文件（预估 <500 行；超限拆 StatsView + StatsCards）。SidebarItem 增加 `.learningStats`（图标 `chart.bar.fill`，位置：背记之后）。堆叠条用 HStack + Capsule 自绘（不引入 Swift Charts：风格融合差、非必要）。L10n 新键约 25 条，`displayName` 一律计算属性。

## 术语（定稿）

已掌握 / 进行中 / 未学 / 待复习；「Section」沿用 terminology.md 不翻译。实施时将四术语补入 `openspec/specs/terminology.md` 基线表。

## Risks

| 风险 | 缓解 |
| --- | --- |
| 锚点判定与引擎 restore 漂移 | D4 单一共享判定接口，引擎为真源 |
| 聚合查询在大词库卡顿 | 单次 fetch + 内存 join；需求 ≤100ms |
| 孤儿 ReviewState（词条已删）虚增计数 | join 时按 wordId 匹配自然排除；孤儿清理列为范围外后续项 |
| 模式切换瞬间 Tab 显示旧状态 | 监听 `.appSettingsDidChange` 同步刷新主视图分支 |

## 范围外（仅记录）

词级下钻列表、历史趋势图（需 ReviewLog v5）、ReviewState 孤儿一致性清理、走马灯轮次完成度展示（循环轮次完成数未持久化）。
