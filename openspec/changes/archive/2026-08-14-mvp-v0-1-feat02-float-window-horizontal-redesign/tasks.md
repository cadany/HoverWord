## 1. Constants 更新（基础层）

- [x] 1.1 在 `Utils/Constants.swift` 中更新窗口尺寸：`floatWindowWidth` 300pt，`floatWindowMinWidth` 300pt，`floatWindowMaxWidth` 1200pt，`floatWindowMinHeight` 30pt，`floatWindowMaxHeight` 800pt
- [x] 1.2 更新内边距：`floatWindowPaddingHorizontal` 4pt，`floatWindowPaddingVertical` 2pt
- [x] 1.3 更新字号：`wordFontSize` 14pt，`phoneticFontSize` 10pt，`meaningFontSize` 12pt
- [x] 1.4 删除 `Constants.maxMeaningDisplayCount` 常量
- [x] 1.5 新增 `defaultTextColorHex = "#000000"`，删除 `columnsSpacing`，新增 `meaningToButtonSpacing = 16`
- [x] 1.6 更新间距：`phoneticToMeaningSpacing` 16pt，`wordToPhoneticSpacing` 保持 8pt

## 2. AppSettings 模型扩展

- [x] 2.1 在 `Models/AppSettings.swift` 的 `StoredSettings` 结构体中新增字段 `textColorHex: String`，默认值 `Constants.defaultTextColorHex`
- [x] 2.2 在 `AppSettings` 公共接口添加 `textColorHex` 的计算属性（getter/setter 桥接到 StoredSettings）
- [x] 2.3 确保 Codable 向后兼容：使用 `decodeIfPresent` + 默认值，让旧用户无感升级

## 3. FloatContentView 布局重构（核心）

- [x] 3.1 将根容器 `rootStack` 改为 horizontal，alignment `.centerY`，默认 spacing `wordToPhoneticSpacing`（8pt）
- [x] 3.2 移除 `leftColumn`（NSStackView vertical），将 `wordLabel` 和 `phoneticLabel` 直接作为 rootStack 的 arranged subview
- [x] 3.3 通过 `setCustomSpacing(_:after:)` 设置分级间距：音标→释义 16pt，释义→按钮 16pt
- [x] 3.4 将 `buttonStack` 改为 horizontal，alignment `.centerY`，设置高 hugging 保持紧凑
- [x] 3.5 移除 `trailingSpacer`（NSView），按钮通过高 hugging 自然右对齐
- [x] 3.6 更新约束：rootStack 四边 pin 到 superview，padding 使用新的 `floatWindowPaddingHorizontal`（4）和 `floatWindowPaddingVertical`（2）
- [x] 3.7 重写 `resize(withOldSuperviewSize:)`：根据可用高度判断 `meaningLabel.maximumNumberOfLines`（1 行或 0）
- [x] 3.8 修改 `showWord()`：移除 `maxMeaningDisplayCount` 截断，展示全部释义；释义之间用 " / " 分隔符拼接（单行模式）或换行展示（多行模式）
- [x] 3.9 修改 `updateTextColors()`：从 `AppSettings.shared.textColorHex` 读取颜色，word 与 meaning 用 alpha 1.0，phonetic 用 alpha 0.65
- [x] 3.10 验证按钮 hover 浮现动效在横向布局下仍正常工作

## 4. FloatWindowController 尺寸调整

- [x] 4.1 更新初始窗口尺寸：使用 `Constants.floatWindowWidth × Constants.floatWindowMinHeight`（300×30pt）
- [x] 4.2 在 `restoreWindowPosition()` 中添加 `clampSize()` 调用，将历史 rect 的 width / height 分别 clamp 到新 min/max
- [x] 4.3 验证 resize 边界生效：拖拽缩小至 300×30 停止，拖拽放大至 1200×800 停止

## 5. AppearanceView 文字颜色设置

- [x] 5.1 在 `Views/Settings/AppearanceView.swift` 中，背景色 ColorPicker 下方新增文字颜色 ColorPicker，绑定 `AppSettings.shared.textColorHex`
- [x] 5.2 更新 `ThemeOption` 枚举，每个主题新增 `textColor` 属性：浅色 #000000，深色 #FFFFFF，护眼绿 #2D5A2D
- [x] 5.3 切换主题时同步更新 `AppSettings.shared.textColorHex`
- [x] 5.4 更新 `FloatPreviewView`：使用横向四列布局（单词 | 音标 | 释义 | 按钮横排），文字颜色使用 `AppSettings.shared.textColorHex`

## 6. OpenSpec 文档更新

- [x] 6.1 更新 `specs/floating-window/spec.md`：反映四列布局、300×30~1200×800 尺寸边界
- [x] 6.2 更新 `design.md`：反映四列布局决策、分级间距、新字号内边距
- [x] 6.3 更新 `tasks.md`：反映所有已完成任务

## 7. 集成验证

- [ ] 7.1 启动应用，验证悬浮窗默认尺寸为 300×30pt，横向四列布局正确渲染
- [ ] 7.2 拖拽悬浮窗右边缘 / 下边缘 / 右下角，验证 resize 边界（300×30 ~ 1200×800）
- [ ] 7.3 拖拽窗口高度到 30pt，验证释义区截为单行；拖高到 80pt，验证释义区自动换行
- [ ] 7.4 在设置中修改文字颜色，验证悬浮窗与预览区域实时同步
- [ ] 7.5 切换预设主题，验证文字颜色联动更新
- [ ] 7.6 重启应用，验证位置 / 尺寸恢复正确（特别是历史尺寸 < 300pt 的 clamp 行为）
- [ ] 7.7 走马灯模式下验证悬浮窗布局正常，仅显示收藏按钮于第 4 列
