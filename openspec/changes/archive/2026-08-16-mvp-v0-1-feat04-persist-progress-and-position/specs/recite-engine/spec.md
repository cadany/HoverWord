Change-Sub-Version: mvp-v0-1-feat04

## Purpose

背记进度跨启动持久化，用户重启应用后从上次学习位置继续，而非从头开始。

## ADDED Requirements

### Requirement: 背记进度持久化
系统 SHALL 将背记进度（当前 Section 索引、Section 内单词索引、已反馈单词集合）持久化到 UserDefaults。重启后 SHALL 自动恢复到上次进度，用户无需重新开始。

#### Scenario: 背记过程中保存进度
- **WHEN** 引擎在背记模式下切换到下一个单词或完成一个 Section
- **THEN** 系统 SHALL 将当前 Section 索引、单词索引和已反馈集合保存到 UserDefaults

#### Scenario: 重启后恢复进度
- **WHEN** 用户启动应用，存在历史背记进度
- **THEN** 引擎 SHALL 从历史进度恢复，从上次中断的单词继续背记，已反馈的单词不再重复出现

#### Scenario: 进度与当前配置不匹配时回退
- **WHEN** 历史进度中的 Section 索引超出当前队列范围（单词本已修改或 Section 大小已变更）
- **THEN** 系统 SHALL 安全回退到从头开始背记，不崩溃、不显示异常

#### Scenario: 完成全部单词后清除进度
- **WHEN** 用户完成所有 Section 的背记
- **THEN** 系统 SHALL 清除持久化的进度数据，下次启动时从头开始

#### Scenario: 手动重新开始清除进度
- **WHEN** 用户在"已学完"状态点击"重新开始"
- **THEN** 系统 SHALL 清除进度数据并从队列第一个 Section 重新开始
