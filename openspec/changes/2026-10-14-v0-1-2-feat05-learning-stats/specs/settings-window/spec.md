> Change-Sub-Version: v0-1-2-feat05

## MODIFIED Requirements

### Requirement: Sidebar 导航

设置窗口 SHALL 使用左侧 sidebar 导航替代顶部 Tab 切换。Sidebar 包含 7 个导航项：单词本、背记、学习统计、外观、发音、体验、通用。每个导航项包含 SF Symbol 图标 + 文字标签。选中项 SHALL 以蓝色玻璃药丸高亮。导航项标签 SHALL 跟随界面语言设置本地化渲染。

#### Scenario: Sidebar 导航项

- **WHEN** 用户打开设置窗口
- **THEN** 左侧 sidebar SHALL 显示 7 个导航项（单词本、背记、学习统计、外观、发音、体验、通用；学习统计位于背记之后、外观之前），每项包含图标与文字标签，默认选中第一项

#### Scenario: 学习统计图标

- **WHEN** 渲染学习统计导航项
- **THEN** SHALL 使用 SF Symbols 的 "chart.bar.fill" 图标（或语义相近的统计类图标）

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

## ADDED Requirements

### Requirement: 学习统计 Tab

设置窗口 SHALL 提供"学习统计"Tab，展示背记进度可视化数据。Tab 主视图 SHALL 跟随全局背记模式：记忆反馈模式显示掌握度卡片区，走马灯模式显示背记进度卡片区。统计页 SHALL 只读：SHALL NOT 修改 ReviewState、背记进度或续背锚点。悬浮窗 SHALL 保持现状，SHALL NOT 因本能力增加任何掌握度标识。

#### Scenario: 主视图跟随模式

- **WHEN** 全局背记模式为记忆反馈模式，用户打开学习统计 Tab
- **THEN** 主区块 SHALL 显示掌握度总览卡与各启用词本的掌握卡；无 ReviewState 记录的启用词本 SHALL 显示走马灯历史折叠行或「未开始」

- **WHEN** 全局背记模式为走马灯模式，用户打开学习统计 Tab
- **THEN** 主区块 SHALL 显示背记进度卡；有 ReviewState 记录的词本 SHALL 以折叠汇总行显示历史掌握度

- **WHEN** 用户在背记规则 Tab 切换背记模式后回到学习统计 Tab（或 Tab 正在显示）
- **THEN** 主视图 SHALL 跟随新模式切换卡片区，SHALL NOT 显示旧模式残留内容

#### Scenario: 掌握度总览卡

- **WHEN** 记忆反馈模式下学习统计 Tab 渲染掌握度总览卡
- **THEN** SHALL 显示启用词本范围内聚合的三态堆叠条与图例计数（已掌握 / 进行中 / 未学），以及"待复习"（dueAt 已到期的词数，警示色）与"累计曝光"（全部累计曝光之和）两个指标

#### Scenario: 词本掌握卡

- **WHEN** 记忆反馈模式下渲染某启用词本的掌握卡
- **THEN** SHALL 显示词本名、词数、三态堆叠条与图例计数、"最近学习"（相对时间）与该词本"待复习"数；词本全部词条均已掌握时 SHALL 显示"已学完"徽标

#### Scenario: 背记进度卡

- **WHEN** 走马灯模式下学习统计 Tab 渲染背记进度卡
- **THEN** SHALL 显示合流 Section 队列的进度条与「已完成 N / 共 M 个 Section」（N/M 为跨词本连续计数），副标题显示「已启用 K 个词本 · 共 M 个 Section」；引擎处于有效走马灯位置时 SHALL 另显示「正在背：Section N+1 · 第 X / Y 词」明细行（实时位置）；存在有效续背锚点时 SHALL 显示「上次背完：〈词本名〉 · Section N」，单选词本时词本名 SHALL 同样显示

#### Scenario: 背记进度实时刷新

- **WHEN** 走马灯模式下引擎推进单词或切换 Section（含引擎重启、进度归零、一整轮完成绕回）
- **THEN** 学习统计 Tab（若正在显示）SHALL 实时反映最新位置（词级轮询快照，无需手动重进 Tab），SHALL NOT 因统计浏览向引擎广播高频通知

#### Scenario: 续背锚点状态

- **WHEN** 走马灯模式下无有效续背锚点（首次安装或从未完成 Section）且引擎无有效走马灯位置
- **THEN** 背记进度卡 SHALL 显示空态「还没有背记进度」与引导文案「背完一个 Section 后，这里会显示进度」

- **WHEN** 无有效续背锚点但引擎正处于有效走马灯位置（背记进行中）
- **THEN** SHALL NOT 显示空态卡（进行中进度已在背记进度卡实时展示）

- **WHEN** 续背锚点指向的词本已被删除
- **THEN** 锚点行 SHALL 显示「上次背完的词本已删除」

- **WHEN** 续背锚点指向的词本存在但未启用
- **THEN** 锚点行 SHALL 显示「上次背完的词本已停用」

- **WHEN** 续背锚点指向的词本已启用但对应 Section 已无词条
- **THEN** SHALL 显示空态（与引擎锚点失效回退语义一致）

#### Scenario: 口径说明 popover

- **WHEN** 用户点击学习统计页标题旁的 `?` 按钮
- **THEN** 系统 SHALL 弹出口径说明，内容包含：已掌握（累计 5 次复习点「认识」）、进行中（已开始背记还没达到 5 次「认识」）、未学（尚未在记忆反馈模式下背过）、待复习（距下次复习的间隔已到，下次背记优先出现），以及三态反馈对复习间隔的影响说明与"已掌握词会定期重现巩固、悬浮窗显示一致"的预期管理说明、掌握度数据仅在记忆反馈模式产生的边界说明

#### Scenario: 统计实时刷新

- **WHEN** 用户在记忆反馈模式下产生任一反馈（认识 / 模糊 / 超时不认识）、重置学习记录、或修改影响数据范围的设置（模式切换、词本启停）
- **THEN** 学习统计 Tab（若正在显示）SHALL 在数据变更后刷新显示，无需手动重进 Tab

#### Scenario: 统计只读

- **WHEN** 用户浏览学习统计 Tab
- **THEN** 系统 SHALL NOT 修改 ReviewState、背记进度、续背锚点或任何背记引擎状态（悬浮窗显示的单词与进度 SHALL 不受浏览统计影响）
