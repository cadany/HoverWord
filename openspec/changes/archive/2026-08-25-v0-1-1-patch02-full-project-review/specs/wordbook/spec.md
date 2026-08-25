Change-Sub-Version: v0-1-1-patch02

## Purpose

删除词本的收藏一致性、导入错误类型语义、列表统计查询合并。

## MODIFIED Requirements

### Requirement: 导入格式校验与错误报告
系统 SHALL 在导入时自动校验文件格式，字段缺失、格式错误或无任何有效词条时弹出提示，告知错误行号与原因（空文件提示内容为空），导入中断，保留原有数据。导入目标单词本不存在时（导入面板打开期间被删除的竞态），系统 SHALL 抛出专用的 `wordbookMissing` 错误并以对应文案提示，不得以"第 0 行格式错误"类魔法行号伪装成文件格式错误。

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

#### Scenario: 导入目标词本已被删除
- **WHEN** 用户打开导入面板后词本在别处被删除，确认导入
- **THEN** 系统 SHALL 抛出 `ImportError.wordbookMissing`，用户看到"单词本不存在"提示而非格式错误

## ADDED Requirements

### Requirement: 删除词本清理孤儿收藏
删除单词本时，系统 SHALL 在级联删除词条前快照其全部 sourceWord；对无任何其他单词本包含的 sourceWord，SHALL 一并移除对应收藏并广播 `favoritesDidChange`（与删除单词条、导入后同步的收藏清理语义一致）。

#### Scenario: 删除含已收藏词条的词本
- **WHEN** 词本 A 含词条 "apple"（已收藏），无其他词本含 "apple"，用户删除词本 A
- **THEN** "apple" 的收藏记录 SHALL 被移除，收藏夹不再出现该词条

#### Scenario: 其他词本仍有同名词条时保留收藏
- **WHEN** 词本 A、B 均含 "apple"（已收藏），用户删除词本 A
- **THEN** "apple" 收藏 SHALL 保留（B 仍提供该词条）

### Requirement: 词本统计合并查询
设置页词本列表刷新时，系统 SHALL 通过单次合并查询获取每个词本的（词条数, Section 数）；收藏夹单词本的两项统计 SHALL 源自同一次 Favorite count，不得重复查询。

#### Scenario: 列表刷新查询次数
- **WHEN** 设置窗口获焦点或 CRUD 操作后刷新词本列表
- **THEN** 收藏夹行 SHALL 仅执行 1 次 count 查询（原为 2 次），普通词本行为不变
