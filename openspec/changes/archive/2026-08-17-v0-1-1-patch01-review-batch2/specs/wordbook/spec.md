Change-Sub-Version: v0-1-1-patch01

## Purpose

词条级变更（编辑/删除/重新导入）后向背记引擎广播内容变更，保证启用中单词本的队列实时反映最新数据；同时修复词条变更与收藏记录的一致性（编辑 sourceWord、删除词条后收藏同步）。

## ADDED Requirements

### Requirement: 词条变更通知
系统 SHALL 仅在单词本内容发生成功落盘的变更时发送 `.wordbookContentDidChange` 通知：触发点为词条更新完成、词条删除完成、词库导入完成后（各操作仅发送一次，批量操作不逐条发送）。通知 SHALL 在主线程发送，且 userInfo SHALL 携带变更所属的 `wordbookId`。无实际变更的路径（如 wordId 不存在）SHALL 不发送。导入链路同时触发收藏同步时，本通知 SHALL 晚于 `.favoritesDidChange` 发送（两者均经主线程队列按派发顺序派发）。

#### Scenario: 删除词条后通知
- **WHEN** 用户在某单词本中删除一个词条并成功落盘
- **THEN** 系统 SHALL 在主线程发送一次 `.wordbookContentDidChange` 通知，userInfo 携带该单词本 wordbookId

#### Scenario: 编辑词条后通知
- **WHEN** 用户编辑词条的单词/音标/词性/释义字段并保存成功
- **THEN** 系统 SHALL 在主线程发送一次 `.wordbookContentDidChange` 通知，userInfo 携带该单词本 wordbookId

#### Scenario: 导入完成后通知
- **WHEN** 词库全量覆盖导入（含收藏夹同步）完成
- **THEN** 系统 SHALL 在主线程发送一次 `.wordbookContentDidChange` 通知，且发送顺序晚于本次导入触发的 `.favoritesDidChange`

#### Scenario: 无变更时不发送
- **WHEN** 更新或删除接口收到的 wordId 不存在（无数据变更）
- **THEN** 系统 SHALL 不发送 `.wordbookContentDidChange` 通知

### Requirement: 词条变更与收藏一致性
词条的源语言文本（sourceWord）或词条本身发生变更时，关联的收藏记录 SHALL 保持一致：编辑词条的 sourceWord 后，该单词本范围内以旧 sourceWord 匹配的收藏记录 SHALL 更新为新的 sourceWord；删除词条后，若不存在其他单词本包含相同 sourceWord，对应收藏记录 SHALL 被移除（与其他词本包含性判断的隔离语义一致）；收藏状态因此发生变化时 SHALL 同步发送 `.favoritesDidChange` 通知（主线程）。

#### Scenario: 编辑已收藏词条的单词文本
- **WHEN** 用户编辑一个已收藏词条的 sourceWord 并保存
- **THEN** 对应收藏记录的 sourceWord SHALL 更新为新文本，收藏状态保持不丢失

#### Scenario: 删除已收藏词条且无其他词本包含
- **WHEN** 用户删除一个已收藏词条，且没有其他单词本包含相同 sourceWord
- **THEN** 对应收藏记录 SHALL 被移除，并在主线程发送 `.favoritesDidChange`

#### Scenario: 删除词条但其他词本包含同词
- **WHEN** 用户删除一个已收藏词条，但另一单词本仍包含相同 sourceWord
- **THEN** 对应收藏记录 SHALL 保留
