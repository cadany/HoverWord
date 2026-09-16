## 1. 窗口构造改造

- [x] 1.1 `SettingsWindowController` 的 `styleMask` 补充 `.fullSizeContentView`
- [x] 1.2 设置 `window.titlebarAppearsTransparent = true`（与既有 `isOpaque=false / backgroundColor=.clear` 成组，注释说明"显式接管标题栏、绕开各版本系统默认渲染差异"）
- [x] 1.3 更新 `SettingsRootView` 文档注释中 `.id` 挂载位置段落对"独立不透明条带"风险的表述（接管后风险降低，`.id` 仍挂子树）

## 2. 低版本视觉回归 CI

- [x] 2.1 新增 `.github/workflows/settings-screenshot-smoke.yml`：`macos-26` 构建（`-target HoverWord`，产物上传 artifact）
- [x] 2.2 capture job matrix 跑 `macos-14` / `macos-15` / `macos-26`：下载产物 → `open -n` → 等待预热 → 断言进程存活 → `screencapture` 浅色 / 深色各一张 → 按版本分别上传 artifact
- [x] 2.3 深浅色切换用 `defaults write -g AppleInterfaceStyle` + 关闭系统自动切换，避免设置被覆盖
- [x] 2.4 `macos-14` 设 `continue-on-error`（镜像弃用期），`fail-fast: false` 保证三版本互不阻塞
- [ ] 2.5 首次触发跑通并核对 artifact 截图可读（若 runner 无 GUI 会话导致截图失败，按 design D4 记录的约束调整）

## 3. 文档同步

- [x] 3.1 `docs/ui-spec.md` 设置窗口小节：标题栏描述改为"显式接管（fullSizeContentView + titlebarAppearsTransparent），材质全窗贯穿"

## 4. 验证

- [x] 4.1 `xcodebuild build` 通过，无新增告警
- [x] 4.2 全量 `xcodebuild test` 通过（全新 DerivedData 复跑 149 tests / 0 failures，TEST SUCCEEDED；首次跑的 2 条失败经隔离重跑确认为既有间歇性 flaky，与本改动无关）
- [x] 4.3 macOS 27 本机验证：不透明白条消失、折叠按钮回标题栏、顶部内容不与红绿灯重叠、红绿灯/拖拽/缩放正常、sidebar 折叠按钮可用、深浅色各截图一张 —— 用户已确认通过
- [ ] 4.4 触发 CI 截图矩阵，人工核对 14 / 15 / 26 三版本标题栏无独立不透明条带、材质贯穿正常
- [x] 4.5 `openspec validate v0-1-2-fix01-settings-titlebar-macos27 --strict` 通过 + schema 落盘自检
