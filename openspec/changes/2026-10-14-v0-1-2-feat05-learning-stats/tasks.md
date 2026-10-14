# Tasks: 学习统计 Tab

## 1. Service 层

- [ ] 1.1 `Shared/NotificationNames.swift` 新增 `reviewStateDidChange`
- [ ] 1.2 `ReviewStateService`：`record()` / `resetAll()` 落盘后发送 `reviewStateDidChange`
- [ ] 1.3 `ReviewStateService.masterySummary(wordbookIds:)` 聚合查询：三态计数、待复习（dueAt ≤ now 且词条在启用词库）、累计曝光（Σ cumulativeExposures）、最近学习（max lastReviewedAt）；单次 fetch + 内存 join
- [ ] 1.4 `ReciteEngine` 抽出只读锚点状态判定（`none / valid(name, sectionIndex) / wordbookMissing / wordbookDisabled / sectionInvalid`），restore 失效判定改调同一接口（行为不变）
- [ ] 1.5 `xcodegen generate`（新增 StatsView.swift）

## 2. UI

- [ ] 2.1 `SidebarItem` 新增 `.learningStats`（`chart.bar.fill`，背记之后，第 3 位）
- [ ] 2.2 `StatsView.swift`：主视图按 `reciteMode` 分支；监听 `reviewStateDidChange` + `.appSettingsDidChange` + `onAppear` 刷新
- [ ] 2.3 状态 A：掌握度总览卡（三态堆叠条 + 待复习 + 累计曝光）+ 词本掌握卡（含已学完徽标、最近学习、待复习）+ 走马灯历史折叠行
- [ ] 2.4 状态 B：背记进度卡（合流进度条 + 副标题）+ 锚点行（统一显示词本名）+ 锚点异常/空态 + 历史掌握度折叠行
- [ ] 2.5 `?` popover 口径说明（D5 定稿文案）
- [ ] 2.6 设置窗口导航接入（SettingsWindowController/主视图 switch 分支）

## 3. L10n

- [ ] 3.1 `Localizable.xcstrings` 新增统计键（sidebar 项、卡片标题、图例、四术语、锚点行/异常/空态、popover 全文案，zh + en；4 空格缩进、diff 最小化、displayName 计算属性）
- [ ] 3.2 `openspec/specs/terminology.md` 补入四术语基线

## 4. 测试

- [ ] 4.1 `ReviewStateService` 聚合：三态计数边界（box5/1-4/无记录）、待复习口径（dueAt 过去/未来/nil）、孤儿 wordId 排除、空词库
- [ ] 4.2 锚点判定矩阵：nil / 词本删除 / 词本停用 / 有效 / Section 无词条
- [ ] 4.3 `record()` / `resetAll()` 触发 `reviewStateDidChange`
- [ ] 4.4 restore 行为回归（锚点判定重构不改变现有持久化测试结果）

## 5. 验证与收尾

- [ ] 5.1 沙箱构建通过；openspec validate --strict；schema 版本自检
- [ ] 5.2 用户本机 Xcode 全量测试通过
- [ ] 5.3 手动验收：两模式切换 Tab 主视图跟随；反馈后统计实时刷新；多选/单选词本锚点行；停用/删除锚点词本后的异常行；首次安装空态；popover 文案
- [ ] 5.4 用户验证通过后归档
