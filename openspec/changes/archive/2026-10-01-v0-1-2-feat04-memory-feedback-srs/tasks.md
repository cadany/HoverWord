## 1. Core Data：ReviewState 实体

- [x] 1.1 数据模型新增 ReviewState 实体（wordId 唯一索引、boxLevel Int16 默认 1、dueAt Date、lastReviewedAt Date 可空、lastFeedbackRaw Int16 默认 0、cumulativeExposures Int32 默认 0），确认轻量迁移加表
- [x] 1.2 新增 `Services/ReviewStateService.swift`：`state(for:)`、`record(feedback:for:)`（取或建 + 原子更新 + save）、`dueStates(now:)`（dueAt <= now）
- [x] 1.3 生成 NSManagedObject 子类并接入 xcodegen（`xcodegen generate` 后构建验证）

## 2. 常量与设置

- [x] 2.1 `Shared/Constants.swift` 新增 SRS 常数：baseInterval（1 天）、模糊间隔（4 小时）、不认识间隔（1 小时）、盒级上限 5、曝光次数默认值 3 与边界 1-10、会话重试延迟（不认识 3 词 / 模糊 2 词）
- [x] 2.2 `Models/AppSettings.swift` 新增 `maxExposureRounds: Int = 3`，`StoredSettings` 加可选字段 `maxExposureRounds: Int?`（nil → 默认 3），save/apply 同步
- [x] 2.3 设置页背记 Tab 改**固定分区**：卡片自上而下按序为 Section 设置（公共）→ 背记模式 → 走马灯 → 记忆反馈；公共"Section 设置"卡移除"走马灯循环轮次"行；新增"走马灯"卡（承载循环轮次，仅走马灯模式可交互）与"记忆反馈"卡（承载三行：单词最大曝光次数 / 会话复习上限 / 复习基础间隔）；两专属卡固定展示、非当前模式整卡禁用 + 0.5 透明度；变更走 `postDidChange()`
- [x] 2.4 `Resources/Localizable.xcstrings` 新增词条（4 空格缩进固定键序、diff 最小化）：`recite.memoryFeedback`（记忆反馈 / Memory Feedback）、`recite.maxExposureRounds`（单词最大曝光次数 / Max Exposures per Word）、`recite.carousel`（走马灯 / Carousel，若分区卡标题需独立词条）
- [x] 2.5 `Shared/Constants.swift` 新增 `sessionReviewCap`（默认 0，边界 0-200，0=不限）与 `reviewBaseIntervalDays`（选项 0.5/1/2 天，默认 1.0）
- [x] 2.6 `Models/AppSettings.swift` 新增 `sessionReviewCap: Int = 0` 与 `reviewBaseIntervalDays: Double = 1.0`，`StoredSettings` 加可选字段（nil → 默认），save / apply 同步，向后兼容
- [x] 2.7 设置页记忆反馈卡新增"会话复习上限"Stepper（0-200，0 显示"不限"）与"复习基础间隔"分段 Picker（0.5/1/2 天），均 clamp + postDidChange，非当前模式禁用置灰
- [x] 2.8 `Resources/Localizable.xcstrings` 新增 4 词条：`recite.sessionReviewCap`（每次会话复习上限 / Review Words per Session）、`recite.reviewBaseInterval`（复习基础间隔 / Review Base Interval）、`recite.unlimited`（不限 / Unlimited）、`recite.dayUnit`（天 / day(s)）

## 3. 引擎：记忆反馈分支重写

- [x] 3.1 新增反馈三态模型（known / vague / unknown）与统一反馈入口：✓ = known（点击）、↺ = vague（点击）、超时 = unknown（timerFired 记忆反馈分支自动记录）
- [x] 3.2 反馈统一入口：按 D4 规则更新 ReviewState（认识升盒重算 dueAt / 模糊盒级不变 / 不认识回盒 1），即时落盘；会话内曝光计数累加
- [x] 3.3 全局复习队列构建：到期复习词（dueStates 按 dueAt 升序）+ 新词（无 ReviewState，按 sectionOrder/playOrder 组织，每批 sectionSize）；批次内到期词在前新词在后
- [x] 3.4 会话内延迟重现：不认识延迟 3 词、模糊延迟 2 词的重现计数器；取词优先级 = 到期重现词 > 批内新词；放行判定 = 曝光计数 >= maxExposureRounds
- [x] 3.5 批次完成与流转：批内全部认识或放行 → `engineDidCompleteSection(batchIndex, estimatedTotalBatches)` → 构建下一批；无新词 + 无 due + 无待重现 → `allComplete`（不写走马灯续背锚点）
- [x] 3.6 进度持久化新格式（formatVersion: 2）：批次词单 + 会话状态（待展示/待重现计数/已通过/已放行）+ 曝光计数 + 批次序号 + 会话复习剩余预算 `reviewBudgetRemaining: Int?`；恢复校验（wordId 存在于启用词库、状态合法、计数不越界、预算负数归 0）失败回退重建；旧格式（无 formatVersion）清零失效
- [x] 3.7 记忆反馈路径退役续背锚点读写（锚点键保留供走马灯）；`restart()` 记忆反馈模式下仅清会话进度、保留 ReviewState
- [x] 3.8 回归核对横切能力不受影响：暂停三源合成、发音挂起、`appTimingDidChange` 热更新、词本/收藏/内容变更通知响应、悬停暂停等在记忆反馈新分支下语义不变

## 4. 悬浮窗：反馈键图标改造 + 重置学习记录入口

- [x] 4.0 反馈键改造：原 ✗（unknownButton）图标改为 ↺、`toolTip` 关联词条由「不认识」改为「模糊」；`unknownTapped` 逻辑改为标记 vague；超时路径（timerFired）改为标记 unknown；按键数量仍 4 键（♡ ▶ ✓ ↺）
- [x] 4.1 `FloatMenuTag` 新增 `resetLearningRecord` tag；右键菜单仅记忆反馈模式"已学完"状态插入"重置学习记录"项（"重新开始"之后、"打开设置"之前），走马灯模式与非完成态不出现
- [x] 4.2 `ReviewStateService` 新增 `resetAll()`（批量删除全部 ReviewState）；`ReciteEngine` 新增 `resetLearningRecord()`（清 ReviewState + 会话进度 + 按策略重新开始）
- [x] 4.3 确认对话框：点击菜单项先弹确认（提示清除全部掌握度且不可恢复，样式复用删除词本确认），确认调用 `resetLearningRecord()`，取消无副作用
- [x] 4.4 `Resources/Localizable.xcstrings` 新增"重置学习记录"菜单项、确认弹窗词条、以及「模糊」按钮 toolTip 词条（zh / en，4 空格缩进固定键序、diff 最小化）

## 5. 测试（用户本机 Xcode 运行）

- [x] 5.1 `ReciteEngineSrsTests`（新增）：认识升盒与间隔、模糊盒级不变、不认识回盒 1、反馈即时落盘、due 词优先入队、due 不足补新词、due 超一批分批、批次完成判定（全认识/放行）、无词可调度进入已学完
- [x] 5.2 放行与重现：曝光达阈值放行且本会话不再出现、阈值=1 单次展示、重现延迟计数（3 词/2 词）、重现后再反馈按规则处理、模糊后认识即通过
- [x] 5.3 进度持久化：新格式保存恢复到确切单词、会话状态恢复不重复展示、wordId 失效回退、旧格式一次性失效清零、记忆反馈不写锚点
- [x] 5.4 ReviewStateService：首次创建、原子更新不重复、到期查询谓词、孤儿记录不参与调度不崩溃、`resetAll()` 清空后全部词条回到新词
- [x] 5.5 设置兼容：StoredSettings 旧 JSON（无 maxExposureRounds）解码后默认 3
- [x] 5.6 回归：走马灯既有用例全绿、暂停/静音/通知响应用例全绿；记忆反馈旧用例按新语义重写
- [x] 5.7 重置学习记录：确认后 ReviewState 全清 + 全部回新词 + 重新开始、取消无副作用、非完成态菜单无该项

## 6. 验证与收尾

- [x] 6.1 `xcodegen generate` + 沙箱构建通过，无新增编译告警
- [x] 6.2 全量测试通过（用户本机 Xcode），记录用例数
- [x] 6.3 手动验收：真实词本背一轮（认识/不认识/超时混合）、中途退出重启恢复、次日到期词复习优先、曝光阈值放行、走马灯模式行为不变、设置页曝光次数行走马灯模式下禁用、"已学完"状态重置学习记录确认/取消
- [x] 6.4 跑 schema 落盘自检（baseline_version / change_sub_version 与 MARKETING_VERSION 派生值一致）
- [x] 6.5 `openspec validate` 通过后交用户验证；验证通过后收口 PRD v0.1 中过时的完成条件描述（L53 表格、3.2.3 节）
