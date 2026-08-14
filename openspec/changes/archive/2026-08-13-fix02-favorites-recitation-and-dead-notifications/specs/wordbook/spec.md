> Change-Sub-Version: mvp-v0-1-fix02

## MODIFIED Requirements

### Requirement: 单词本启用与停用
系统 SHALL 支持对每个单词本独立设置启用或停用状态。仅启用状态的单词本进入背记队列。对于非系统单词本，启用前须有词条导入；对于系统收藏夹单词本，只要存在收藏词条即可启用，不依赖手动导入。

#### Scenario: 启用单词本
- **WHEN** 用户勾选启用一个非系统单词本
- **THEN** 系统 SHALL 将该单词本标记为启用，其 Section 进入背记队列

#### Scenario: 停用单词本
- **WHEN** 用户取消勾选一个已启用的单词本
- **THEN** 系统 SHALL 将该单词本标记为停用，其 Section 从背记队列中移除

#### Scenario: 启用空单词本
- **WHEN** 用户尝试启用一个单词总数为 0 的非系统单词本
- **THEN** 系统 SHALL 拒绝启用并提示用户先导入词库

#### Scenario: 启用无收藏的收藏夹单词本
- **WHEN** 用户尝试启用收藏夹单词本，但收藏词条数量为 0
- **THEN** 系统 SHALL 拒绝启用并提示用户先收藏单词

### Requirement: 系统收藏夹单词本
系统 SHALL 内置一个名为"我的收藏"的系统单词本，默认存在，不可删除、不可手动导入。仅通过收藏动作自动增减词条，支持勾选启用进入背记队列。启用后，系统 SHALL 将收藏词条按全局"单 Section 单词数"拆分 Section 并纳入背记队列；背记引擎消费收藏夹单词本时，收藏词条 SHALL 被转换为与 WordEntry 兼容的数据结构。

#### Scenario: 收藏夹单词本自动创建
- **WHEN** 应用首次启动
- **THEN** 系统 SHALL 自动创建"我的收藏"单词本，标记为系统内置

#### Scenario: 尝试删除收藏夹单词本
- **WHEN** 用户尝试删除"我的收藏"单词本
- **THEN** 系统 SHALL 拒绝操作，删除入口对该单词本不可用

#### Scenario: 启用收藏夹单词本参与背记
- **WHEN** 用户勾选启用"我的收藏"单词本，且收藏词条数量 > 0
- **THEN** 系统 SHALL 将收藏词条按全局 Section 大小拆分 Section 纳入背记队列

#### Scenario: 收藏夹单词本词条计数
- **WHEN** 收藏夹中有 15 条收藏词条
- **THEN** 单词本列表 SHALL 显示收藏夹单词总数为 15，Section 数量按全局 Section 大小计算

#### Scenario: 收藏夹单词本背记数据转换
- **WHEN** 背记引擎构建队列，处理到收藏夹单词本
- **THEN** 系统 SHALL 将每条 Favorite 记录的 wordDetail JSON 反序列化为 WordEntry 兼容数据，供引擎正常调度
