## Context

当前设置窗口使用 SwiftUI 默认 TabView + Form，视觉上与悬浮窗的 Liquid Glass 设计语言完全脱节。需要将设置窗口重构为 sidebar 布局 + Liquid Glass 材质，实现全应用视觉统一。

当前技术状态：
- 设置窗口由 `SettingsWindowController` 管理，内部使用 `NSHostingView` 承载 SwiftUI `TabView`
- 4 个 Tab 视图（WordbookTabView、ReciteSettingsView、AppearanceView、SpeechSettingsView）各自独立
- 所有配置项通过 `AppSettings.shared` 读写
- 项目当前最低版本 macOS 12.0，本次需提升至 14.0

## Goals / Non-Goals

**Goals:**
- 设置窗口全面使用 Liquid Glass 材质，与悬浮窗视觉统一
- sidebar 导航替代 TabView，选中态为玻璃药丸高亮
- 卡片式分组替代默认 Form Section
- 自定义 glass 控件样式（Button、Toggle、Picker）
- 流畅 spring / ease-out 动效
- 功能完全不变，仅视觉层重构

**Non-Goals:**
- 不新增/删除任何配置项
- 不改变数据流（AppSettings / Core Data 交互保持不变）
- 不做 macOS 12-13 降级方案（最低版本直接提 14）
- 不改悬浮窗代码（除 Constants 可能新增设置窗相关常量）

## Decisions

### D1: 使用 NavigationSplitView 实现 sidebar

**选择**：SwiftUI `NavigationSplitView`（macOS 13+）

**理由**：
- 原生 sidebar 行为，自动适配系统主题
- macOS 14 下自动获得最新 sidebar 材质
- 比自定义 HStack sidebar 代码量少得多

**替代方案**：自定义 HStack + 手工 sidebar。优点是视觉完全可控，缺点是需要自己实现选中态、hover 态、键盘导航，代码量大且容易出 bug。NavigationSplitView 已经足够好，优先选原生。

### D2: 材质策略

| 区域 | 材质 | 说明 |
|------|------|------|
| 整窗背景 | `.liquid` | 基础玻璃层 |
| Sidebar | `.sidebar` | 标准 sidebar 材质，比内容区略深 |
| 内容区 | `.content` | 标准内容区材质 |
| 分组卡片 | 自定义半透明填充 | `Material.regular` + `Color.primary.opacity(0.04)` 叠加，圆角 12pt |
| 选中药丸 | `.accentColor.opacity(0.15)` + 内发光 stroke | 蓝色半透明 + 细微亮边 |

### D3: 控件样式实现方式

**选择**：自定义 `ButtonStyle` / `ToggleStyle`，通过 `ViewModifier` 封装卡片样式

**理由**：
- ButtonStyle / ToggleStyle 是 SwiftUI 原生扩展点，与系统控件完全兼容
- ViewModifier 封装卡片样式可复用于所有分组
- 不需要替换为 AppKit 控件，保持 SwiftUI 开发效率

### D4: Sidebar 图标选择

| 导航项 | SF Symbol |
|--------|-----------|
| 单词本 | `book` |
| 背记 | `arrow.triangle.2.circlepath` |
| 外观 | `paintbrush` |
| 发音 | `speaker.wave.2` |

沿用现有 TabView 的图标，保持一致。

### D5: 文件组织

```
Features/Settings/
├── SettingsWindowController.swift      # 窗口控制器，改用 NavigationSplitView
├── SidebarItem.swift                   # [新增] sidebar 导航项模型
├── GlassStyles.swift                   # [新增] 自定义 ButtonStyle / ToggleStyle / ViewModifier
├── SettingsCard.swift                  # [新增] 卡片分组容器 ViewModifier
├── WordbookTabView.swift               # 重写视觉层
├── ReciteSettingsView.swift            # 重写视觉层
├── AppearanceView.swift                # 重写视觉层
└── SpeechSettingsView.swift            # 重写视觉层
```

### D6: 最低版本提升

**选择**：Deployment Target 从 12.0 提升到 14.0

**影响**：
- `project.pbxproj` 修改 `MACOSX_DEPLOYMENT_TARGET`
- `AGENTS.md` 更新最低版本
- 可安全使用：`.liquid`、`NavigationSplitView`、`.content`/`.sidebar` 材质、最新 spring 动画 API

## Risks / Trade-offs

| 风险 | 影响 | 缓解 |
|------|------|------|
| 放弃 macOS 12-13 用户 | 老 Intel 机器无法使用 | macOS 14 覆盖率已很高；这是追求最佳视觉的必要取舍 |
| NavigationSplitView 定制有限 | sidebar 可能无法完全匹配设计稿 | 可用 `.listStyle(.sidebar)` + 自定义 row 内容达到 90% 效果 |
| `.liquid` 材质在设置窗上的效果未知 | 可能比预期更透/更糊 | 实现后快速验证，必要时降级为 `.hudWindow` 或自定义 `NSVisualEffectView` |
| 功能不变但视觉全面重写 | 回归风险 | 逐个 Tab 验证所有配置项可正常读写 |
| 回退需求 | 用户可能不满意新设计 | 已在 `feature/settings-redesign` 分支开发，main 保留旧版 |
