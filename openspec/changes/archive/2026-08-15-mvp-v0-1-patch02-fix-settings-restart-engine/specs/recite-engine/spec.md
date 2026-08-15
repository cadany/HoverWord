Change-Sub-Version: mvp-v0-1-patch02

## MODIFIED Requirements

### Requirement: 引擎响应计时参数变更
背记引擎 SHALL 监听 `.appTimingDidChange` 通知，收到后热更新计时器（重新计算当前单词的剩余展示时间），不重建队列、不重置当前进度。引擎仍监听 `.appSettingsDidChange` 通知，收到后重启引擎（重建队列、重置进度）。

#### Scenario: 计时参数变更热更新计时器
- **WHEN** 系统发送 `.appTimingDidChange` 通知且引擎处于 `.playing` 状态
- **THEN** 引擎 SHALL 使用新的 `stayDuration` 值重新启动计时器，当前单词和进度保持不变

#### Scenario: 非播放状态忽略计时变更
- **WHEN** 系统发送 `.appTimingDidChange` 通知但引擎处于 `.idle` 或 `.allComplete` 状态
- **THEN** 引擎 SHALL 不执行任何操作
