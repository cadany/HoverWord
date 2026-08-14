## 1. ReciteEngine Bug 修复

- [x] 1.1 修复首词跳过：将 `advanceToNextWord()` 拆分为索引递增（`advanceIndex()`）和展示（`displayCurrentWord()`），`start()` / `advanceToNextSection()` / 新轮次开始时调用 `displayCurrentWord()` 而非 `advanceToNextWord()`
- [x] 1.2 修复 markUnknown：`markUnknown()` 中移除 `feedbackSet.insert(word.wordId)`，仅调用 `advanceToNextWord()` 切换到下一单词
- [x] 1.3 更新 ReciteEngineTests：新增 `testFirstWordNotSkipped`（验证 start 后 currentWord 为 index 0）、修改 `testMemoryFeedbackMarkUnknown`（验证 markUnknown 后单词在后续轮次重试）
- [x] 1.4 运行全部测试验证 ReciteEngine 修复无回归

## 2. 深色模式修复

- [x] 2.1 GlassBackgroundView：删除 `appearance = NSAppearance(named: .aqua)` 硬编码，让 NSVisualEffectView 自动跟随系统外观
- [x] 2.2 FloatContentView：新增 `isDarkMode` 属性和 `updateTextColors()` 方法，根据系统外观切换文字颜色（浅色: black α=0.85/0.55, 深色: white α=0.90/0.60）和按钮颜色（浅色: white α=0.20, 深色: white α=0.15）
- [x] 2.3 FloatContentView：重写 `viewDidChangeEffectiveAppearance()`，调用 `updateTextColors()` 自动刷新
- [x] 2.4 FloatContentView：`addMeaningRow()` 中的释义文字颜色改为动态获取（不再硬编码 black α=0.85）
- [x] 2.5 构建验证深色模式修复无编译错误

## 3. 动效补全

- [x] 3.1 单词切换 1px 垂直位移：`showWord()` 的淡出阶段对 wordLabel/phoneticLabel 同时动画 y 位移 -1px，淡入阶段从 +1px 回到原位
- [x] 3.2 按钮悬停底部滑入：`setButtonsHidden(false)` 时先设置按钮初始 y 偏移 -4px + alpha=0，动画到正常位置 + alpha=1，时长 0.15s ease-out
- [x] 3.3 按钮点击态动效：在 `knowTapped` / `unknownTapped` / `favoriteTapped` 中触发 scale(0.95) + 亮度降低动画，0.1s 后恢复
- [x] 3.4 窗口显示/隐藏动效：FloatWindowController 的 `showWindow()` 中实现 alpha 0→1 + scale 0.95→1.0 过渡（0.2s ease-out），隐藏时反向
- [x] 3.5 完成状态切换动效：`showCompleted()` 用 NSAnimationContext 包裹，先淡出单词内容（0.2s），再淡入"已学完"文字
- [x] 3.6 设置应用过渡动效：`handleSettingsChange()` 中的 `applyAppearanceSettings()` 用 NSAnimationContext 包裹，时长 0.2s ease-out
- [x] 3.7 构建 + 运行验证动效无编译错误和崩溃

## 4. 最终验证

- [x] 4.1 运行全部单元测试，确认 0 失败
- [x] 4.2 重新运行 app，人工验证：深色模式切换、首词正常展示、markUnknown 重试效果、所有动效表现
  - ✅ 人工验证通过。额外修复了 `addMeaningRow()` 深色模式下释义文字颜色硬编码为黑色导致不可见的问题
