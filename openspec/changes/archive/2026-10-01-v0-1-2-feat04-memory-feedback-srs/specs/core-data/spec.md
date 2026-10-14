Change-Sub-Version: v0-1-2-feat04

## Purpose

新增 ReviewState 实体，持久化记忆反馈模式下每个单词的掌握度（Leitner 盒级、到期时间、最近反馈、累计曝光），为全局复习队列调度（v0-1-2-feat04）提供跨会话数据基础。

## ADDED Requirements

### Requirement: 复习状态实体持久化

系统 SHALL 提供 ReviewState 实体，按 wordId 唯一寻址，存储单词的复习调度状态：Leitner 盒级（1-5，默认 1）、下次到期时间（dueAt）、最近反馈时间（可空）、最近反馈等级（认识 / 模糊 / 不认识）、累计曝光次数。字段设计 SHALL 语种无关（不绑定具体语种，仅以 wordId 关联词条）。模型变更 SHALL 通过轻量迁移完成（新增实体加表，不触碰既有实体）。ReviewState 的读写 SHALL 由服务层封装：按 wordId 取得或创建记录、反馈时原子更新盒级与到期时间、按 dueAt 查询到期记录。

#### Scenario: 首次反馈创建记录

- **WHEN** 某词条在记忆反馈模式下首次收到反馈且无既有 ReviewState 记录
- **THEN** 系统 SHALL 创建一条 ReviewState 记录，以该词条 wordId 唯一寻址，写入反馈对应的盒级、到期时间、最近反馈等级与时间、累计曝光 1

#### Scenario: 再次反馈更新记录

- **WHEN** 某词条已有 ReviewState 记录并再次收到反馈
- **THEN** 系统 SHALL 原子更新该记录的盒级、到期时间、最近反馈等级与时间，并累加曝光计数，SHALL NOT 产生重复记录

#### Scenario: 轻量迁移加表

- **WHEN** 旧版本数据文件在含 ReviewState 实体的新版本应用中首次加载
- **THEN** 系统 SHALL 通过轻量迁移自动完成加表，既有 Wordbook / WordEntry / Favorite 数据不受影响

#### Scenario: 到期查询

- **WHEN** 引擎构建全局复习队列
- **THEN** 服务层 SHALL 支持按 dueAt 不晚于当前时间的条件查询 ReviewState 记录，供队列取到期复习词

#### Scenario: 词条失效后记录成为孤儿

- **WHEN** 词条因词库重新导入或删除导致其 wordId 不再存在于任何启用单词库
- **THEN** 对应 ReviewState 记录 SHALL 保留在存储中但 SHALL NOT 参与调度（查询不到对应词条即不入队），系统 SHALL NOT 因孤儿记录崩溃或报错

#### Scenario: store 损坏自愈覆盖新实体

- **WHEN** 持久化 store 损坏触发自愈重建
- **THEN** ReviewState 数据 SHALL 与其他实体一致按"重建后丢失"处理，应用可用（用户设置保留）
