---
baseline_version: "v0-1-2"
change_sub_version: "v0-1-2-feat05"
---

# Proposal: 学习统计 Tab（背记进度可视化）

## Why

两种背记模式的学习成果目前均不可视：记忆反馈模式的掌握度（ReviewState）只写不读，用户无法感知已掌握/进行中/待复习的分布；走马灯模式的 Section 进度只有续背锚点，无任何界面呈现。用户需要统计入口回答「我现在学得怎么样」。

## What Changes

1. 设置窗口新增「学习统计」Tab（Sidebar 第 3 位，位于背记之后），主视图跟随全局背记模式（方案 2，评审定稿）：
   - 记忆反馈模式：掌握度总览卡（三态堆叠条 + 待复习 + 累计曝光）+ 每词本掌握卡（三态堆叠条、最近学习、待复习、已学完徽标）
   - 走马灯模式：背记进度卡（合流队列进度 + 续背锚点行），历史掌握度折叠为汇总行
2. 引擎提供只读统计查询：掌握度聚合（按词本三态计数、待复习、累计曝光、最近学习）与续背锚点状态判定（与 restore 同源）
3. ReviewState 变更通知（`reviewStateDidChange`），统计 Tab 实时刷新；统计路径只读，SHALL NOT 写 ReviewState 或进度
4. 页标题 `?` popover 口径说明（已掌握/进行中/未学/待复习，无实现隐喻）；悬浮窗零改动

已评审定稿的产品决策（不再开放）：主视图跟随当前模式；「待复习」口径 = dueAt ≤ 当前时间；单选词本时锚点行统一显示词本名；锚点异常行显示「上次背完的词本已停用 / 已删除」；悬浮窗保持纯净不加掌握度标识。

## Impact

- **Affected specs**：
  - `openspec/specs/settings-window/spec.md`（MODIFIED: Sidebar 导航 6→7 项；ADDED: 学习统计 Tab）
  - `openspec/specs/recite-engine/spec.md`（ADDED: 学习统计只读查询与通知）
- **Affected code**：
  - `Features/Settings/SidebarItem.swift`（新增导航项）
  - `Features/Settings/StatsView.swift`（新增）
  - `Services/ReviewStateService.swift`（聚合查询 + 通知）
  - `Services/ReciteEngine.swift`（锚点状态只读判定）
  - `Shared/NotificationNames.swift`、`Localizable.xcstrings`
  - 测试：`ReviewStateService` 聚合、锚点判定、通知触发
- **Out of scope（只提出不实施）**：ReviewState 孤儿记录清理、词级下钻列表、历史趋势（需 ReviewLog 模型 v5）
