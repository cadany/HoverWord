Change-Sub-Version: v0-1-1-patch02

## Purpose

队列构建由逐 Section 查询改为单次查询内存分组，消除万级词库下设置变更触发的 500+ 次主线程 fetch；新增全屏静音挂起，隐藏期间发音挂起但切词进度不受影响。

## MODIFIED Requirements

### Requirement: Section 队列构建
系统 SHALL 根据用户勾选启用的单词本，按单词本在列表中的排列顺序，将所有 Section 依次拼接为完整的背记队列。构建 SHALL 采用每单词本单次查询取出全部词条并按 sectionIndex 内存分组（排序口径 sectionIndex → orderIndex → sourceWord，与逐 Section 查询一致），而非逐 Section 发起查询。收藏夹单词本 SHALL 单次取全部 Favorite 按 sectionSize 分桶，sectionIndex 由分桶位置推导。

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

#### Scenario: 万级词库构建队列
- **WHEN** 启用词本含 10000 词条（sectionSize=20），引擎启动或设置/数据变更触发队列重建
- **THEN** 系统 SHALL 对每个启用词本仅执行 1 次词条查询（而非 501 次），构建结果与逐 Section 查询完全一致

#### Scenario: 收藏夹队列构建
- **WHEN** 收藏夹单词本启用且含收藏词条
- **THEN** 系统 SHALL 单次取全部收藏按 collectedAt 排序分桶，分桶语义与原分页查询（offset 递进）一致

## ADDED Requirements

### Requirement: 全屏静音挂起
系统 SHALL 支持挂起自动发音而不影响背记流转：挂起期间 Timer、轮次推进、进度持久化照常执行，仅自动发音被拦截。手动点击喇叭按钮 SHALL 不受挂起影响。

#### Scenario: 全屏隐藏时静音
- **WHEN** 全屏自动隐藏开启且"全屏隐藏时静音发音"开启，悬浮窗因全屏应用隐藏
- **THEN** 系统 SHALL 停止在播语音并挂起后续自动发音，切词与进度保存照常进行

#### Scenario: 恢复显示后发音自然恢复
- **WHEN** 退出全屏，悬浮窗恢复显示
- **THEN** 系统 SHALL 解除发音挂起，下一个切到的单词自动发音恢复正常，无需重启引擎

#### Scenario: 静音开关关闭时隐藏不挂起
- **WHEN** 全屏自动隐藏开启但静音开关关闭，悬浮窗隐藏
- **THEN** 自动发音 SHALL 照常进行（保持原有行为），显示路径重复解除挂起为幂等操作
