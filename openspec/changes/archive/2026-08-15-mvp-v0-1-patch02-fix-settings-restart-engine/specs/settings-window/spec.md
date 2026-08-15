Change-Sub-Version: mvp-v0-1-patch02

## MODIFIED Requirements

### Requirement: 设置变更通知分类
系统 SHALL 根据设置类型发送不同的通知，避免无关设置变更触发引擎重启。外观设置（背景色、字体、透明度等）和发音设置（自动播放、口音）变更后 SHALL 发送 `.appAppearanceDidChange` 通知；计时参数（停留时长、全屏自动隐藏）变更后 SHALL 发送 `.appTimingDidChange` 通知；背记规则（背记模式、播放顺序、Section 大小、走马灯轮次）变更后 SHALL 发送 `.appSettingsDidChange` 通知。

#### Scenario: 外观设置变更不重启引擎
- **WHEN** 用户在外观设置页修改背景色、字体、透明度等
- **THEN** 系统 SHALL 发送 `.appAppearanceDidChange` 通知，悬浮窗刷新外观样式，背记引擎不重启、不重置进度

#### Scenario: 发音设置变更不重启引擎
- **WHEN** 用户在发音设置页切换自动播放开关或口音类型
- **THEN** 系统 SHALL 发送 `.appAppearanceDidChange` 通知，背记引擎不重启、不重置进度

#### Scenario: 计时参数变更热更新计时器
- **WHEN** 用户在背记设置页修改停留时长或全屏自动隐藏开关
- **THEN** 系统 SHALL 发送 `.appTimingDidChange` 通知，背记引擎热更新计时器（重新计算剩余时间），不重建队列、不重置进度

#### Scenario: 背记规则变更重启引擎
- **WHEN** 用户在背记设置页修改背记模式、播放顺序、Section 大小或走马灯轮次
- **THEN** 系统 SHALL 发送 `.appSettingsDidChange` 通知，背记引擎重启（重建队列、重置进度、从第一个单词开始）
