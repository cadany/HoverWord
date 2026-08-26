Change-Sub-Version: v0-1-2-patch01

## MODIFIED Requirements

### Requirement: 动效协议定义
系统提供 `WordTransitionEffect` 协议，所有动效必须实现统一接口。协议将动画编排与内容切换职责分离：动效只负责"如何动画"，新内容落位由调用方经 `swapContent` 回调完成。

#### Scenario: 协议接口
- **WHEN** 实现一个新的动效
- **THEN** 该动效 SHALL 实现 `WordTransitionEffect` 协议，提供 `id`、`displayName`、`category`、`animate(from:to:in:parameters:swapContent:completion:)` 方法

#### Scenario: 内容切换职责
- **WHEN** 动效动画进行到旧内容视觉不可辨的时点（翻转侧立、缩放为零、淡出完成、逐字符开始前等）
- **THEN** 动效 SHALL 调用 `swapContent()` 恰好一次，由视图层完成单词与音标的新内容落位，动效 SHALL NOT 自行写入标签内容

#### Scenario: 音标同步
- **WHEN** 任意动效切换内容
- **THEN** 单词与音标 SHALL 在同一动画节点经 `swapContent` 同步切换，音标 SHALL NOT 在动画全程残留旧内容至结束后跳变
