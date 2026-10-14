> Change-Sub-Version: v0-1-2-feat05

## ADDED Requirements

### Requirement: 学习统计只读查询

引擎与 ReviewState 服务 SHALL 向学习统计页提供只读查询能力：

- **掌握度聚合**：按词本聚合三态计数（已掌握 = boxLevel 达到上限 5、进行中 = 1-4、未学 = 无 ReviewState 记录）、待复习词数（dueAt 不晚于当前时间且词条属于查询范围内词库）、累计曝光（Σ cumulativeExposures）与最近学习时间（max lastReviewedAt）。聚合 SHALL 单次取全量 ReviewState 后在内存按 wordId 与词条集合 join；词条已删除的孤儿 ReviewState 记录 SHALL 被排除。聚合范围由调用方指定（学习统计页传当前启用词本）。
- **续背锚点状态判定**：提供只读锚点状态查询，判定结果 SHALL 覆盖：无锚点 / 锚点有效（词本启用且 Section 存在）/ 锚点词本已删除 / 锚点词本未启用 / 锚点词本启用但该 Section 已无词条。该判定 SHALL 与走马灯进度恢复（restore）的锚点失效判定为同一实现，SHALL NOT 出现两套口径。统计查询路径 SHALL NOT 清除锚点、SHALL NOT 写入任何引擎状态——锚点失效的清除仍仅由引擎 restore 路径执行。
- **变更通知**：ReviewState 的任一写入（三态反馈落盘）与重置学习记录完成后，系统 SHALL 发送 `reviewStateDidChange` 通知；该通知 SHALL NOT 携带引擎重启副作用（背记引擎的调度不因该通知变化）。

#### Scenario: 掌握度聚合口径

- **WHEN** 学习统计页请求某启用词本的掌握度聚合
- **THEN** 系统 SHALL 返回该词本三态计数、待复习词数、累计曝光与最近学习时间；boxLevel 5 计入已掌握、1-4 计入进行中、无记录计入未学，孤儿记录不计入

#### Scenario: 待复习口径与引擎一致

- **WHEN** 学习统计页计算待复习词数
- **THEN** 判定口径（dueAt ≤ 当前时间且词条属于启用词库）SHALL 与引擎全局复习队列的到期词取数口径一致

#### Scenario: 锚点判定与恢复同源

- **WHEN** 走马灯进度恢复与学习统计页分别对同一锚点做有效性判定
- **THEN** 两者 SHALL 得出相同结果（同一判定实现），统计页 SHALL NOT 因此清除或修改锚点

#### Scenario: 反馈触发统计通知

- **WHEN** 记忆反馈模式下任一反馈写入 ReviewState（认识 / 模糊 / 超时不认识）或用户重置学习记录完成
- **THEN** 系统 SHALL 发送 `reviewStateDidChange`，引擎调度 SHALL NOT 因该通知发生任何变化

#### Scenario: 统计查询无副作用

- **WHEN** 学习统计页在引擎播放中调用掌握度聚合与锚点状态查询
- **THEN** 引擎当前单词、进度、锚点与调度状态 SHALL 全部保持不变
