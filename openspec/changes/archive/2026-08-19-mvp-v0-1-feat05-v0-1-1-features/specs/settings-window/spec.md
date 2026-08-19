Change-Sub-Version: mvp-v0-1-feat05

## Purpose

本次变更修复系统菜单栏"设置…"入口未接入 HoverWord 自定义设置窗口的问题，使其符合 macOS 标准应用行为。

## MODIFIED Requirements

### Requirement: 系统菜单栏设置入口

HoverWord 作为 macOS 应用，SHALL 在系统菜单栏的应用名下拉菜单中提供"HoverWord 设置…"菜单项，快捷键 ⌘,（Command + 逗号）。点击该菜单项 SHALL 打开与悬浮窗右键菜单"打开设置"相同的 `SettingsWindowController` 设置窗口。

#### Scenario: 点击菜单设置项
- **WHEN** 用户点击系统菜单栏的 "HoverWord → HoverWord 设置…"
- **THEN** 系统 SHALL 调用 `AppDelegate.showSettingsWindow()`，显示已有的 AppKit 设置窗口（与右键菜单"打开设置"行为完全一致）

#### Scenario: 快捷键 ⌘,
- **WHEN** 用户按下 ⌘,
- **THEN** 系统 SHALL 触发与菜单项相同的"打开设置"动作

#### Scenario: 设置窗口已打开时再次触发
- **WHEN** 设置窗口已经在前台显示，用户再次触发菜单项或 ⌘,
- **THEN** 系统 SHALL 将已存在的设置窗口置为 key window，不重复创建

### Requirement: 菜单标题

菜单栏设置项的标题 SHALL 为 "HoverWord 设置…"（包含省略号），符合 macOS HIG 对"打开配置界面"动作的命名约定。

#### Scenario: 菜单标题显示
- **WHEN** 用户展开系统菜单栏的 HoverWord 下拉菜单
- **THEN** SHALL 看到 "HoverWord 设置…" 菜单项，位于应用标准菜单区域
