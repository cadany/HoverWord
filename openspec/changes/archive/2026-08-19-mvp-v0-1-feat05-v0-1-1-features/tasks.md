## 1. 数据模型与持久化基础设施

- [x] 1.1 Core Data 模型版本升级：在 `Resources/HoverWord.xcdatamodeld` 下新建模型版本，为 `WordEntry` 实体新增 `sourceLineNumber: Int32` attribute（默认值 0），设置为当前活跃版本；确认轻量迁移可正常工作
- [x] 1.2 `WordEntry+CoreDataProperties.swift`：新增 `@NSManaged public var sourceLineNumber: Int32`，补充文档注释
- [x] 1.3 `AppSettings` 字段重构：删除 `useAmericanAccent: Bool`；新增 `voiceNameByLanguage: [String: String]` 与 `speechRateMultiplier: Double = 1.0`；同步更新 `StoredSettings` Codable 模型
- [x] 1.4 `AppSettings.apply(stored:)` 向后兼容迁移：读取旧 `useAmericanAccent` 字段（Optional 处理），`true` → `voiceNameByLanguage["en"] = "Samantha"`（若系统存在），`false` → `voiceNameByLanguage["en"] = "Daniel"`；迁移完成后不再持久化旧字段

## 2. SpeechService 架构重构

- [x] 2.1 删除 `SpeechService.Accent` enum；重写公开接口为 `speak(_:language:)`、`availableVoices(for:) -> [VoiceInfo]`、`setVoice(for:voiceName:)`、`preview(language:)`；新增 `VoiceInfo` 结构体（name / language / identifier）
- [x] 2.2 实现 `availableVoices(for:)`：基于 `AVSpeechSynthesisVoice.speechVoices()` 按语言前缀过滤，返回 `VoiceInfo` 数组
- [x] 2.3 实现 `speak(_:language:)`：从 `voiceNameByLanguage[language]` 取出用户选中语音名；找不到则降级到该语言系统默认语音；应用 `speechRateMultiplier` 到 `utterance.rate`
- [x] 2.4 实现 `preview(language:)`：用当前选中语音 + 当前语速播放示例句 `"Hello, this is a preview."`
- [x] 2.5 发音降级处理：当指定语言无任何可用语音时，静默跳过，不抛错，不影响背记流程（沿用 v0.1 降级语义）

## 3. 发音设置 UI 重写

- [x] 3.1 `SpeechSettingsView` 重写：删除英式 / 美式 Picker；改为按语言分区的卡片式布局。v0.1.1 仅有"英语 (English)"分区，未来按启用单词本的 source_lang 自动扩展
- [x] 3.2 每个语言分区包含：语音 Picker（下拉，列出该语言系统可用语音）、试听按钮（▶ 图标 + "试听" 标签）、语速 Slider（0.5x – 1.5x，步进 0.1，右侧数字显示当前值）
- [x] 3.3 试听按钮交互：点击后调用 `SpeechService.preview(language:)`，播放期间按钮短暂禁用或视觉反馈
- [x] 3.4 语速 Slider 变更即时生效：修改 `AppSettings.shared.speechRateMultiplier` 并 `postTimingChange()`，让当前正在播放的单词后续切换时使用新语速
- [x] 3.5 预设主题与 glassCard 样式：发音设置卡片沿用现有 `glassCard()` / `glassButtonStyle()` 风格，保持与其他 Tab 视觉一致

## 4. 背记引擎与悬浮窗接入新发音接口

- [x] 4.1 `ReciteEngine` 暴露当前词条的语种访问路径：确保 `currentWord()` 返回的 `WordEntry` 能通过 `wordbook?.sourceLang` 拿到语种；或新增 `currentLanguage() -> String` 便捷方法
- [x] 4.2 `FloatWindowController` 引擎触发发音时（自动播放），调用 `SpeechService.shared.speak(word.sourceWord, language: currentLanguage)`；语言从当前词条的 wordbook.sourceLang 取
- [x] 4.3 监听设置变更：`SpeechService.applySettings()` 在发音设置改动时被调用，重新读取 `voiceNameByLanguage` 与 `speechRateMultiplier`

## 5. 悬浮窗手动播报 ▶ 按钮

- [x] 5.1 `FloatContentView` 新增 `speakButton`（`NSButton`），title 设为 `▶`（U+25B6）；复用 `configureButton` 现有样式（单色文字按钮 + 玻璃背景）
- [x] 5.2 按钮顺序：反馈模式 `[ ♡ ] [ ▶ ] [ ✓ ] [ ✗ ]`，走马灯模式 `[ ♡ ] [ ▶ ]`；更新 `visibleButtons()` 返回值
- [x] 5.3 新增 `onSpeakTap: (() -> Void)?` 回调；`speakTapped()` 触发 `animateButtonClick(speakButton)` + 回调
- [x] 5.4 已学完状态：`showCompleted()` 中隐藏 speakButton；`activeButtons()` 返回空数组（已学完无任何按钮）
- [x] 5.5 `FloatWindowController.setupContentView()` 中 wiring：`onSpeakTap = { [weak self] in guard let word = self?.engine.currentWord() else { return }; SpeechService.shared.speak(word.sourceWord, language: self?.currentLanguage ?? "en") }`

## 6. 悬浮窗反馈按钮图标化

- [x] 6.1 `FloatContentView.setupButtons()` 中将 `knowButton.title = "认识"` 改为 `knowButton.title = "✓"`（U+2713），`unknownButton.title = "不认识"` 改为 `unknownButton.title = "✗"`（U+2717）
- [x] 6.2 为两个按钮设置 `toolTip`：`knowButton.toolTip = "认识"`、`unknownButton.toolTip = "不认识"`
- [x] 6.3 视觉对齐：确认 ✓ / ✗ 与 ♡ / ♥ / ▶ 在同一按钮尺寸、字号、背景 alpha、hover / press 动效下视觉权重均衡；必要时微调字号（统一走 `Constants.buttonFontSize`）

## 7. 系统菜单栏设置入口

- [x] 7.1 `HoverWordApp.swift`：将 `Settings { EmptyView() }` 增加 `.commands { CommandGroup(replacing: .appSettings) { Button("HoverWord 设置…") { AppDelegate.shared.showSettingsWindow() }.keyboardShortcut(",", modifiers: .command) } }`
- [x] 7.2 验证 ⌘, 快捷键触发后显示已有的 `SettingsWindowController` 窗口，不创建重复窗口
- [x] 7.3 验证：当设置窗口已在前台时，再次 ⌘, 应将其置为 key window（由 `showSettingsWindow()` 既有逻辑保证）

## 8. 单词本预览行号

- [x] 8.1 `WordbookImportService.ParsedEntry` 新增 `lineNumber: Int` 字段
- [x] 8.2 `WordbookImportService.parse()`：在循环中把已跟踪的 `lineNumber`（含空行计数）写入 `ParsedEntry.lineNumber`
- [x] 8.3 `WordbookImportService.importEntries()`：将 `parsed.lineNumber` 写入 `entry.sourceLineNumber`
- [x] 8.4 `WordbookService.getEntriesPaginated`：返回结果包含 `sourceLineNumber` 字段；`WordbookPreviewView.EntryItem` 新增 `lineNumber: Int` 字段承接
- [x] 8.5 `WordbookPreviewView` UI：表头新增"行号"列（50pt，右对齐），作为第一列；`EntryRowView` 新增行号 Text 显示；当 `lineNumber == 0` 时显示 "-"
- [x] 8.6 行号列与分页协同：行号显示的是**原 TXT 真实行号**而非页内序号，跨页切换时保持行号语义

## 9. 集成验证与回归

- [x] 9.1 老数据升级测试：使用 v0.1 构建 → 导入词库 → 升级到 v0.1.1 构建，验证 Core Data 轻量迁移成功、所有老词条 `sourceLineNumber == 0`、预览行号显示为 "-"
- [x] 9.2 老用户发音设置迁移测试：分别测试 `useAmericanAccent=true` 与 `false` 的老用户升级后，语音选择器默认选中预期语音（美式 / 英式）
- [x] 9.3 新功能端到端测试：
  - 发音设置：选语音 → 试听 → 调节语速 → 切回悬浮窗验证后续单词发音符合预期
  - ▶ 按钮：两种模式下均能手动重听；已学完状态无按钮
  - ✓ / ✗ 图标：点击反馈正确，toolTip 显示正确文字
  - ⌘, 菜单：从菜单栏与快捷键均能打开设置窗口
  - 行号：导入含空行的 TXT，验证行号计数准确含空行；预览翻页行号不重置
- [x] 9.4 性能回归：悬浮窗单词切换延迟仍 ≤ 100ms；导入 10000 条单词仍 ≤ 3s；内存占用无明显增加
- [x] 9.5 边界情况：
  - 系统无英语语音时（极端情况），发音降级为不播放，UI 不崩溃
  - 预览视图在空单词本下仍能正常打开（显示空状态）
  - 悬浮窗在走马灯 / 反馈模式切换后，按钮序列正确刷新
