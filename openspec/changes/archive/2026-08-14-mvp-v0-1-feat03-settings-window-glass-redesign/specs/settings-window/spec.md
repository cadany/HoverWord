Change-Sub-Version: mvp-v0-1-feat03

## MODIFIED Requirements

### Requirement: 设置窗口基础样式
主设置窗口 SHALL 采用 Liquid Glass 玻璃材质贯穿设计。标题栏使用 `.underWindowBackground` 材质与内容区无缝融合。内容区分 sidebar 与主区域：sidebar 使用 `.sidebar` 材质，主内容区使用 `.content` 材质。整窗自动适配深色/浅色模式。最低系统版本 macOS 14.0 (Sonoma)。

#### Scenario: 窗口外观
- **WHEN** 主设置窗口打开
- **THEN** 窗口 SHALL 显示标准 macOS 标题栏（含红绿灯按钮），整窗呈现 Liquid Glass 磨砂玻璃质感，标题栏与内容区材质无缝过渡

#### Scenario: 深浅色自适应
- **WHEN** 系统切换外观模式
- **THEN** 设置窗口 SHALL 自动适配玻璃材质配色，sidebar 与内容区均跟随系统深浅色

#### Scenario: 最低系统版本
- **WHEN** 应用在 macOS 14.0 及以上系统运行
- **THEN** 设置窗口 SHALL 使用 `.liquid` 材质渲染；macOS 14 以下版本不运行本应用

### Requirement: Sidebar 导航
设置窗口 SHALL 使用左侧 sidebar 导航替代顶部 Tab 切换。Sidebar 包含 4 个导航项：单词本、背记、外观、发音。每个导航项包含 SF Symbol 图标 + 文字标签。选中项 SHALL 以蓝色玻璃药丸高亮。

#### Scenario: Sidebar 导航项
- **WHEN** 用户打开设置窗口
- **THEN** 左侧 sidebar SHALL 显示 4 个导航项，每项包含图标与文字标签，默认选中第一项

#### Scenario: 选中态高亮
- **WHEN** 某导航项被选中
- **THEN** 该项 SHALL 以蓝色玻璃药丸形状高亮，药丸带细微内发光效果

#### Scenario: Hover 态
- **WHEN** 鼠标悬停在非选中的导航项上
- **THEN** 该项 SHALL 微微提亮背景，过渡动效 ease-out 0.15s

#### Scenario: 切换导航
- **WHEN** 用户点击 sidebar 中的导航项
- **THEN** 右侧内容区 SHALL 以 spring 过渡切换到对应 Tab 内容，选中药丸平滑滑动到新项

### Requirement: 卡片式分组
内容区配置项 SHALL 使用圆角玻璃卡片分组，替代默认 Form Section 样式。卡片圆角 12pt，卡片间垂直间距 12pt，卡片内配置项行间使用 Divider 分隔。

#### Scenario: 卡片分组外观
- **WHEN** 设置窗口渲染内容区
- **THEN** 每组配置项 SHALL 包裹在圆角 12pt 的半透明玻璃卡片中，卡片间留 12pt 间距

#### Scenario: 卡片材质
- **WHEN** 系统切换深浅色模式
- **THEN** 卡片 SHALL 保持半透明玻璃质感，自动适配深浅色调

### Requirement: 自定义控件样式
设置窗口内所有可交互控件 SHALL 使用自定义 glass 样式，与悬浮窗玻璃质感语言一致。包括：自定义 ButtonStyle（默认/悬停/点击/禁用四态）、自定义 ToggleStyle（glass 滑块）、Picker 使用 .segmented 或 glass radio group。

#### Scenario: 按钮四态
- **WHEN** 按钮处于不同交互状态
- **THEN** 按钮 SHALL 呈现对应的玻璃质感状态：默认态半透明、悬停态微亮、点击态微暗 + 微缩 0.97、禁用态 50% 不透明度

#### Scenario: Toggle 样式
- **WHEN** Toggle 控件渲染
- **THEN** SHALL 使用 glass 风格滑块，开启态蓝色玻璃药丸，关闭态灰色半透明

#### Scenario: 动效过渡
- **WHEN** 控件状态变化
- **THEN** SHALL 以 ease-out 0.2s 过渡到新状态

## ADDED Requirements

### Requirement: 设置窗口尺寸
设置窗口 SHALL 使用 720×560pt 默认尺寸，sidebar 宽度 200pt。最小尺寸 640×480pt。

#### Scenario: 默认尺寸
- **WHEN** 设置窗口首次打开
- **THEN** 窗口 SHALL 为 720×560pt，sidebar 宽 200pt，内容区占剩余宽度

#### Scenario: 最小尺寸
- **WHEN** 用户尝试缩小窗口
- **THEN** 窗口 SHALL 停止在 640×480pt

### Requirement: 设置窗口关闭行为
点击设置窗口关闭按钮 SHALL 不退出程序，仅隐藏主窗口与 Dock 栏图标，悬浮窗持续运行。（沿用现有行为）

#### Scenario: 关闭设置窗口
- **WHEN** 用户点击设置窗口的关闭按钮
- **THEN** 系统 SHALL 隐藏主设置窗口，同时隐藏 Dock 栏图标，悬浮窗继续运行

#### Scenario: 重新唤起设置窗口
- **WHEN** 用户通过悬浮窗右键菜单选择"打开设置"
- **THEN** 系统 SHALL 重新显示主设置窗口，同时恢复 Dock 栏图标
