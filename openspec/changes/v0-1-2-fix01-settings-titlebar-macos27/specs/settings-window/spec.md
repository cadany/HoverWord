Change-Sub-Version: v0-1-2-fix01

## Purpose

明确设置窗口标题栏由应用显式接管（透明标题栏 + 全尺寸内容视图），消除 macOS 27 下标题栏区域出现独立不透明条带的渲染异常，并使 14-27 各版本走同一条渲染路径。

## MODIFIED Requirements

### Requirement: 设置窗口基础样式

主设置窗口 SHALL 采用 Liquid Glass 玻璃材质贯穿设计。标题栏 SHALL 由应用显式接管：`styleMask` 包含 `.fullSizeContentView` 且 `titlebarAppearsTransparent = true`，标题栏区域 SHALL NOT 绘制独立于内容的系统背景，材质由窗口内容层统一贯穿。内容区分 sidebar 与主区域：sidebar 使用 `.thinMaterial` 材质，主内容区使用 `.regularMaterial` 材质。红绿灯按钮与窗口标题保持系统默认位置与行为。整窗自动适配深色/浅色模式。最低系统版本 macOS 14.0 (Sonoma)。

#### Scenario: 窗口外观

- **WHEN** 主设置窗口打开
- **THEN** 窗口 SHALL 显示标准 macOS 标题栏（含红绿灯按钮），整窗呈现 Liquid Glass 磨砂玻璃质感，标题栏与内容区材质无缝过渡

#### Scenario: 深浅色自适应

- **WHEN** 系统切换外观模式
- **THEN** 设置窗口 SHALL 自动适配玻璃材质配色，sidebar 与内容区均跟随系统深浅色

#### Scenario: 最低系统版本

- **WHEN** 应用在 macOS 14.0 及以上系统运行
- **THEN** 设置窗口 SHALL 使用最新材质渲染；macOS 14 以下版本不运行本应用

#### Scenario: macOS 27 标题栏无独立不透明条带

- **WHEN** 应用在 macOS 27 上打开设置窗口
- **THEN** 标题栏区域 SHALL NOT 出现独立于内容的系统默认背景条带，sidebar 折叠按钮 SHALL 呈现于标题栏区域内且无独立不透明底色

#### Scenario: 标题栏接管不破坏窗口操作

- **WHEN** 用户在任意受支持系统版本上操作设置窗口标题栏
- **THEN** 红绿灯关闭/最小化、标题栏拖拽移动窗口 SHALL 与接管前行为一致
