Change-Sub-Version: v0-1-1-patch02

## Purpose

背记设置"其他"卡片新增全屏静音开关，与全屏自动隐藏联动。

## ADDED Requirements

### Requirement: 全屏静音设置项
背记设置"其他"卡片 SHALL 提供"全屏隐藏时静音发音"开关（`recite.muteInFullscreen`，默认开启，含中英文案）。开关 SHALL 仅在全屏自动隐藏开启时可用，未启用时置灰半透明。变更经 `postTimingChange` 持久化（不重置背记进度）。

#### Scenario: 开关联动置灰
- **WHEN** "全屏应用时自动隐藏悬浮窗"未勾选
- **THEN** "全屏隐藏时静音发音"开关 SHALL 置灰不可操作；勾选自动隐藏后恢复可用

#### Scenario: 开关状态持久化
- **WHEN** 用户切换静音开关后重启应用
- **THEN** 开关状态 SHALL 保持；旧版本升级（存储无此字段）SHALL 默认开启
