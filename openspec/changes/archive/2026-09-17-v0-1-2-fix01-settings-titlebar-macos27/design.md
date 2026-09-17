## Context

设置窗口当前构造（[SettingsWindowController.swift](file:///Users/cadany/Desktop/code/richops/HoverWord/Features/Settings/SettingsWindowController.swift#L14-L30)）：

```swift
styleMask: [.titled, .closable, .miniaturizable]
window.isOpaque = false
window.backgroundColor = .clear
```

标题栏本身零显式配置：不加 `titlebarAppearsTransparent`、不加 `.fullSizeContentView`，标题栏长什么样完全交给系统默认。`NavigationSplitView` 会自动把 sidebar 折叠按钮装进标题栏工具栏，与透明窗口组合后，macOS 27 的默认渲染把标题栏区域装成了独立不透明条带（26 无此现象）。

先例：悬浮窗 `NSPanel` 早已采用 `.fullSizeContentView` + `titlebarAppearsTransparent = true` + `backgroundColor = .clear`（[FloatWindowController.swift](file:///Users/cadany/Desktop/code/richops/HoverWord/Features/FloatingWindow/FloatWindowController.swift#L41-L51)），跨版本渲染稳定。本方案将设置窗对齐到同一做法。

## Goals / Non-Goals

**Goals**

- macOS 27 下标题栏区域不再出现独立不透明条带，玻璃材质全窗贯穿
- 标题栏渲染行为由应用显式控制，不再依赖各版本系统默认值
- 红绿灯、拖拽、缩放、标题显示等行为不变

**Non-Goals**

- 不为 macOS 27 单独引入 `#available` 版本分支
- 不改 SwiftUI 侧材质布局（`.thinMaterial` / `.regularMaterial` / `glassEffect` 卡片维持现状）
- 不改 sidebar 折叠按钮的功能与位置逻辑（其位置由系统工具栏装配决定，接管后预期回归标题栏内）
- 不动悬浮窗

## Decisions

### D1：显式接管标题栏，而非按版本补偿

`styleMask` 补 `.fullSizeContentView`，并设置 `titlebarAppearsTransparent = true`。内容视图延伸到标题栏区域后，该区域的像素由 SwiftUI 材质层绘制，系统不再叠加自己的标题栏背景——27 的默认行为变化被绕开，且 14-27 全走同一路径。

**权衡（已确认选 A）：** 14-25 / 26 的标题栏观感随之变化（从"系统标题栏 + 透明窗口"变为"内容贯穿"），需要回归截图确认；换来的是行为确定性。备选"仅 27 分支补偿"被否决：版本分支会随系统迭代失真。

### D2：`titleVisibility` 保持默认（标题可见）

不隐藏标题，"HoverWord 设置"文案照常显示；`titlebarAppearsTransparent` 只影响背景绘制，不影响标题与红绿灯。若回归发现浅色材质上标题对比度不足，再单独决策，不在本 change 预设。

### D3：保留既有 `.id` 挂载位置注释并更新表述

原注释（"整树重建会重装标题栏 chrome → 独立不透明条带"）描述的风险在接管后显著降低，但 `.id` 挂子树仍是正确做法（避免无谓重建），注释更新为"标题栏已显式接管，重建不再产生条带，但 `.id` 仍挂子树以保留窗口标题栏集成"。

### D4：低版本视觉回归用 GitHub Actions runner 矩阵（方案 B）

无低版本实机，改用托管 runner 提供实证。关键约束决定了架构：`.glassEffect` / `.buttonStyle(.glass)` 只存在于 macOS 26 SDK，在 14 / 15 runner 上用其自带 Xcode（15.x / 16.x）**编译不过**。因此拆成两段：

```
build (macos-26 runner)          capture (matrix: macos-14 / 15 / 26)
  xcodebuild -target HoverWord  →  artifact HoverWord.app
                                   open -n → 等预热 → 断言进程存活
                                   → screencapture 浅色 / 深色各一张
```

产物可跨版本运行的前提已核对：部署目标 14.0，且所有 26-only 调用点均有 `#available(macOS 26, *)` 守卫（见 [GlassStyles.swift](file:///Users/cadany/Desktop/code/richops/HoverWord/Features/Settings/GlassStyles.swift)），低版本走"系统默认"分支——这正是本次要观察的分支。

其他要点：

- **无需测试接缝**：`applicationDidFinishLaunching` 本身就调用 `showSettingsWindow()`（[AppDelegate.swift](file:///Users/cadany/Desktop/code/richops/HoverWord/App/AppDelegate.swift#L51)），启动即出现设置窗
- **用 `-target` 而非 `-scheme`**：工程由 XcodeGen 生成，未导出 shared scheme
- **自动断言仅一条**：进程启动后存活即通过（跨版本不崩溃）；截图本身交人工判读，不做像素比对
- **macos-14 标记 `allow_failure`**：该镜像 2026-11-02 起弃用，不作为阻塞信号
- 手动 `workflow_dispatch` 触发，不进 push/PR 主流程（macOS runner 分钟成本高，且仅在窗口/材质相关改动时需要）

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 低版本（≤26）无实机回归条件：本机即 macOS 27.0，Apple Silicon 虚拟机无法降级安装旧系统 | D4 的 runner 矩阵提供 14 / 15 / 26 真实截图；另据"API 自 10.10 稳定 + 悬浮窗同源组合已跨版本验收"降低预期风险 |
| runner 截图与真机存在差异（无外接显示器、虚拟 GPU、材质采样背景为默认桌面） | 仅用于判读"标题栏是否出现独立不透明条带"这类结构性差异，不用于比对材质细节观感 |
| 内容延伸到标题栏后，顶部控件与红绿灯重叠 | 内容区顶部为卡片标题/留白，NavigationSplitView 自带顶部安全区处理；在 27 本机实测确认 |
