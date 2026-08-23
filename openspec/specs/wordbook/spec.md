## Purpose

管理单词本的创建、删除、重命名、启用停用，以及 TXT 格式词库的全量导入。包含系统内置"我的收藏"单词本的特殊管理逻辑，以及导入时与收藏夹的状态同步。
## Requirements
### Requirement: 单词本 CRUD 操作
系统 SHALL 支持用户新建、删除、重命名单词本。新建单词本默认为空，需导入词库后启用。

#### Scenario: 新建空单词本
- **WHEN** 用户新建一个单词本并输入名称
- **THEN** 系统 SHALL 创建该单词本，单词总数为 0，Section 数量为 0，启用状态为 false

#### Scenario: 重命名单词本
- **WHEN** 用户对某单词本执行重命名操作
- **THEN** 系统 SHALL 更新该单词本名称，不影响其词条与启用状态

#### Scenario: 删除非空单词本
- **WHEN** 用户删除一个已导入词条的单词本
- **THEN** 系统 SHALL 删除该单词本及其全部词条记录

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

### Requirement: TXT 词库全量覆盖导入
系统 SHALL 支持导入 UTF-8 编码的 .txt 文件，采用全量覆盖逻辑：导入成功后清空该单词本原有全部单词，替换为新导入内容。导入时 SHALL 为每个词条写入 `orderIndex` 字段，值等于该词条在文件中的行序（从 0 起递增），用于保留文件原始顺序。文件无任何有效词条（空文件或仅含空白行）时 SHALL 中断导入并提示，原有词条不受影响。

#### Scenario: 成功导入合法词库
- **WHEN** 用户选择一个格式正确的 UTF-8 .txt 文件导入某单词本
- **THEN** 系统 SHALL 清空该单词本原有词条，写入新词条，自动按全局"单 Section 单词数"拆分 Section，每个词条的 `orderIndex` 等于其在文件中的行序（从 0 起递增），并显示导入后的单词总数与 Section 数量

#### Scenario: 重复导入覆盖原有数据
- **WHEN** 用户对已有词条的单词本再次导入新词库
- **THEN** 系统 SHALL 完全替换原有词条，新词条的 `orderIndex` 从 0 重新递增，与原有 orderIndex 无关

#### Scenario: 导入空文件
- **WHEN** 用户导入一个内容为空的 .txt 文件
- **THEN** 系统 SHALL 中断导入并提示文件内容为空，该单词本原有词条不受影响

#### Scenario: 导入仅含空白行的文件
- **WHEN** 用户导入一个仅包含空白行、无任何有效词条的 .txt 文件
- **THEN** 系统 SHALL 中断导入并提示文件内容为空，该单词本原有词条不受影响

### Requirement: 导入格式校验与错误报告
系统 SHALL 在导入时自动校验文件格式，字段缺失、格式错误或无任何有效词条时弹出提示，告知错误行号与原因（空文件提示内容为空），导入中断，保留原有数据。

#### Scenario: 必填字段缺失
- **WHEN** 导入文件中某行缺少源语言词条（第 1 字段）或释义 1（第 4 字段）
- **THEN** 系统 SHALL 中断导入，弹出错误提示，精准标明错误行号与缺失字段名称，单词本原有数据不受影响

#### Scenario: 编码错误
- **WHEN** 导入文件非 UTF-8 编码
- **THEN** 系统 SHALL 中断导入，提示文件编码错误，单词本原有数据不受影响

#### Scenario: 空文件或仅空白行
- **WHEN** 导入文件内容为空，或仅包含空白行
- **THEN** 系统 SHALL 中断导入，提示文件内容为空，单词本原有数据不受影响

#### Scenario: 正常行与错误行混合
- **WHEN** 导入文件中前 10 行格式正确，第 11 行格式错误
- **THEN** 系统 SHALL 中断导入，提示第 11 行的错误原因，前 10 行的数据不写入（整体回滚）

### Requirement: 导入后自动拆分 Section
系统 SHALL 在词库导入成功后，按全局"单 Section 单词数"设置，将词条按原始顺序自动拆分为若干 Section；不足一个 Section 的剩余单词独立组成最后一个 Section。

#### Scenario: 整除拆分
- **WHEN** 导入 100 个词条，全局 Section 单词数设为 20
- **THEN** 系统 SHALL 拆分为 5 个 Section，每个 Section 包含 20 个词条

#### Scenario: 有余数拆分
- **WHEN** 导入 55 个词条，全局 Section 单词数设为 20
- **THEN** 系统 SHALL 拆分为 3 个 Section：前两个各 20 条，最后一个 15 条

#### Scenario: 词条数少于 Section 大小
- **WHEN** 导入 10 个词条，全局 Section 单词数设为 20
- **THEN** 系统 SHALL 拆分为 1 个 Section，包含 10 个词条

### Requirement: TXT 词库导出
系统 SHALL 支持将单词本导出为 UTF-8 编码的 .txt 文件，格式与导入格式完全对称：每行一个词条，字段以 Tab 分隔，字段顺序固定为 源语言词条 / 注音 / 词性1 / 释义1 / 词性2 / 释义2 / 词性3 / 释义3（共 8 列，空字段输出空字符串），换行符 `\n`，不带 BOM。普通单词本按导入顺序（orderIndex 升序）导出；系统收藏夹按收藏时间升序从 wordDetail 快照导出。导出文件 SHALL 可直接经现有导入功能无损还原。

#### Scenario: 普通单词本导出
- **WHEN** 用户在某普通单词本行 `...` 菜单点击"导出"并在保存面板确认
- **THEN** 系统 SHALL 按导入顺序导出该词本全部词条为对称 TXT 格式，写入用户选择的路径

#### Scenario: 收藏夹导出
- **WHEN** 用户在"我的收藏"行 `...` 菜单点击"导出"并确认保存
- **THEN** 系统 SHALL 按收藏时间升序导出全部收藏快照（8 字段从 wordDetail 还原）为对称 TXT 格式

#### Scenario: 导出往返无损
- **WHEN** 用户将导出文件重新导入任一单词本
- **THEN** 导入后的词条字段（词条/注音/词性/释义各 3 组）SHALL 与导出时完全一致

#### Scenario: 空单词本导出禁用
- **WHEN** 某单词本词条数为 0
- **THEN** 该行 `...` 菜单中的"导出"项 SHALL 处于禁用状态

#### Scenario: 默认文件名
- **WHEN** 保存面板打开
- **THEN** 默认文件名 SHALL 为 `<词本名>.txt`（词本名中的文件系统非法字符被替换为 `-`）

#### Scenario: 导出失败提示
- **WHEN** 导出或写文件失败（如词本已被删除、磁盘不可写）
- **THEN** 系统 SHALL 弹出"导出失败"alert 并展示错误原因；成功时 SHALL NOT 弹任何提示

### Requirement: 全局 Section 单词数设置
系统 SHALL 提供全局"单 Section 单词数"设置项，数字输入框，默认值 20，最小值 1。该值在导入时生效，修改后不影响已导入单词本的 Section 划分。

#### Scenario: 修改全局 Section 大小
- **WHEN** 用户将 Section 单词数从 20 改为 30
- **THEN** 系统 SHALL 保存新值，后续新导入的词库按 30 拆分，已有词库保持原拆分不变

### Requirement: 系统收藏夹单词本
系统 SHALL 内置一个名为"我的收藏"的系统单词本，默认存在，不可删除、不可手动导入。仅通过收藏动作自动增减词条，支持勾选启用进入背记队列。启用后，系统 SHALL 将收藏词条按全局"单 Section 单词数"拆分 Section 并纳入背记队列；背记引擎消费收藏夹单词本时，收藏词条 SHALL 被转换为与 WordEntry 兼容的数据结构，且词条标识（wordId）SHALL 使用收藏记录持久化的 `favoriteId`（跨会话稳定），不得使用临时生成的 UUID，以保证背记进度保存/恢复与反馈状态在重启后仍然有效。

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

#### Scenario: 收藏词条标识跨会话稳定
- **WHEN** 收藏夹单词本启用且背记中，用户保存进度后退出并重启应用
- **THEN** 引擎 SHALL 依据重启前一致的词条标识（favoriteId）恢复进度到上次展示的收藏词条，不因标识变化而重置进度

### Requirement: 导入时收藏夹状态同步
单词本全量覆盖导入时，系统 SHALL 基于"源语言词条"精确匹配保留收藏状态：新导入词条与历史收藏词条完全一致的保留收藏状态；历史收藏但新导入不存在的词条自动从收藏夹中移除。同步执行完成后 SHALL 在主线程发送 `.favoritesDidChange` 通知，供背记引擎重建收藏夹相关队列；同步保存失败 SHALL 记录错误日志。

#### Scenario: 导入后保留匹配的收藏
- **WHEN** 用户已收藏单词 "apple"，对该单词本重新导入仍包含 "apple" 的词库
- **THEN** 系统 SHALL 保留 "apple" 的收藏状态

#### Scenario: 导入后移除不匹配的收藏
- **WHEN** 用户已收藏单词 "banana"，对该单词本重新导入不含 "banana" 的词库
- **THEN** 系统 SHALL 自动从收藏夹中移除 "banana"

#### Scenario: 跨单词本收藏同步
- **WHEN** 用户对单词本 A 执行导入，收藏夹中包含来自单词本 B 的收藏词条
- **THEN** 系统 SHALL 仅检查单词本 A 的导入内容对收藏夹中源自单词本 A 的词条进行同步，不影响源自单词本 B 的收藏

#### Scenario: 同步完成后通知引擎
- **WHEN** 导入触发的收藏夹同步执行完成（含无任何变更的情形）
- **THEN** 系统 SHALL 在主线程发送 `.favoritesDidChange` 通知

### Requirement: 词条查询按导入顺序排序
系统 SHALL 在查询单词本指定 Section 的词条时，按 `orderIndex` 升序排序。当多个词条 `orderIndex` 相同时（存量数据迁移场景），SHALL 以 `sourceWord` 字母序作为次要排序，保证结果确定性。

#### Scenario: 查询 Section 词条顺序
- **WHEN** 系统查询某 Section 内的词条列表
- **THEN** 返回的词条 SHALL 按 `orderIndex` 升序排列，与导入时的文件行序一致

#### Scenario: 存量数据平局排序
- **WHEN** 系统查询的词条中，多个词条的 `orderIndex` 均为 0（轻量迁移默认值）
- **THEN** 系统 SHALL 对这些词条按 `sourceWord` 字母升序排列，保证每次查询结果一致

### Requirement: Core Data 轻量迁移
系统 SHALL 在 Core Data 模型版本升级时启用轻量迁移（`NSMigratePersistentStoresAutomaticallyOption` + `NSInferMappingModelAutomaticallyOption`），自动为存量 `WordEntry` 填充新增属性默认值（`orderIndex` 0、`sourceLineNumber` 0）。

#### Scenario: 模型版本升级自动迁移
- **WHEN** 应用启动时检测到 Core Data store 使用旧版模型
- **THEN** 系统 SHALL 使用轻量迁移自动升级 store，存量词条的新增属性填充默认值 0，不丢失任何数据

#### Scenario: 迁移后行号可用
- **WHEN** 迁移完成后用户重新导入单词本
- **THEN** 新导入的词条 SHALL 正确记录 `sourceLineNumber`，预览视图正常显示行号

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

### Requirement: 词条原始 TXT 行号记录
系统 SHALL 在 TXT 词库导入时为每个词条记录其在原文件中的真实行号（从 1 起计），含被跳过的空行。该信息 SHALL 持久化到 `WordEntry.sourceLineNumber` 字段，不随词条编辑或删除而改变其他词条的行号。

#### Scenario: 成功导入时记录行号
- **WHEN** 用户导入一个 UTF-8 TXT 文件，文件中第 1 行为 `apple ...`，第 2 行为空行，第 3 行为 `banana ...`
- **THEN** 系统 SHALL 将 apple 的 `sourceLineNumber` 设为 1，banana 的 `sourceLineNumber` 设为 3

#### Scenario: 行号含被跳过的空行
- **WHEN** TXT 文件包含空行
- **THEN** 空行 SHALL 继续占据行号计数，后续词条的行号反映其在原文件中的真实位置

#### Scenario: 重新导入覆盖行号
- **WHEN** 用户对已有词条的单词本再次导入新词库
- **THEN** 系统 SHALL 用新文件中每个词条的行号完全替换旧的 `sourceLineNumber`，与 `orderIndex` 同步重置

#### Scenario: 编辑词条不影响行号
- **WHEN** 用户在预览视图中内联编辑某词条的单词 / 音标 / 词性 / 释义
- **THEN** 该词条的 `sourceLineNumber` SHALL 保持不变

#### Scenario: 删除词条不影响其他行号
- **WHEN** 用户在预览视图中删除某词条
- **THEN** 其他词条的 `sourceLineNumber` SHALL 保持不变

### Requirement: 预览视图行号列
单词本预览视图 SHALL 在表格最左侧显示"行号"列，展示每个词条的 `sourceLineNumber`。列宽 50pt，数字右对齐，使用等宽数字字体。

#### Scenario: 正常显示行号
- **WHEN** 用户打开单词本预览，词条存在且 `sourceLineNumber > 0`
- **THEN** 行号列 SHALL 显示该词条的原始 TXT 行号（整数）

#### Scenario: 老数据行号缺失
- **WHEN** 用户打开单词本预览，词条为 v0.1 已导入的老数据（`sourceLineNumber == 0`）
- **THEN** 行号列 SHALL 显示为 `-`，提示行号信息不可用

#### Scenario: 行号列表头
- **WHEN** 预览视图表头渲染
- **THEN** SHALL 显示为 `[ 行号 | 单词 | 音标 | 释义 | ⌫ ]`，行号列为第一列

### Requirement: 预览多组释义展示与编辑
预览视图的释义列 SHALL 将词条的全部释义组（最多 3 组）以 " / " 拼接展示，每组格式为"词性 释义"（与悬浮窗释义区展示格式一致）。释义列 SHALL 支持内联编辑：编辑文本按 " / " 拆组、每组内首个空格分隔词性与释义，保存时解析回 `pos1-3` / `meaning1-3` 字段；超过 3 组时仅保留前 3 组。

#### Scenario: 多组释义完整展示
- **WHEN** 词条包含 3 组释义（pos1-3 均非空），用户打开预览
- **THEN** 释义列 SHALL 显示 `v. 跑 / n. 奔跑 / n. 运转` 格式的拼接文本，而非仅第 1 组

#### Scenario: 编辑多组释义
- **WHEN** 用户将释义列编辑为 `v. 跑 / n. 奔跑` 并失焦保存
- **THEN** 系统 SHALL 解析回 pos1=v.、meaning1=跑、pos2=n.、meaning2=奔跑、第 3 组清空，悬浮窗展示同步更新

#### Scenario: 编辑文本解析容错
- **WHEN** 用户输入的某组释义无词性（如仅 `跑`）
- **THEN** 系统 SHALL 将该组整体存为释义，词性留空

#### Scenario: 行号列与分页协同
- **WHEN** 用户切换到第 2 页（第 101-200 条词条）
- **THEN** 行号列 SHALL 显示这些词条在原 TXT 文件中的真实行号，不是页内序号（如 103、107、109... 而非 101、102、103...，中间跳跃反映空行的存在）

