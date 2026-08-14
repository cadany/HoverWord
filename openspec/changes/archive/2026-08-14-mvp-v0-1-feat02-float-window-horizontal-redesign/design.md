## Context

悬浮窗当前采用纵向布局（NSStackView vertical），默认宽 300pt / 高自适应，最大 600×500。FloatContentView 内部结构为：纵向 contentStack（word → phonetic → meaningStack）+ 底部 buttonStack，所有元素居中对齐。AppSettings 存储 backgroundColorHex / backgroundOpacity，但无文字颜色字段。AppearanceView 使用 SwiftUI，提供背景色 / 透明度 / 字体设置。NSColor(hex:) 仅支持 6 字符 RGB。Constants.maxMeaningDisplayCount = 3 限制释义展示数量。

本次变更涉及：布局重构（纵→横，3列→4列）、resize 边界变更、释义高度自适应换行、新增文字颜色设置。单位统一使用 points（pt）。

## Goals / Non-Goals

**Goals:**
- 悬浮窗改为横向四列布局（单词 | 音标 | 释义 | 按钮横排），更紧凑
- 支持 300×30 至 1200×800 自由 resize
- 释义区根据窗口可用高度自动决定展示行数
- 外观设置增加文字颜色取色器，单词/音标/释义共用
- 历史存储的窗口尺寸自动 clamp 到新边界

**Non-Goals:**
- 不改变玻璃材质渲染逻辑（Liquid Glass / hudWindow 降级保持不变）
- 不改变按钮交互模式（hover 浮现 / 走马灯模式逻辑不变）
- 不改变现有动效参数（时长、缓动曲线不变）
- 不支持文字颜色按层级分别设置（单词/音标/释义各自不同颜色）
- 用户设置更大字号导致溢出时不处理，由用户自行调整窗口大小

## Decisions

### Decision 1: FloatContentView 布局重构为横向四列

将 FloatContentView 的主容器由纵向 NSStackView 改为横向 NSStackView，4 个独立列：

```
rootStack (.horizontal, alignment: .centerY)
├── wordLabel (Semibold, 14pt, 左对齐, 垂直居中)
├── phoneticLabel (Regular, 10pt, 左对齐, 垂直居中)
│   ← setCustomSpacing(16pt, after:)
├── meaningLabel (NSTextField, multi-line, 低 hugging, 占据剩余宽度)
│   ← setCustomSpacing(16pt, after:)
└── buttonStack (.horizontal, .centerY, 高 hugging, 右对齐)
    ├── favoriteButton
    ├── knowButton (仅记忆反馈模式)
    └── unknownButton (仅记忆反馈模式)
```

- **第 1 列**（`wordLabel`）：直接作为 rootStack 的 arranged subview，垂直居中
- **第 2 列**（`phoneticLabel`）：直接作为 rootStack 的 arranged subview，垂直居中，无音标时隐藏
- **第 3 列**（`meaningLabel`）：多行 NSTextField，低 hugging + 低压缩阻力，占据剩余水平空间
- **第 4 列**（`buttonStack`）：NSStackView horizontal，高 hugging 保持紧凑，自然右对齐

**列间距**：使用 `rootStack.spacing = 8` 作为默认间距（单词-音标之间），通过 `setCustomSpacing(_:after:)` 设置音标-释义、释义-按钮之间为 16pt。

**理由**：4 列独立布局比 3 列（左列内嵌垂直堆叠）更扁平，减少约束层级。单词和音标各自独立列，在窄窗口下更灵活。`setCustomSpacing` 原生支持每列间不同间距，无需嵌套 stack 或额外 spacer view。

### Decision 2: 释义区高度响应策略

通过 FloatContentView 重写 `resize(withOldSuperviewSize:)` 监听窗口尺寸变化：

```swift
override func resize(withOldSuperviewSize oldSize: NSSize) {
    super.resize(withOldSuperviewSize: oldSize)
    updateMeaningLines()
}

private func updateMeaningLines() {
    let contentHeight = bounds.height - Constants.floatWindowPaddingVertical * 2
    let lineH = meaningLabel.font?.ascender ?? 12
    let canFitMultipleLines = contentHeight >= lineH * 2 + Constants.meaningLineSpacing
    meaningLabel.maximumNumberOfLines = canFitMultipleLines ? 0 : 1
    meaningLabel.cell?.truncatesLastVisibleLine = !canFitMultipleLines
}
```

- **窗口高度 < ~2行高度**：maximumNumberOfLines = 1，单行截断
- **窗口高度 ≥ ~2行高度**：maximumNumberOfLines = 0，自动换行

**理由**：重写 `resize` 是最直接的窗口尺寸感知方式，不需要监听通知或 KVO。判断条件使用字体 ascender 而非硬编码阈值，能适应用户修改字号后的变化。

### Decision 3: 移除释义数量上限

删除 Constants.maxMeaningDisplayCount，showWord() 中展示全部释义，不再截断到 3 组。中列使用 NSTextField multi-line（NSTextField with `maximumNumberOfLines`），不额外使用 NSScrollView（释义区本身随窗口高度扩展，无需滚动）。

**理由**：横向布局下，中列宽度通常足够，3+ 组释义在一行内通常可容纳；窗口高度增加后自然换行展示更多。

### Decision 4: Resize 边界变更与历史尺寸 clamp

更新 Constants：

| 常量 | 旧值 | 新值 |
|---|---|---|
| `floatWindowWidth`（默认宽度） | 300 | 300 |
| `floatWindowMinWidth` | 200 | 300 |
| `floatWindowMaxWidth` | 600 | 1200 |
| `floatWindowMinHeight` | 120 | 30 |
| `floatWindowMaxHeight` | 500 | 800 |

FloatWindowController 恢复历史尺寸时增加 clamp：

```swift
private func clampSize(_ size: NSSize) -> NSSize {
    NSSize(
        width: min(max(size.width, Constants.floatWindowMinWidth), Constants.floatWindowMaxWidth),
        height: min(max(size.height, Constants.floatWindowMinHeight), Constants.floatWindowMaxHeight)
    )
}
```

在 `restoreWindowPosition()` 中，对从 UserDefaults 读取的 rect 的 size 部分调用 clampSize 后再恢复。

**理由**：直接更新常量 + 恢复时 clamp 是最简洁的方案，不引入迁移逻辑，历史尺寸自然适配新边界。

### Decision 5: 字号与内边距变更

| 常量 | 旧值 | 新值 | 说明 |
|---|---|---|---|
| `wordFontSize` | 24 | 14 | 适配更紧凑的窗口 |
| `phoneticFontSize` | 12 | 10 | 同上 |
| `meaningFontSize` | 14 | 12 | 同上 |
| `floatWindowPaddingHorizontal` | 16 | 4 | 节省水平空间 |
| `floatWindowPaddingVertical` | 12 | 2 | 适配 30pt 最小高度 |

30pt 最小高度下的内容空间：30 - 2×2 = 26pt 可用。单词 14pt 行高约 17pt，可正常显示。

### Decision 6: 文字颜色数据模型

AppSettings 新增字段：

```swift
var textColorHex: String = "#000000"  // 默认黑色，浅色模式适用
```

使用与 backgroundColorHex 相同的 6 字符 RGB 格式（复用现有 NSColor(hex:) 扩展）。

默认值 "#000000"（黑色）适配浅色模式；深色模式下由代码检测后自动切换为 "#FFFFFF"（白色）作为 fallback，但当用户已显式设置过颜色时，以用户值为准。

**理由**：复用现有 hex 存储模式，保持 Codable 一致性。

### Decision 7: 文字颜色 UI 集成

AppearanceView.swift 在现有"背景色"ColorPicker 下方新增"文字颜色"ColorPicker：

```swift
ColorPicker("文字颜色", selection: $textColor)
```

ThemeOption 枚举新增 `textColor` 属性，预设主题联动：

| 主题 | 背景色 | 文字颜色 |
|---|---|---|
| 浅色 | #FFFFFF | #000000 |
| 深色 | #262626 | #FFFFFF |
| 护眼绿 | #D9F2D9 | #2D5A2D |

FloatPreviewView 同步更新为 4 列布局，使用 textColor 渲染文字。

### Decision 8: FloatContentView 文字颜色应用

FloatContentView 的 `updateTextColors()` 方法改为从 AppSettings.shared.textColorHex 读取颜色：

- 单词（wordLabel）：直接使用 textColorHex，alpha 1.0
- 音标（phoneticLabel）：使用 textColorHex，alpha 0.65（保持视觉层级差异）
- 释义（meaningLabel）：直接使用 textColorHex，alpha 1.0

### Decision 9: Constants 更新汇总

| 常量 | 变化 | 说明 |
|---|---|---|
| `floatWindowWidth` | 保持 300 | 默认宽度 |
| `floatWindowMinWidth` | 200 → 300 | 新最小宽度 |
| `floatWindowMaxWidth` | 600 → 1200 | 新最大宽度 |
| `floatWindowMinHeight` | 120 → 30 | 新最小高度 |
| `floatWindowMaxHeight` | 500 → 800 | 新最大高度 |
| `floatWindowPaddingHorizontal` | 16 → 4 | 紧凑水平边距 |
| `floatWindowPaddingVertical` | 20 → 2 | 紧凑垂直边距 |
| `wordFontSize` | 24 → 14 | 紧凑字号 |
| `phoneticFontSize` | 12 → 10 | 紧凑字号 |
| `meaningFontSize` | 14 → 12 | 紧凑字号 |
| `maxMeaningDisplayCount` | 删除 | 不再截断释义 |
| 新增 `defaultTextColorHex` | "#000000" | 文字颜色默认值 |
| `wordToPhoneticSpacing` | 8 | 单词-音标列间距（pt） |
| `phoneticToMeaningSpacing` | 12 → 16 | 音标-释义列间距（pt） |
| 新增 `meaningToButtonSpacing` | 16 | 释义-按钮区间距（pt） |
| 删除 `columnsSpacing` | — | 被分级间距替代 |

## Risks / Trade-offs

### Risk 1: 横向布局重构复杂度高
FloatContentView 的 setupContent / setupButtons 全为纵向逻辑，重构涉及约束全面重写。**缓解**：分步骤重构——先改根容器方向，再迁移列内部约束，最后验证 resize / 动效行为。

### Risk 2: 300pt 宽度下释义空间有限
窗口 300pt 宽时，padding 4×2 = 8pt，单词约 60pt，音标约 50pt，按钮横排约 150pt，释义仅剩约 32pt。**缓解**：用户可拖宽窗口获得更多释义空间；最小宽度 300pt 保证基本可用。

### Risk 3: 历史 UserDefaults 数据兼容性
已安装用户的历史窗口尺寸可能超出新边界。clampSize 在恢复时自动修正，无需数据迁移。

### Risk 4: 文字颜色可读性
用户可能选择与背景色相近的颜色。**缓解**：不在本版本强制对比度检测，通过预设主题提供合理默认值。

### Trade-off: 取消 maxMeaningDisplayCount
移除 3 组释义截断后，极端情况下释义区可能占用大量空间。**接受**：这是用户主动将窗口拖高的结果，属于预期行为。

### Trade-off: 音标用 alpha 0.65 而非独立颜色
视觉层级通过 alpha 而非颜色区分。**接受**：0.65 是在"层级可辨"与"可读"之间的折中。

### Trade-off: 大字号溢出时不处理
用户设置字号大于窗口可容纳空间时，内容会溢出裁切。**接受**：由用户自行调整窗口大小适配，不引入复杂的自动缩放逻辑。
