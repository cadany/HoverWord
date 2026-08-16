Change-Sub-Version: v0-1-1-feat01

## Purpose

Sidebar 新增第 5 个导航项"通用"，承载界面语言设置（后续版本的全局类设置也归入此页）。

## MODIFIED Requirements

### Requirement: Sidebar 导航
设置窗口 SHALL 使用左侧 sidebar 导航替代顶部 Tab 切换。Sidebar 包含 5 个导航项：单词本、背记、外观、发音、通用。每个导航项包含 SF Symbol 图标 + 文字标签。选中项 SHALL 以蓝色玻璃药丸高亮。导航项标签 SHALL 跟随界面语言设置本地化渲染。

#### Scenario: Sidebar 导航项
- **WHEN** 用户打开设置窗口
- **THEN** 左侧 sidebar SHALL 显示 5 个导航项，每项包含图标与文字标签，默认选中第一项

#### Scenario: 选中态高亮
- **WHEN** 某导航项被选中
- **THEN** 该项 SHALL 以蓝色玻璃药丸形状高亮，药丸带细微内发光效果

#### Scenario: Hover 态
- **WHEN** 鼠标悬停在非选中的导航项上
- **THEN** 该项 SHALL 微微提亮背景，过渡动效 ease-out 0.15s

#### Scenario: 切换导航
- **WHEN** 用户点击 sidebar 中的导航项
- **THEN** 右侧内容区 SHALL 以 spring 过渡切换到对应 Tab 内容，选中药丸平滑滑动到新项

#### Scenario: 通用页内容
- **WHEN** 用户点击"通用"导航项
- **THEN** 内容区 SHALL 显示"界面语言"设置组（"跟随系统"与已提供的语言选项，v0.1.1 为简体中文、English），采用与其他页一致的卡片分组样式
