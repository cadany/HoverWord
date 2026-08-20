## 1. 数据模型层

- [x] 1.1 创建 `Models/Enums/ContentVisibility.swift`
  - 定义 `ContentVisibility` 枚举：`always` / `hover` / `hidden`
  - 遵循 `String, Codable, CaseIterable`
  - 添加 `displayName` 计算属性（返回本地化显示名）

- [x] 1.2 修改 `Models/AppSettings.swift`
  - 新增字段：`phoneticFontSize: Double = Double(Constants.phoneticFontSize)`
  - 新增字段：`phoneticVisibility: ContentVisibility = .always`
  - 新增字段：`meaningVisibility: ContentVisibility = .always`
  - 更新 `StoredSettings` 结构体，新增对应的可选字段
  - 更新 `apply(stored:)` 方法，处理向后兼容（nil 时使用默认值）
  - 更新 `save()` 方法，写入新字段

## 2. 常量定义

- [x] 2.1 修改 `Shared/Constants.swift`
  - 新增 `secondaryTextAlpha: CGFloat = 0.85`（原音标 alpha 0.65 的替代）
  - 新增 `phoneticFontSizeMin: Double = 8`
  - 新增 `phoneticFontSizeMax: Double = 14`

## 3. 悬浮窗交互

- [x] 3.1 修改 `Features/FloatingWindow/FloatContentView.swift` - 颜色更新（两处硬编码）
  - `updateTextColors()`：`baseColor.withAlphaComponent(0.65)` → `baseColor.withAlphaComponent(Constants.secondaryTextAlpha)`
  - `setupContent()`：`NSColor.black.withAlphaComponent(0.65)` → `NSColor.black.withAlphaComponent(Constants.secondaryTextAlpha)`（初始占位色，updateTextColors 稍后覆盖）

- [x] 3.2 修改 `Features/FloatingWindow/FloatContentView.swift` - 字号应用
  - 修改 `applyAppearanceSettings()` 方法
  - 使用 `AppSettings.shared.phoneticFontSize` 设置 `phoneticLabel.font`

- [x] 3.3 修改 `Features/FloatingWindow/FloatContentView.swift` - 悬停显隐逻辑
  - 新增私有方法 `updatePhoneticVisibility()`
  - 新增私有方法 `updateMeaningVisibility()`
  - 每个方法读取对应的 `ContentVisibility` 配置
  - 根据 `isMouseInside` 状态决定 `alphaValue`（0 或 1）
  - 使用 `CATransaction` 动画（时长 `Constants.buttonFadeDuration`）

- [x] 3.4 修改 `Features/FloatingWindow/FloatContentView.swift` - 鼠标事件扩展
  - 修改 `mouseEntered(with:)` 方法
  - 调用 `updatePhoneticVisibility()` 和 `updateMeaningVisibility()`
  - 修改 `mouseExited(with:)` 方法
  - 调用 `updatePhoneticVisibility()` 和 `updateMeaningVisibility()`

- [x] 3.5 修改 `Features/FloatingWindow/FloatContentView.swift` - 外观变更响应
  - 修改 `handleAppearanceChange()` 方法
  - 调用 `updatePhoneticVisibility()` 和 `updateMeaningVisibility()`
  - 确保设置变更后立即应用新的显示规则

- [x] 3.6 修改 `Features/FloatingWindow/FloatContentView.swift` - 初始化
  - 在 `init(frame:)` 中调用 `updatePhoneticVisibility()` 和 `updateMeaningVisibility()`
  - 确保初始状态正确

## 4. 设置 UI

- [x] 4.1 修改 `Features/Settings/AppearanceView.swift` - 状态变量
  - 新增 `@State` 变量：`phoneticFontSize`
  - 新增 `@State` 变量：`phoneticVisibility`（类型 `ContentVisibility`）
  - 新增 `@State` 变量：`meaningVisibility`（类型 `ContentVisibility`）

- [x] 4.2 修改 `Features/Settings/AppearanceView.swift` - 卡片扩展
  - 保留现有卡片：预设主题 / 背景与文字 / 单词样式 / 释义样式
  - 在"单词样式"与"释义样式"之间插入"注音样式"卡片（字号滑块 + 显示模式）
  - "释义样式"卡片末尾追加显示模式行

- [x] 4.3 修改 `Features/Settings/AppearanceView.swift` - 注音卡片
  - 添加注音字号 Slider（8-14pt，步进 1pt）
  - 添加显示模式 Segmented Control（Picker with `.pickerStyle(.segmented)`）
  - 选项：总是显示 / 悬停显示 / 隐藏

- [x] 4.4 修改 `Features/Settings/AppearanceView.swift` - 释义卡片
  - 保留原有字体、字号配置
  - 添加显示模式 Segmented Control

- [x] 4.5 修改 `Features/Settings/AppearanceView.swift` - 数据加载
  - 修改 `loadAppearance()` 方法
  - 从 `AppSettings.shared` 加载新字段值

- [x] 4.6 修改 `Features/Settings/AppearanceView.swift` - 数据保存
  - 修改 `saveAppearance()` 方法
  - 保存新字段到 `AppSettings.shared`
  - 更新 guard 条件，包含新字段的变更检测

## 5. 本地化

- [x] 5.1 在 `Resources/Localizable.xcstrings` 添加词条（zh-Hans/en）
  - `appearance.displayMode` = "显示模式" / "Display Mode"
  - `appearance.displayMode.always` = "总是显示" / "Always"
  - `appearance.displayMode.hover` = "悬停显示" / "On Hover"
  - `appearance.displayMode.hidden` = "隐藏" / "Hidden"
  - `appearance.phoneticStyle` = "注音样式" / "Phonetic Style"
  - `appearance.meaningStyle` 复用现有词条（释义样式）

## 6. 测试

- [x] 6.1 创建 `HoverWordTests/Models/ContentVisibilityTests.swift`
  - 测试 Codable 序列化/反序列化
  - 测试 CaseIterable 遍历

- [x] 6.2 修改 `HoverWordTests/Models/AppSettingsTests.swift`
  - 测试新字段持久化
  - 测试旧版本迁移（StoredSettings 无新字段时使用默认值）

## 7. 验证

- [x] 7.1 构建验证
  - 运行 `xcodebuild` 确保项目构建成功
  - 无编译错误、无警告
  - 备注：沙箱环境编译+签名通过；修复了 ContentVisibility 未加入 Sources 编译阶段的问题
  - 备注：修复测试污染真实配置缺陷（AppSettingsTests/L10nTests 的 save() 落盘写入了用户 UserDefaults，现 setUp 备份、tearDown 还原）；已还原被污染的 11 个字段

- [x] 7.2 功能验证（2026-08-20 用户验证通过：默认行为/hover/hidden/字号/持久化）
  - 启动应用，验证默认行为（注音/释义始终显示）
  - 修改注音显示模式为 hover，验证鼠标进入/离开时的显隐
  - 修改注音显示模式为 hidden，验证始终隐藏
  - 修改释义显示模式，验证同样行为
  - 修改注音字号，验证悬浮窗立即更新
  - 重启应用，验证配置持久化

- [x] 7.3 回归验证
  - 验证单词/释义的其他配置仍正常工作
  - 验证外观设置的其他功能未受影响
  - 验证悬浮窗的其他交互（按钮、右键菜单）正常
  - 备注：单元测试全部通过（2026-08-20 15:04，xcodebuild test TEST SUCCEEDED）
