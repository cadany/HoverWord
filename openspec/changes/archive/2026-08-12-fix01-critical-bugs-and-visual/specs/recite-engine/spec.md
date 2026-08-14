## Purpose

修复背记引擎两个关键逻辑缺陷：Section/轮次起始时首个单词被跳过、"不认识"标记与"认识"行为相同导致单词不重试。

## MODIFIED Requirements

### Requirement: 记忆反馈模式调度（修正）
记忆反馈模式下，系统 SHALL 要求用户对每个单词主动标记"认识"或"不认识"。"认识"标记为已反馈，"不认识"标记为未反馈，未反馈单词在后续轮次重复出现。Section 启动时 SHALL 从第一个单词开始展示，不跳过。

#### Scenario: 用户点击认识
- **WHEN** 用户在记忆反馈模式下对当前单词点击"认识"
- **THEN** 系统 SHALL 将该单词标记为已反馈（加入 feedbackSet），立即切换至下一单词

#### Scenario: 用户点击不认识
- **WHEN** 用户在记忆反馈模式下对当前单词点击"不认识"
- **THEN** 系统 SHALL 将该单词标记为未反馈（不加入 feedbackSet），立即切换至下一单词，该单词将在后续轮次再次出现

#### Scenario: 单轮循环中未反馈单词重复出现
- **WHEN** 一个 Section 有 5 个单词，第一轮中 2 个标记为"不认识"
- **THEN** 系统 SHALL 在第二轮中仅展示这 2 个未反馈单词，已反馈的 3 个不再出现

### Requirement: Section 启动从首词展示
系统启动背记、进入新 Section、或进入新一轮循环时，SHALL 从当前 Section 单词列表的 index 0 开始展示，不跳过任何单词。

#### Scenario: 启动时展示首词
- **WHEN** 引擎调用 `start()` 启动背记
- **THEN** 系统 SHALL 展示当前 Section 的第一个单词（index 0），而非第二个

#### Scenario: Section 流转后展示首词
- **WHEN** 当前 Section 完成，引擎进入下一个 Section
- **THEN** 系统 SHALL 展示新 Section 的第一个单词（index 0）

#### Scenario: 新一轮循环展示首词
- **WHEN** 走马灯模式或记忆反馈模式进入新一轮循环（`rebuildWordOrder()` 后）
- **THEN** 系统 SHALL 展示新轮次的第一个单词（index 0）

### Requirement: 走马灯模式调度（修正）
走马灯模式下，每完整播放一遍 Section 内所有单词计为 1 轮。新一轮循环开始时 SHALL 从 index 0 开始展示，不跳过首词。

#### Scenario: 新一轮循环从首词开始
- **WHEN** 走马灯模式完成一轮，进入下一轮
- **THEN** 系统 SHALL 从新轮次单词列表的 index 0 开始展示
