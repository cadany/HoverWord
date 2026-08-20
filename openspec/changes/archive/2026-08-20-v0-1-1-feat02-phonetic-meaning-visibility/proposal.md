---
baseline_version: "v0-1-1"
change_sub_version: "v0-1-1-feat02"
---

## Why

当前悬浮窗的注音（音标）和释义始终显示，无法根据用户偏好隐藏或仅在鼠标悬停时显示。核心价值是支持**主动回忆记忆法**：用户先只看单词回忆释义，再悬停验证——比被动浏览的记忆效果更好。同时也提供更简洁的"沉浸式"体验。

此外，注音颜色（alpha=0.65）对比度不足，用户在浅色背景下难以看清音标内容。需要提升注音文字的可读性。

## What Changes

1. **注音/释义显示模式可配置**：新增三态枚举（always / hover / hidden），用户可独立配置注音和释义的显示模式
   - `always`：始终显示（默认，保持现有行为）
   - `hover`：鼠标进入悬浮窗时淡入显示，离开时淡出隐藏（与操作按钮浮现共用同一动画时长）
   - `hidden`：始终隐藏

2. **注音颜色改善**：将注音文字 alpha 从 0.65 提升至 0.85（`updateTextColors()` 与 `setupContent()` 两处硬编码同步替换），增强可读性同时保持视觉层级

3. **注音字号可配置**：新增注音字号设置项，范围 8-14pt，默认 10pt

4. **外观设置 UI 扩展**：现有卡片结构（预设主题 / 背景与文字 / 单词样式 / 释义样式）基础上：
   - 新增"注音样式"卡片（字号滑块、显示模式）
   - "释义样式"卡片追加显示模式行

## Capabilities

### New Capabilities

- `content-visibility`: 悬浮窗内容显示模式配置（注音/释义的 always/hover/hidden 三态控制）

### Modified Capabilities

- `floating-window`: 新增鼠标悬停时的注音/释义显隐交互逻辑
- `settings-window`: 外观设置新增注音卡片、注音字号与显示模式配置项
- `speech`: 无变更（注音显示模式不影响发音功能）

## Impact

### 影响文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Models/AppSettings.swift` | 修改 | 新增 phoneticVisibility、meaningVisibility、phoneticFontSize 字段及 StoredSettings/apply/save 扩展 |
| `Models/Enums/ContentVisibility.swift` | 新增 | 显示模式枚举定义 |
| `Shared/Constants.swift` | 修改 | 新增 secondaryTextAlpha=0.85、phoneticFontSizeMin/Max 常量 |
| `Features/FloatingWindow/FloatContentView.swift` | 修改 | 核心交互：updatePhoneticVisibility()/updateMeaningVisibility()、alpha 淡入淡出、鼠标事件扩展、两处 0.65 硬编码替换 |
| `Features/Settings/AppearanceView.swift` | 修改 | 新增注音卡片、释义卡片显示模式行、状态变量与保存逻辑 |
| `Resources/Localizable.xcstrings` | 修改 | 新增显示模式相关词条（zh-Hans/en） |

### 数据迁移

- 新增字段使用 `.always` 作为默认值，保持现有用户行为不变
- StoredSettings 新增可选字段，apply(stored:) 处理向后兼容（nil 时使用默认值）

### 性能影响

- 无明显性能影响，仅在鼠标事件时更新 alphaValue
- 布局策略采用 alpha 淡入淡出 + 保留占位空间，避免窗口尺寸跳动

### 测试覆盖

- AppSettings 新字段持久化测试
- ContentVisibility 枚举 Codable 测试
