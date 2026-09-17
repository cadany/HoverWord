---
baseline_version: "v0-1-2"
change_sub_version: "v0-1-2-fix01"
---

## Why

macOS 27（Tahoe 后继版本）下设置窗口标题栏区域出现严重渲染异常：标题栏下方出现一条独立的不透明白色条带，sidebar 折叠按钮从标题栏内被挤到白条上且呈不透明白底，与整窗 Liquid Glass 质感割裂；macOS 26 下无此现象。

根因：设置窗口对标题栏**完全依赖系统默认渲染**——[SettingsWindowController.swift](../../../Features/Settings/SettingsWindowController.swift) 仅有 `styleMask: [.titled, .closable, .miniaturizable]` + `isOpaque=false / backgroundColor=.clear`，未显式设置 `titlebarAppearsTransparent` / `fullSizeContentView`。透明窗口 + `NavigationSplitView` 自动装配的标题栏 chrome（sidebar 折叠按钮工具栏）这一组合，macOS 27 的默认渲染行为发生了变化，把标题栏区域装成了独立不透明条带。

这一失效模式并非首次出现：[SettingsWindowController.swift L88-90](../../../Features/Settings/SettingsWindowController.swift) 的注释记录过语言切换时"整树重建会重装标题栏 chrome，导致标题栏样式异常（变成独立不透明条带）"，当时靠把 `.id` 移出 `NavigationSplitView` 本体规避。macOS 27 把该症状从"仅重建触发"扩大为"首次挂载即触发"，说明依赖系统默认行为不可靠，需要应用侧显式接管标题栏。

## What Changes

### 1. 显式接管设置窗口标题栏（方案 A，跨版本统一）

- `styleMask` 补充 `.fullSizeContentView`，SwiftUI 内容延伸到标题栏区域
- 设置 `titlebarAppearsTransparent = true`，标题栏不再绘制独立的系统背景，材质由窗口内容（`.regularMaterial` / `.thinMaterial`）统一贯穿
- 红绿灯按钮与窗口标题保持系统默认位置与行为不变

### 2. 不引入版本分支

不对 macOS 27 单独做 `#available` 补偿：显式接管后标题栏渲染不再依赖各版本系统默认值，26 / 27 走同一条路径，避免版本分支随系统迭代失真。

## Capabilities

### New Capabilities

无。

### Modified Capabilities

- `settings-window` — "设置窗口基础样式"需求修改：标题栏从"系统默认渲染 + 材质融合"改为"应用显式接管（透明标题栏 + 全尺寸内容视图）"，新增 macOS 27 回归 Scenario

## Impact

**受影响文件：**

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Features/Settings/SettingsWindowController.swift` | 修改 | `styleMask` 补 `.fullSizeContentView`；新增 `titlebarAppearsTransparent = true`；更新相关注释 |
| `docs/ui-spec.md` | 修改 | 设置窗口标题栏描述同步为显式接管方案 |
| `.github/workflows/settings-screenshot-smoke.yml` | 新增 | 低版本视觉回归：macOS 26 runner 构建 → 14 / 15 / 26 三版本启动并浅深色截图 → artifact 供人工核对；手动触发 |

**兼容性：**

- macOS 14-26：设置窗口标题栏观感随之变化（系统标题栏背景消失、内容贯穿）；所用 API 自 10.10 起行为稳定，红绿灯、拖拽、缩放不受影响；由 CI 截图矩阵提供实证
- macOS 27（本机）：不透明白条消失，标题栏区域恢复玻璃贯穿，可直接验证
- 悬浮窗（NSPanel 已是 `.fullSizeContentView` + `titlebarAppearsTransparent`）不受影响，本方案与悬浮窗的既有做法对齐

**验证约束：** 开发机即 macOS 27.0（arm64），修复效果与 27 现象消除均可本机直接验证；低版本回归无实机（Apple Silicon 无法虚拟机降级安装旧系统），改由 GitHub Actions 托管 runner 承担。注意 `.glassEffect` 等 API 仅存在于 macOS 26 SDK，故**构建只能跑在 macos-26 runner**，产物（部署目标 14.0 + 全部 26-only 调用有 `#available` 守卫）再分发到 14 / 15 / 26 上运行截图。
