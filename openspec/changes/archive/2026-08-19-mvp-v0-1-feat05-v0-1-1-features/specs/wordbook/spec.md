Change-Sub-Version: mvp-v0-1-feat05

## Purpose

本次变更为单词本预览视图新增"原始 TXT 行号"列，帮助用户在"外部编辑 TXT 再重新导入"的工作流中快速定位词条在原文件中的位置。

## ADDED Requirements

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
- **THEN** SHALL 显示为 `[ 行号 | 单词 | 音标 | 词性 | 释义 | ⌫ ]`，行号列为第一列

#### Scenario: 行号列与分页协同
- **WHEN** 用户切换到第 2 页（第 101-200 条词条）
- **THEN** 行号列 SHALL 显示这些词条在**原 TXT 文件中的真实行号**，不是页内序号（如 103、107、109... 而非 101、102、103...，中间跳跃反映空行的存在）

### Requirement: 数据模型迁移

`WordEntry` 实体 SHALL 新增 `sourceLineNumber: Int32` 属性，默认值为 0。Core Data SHALL 通过轻量迁移（lightweight migration）完成升级：新建模型版本、添加属性、保留原有数据。

#### Scenario: 应用升级时的轻量迁移
- **WHEN** 已安装 v0.1 的用户升级到 v0.1.1
- **THEN** 系统 SHALL 自动执行轻量迁移，所有现有 `WordEntry` 的 `sourceLineNumber` 默认为 0，不丢失任何原有数据

#### Scenario: 迁移后可用
- **WHEN** 迁移完成后用户重新导入单词本
- **THEN** 新导入的词条 SHALL 正确记录 `sourceLineNumber`，预览视图正常显示行号
