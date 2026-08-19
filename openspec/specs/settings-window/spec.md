## Purpose

主设置窗口，用户通过该界面管理单词本、配置背记规则、自定义外观样式与发音设置。窗口采用 Liquid Glass 玻璃材质 + sidebar 导航设计，内嵌悬浮窗实时预览。最低系统版本 macOS 14.0 (Sonoma)。
## Requirements
### Requirement: 设置窗口基础样式
主设置窗口 SHALL 采用 Liquid Glass 玻璃材质贯穿设计。标题栏使用 `.underWindowBackground` 材质与内容区无缝融合。内容区分 sidebar 与主区域：sidebar 使用 `.thinMaterial` 材质，主内容区使用 `.regularMaterial` 材质。整窗自动适配深色/浅色模式。最低系统版本 macOS 14.0 (Sonoma)。

#### Scenario: 窗口外观
- **WHEN** 主设置窗口打开
- **THEN** 窗口 SHALL 显示标准 macOS 标题栏（含红绿灯按钮），整窗呈现 Liquid Glass 磨砂玻璃质感，标题栏与内容区材质无缝过渡

#### Scenario: 深浅色自适应
- **WHEN** 系统切换外观模式
- **THEN** 设置窗口 SHALL 自动适配玻璃材质配色，sidebar 与内容区均跟随系统深浅色

#### Scenario: 最低系统版本
- **WHEN** 应用在 macOS 14.0 及以上系统运行
- **THEN** 设置窗口 SHALL 使用最新材质渲染；macOS 14 以下版本不运行本应用

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

### Requirement: 卡片式分组
内容区配置项 SHALL 使用圆角玻璃卡片分组，替代默认 Form Section 样式。卡片圆角 12pt，卡片间垂直间距 12pt，卡片内配置项行间使用 Divider 分隔。

#### Scenario: 卡片分组外观
- **WHEN** 设置窗口渲染内容区
- **THEN** 每组配置项 SHALL 包裹在圆角 12pt 的半透明玻璃卡片中，卡片间留 12pt 间距

#### Scenario: 卡片材质
- **WHEN** 系统切换深浅色模式
- **THEN** 卡片 SHALL 保持半透明玻璃质感，自动适配深浅色调

### Requirement: 自定义控件样式
设置窗口内所有可交互控件 SHALL 使用自定义 glass 样式，与悬浮窗玻璃质感语言一致。包括：自定义 ButtonStyle（默认/悬停/点击/禁用四态）、自定义 ToggleStyle（glass 滑块）、Picker 使用 glass radio group。

#### Scenario: 按钮四态
- **WHEN** 按钮处于不同交互状态
- **THEN** 按钮 SHALL 呈现对应的玻璃质感状态：默认态半透明、悬停态微亮、点击态微暗 + 微缩 0.97、禁用态 50% 不透明度

#### Scenario: Toggle 样式
- **WHEN** Toggle 控件渲染
- **THEN** SHALL 使用 glass 风格滑块，开启态蓝色玻璃药丸，关闭态灰色半透明

#### Scenario: 动效过渡
- **WHEN** 控件状态变化
- **THEN** SHALL 以 ease-out 0.2s 过渡到新状态

### Requirement: 设置窗口尺寸
设置窗口 SHALL 使用 720×560pt 默认尺寸，sidebar 宽度 200pt。最小尺寸 640×480pt。

#### Scenario: 默认尺寸
- **WHEN** 设置窗口首次打开
- **THEN** 窗口 SHALL 为 720×560pt，sidebar 宽 200pt，内容区占剩余宽度

#### Scenario: 最小尺寸
- **WHEN** 用户尝试缩小窗口
- **THEN** 窗口 SHALL 停止在 640×480pt

### Requirement: 单词本管理 Tab
系统 SHALL 提供单词本管理 Tab 页，展示单词本列表，支持新建、删除、重命名、启用勾选，以及 TXT 词库导入操作。显示每个单词本的单词总数与 Section 数量。

#### Scenario: 显示单词本列表
- **WHEN** 用户打开单词本管理 Tab
- **THEN** 系统 SHALL 展示所有单词本，每行显示名称、单词总数、Section 数量、启用勾选框

#### Scenario: 单词本操作栏
- **WHEN** 用户打开单词本管理 Tab
- **THEN** 列表下方 SHALL 显示操作栏卡片，包含新建、导入、重命名、删除四个按钮，横向排列；除新建外，其余按钮在未选中单词本时禁用；删除按钮在选中系统内置单词本时禁用

#### Scenario: 导入词库
- **WHEN** 用户选中某单词本并点击导入按钮选择 .txt 文件
- **THEN** 系统 SHALL 执行全量覆盖导入，导入完成后刷新列表中的单词总数与 Section 数量

#### Scenario: 系统内置单词本标记
- **WHEN** 单词本列表包含"我的收藏"
- **THEN** 系统 SHALL 在列表中标记该单词本为系统内置，禁用删除与手动导入入口

### Requirement: 背记规则设置 Tab
系统 SHALL 提供背记规则设置 Tab 页，包含背记模式选择、Section 设置（合并每组词数与走马灯循环轮次）、展示顺序、单单词停留时长、全屏自动隐藏等配置项。

#### Scenario: 背记模式选择
- **WHEN** 用户在背记规则 Tab 切换模式
- **THEN** 系统 SHALL 在"记忆反馈模式"与"走马灯式刷词模式"之间单选切换，立即生效

#### Scenario: Section 设置卡片
- **WHEN** 用户打开背记规则 Tab
- **THEN** 系统 SHALL 显示"Section 设置"卡片，包含"每组词数"（全局，始终可编辑，1-500，默认 20）与"走马灯循环轮次"（仅走马灯模式下可交互；记忆反馈模式下 SHALL 禁用并降低不透明度至 0.5 以示提示）

#### Scenario: 停留时长设置
- **WHEN** 用户调整单单词停留时长
- **THEN** 系统 SHALL 通过滑块 + 数字输入框同步设置，取值 1-60 秒，默认 5 秒

#### Scenario: 全屏自动隐藏开关
- **WHEN** 用户开启全屏自动隐藏
- **THEN** 当前活跃窗口为全屏的应用时，悬浮窗 SHALL 自动隐藏；退出全屏后自动恢复

### Requirement: 外观设置 Tab
系统 SHALL 提供外观设置 Tab 页，包含预设主题一键切换、背景色取色器、文字颜色取色器、背景透明度滑块、单词/释义字体与字号设置。配置修改实时反映到悬浮窗，无需预览区。

#### Scenario: 应用预设主题
- **WHEN** 用户点击"浅色""深色"或"护眼绿"预设主题
- **THEN** 系统 SHALL 一键应用该主题对应的所有外观参数，悬浮窗实时同步更新

#### Scenario: 自定义背景色
- **WHEN** 用户通过取色器选择自定义背景色
- **THEN** 系统 SHALL 将背景色叠加到玻璃材质层，悬浮窗实时反映变化

#### Scenario: 自定义文字颜色
- **WHEN** 用户在外观设置 Tab 通过取色器选择自定义文字颜色
- **THEN** 系统 SHALL 将该颜色应用到悬浮窗内所有文字（单词、音标、释义），悬浮窗实时反映变化

#### Scenario: 浅色模式自动微调
- **WHEN** 系统处于浅色模式，用户选择较深文字颜色
- **THEN** 系统 SHALL 保持该颜色不透明度 100% 直接应用

#### Scenario: 深色模式自动微调
- **WHEN** 系统处于深色模式，用户选择较浅文字颜色
- **THEN** 系统 SHALL 保持该颜色不透明度 100% 直接应用

#### Scenario: 预设主题联动
- **WHEN** 用户点击预设主题（浅色 / 深色 / 护眼绿）
- **THEN** 系统 SHALL 同步切换文字颜色为预设主题配套颜色

#### Scenario: 调整背景透明度
- **WHEN** 用户调整背景透明度滑块
- **THEN** 系统 SHALL 同步更新玻璃层与 tint 层的不透明度（0%-100%，默认 90%），文字层保持 100% 不透明

#### Scenario: 修改字体与字号
- **WHEN** 用户修改单词字体/字号或释义字体/字号
- **THEN** 悬浮窗 SHALL 实时反映字体与字号变化

### Requirement: 设置实时生效
设置界面修改的所有外观参数 SHALL 实时同步到悬浮窗，无需预览区域，无需重启应用。

#### Scenario: 外观设置实时响应
- **WHEN** 用户在任意外观设置项进行调整
- **THEN** 悬浮窗 SHALL 在 0.2s 内同步反映变化

### Requirement: 发音设置 Tab
系统 SHALL 提供发音设置 Tab 页，包含自动播放开关、按语言分区的具体语音选择（含试听按钮）、全局语速滑块，以及"发音基于系统语音引擎，离线可用"说明文案。语音选择与语速的行为规格见 speech 能力规格（openspec/specs/speech/spec.md）。

#### Scenario: 自动播放开关
- **WHEN** 用户开启/关闭自动播放
- **THEN** 系统 SHALL 保存设置，切换单词时按设置决定是否自动播放发音

#### Scenario: 发音类型切换
- **WHEN** 用户在语言分区的语音下拉中选择具体语音，或调整语速滑块
- **THEN** 系统 SHALL 保存选择，后续发音使用对应语音与语速

### Requirement: 系统菜单栏设置入口
HoverWord 作为 macOS 应用，SHALL 在系统菜单栏的应用名下拉菜单中提供"HoverWord 设置…"菜单项，快捷键 ⌘,（Command + 逗号）。点击该菜单项 SHALL 打开与悬浮窗右键菜单"打开设置"相同的设置窗口。

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

### Requirement: 设置窗口关闭行为
点击设置窗口关闭按钮 SHALL 不退出程序，仅隐藏主窗口与 Dock 栏图标，悬浮窗持续运行。

#### Scenario: 关闭设置窗口
- **WHEN** 用户点击设置窗口的关闭按钮
- **THEN** 系统 SHALL 隐藏主设置窗口，同时隐藏 Dock 栏图标，悬浮窗继续运行

#### Scenario: 重新唤起设置窗口
- **WHEN** 用户通过悬浮窗右键菜单选择"打开设置"
- **THEN** 系统 SHALL 重新显示主设置窗口，同时恢复 Dock 栏图标

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

### Requirement: 单词本预览
单词本管理 Tab SHALL 提供"预览"按钮，点击后弹出 Sheet 展示选中单词本内的词条列表。每条词条显示原始 TXT 行号、单词、音标、释义（多组释义拼接展示与编辑，见 wordbook 能力规格）。支持内联编辑（点击字段直接修改）和按钮删除（每行一个删除按钮）。列表分页展示，每页 100 条。列表行点击热区 SHALL 覆盖整行视觉区域，点击启用勾选框时 SHALL 同步选中该行。

#### Scenario: 打开预览
- **WHEN** 用户选中某单词本并点击"预览"按钮
- **THEN** 系统 SHALL 弹出 Sheet，展示该单词本内所有词条的分页列表

#### Scenario: 词条列表展示
- **WHEN** 预览 Sheet 打开
- **THEN** 系统 SHALL 以表格形式展示每条词条的行号（见 wordbook 能力规格的行号列需求）、单词、音标、释义（多组拼接），每页最多 100 条，底部提供分页控件

#### Scenario: 内联编辑词条
- **WHEN** 用户在预览列表中点击某词条的单词 / 音标 / 释义字段
- **THEN** 该字段 SHALL 变为可编辑状态，用户修改后按回车或失焦时自动保存

#### Scenario: 删除词条
- **WHEN** 用户点击某词条行的删除按钮
- **THEN** 系统 SHALL 删除该词条并刷新列表，若删除后列表为空则显示空状态提示

#### Scenario: 空单词本预览
- **WHEN** 用户对无词条的单词本点击"预览"
- **THEN** 预览 Sheet SHALL 显示"该单词本暂无词条"的空状态提示

#### Scenario: 分页导航
- **WHEN** 单词本包含超过 100 条词条
- **THEN** 预览 Sheet SHALL 显示分页控件，用户可翻页浏览所有词条

