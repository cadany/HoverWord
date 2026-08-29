# spec.md — recite-engine delta

## MODIFIED Requirements

### Requirement: Section 队列构建
系统从启用单词本按词本顺序 × Section 索引升序构建确定性基础队列，随后按用户配置的 Section 顺序策略（`sectionOrder`）应用于队列：

- `sequential`（默认）：队列即基础队列，按序推进
- `randomStart`：新开始时随机选起点 Section，队列 rotate 至该起点，之后顺序推进（环形语义）
- `shuffled`：新开始时打乱全部 Section 顺序

策略仅在"新开始"（无有效进度冷启动 / restart / 进度校验失败回退 / 续背新轮）时执行随机化；恢复进行中进度时按确定性规则重建基础队列并套用保存的队列布局。单 Section 队列（含收藏夹单词本）时 randomStart/shuffled 退化为 sequential。

#### Scenario: 单个单词本启用
- **WHEN** 单个单词本启用且含多个 Section
- **AND** sectionOrder 为 sequential
- **THEN** 队列 SHALL 按词本内 Section 索引升序构建

#### Scenario: 随机起点
- **WHEN** sectionOrder 为 randomStart
- **AND** 无有效进度的新开始
- **THEN** 队列 SHALL 为基础队列按随机起点的 rotate 结果；背到末尾后 SHALL 环形绕回起点前的 Section

#### Scenario: 随机打乱
- **WHEN** sectionOrder 为 shuffled
- **AND** 无有效进度的新开始
- **THEN** 队列 SHALL 为基础队列的随机排列，全部 Section 均出现且仅出现一次

#### Scenario: 单 Section 退化
- **WHEN** 队列仅含一个 Section（如收藏夹单词本）
- **THEN** 任意策略下队列 SHALL 等价于基础队列（无随机空间）

#### Scenario: 万级词库构建队列
- **WHEN** 启用词库含 10000 词条（约 500 Section）
- **THEN** 含策略应用的队列构建 SHALL 保持 O(n) 复杂度，满足性能预算

#### Scenario: 策略变更重置
- **WHEN** 背记进行中修改 sectionOrder 设置
- **THEN** SHALL 清除进度并按新策略重新开始（走既有设置变更重置路径）

#### Scenario: 单词本顺序调整 / 收藏夹队列构建 / 无单词本启用
既有场景不变（见主 spec），仅基础队列构建语义叠加策略应用。

### Requirement: 背记进度持久化
进度以身份寻址持久化：当前 Section 以 `(wordbookId, sectionIndex)` 标识，Section 内顺序以 wordId 列表标识，队列布局（randomStart 的起点身份 / shuffled 的完整身份列表）随进度保存。恢复时按确定性规则重建基础队列、套用保存的布局、按身份定位当前 Section。旧版本索引寻址的进度数据 SHALL 检测失效并清零（一次性迁移代价）。

#### Scenario: 重启后恢复进度
- **WHEN** 退出时保存了进行中进度
- **THEN** 重启后 SHALL 恢复到确切 Section 与Section 内顺序（含随机策略下的布局还原）

#### Scenario: 顺序数据与当前词库不匹配时回退
- **WHEN** 保存的Section 内顺序 wordId 在当前词库中缺失
- **THEN** SHALL 清除进度从策略起点新开始（既有回退语义）

#### Scenario: 身份失效回退
- **WHEN** 恢复时保存的 Section 身份或布局身份不在重建队列中（词本停用/删除）
- **THEN** SHALL 清除进度并按当前策略新开始（重新随机化）

#### Scenario: 词本启停顺序变化不错位
- **WHEN** 进度保存后词本启停或词本列表顺序调整导致队列索引漂移
- **THEN** 身份寻址恢复 SHALL 定位到与保存时相同的 Section（原索引寻址行为的修复）

#### Scenario: 旧版本进度数据一次性失效
- **WHEN** 升级后首次启动检测到旧索引格式进度
- **THEN** SHALL 视为无效清零，从当前策略起点开始

#### Scenario: 背记过程中保存进度 / 已反馈单词在恢复后不重复出现 / 收藏夹单词本启用时恢复到确切单词 / 进度与当前配置不匹配时回退
既有场景不变（见主 spec），存储格式换为身份寻址。

### Requirement: 全队列完成检测

#### Scenario: 所有 Section 完成
- **WHEN** 队列最后一个 Section 完成
- **THEN** 引擎 SHALL 进入 allComplete 状态并记录续背锚点（进度不再清零）

#### Scenario: 已学完状态可重新开始
- **WHEN** 处于 allComplete 状态
- **THEN** 用户点击重新开始 SHALL 清除续背锚点与全部进度，按当前策略从策略起点开始

#### Scenario: 完成全部单词后清除进度
（删除：被续背锚点语义取代——完成后进度保留为锚点，restart 时清除）

#### Scenario: 手动重新开始清除进度
既有语义不变，扩展为同时清除续背锚点。

## ADDED Requirements

### Requirement: 完成后续背循环
全部 Section 完成时记录续背锚点（最后完成 Section 的身份）；下次会话 start() 检测到锚点时，SHALL 从锚点的下一 Section（环形绕回）继续新的一轮，而非从策略起点重来。`restart()` 显式清除锚点从策略起点开始。

#### Scenario: 一轮完成后继续
- **WHEN** 全部 Section 完成后应用重启（或再次 start）
- **THEN** 新一轮 SHALL 从最后完成 Section 的下一 Section 开始

#### Scenario: 最后一个 Section 完成后绕回
- **WHEN** 最后完成的是队列中最后一个 Section
- **THEN** 新一轮 SHALL 从队列第一个 Section 开始（环形）

#### Scenario: 重新开始清除续背
- **WHEN** 用户点击重新开始
- **THEN** SHALL 清除续背锚点与全部进度，按当前策略新开始（重新随机化）
