Change-Sub-Version: v0-1-1-feat05

## Purpose

悬浮窗鼠标进出事件扩展：在既有按钮浮现/内容显隐职责外，向窗口控制器上报悬停状态，用于驱动背记引擎的计时暂停。

## ADDED Requirements

### Requirement: 悬停状态通知引擎
悬浮窗 SHALL 通过既有 tracking area 感知鼠标进出，并向窗口控制器上报悬停状态：进入时通知引擎暂停切词计时，离开时通知引擎从剩余时长恢复计时。窗口被隐藏时 SHALL 将悬停状态重置为"鼠标不在窗内"并通知引擎恢复计时。

#### Scenario: 鼠标进入通知暂停
- **WHEN** 鼠标进入悬浮窗
- **THEN** 系统 SHALL 在既有悬停 UI 行为（按钮浮现、hover 内容淡入）之外，通知背记引擎暂停切词计时

#### Scenario: 鼠标离开通知恢复
- **WHEN** 鼠标离开悬浮窗
- **THEN** 系统 SHALL 在按钮淡出、hover 内容淡出之外，通知背记引擎从剩余时长恢复计时

#### Scenario: 窗口隐藏重置
- **WHEN** 悬浮窗被隐藏（全屏自动隐藏/显隐切换）
- **THEN** 悬停状态 SHALL 重置为"鼠标不在窗内"（按钮与 hover 内容归位），并通知引擎恢复计时，防止 mouseExited 缺失导致背记永久暂停
