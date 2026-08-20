## Context

本次变更在 v0.1 悬浮窗基础上扩展内容显示配置能力。现有架构已具备：
- `FloatContentView` 横向四列布局（单词、注音、释义、按钮）
- `AppSettings` Codable 配置持久化模式
- 鼠标追踪区域（`NSTrackingArea`）驱动按钮 hover 交互
- 外观变更通知机制（`.appAppearanceDidChange`）

本次需新增：ContentVisibility 三态枚举、注音/释义的 hover 显隐逻辑、注音字号配置、外观 UI 重组。

## Goals / Non-Goals

### Goals
- 实现注音/释义独立三态显示模式（always/hover/hidden）
- 提升注音可读性（alpha 0.65 → 0.85）
- 新增注音字号配置（8-14pt）
- 重组外观设置为 4 卡片布局
- 保持现有用户行为不变（默认 always）

### Non-Goals
- 不实现注音字体选择（保持系统字体）
- 不修改单词/释义的其他样式配置
- 不新增预设主题
- 不实现 per-wordbook 的显示模式覆盖

## Decisions

### Decision 1: ContentVisibility 枚举位置
**选择**：新建 `Models/Enums/ContentVisibility.swift`

**理由**：
- 与 `ReciteMode`、`PlayOrder` 保持组织一致性
- 作为独立类型便于复用（未来可能扩展到更多内容元素）
- 遵循 `CaseIterable` 便于 UI 生成 Segmented Control 选项

**备选方案**：内联到 AppSettings.swift 中 → 放弃，因为 AppSettings 已有较多职责

### Decision 2: Hover 显隐的实现方式
**选择**：`alphaValue` 淡入淡出 + 保留占位空间

**理由**：
- 窗口尺寸稳定，不产生跳动
- 与现有按钮 hover 交互模式一致（按钮用 `isHidden`，但按钮在末列，影响小）
- 注音/释义在内容区，尺寸变化会更明显
- `CATransaction` 动画与现有 `wordSwitchDuration` 动效风格统一

**备选方案**：
- `isHidden` 切换 + 动态窗口宽度 → 放弃，会导致窗口"弹跳"
- `isHidden` 切换 + 保留占位 → 放弃，NSTextField hidden 后不占空间

### Decision 3: 鼠标状态同步
**选择**：扩展 `mouseEntered`/`mouseExited`，新增 `updateContentVisibility(isHovering:)` 方法

**实现要点**：
- 复用现有 `isMouseInside` 状态变量
- 新增 `updatePhoneticVisibility()` 和 `updateMeaningVisibility()` 私有方法
- 每个方法内部读取 `AppSettings.shared.phoneticVisibility` 并决定 alpha 值
- 设置变更时（`handleAppearanceChange`）立即应用新规则

**状态机**：
```
                    mouseEntered
          ┌───────────────────────────────┐
          │                               ▼
    ┌──────────┐                    ┌──────────┐
    │ alpha=0  │                    │ alpha=1  │
    │ (hover)  │                    │          │
    └──────────┘                    └──────────┘
          ▲                               │
          │          mouseExited          │
          └───────────────────────────────┘

    条件: visibility == .hover
    其他模式: always → alpha=1, hidden → alpha=0
```

### Decision 4: 注音字号配置存储
**选择**：`AppSettings.phoneticFontSize: Double`，与 wordFontSize/meaningFontSize 保持一致

**持久化**：
- StoredSettings 新增 `phoneticFontSize: Double?`
- apply(stored:) 处理 nil 情况（旧版本迁移，使用默认值 10）

**UI**：
- Slider 范围 8-14pt，步进 1pt
- 与单词/释义字号控件样式一致

### Decision 5: 外观设置 UI 重组
**选择**：单 ScrollView + 4 个 glassCard，非 Tab/NavigationSplitView

**理由**：
- 配置项总量不多（约 10 个），单页滚动足够
- 与现有外观设置风格一致
- 避免引入 Tab 切换的复杂性

**卡片结构**：
```
┌─────────────────────────────────────┐
│ 🪟 悬浮窗口                          │
│  背景色 / 文字颜色 / 透明度          │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 📝 单词                              │
│  字体 / 字号                         │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 🔤 注音                              │
│  字号 / 显示模式 (Segmented)        │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│ 📖 释义                              │
│  字体 / 字号 / 显示模式 (Segmented) │
└─────────────────────────────────────┘
```

**Segmented Control**：
- 使用 SwiftUI `Picker` with `.pickerStyle(.segmented)`
- 与现有"主题"切换控件样式一致
- 选项：总是显示 / 悬停显示 / 隐藏

### Decision 6: 本地化键值组织
**选择**：新增以下本地化键：

```
// 显示模式
"displayMode" = "显示模式"
"displayMode.always" = "总是显示"
"displayMode.hover" = "悬停显示"
"displayMode.hidden" = "隐藏"

// 注音卡片
"appearance.phoneticStyle" = "注音"
"appearance.phoneticFontSize" = "注音字号"

// 卡片标题
"appearance.floatWindow" = "悬浮窗口"
"appearance.wordStyle" = "单词" (复用现有)
"appearance.meaningStyle" = "释义" (复用现有)
```

**实现**：在 `L10n.swift` 或对应的 JSON 文件中添加

## Risks / Trade-offs

### Risk 1: 旧用户迁移
**风险**：StoredSettings 新增字段，旧用户升级时可能丢失配置。

**缓解**：
- 新字段使用可选类型（`phoneticFontSize: Double?`、`phoneticVisibility: ContentVisibility?`）
- apply(stored:) 中处理 nil 情况，使用合理默认值（.always、10pt）
- 默认行为与 v0.1 完全一致，用户无感知

### Risk 2: 布局稳定性
**风险**：hover 模式下，注音/释义的 alpha 变化可能影响视觉效果。

**缓解**：
- 保留占位空间，窗口尺寸不变
- 使用 `CATransaction` 动画，与现有动效风格统一
- 动效时长使用 `Constants.buttonFadeDuration`（0.15s），保持响应感

### Risk 3: 性能影响
**风险**：鼠标事件频繁触发，可能影响性能。

**缓解**：
- 仅修改 `alphaValue`，不触发布局计算
- `mouseEntered`/`mouseExited` 事件频率低（相比 scroll/drag）
- 无额外 Timer 或高频轮询

### Trade-off 1: Segmented Control vs Picker
**选择**：Segmented Control

**权衡**：
- 优点：选项一目了然，操作直观
- 缺点：占用水平空间较多（3 个选项）
- 结论：配置项不多，卡片宽度足够，Segmented 更直观

### Trade-off 2: alpha 值选择
**选择**：0.85（而非 1.0 或 0.75）

**权衡**：
- 0.65（当前）：对比度不足，可读性差
- 0.75：略有改善，但仍偏淡
- 0.85：清晰可读，同时保持与单词的视觉层级
- 1.0：与单词同级，层级模糊
- 结论：0.85 是最佳平衡点
