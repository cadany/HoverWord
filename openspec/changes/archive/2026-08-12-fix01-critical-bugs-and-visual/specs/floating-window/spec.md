> Change-Sub-Version: fix01

## Purpose

修复悬浮窗深色模式失效问题，补全所有缺失的动效实现，使视觉表现与 UI spec 完全一致。

## MODIFIED Requirements

### Requirement: 深色/浅色模式自动适配（修正）
悬浮窗所有视觉元素 SHALL 自动跟随系统深色/浅色模式切换配色，不再硬编码单一外观。

#### Scenario: 系统切换深色模式
- **WHEN** 系统外观切换为深色模式
- **THEN** 悬浮窗 SHALL 自动切换为深色配色方案：玻璃材质背景适配深色、文字使用白色系（primary α=0.90, secondary α=0.60）、按钮使用深色模式配色

#### Scenario: 系统切换浅色模式
- **WHEN** 系统外观切换为浅色模式
- **THEN** 悬浮窗 SHALL 自动切换为浅色配色方案：文字使用黑色系（primary α=0.85, secondary α=0.55）、按钮使用浅色模式配色

### Requirement: 玻璃材质深色模式适配
`GlassBackgroundView` SHALL 不硬编码 `appearance`，让 NSVisualEffectView 自动跟随系统外观。内描边颜色 SHALL 根据当前外观动态切换浅色/深色 alpha 值。

#### Scenario: 深色模式下内描边
- **WHEN** 系统为深色模式
- **THEN** 内描边 SHALL 使用白色 alpha=0.15

#### Scenario: 浅色模式下内描边
- **WHEN** 系统为浅色模式
- **THEN** 内描边 SHALL 使用白色 alpha=0.30

### Requirement: 单词切换动效（修正）
单词切换时 SHALL 使用轻微淡入淡出 + 1px 垂直位移动效，过渡时长 0.15s，ease-out 缓动。

#### Scenario: 切换单词完整动效
- **WHEN** 从单词 A 切换至单词 B
- **THEN** 系统 SHALL 先以 0.15s ease-out 将当前内容淡出并向下位移 1px，再以 0.15s ease-out 将新内容从上方 1px 位移淡入至正常位置

### Requirement: 按钮悬停浮现动效（修正）
操作按钮从隐藏到显示时 SHALL 使用淡入 + 从底部滑入的组合动效，过渡时长 0.15s，ease-out 缓动。

#### Scenario: 按钮浮现完整动效
- **WHEN** 鼠标悬停到悬浮窗，按钮从隐藏变为显示
- **THEN** 按钮 SHALL 以 0.15s ease-out 从底部 4px 位置滑入并同步淡入至不透明度 1.0

### Requirement: 按钮点击态动效（新增）
操作按钮被点击时 SHALL 播放按压反馈动效：轻微亮度降低 + 视觉微缩，过渡时长 0.1s。

#### Scenario: 点击按钮
- **WHEN** 用户点击"认识"/"不认识"/"收藏"按钮
- **THEN** 按钮 SHALL 以 0.1s 过渡降低亮度（layer brightness 增加）并微缩至 0.95 倍，松开后恢复原状

### Requirement: 窗口显示/隐藏动效（新增）
悬浮窗显示和隐藏时 SHALL 使用淡入淡出 + 轻微缩放的组合动效，过渡时长 0.2s，无闪烁。

#### Scenario: 窗口显示
- **WHEN** 悬浮窗从隐藏变为显示
- **THEN** 系统 SHALL 以 0.2s ease-out 执行从 alpha=0 + scale=0.95 到 alpha=1 + scale=1.0 的过渡

#### Scenario: 窗口隐藏
- **WHEN** 悬浮窗从显示变为隐藏
- **THEN** 系统 SHALL 以 0.2s ease-out 执行从 alpha=1 + scale=1.0 到 alpha=0 + scale=0.95 的过渡

### Requirement: 完成状态切换动效（新增）
悬浮窗进入"已学完"状态时 SHALL 使用 ease-out 缓动过渡，而非瞬间切换。

#### Scenario: 进入完成状态
- **WHEN** 所有 Section 完成，悬浮窗切换至"已学完"视图
- **THEN** 系统 SHALL 以 0.2s ease-out 将单词内容淡出，"已学完"文字淡入

### Requirement: 设置应用过渡动效（新增）
用户修改外观设置（字体大小、颜色、透明度等）后，悬浮窗 SHALL 以 0.2s 过渡动画平滑应用变更，而非瞬间跳变。

#### Scenario: 修改字号后过渡
- **WHEN** 用户在设置中修改单词/释义字号
- **THEN** 悬浮窗 SHALL 以 0.2s ease-out 过渡到新字号，文字大小平滑变化

#### Scenario: 修改背景色后过渡
- **WHEN** 用户在设置中修改背景色或透明度
- **THEN** 悬浮窗 SHALL 以 0.2s ease-out 过渡到新颜色/透明度
