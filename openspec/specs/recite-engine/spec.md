## Purpose

背记核心调度引擎，负责将启用单词本的 Section 组织为背记队列，按用户选择的模式（记忆反馈 / 走马灯）驱动单词轮换，检测 Section 完成与全队列完成，并根据设置变化重置进度。
## Requirements
### Requirement: Section 队列构建
系统 SHALL 根据用户勾选启用的单词本，按单词本在列表中的排列顺序，将所有 Section 依次拼接为完整的背记队列。

#### Scenario: 单个单词本启用
- **WHEN** 用户仅启用单词本 A（含 3 个 Section）
- **THEN** 系统 SHALL 构建队列 [A-S0, A-S1, A-S2]

#### Scenario: 多个单词本启用
- **WHEN** 用户按顺序启用单词本 A（2 个 Section）和单词本 B（3 个 Section）
- **THEN** 系统 SHALL 构建队列 [A-S0, A-S1, B-S0, B-S1, B-S2]，Section 间顺序固定

#### Scenario: 无单词本启用
- **WHEN** 用户未启用任何单词本
- **THEN** 系统 SHALL 构建空队列，悬浮窗显示无内容或提示状态

#### Scenario: 单词本顺序调整
- **WHEN** 用户调整单词本列表顺序后（B 在 A 之前）
- **THEN** 系统 SHALL 按新顺序重建队列 [B-S0, ..., A-S0, ...]

### Requirement: 记忆反馈模式调度
记忆反馈模式下，系统 SHALL 要求用户对每个单词主动标记"认识"或"不认识"。"认识"标记为已反馈（加入 feedbackSet），"不认识"标记为未反馈（不加入 feedbackSet），未反馈单词在后续轮次重复出现。Section 启动时 SHALL 从第一个单词开始展示，不跳过。Section 内所有单词均完成反馈后判定该 Section 完成。

#### Scenario: 用户点击认识
- **WHEN** 用户在记忆反馈模式下对当前单词点击"认识"
- **THEN** 系统 SHALL 将该单词标记为已反馈（加入 feedbackSet），立即切换至下一单词

#### Scenario: 用户点击不认识
- **WHEN** 用户在记忆反馈模式下对当前单词点击"不认识"
- **THEN** 系统 SHALL 将该单词标记为未反馈（不加入 feedbackSet），立即切换至下一单词，该单词将在后续轮次再次出现

#### Scenario: 停留时长耗尽未反馈
- **WHEN** 用户在停留时长内未对当前单词进行任何标记
- **THEN** 系统 SHALL 自动切换至下一单词，该单词标记为"未反馈"，在本轮后续再次出现直至完成标记

#### Scenario: 单轮循环中未反馈单词重复出现
- **WHEN** 一个 Section 有 5 个单词，第一轮中 2 个未反馈
- **THEN** 系统 SHALL 在第二轮中仅展示这 2 个未反馈单词，已反馈的 3 个不再出现

#### Scenario: Section 完成判定
- **WHEN** Section 内所有单词均已标记为已反馈
- **THEN** 系统 SHALL 判定该 Section 完成，自动进入队列中下一个 Section

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

### Requirement: 走马灯式刷词模式调度
走马灯模式下，系统 SHALL 按用户设置的停留时长自动切换单词，无需用户操作。每完整播放一遍 Section 内所有单词计为 1 轮，累计播放轮次达到设置值时判定该 Section 完成。新一轮循环开始时 SHALL 从 index 0 开始展示，不跳过首词。

#### Scenario: 自动切换单词
- **WHEN** 走马灯模式运行中，停留时长设为 5 秒
- **THEN** 系统 SHALL 每 5 秒自动切换至下一个单词

#### Scenario: 单轮完成计数
- **WHEN** Section 有 10 个单词，走马灯模式已按顺序播放 10 个
- **THEN** 系统 SHALL 计为完成 1 轮

#### Scenario: 多轮完成判定
- **WHEN** 单 Section 循环轮次设置为 3，当前已完成 2 轮
- **THEN** 系统 SHALL 在第 3 轮播放完毕后判定该 Section 完成，自动进入下一个 Section

#### Scenario: 无用户操作按钮
- **WHEN** 走马灯模式运行中
- **THEN** 系统 SHALL 不显示"认识"/"不认识"操作按钮，仅展示收藏按钮（悬停时）

#### Scenario: 新一轮循环从首词开始
- **WHEN** 走马灯模式完成一轮，进入下一轮
- **THEN** 系统 SHALL 从新轮次单词列表的 index 0 开始展示

### Requirement: Section 内展示顺序
系统 SHALL 支持"顺序播放"与"随机播放"两种展示顺序设置，仅在单个 Section 内部生效，Section 之间的先后顺序固定不变。随机模式下每一轮循环重新打乱一次单词顺序。

#### Scenario: 顺序播放
- **WHEN** 展示顺序设为"顺序播放"
- **THEN** 系统 SHALL 按词条原始顺序在 Section 内展示单词

#### Scenario: 随机播放每轮重排
- **WHEN** 展示顺序设为"随机播放"
- **THEN** 系统 SHALL 在每一轮循环开始时重新打乱 Section 内单词顺序，不同轮次的顺序互不相关

#### Scenario: Section 间顺序不受影响
- **WHEN** 展示顺序设为"随机播放"，队列中有多个 Section
- **THEN** 系统 SHALL 保持 Section 之间的队列顺序不变，仅 Section 内部打乱

### Requirement: 全队列完成检测
当背记队列中所有 Section 全部完成时，系统 SHALL 停止单词切换，进入"已学完"状态。

#### Scenario: 所有 Section 完成
- **WHEN** 队列中最后一个 Section 完成
- **THEN** 系统 SHALL 停止调度，悬浮窗显示"已学完"状态

#### Scenario: 已学完状态可重新开始
- **WHEN** 悬浮窗处于"已学完"状态
- **THEN** 用户 SHALL 可点击"重新开始"按钮，从队列第一个 Section 重新背记

### Requirement: 设置变化重置进度
当用户在设置中修改背记规则、增减或调整单词本启用状态时，系统 SHALL 自动重置背记进度，从当前队列第一个 Section 重新开始。

#### Scenario: 修改背记模式
- **WHEN** 用户从记忆反馈模式切换为走马灯模式
- **THEN** 系统 SHALL 重置进度，从队列第一个 Section 重新开始

#### Scenario: 启用新单词本
- **WHEN** 用户启用一个新单词本
- **THEN** 系统 SHALL 重建队列并重置进度，从新队列第一个 Section 开始

#### Scenario: 修改停留时长
- **WHEN** 用户修改单单词停留时长
- **THEN** 系统 SHALL 热更新计时器（使用新时长重新计算当前单词剩余展示时间），不重建队列、不重置进度

### Requirement: 模式切换进度重置
全局二选一选择背记模式，切换模式后背记进度 SHALL 重置，从当前队列第一个 Section 重新开始。

#### Scenario: 切换模式
- **WHEN** 用户从记忆反馈模式切换为走马灯模式（或反之）
- **THEN** 系统 SHALL 重置当前背记进度，所有 Section 从头开始

### Requirement: 引擎响应计时参数变更
背记引擎 SHALL 监听 `.appTimingDidChange` 通知，收到后热更新计时器（重新计算当前单词的剩余展示时间），不重建队列、不重置当前进度。引擎仍监听 `.appSettingsDidChange` 通知，收到后重启引擎（重建队列、重置进度）。

#### Scenario: 计时参数变更热更新计时器
- **WHEN** 系统发送 `.appTimingDidChange` 通知且引擎处于 `.playing` 状态
- **THEN** 引擎 SHALL 使用新的 `stayDuration` 值重新启动计时器，当前单词和进度保持不变

#### Scenario: 非播放状态忽略计时变更
- **WHEN** 系统发送 `.appTimingDidChange` 通知但引擎处于 `.idle` 或 `.allComplete` 状态
- **THEN** 引擎 SHALL 不执行任何操作

### Requirement: 悬停暂停计时
鼠标进入悬浮窗时，引擎 SHALL 暂停当前单词的切词计时；鼠标离开时 SHALL 从剩余时长继续计时。暂停对记忆反馈模式与走马灯模式一致生效（超时推进/轮次计数均冻结）。本行为默认常开，SHALL NOT 提供设置开关。

#### Scenario: 悬停暂停
- **WHEN** 引擎处于播放状态且鼠标进入悬浮窗
- **THEN** 引擎 SHALL 记录当前单词的剩余停留时长并停止计时器，当前单词保持展示不切换

#### Scenario: 离开恢复
- **WHEN** 鼠标离开悬浮窗
- **THEN** 引擎 SHALL 按暂停时的剩余时长恢复计时（不重新计满整段）

#### Scenario: 两模式一致
- **WHEN** 记忆反馈模式或走马灯模式下鼠标进入悬浮窗
- **THEN** 两种模式 SHALL 表现出相同的暂停/恢复行为

#### Scenario: 暂停中手动切词
- **WHEN** 暂停期间用户点击"认识"或"不认识"按钮切换到下一词
- **THEN** 新单词 SHALL 保持暂停状态（不启动计时器，记录整段停留时长）

#### Scenario: 暂停中计时参数变更
- **WHEN** 暂停期间用户修改单单词停留时长
- **THEN** 引擎 SHALL 更新暂停记录值为新时长，SHALL NOT 启动计时器；恢复后按新值剩余时长计时

#### Scenario: 引擎重启保持暂停
- **WHEN** 鼠标位于悬浮窗内时触发引擎重启（背记规则变更/词本启停/进度恢复）
- **THEN** 重启后的首个单词 SHALL 保持暂停状态

#### Scenario: 悬浮窗隐藏强制恢复
- **WHEN** 悬浮窗被隐藏（全屏自动隐藏/显隐切换）时鼠标位于窗内
- **THEN** 系统 SHALL 强制清除悬停暂停状态并恢复计时，防止背记因 mouseExited 缺失而永久卡住

#### Scenario: 非播放状态
- **WHEN** 引擎处于空闲或全部完成状态时鼠标进出悬浮窗
- **THEN** 引擎 SHALL 仅记录悬停标志，SHALL NOT 产生计时器副作用

### Requirement: 背记进度持久化
系统 SHALL 将背记进度（当前 Section 索引、Section 内单词索引、当前轮次播放顺序（wordId 列表）、已反馈单词集合、走马灯已完成轮次）持久化到 UserDefaults。重启后 SHALL 自动恢复到上次进度，且恢复时展示的单词 SHALL 与保存时正在展示的单词完全一致，无论播放顺序为顺序、随机，还是记忆反馈后续轮次的"未反馈子集"。

#### Scenario: 背记过程中保存进度
- **WHEN** 引擎在背记模式下切换到下一个单词或完成一个 Section
- **THEN** 系统 SHALL 将当前 Section 索引、单词索引、当前轮次播放顺序（wordId 列表）和已反馈集合保存到 UserDefaults

#### Scenario: 重启后恢复进度
- **WHEN** 用户启动应用，存在历史背记进度（含随机播放顺序或记忆反馈"未反馈子集"轮次的进度）
- **THEN** 引擎 SHALL 按保存的播放顺序还原，从上次正在展示的单词继续背记，该单词与保存时完全一致

#### Scenario: 已反馈单词在恢复后不重复出现
- **WHEN** 历史进度中存在已反馈集合，恢复后进入后续轮次
- **THEN** 引擎 SHALL 仅轮换未反馈单词，已反馈的单词不再出现

#### Scenario: 顺序数据与当前词库不匹配时回退
- **WHEN** 历史进度保存的播放顺序中存在不属于当前 Section 的 wordId（如词库已重新导入）
- **THEN** 系统 SHALL 清除进度并安全回退到从头开始背记，不崩溃、不显示异常

#### Scenario: 旧版本进度数据一次性失效
- **WHEN** 历史进度由旧版本保存，缺少播放顺序数据
- **THEN** 系统 SHALL 视为无效进度，从头开始背记

#### Scenario: 收藏夹单词本启用时恢复到确切单词
- **WHEN** 收藏夹单词本启用的状态下保存进度（收藏词条参与背记队列），用户重启应用
- **THEN** 引擎 SHALL 恢复到上次正在展示的收藏词条，依赖收藏记录的稳定标识（favoriteId）完成匹配

#### Scenario: 进度与当前配置不匹配时回退
- **WHEN** 历史进度中的 Section 索引超出当前队列范围（单词本已修改或 Section 大小已变更）
- **THEN** 系统 SHALL 安全回退到从头开始背记，不崩溃、不显示异常

#### Scenario: 完成全部单词后清除进度
- **WHEN** 用户完成所有 Section 的背记
- **THEN** 系统 SHALL 清除持久化的进度数据，下次启动时从头开始

#### Scenario: 手动重新开始清除进度
- **WHEN** 用户在"已学完"状态点击"重新开始"
- **THEN** 系统 SHALL 清除进度数据并从队列第一个 Section 重新开始

### Requirement: 引擎响应收藏内容变更
背记引擎 SHALL 监听 `.favoritesDidChange` 通知（收藏新增/移除、导入后收藏夹同步完成时发送）。收藏夹单词本未启用时 SHALL 忽略该通知，不重建队列、不重置进度。收藏夹单词本已启用且引擎处于播放状态时，SHALL 保存当前进度、重建背记队列并尽量恢复到原位置；恢复校验失败（如当前单词已被移出收藏）时从头开始。

#### Scenario: 收藏夹未启用时忽略收藏变更
- **WHEN** 系统发送 `.favoritesDidChange` 通知，但收藏夹单词本未启用（或引擎未处于播放状态）
- **THEN** 引擎 SHALL 不执行任何操作，当前背记进度保持不变

#### Scenario: 收藏夹启用时新增收藏进入轮换
- **WHEN** 收藏夹单词本已启用且引擎播放中，用户新收藏一个单词
- **THEN** 引擎 SHALL 重建队列，新收藏单词进入后续轮换，且当前展示位置尽量保持不变

#### Scenario: 当前单词被移出收藏时从头开始
- **WHEN** 收藏夹单词本已启用，用户取消收藏的正是当前正在展示的单词
- **THEN** 引擎 SHALL 在恢复校验失败后从头开始背记，不崩溃、不展示已移除的单词

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

