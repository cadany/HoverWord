---
baseline_version: "mvp-v0-1"
change_sub_version: "mvp-v0-1-feat03"
---

## Why

当前设置窗口使用 SwiftUI 默认 TabView + Form 布局，视觉效果为纯白底/灰底的 iOS 风格分组表单，与悬浮窗精心设计的 Liquid Glass 玻璃质感完全断裂。用户直观感受为"整体丑"，缺乏 macOS 原生应用应有的精致感。

核心问题：
- 无材质渲染（纯白底 vs 悬浮窗的磨砂玻璃）
- Section 分组样式在 macOS 上不自然
- Tab 切换控件笨重，无视觉层次
- 控件密度低，信息排版扁平
- 与产品核心视觉语言（Liquid Glass）完全脱节

## What Changes

将设置窗口从默认 TabView 表单重构为 sidebar 布局 + Liquid Glass 材质的现代 macOS 设置界面：

1. **布局重构**：顶部 Tab 改为左侧 sidebar（NavigationSplitView），4 个 Tab 变为 sidebar 导航项
2. **材质贯穿**：整窗使用 Liquid Glass 材质（`.liquid`），sidebar 用 `.sidebar` 材质，内容区用 `.content` 材质，分组用半透明卡片
3. **选中态定制**：sidebar 选中项使用蓝色玻璃药丸高亮，带细微内发光
4. **卡片式分组**：内容区配置项用圆角 12pt 玻璃卡片组织，卡片间 12pt 间距
5. **控件定制**：自定义 glass button style、toggle style，hover/press 四态交互
6. **动效升级**：sidebar 切换 spring 过渡，卡片内控件 ease-out 0.2s
7. **最低版本提升**：macOS 12.0 → macOS 14.0 (Sonoma)，以获取 `.liquid` 材质、NavigationSplitView 等关键 API

## Capabilities

### New Capabilities

无新增 capability。

### Modified Capabilities

- **settings-window**：重构整个设置窗口的布局、材质、分组样式、控件样式与动效，保持功能不变（4 个 Tab 的全部配置项 + 悬浮窗预览），视觉语言与悬浮窗统一

## Impact

- **最低系统版本**：macOS 12.0 → macOS 14.0，放弃 macOS 12-13 用户（Intel 老机器）。当前 macOS 14 覆盖率已很高，此取舍换取最佳视觉效果
- **文件改动范围**：
  - `Features/Settings/` 下 5 个文件全部重写（SettingsWindowController、WordbookTabView、ReciteSettingsView、AppearanceView、SpeechSettingsView）
  - 可能新增自定义 ViewModifier / ButtonStyle / ToggleStyle 文件
  - `Shared/Constants.swift` 新增设置窗相关常量
  - `AGENTS.md` 更新最低系统版本
  - `openspec/specs/settings-window/spec.md` 同步更新
- **功能不变**：所有现有配置项、交互逻辑、数据绑定保持不变，仅改视觉层
- **回退方案**：工作在 `feature/settings-redesign` 分支，`main` 分支保留当前版本，随时可切回
