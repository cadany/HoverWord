## 1. 基础设施

- [x] 1.1 提升 Deployment Target 到 macOS 14.0：修改 `project.pbxproj` 中 `MACOSX_DEPLOYMENT_TARGET` 为 `14.0`，更新 `AGENTS.md` 最低系统版本
- [x] 1.2 新建 `Features/Settings/GlassStyles.swift`：实现 `GlassButtonStyle`（四态：默认/悬停/点击/禁用）、`GlassToggleStyle`（glass 药丸滑块）、`.glassCard()` ViewModifier（半透明填充 + 12pt 圆角 + 柔和阴影）
- [x] 1.3 新建 `Features/Settings/SidebarItem.swift`：定义 sidebar 导航项模型（icon + label + tag），4 个常量对应单词本/背记/外观/发音
- [x] 1.4 在 `Shared/Constants.swift` 新增设置窗相关常量：窗口默认尺寸 720×560pt、最小尺寸 640×480pt、sidebar 宽度 200pt、卡片圆角 12pt、卡片间距 12pt

## 2. 窗口骨架

- [x] 2.1 重写 `SettingsWindowController.swift`：窗口尺寸改为 720×560pt、最小 640×480pt；`SettingsRootView` 从 `TabView` 改为 `NavigationSplitView`（sidebar + detail），sidebar 使用 `List(selection:)` 渲染导航项，选中态应用玻璃药丸样式；保留 `SettingsWindowDelegate` 关闭行为不变
- [x] 2.2 验证 sidebar 导航切换：点击导航项内容区正确切换，spring 过渡流畅，药丸高亮跟随滑动（构建通过，视觉待人工确认）

## 3. 各 Tab 视觉重写

- [x] 3.1 重写 `ReciteSettingsView.swift`：保留全部功能逻辑，外层用 `.glassCard()` 包裹每个 Section（背记模式/走马灯设置/展示顺序/停留时长/其他），Picker 用自定义 glass radio group 样式，Slider 使用 glass track
- [x] 3.2 重写 `SpeechSettingsView.swift`：同上卡片分组风格，Toggle 使用 `GlassToggleStyle`，Picker 使用 glass radio group
- [x] 3.3 重写 `AppearanceView.swift`：卡片分组（预设主题/背景与文字/单词样式/释义样式），主题切换用 segmented glass picker；右侧预览区用 `.glassCard()` 包裹 FloatPreviewView
- [x] 3.4 重写 `WordbookTabView.swift`：列表区使用 glass 风格行样式，底部操作栏按钮使用 `GlassButtonStyle`，sheet 弹窗（新建/重命名）也使用玻璃材质

## 4. 收尾

- [x] 4.1 全量构建验证：`xcodebuild build` 通过，无 warning
- [x] 4.2 全量测试验证：`xcodebuild test` 36 tests 全部通过
- [x] 4.3 更新 `openspec/specs/settings-window/spec.md`：将 delta spec 的 MODIFIED/ADDED 内容同步到主 spec
- [x] 4.4 更新 `docs/ui-spec.md`（如存在）：反映新的设置窗视觉规范
- [x] 4.5 人工视觉验证：运行 App，逐 Tab 检查所有配置项可正常读写，深色/浅色模式切换正确，动效流畅
