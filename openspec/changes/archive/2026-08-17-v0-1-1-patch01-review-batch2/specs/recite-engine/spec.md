Change-Sub-Version: v0-1-1-patch01

## Purpose

词条内容变更（编辑/删除/重新导入）后，背记引擎重建队列并尽量保持当前进度，替代原先"继续轮换过期词条直到重启"的行为。

## ADDED Requirements

### Requirement: 引擎响应词条内容变更
背记引擎 SHALL 监听 `.wordbookContentDidChange` 通知（userInfo 携带 wordbookId）。引擎处于播放状态或 Section 完成等待流转状态，且来源 wordbookId 对应的单词本处于启用状态时，SHALL 保存当前进度、重建背记队列并尽量恢复到原位置：当前单词的 wordId 仍存在于新队列时停留在原位；已不存在（如词库重新导入、词条被删除）时按进度校验规则回退从头开始。来源单词本未启用，或引擎处于空闲/全部完成状态时 SHALL 忽略该通知。引擎对通知的处理 SHALL 幂等：同一变更引发的连续多次通知（如导入同时触发收藏与内容变更）先后到达时，每次处理均以前次处理结果为基线，最终状态与单次处理一致。

#### Scenario: 编辑词条后队列保持
- **WHEN** 引擎播放中，用户编辑当前 Section 内某词条的释义
- **THEN** 引擎 SHALL 重建队列后停留在当前展示的单词，后续轮换使用编辑后的词条内容

#### Scenario: 删除当前单词后回退
- **WHEN** 引擎播放中，用户删除的正是当前正在展示的词条
- **THEN** 引擎 SHALL 在恢复校验失败后从头开始背记，不展示已删除的词条

#### Scenario: 重新导入后从头开始
- **WHEN** 引擎播放中，用户对启用中的单词本重新导入词库（词条 wordId 全部更新）
- **THEN** 引擎 SHALL 回退到第一个 Section 从头开始，不崩溃、不展示旧词条

#### Scenario: 非播放状态忽略
- **WHEN** 引擎处于空闲或已学完状态时收到词条内容变更通知
- **THEN** 引擎 SHALL 不执行任何操作

#### Scenario: 未启用单词本变更忽略
- **WHEN** 引擎播放中，收到 wordbookId 对应未启用单词本的内容变更通知
- **THEN** 引擎 SHALL 忽略该通知，不重建队列、不影响当前进度

#### Scenario: Section 完成态同样处理
- **WHEN** 引擎处于 Section 完成等待流转状态，启用的单词本内容发生变更
- **THEN** 引擎 SHALL 保存进度、重建队列并恢复到该完成态，后续流转使用新数据

#### Scenario: 连续通知幂等
- **WHEN** 重新导入先后触发 `.favoritesDidChange` 与 `.wordbookContentDidChange`（引擎同一处理入口）
- **THEN** 引擎 SHALL 依次处理，最终停留在与新数据一致的进度，不崩溃、不重复计时
