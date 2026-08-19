## Context

v0.1 MVP 已交付，背记引擎、悬浮窗、单词本管理、收藏夹等核心能力稳定。本次 v0.1.1 围绕 **发音系统重构 + 悬浮窗交互打磨 + 工作流补全** 三条主线做增强，共 5 项功能。发音系统是本次最大的架构改动——从 v0.1 的"英式 / 美式"二元 `Accent` enum，升级为按语言键控的语音选择 + 语速控制 + 试听。其他 4 项均为 UI / 工作流层的小幅调整。

## Goals / Non-Goals

### Goals

- 让用户能挑选具体系统语音、调节语速，满足"慢速听清"的高频诉求
- 发音配置架构对齐 AGENTS.md "多语种架构预留"原则，为 v0.2+ 多语种铺路
- 悬浮窗按钮视觉语言统一（全 Unicode 图标风格）
- 悬浮窗提供手动重听能力，不打断背记节奏
- 系统菜单栏 ⌘, 符合 Mac 标准行为
- 单词本预览支持溯源到原 TXT 行号，配合"外部编辑 + 重新导入"工作流

### Non-Goals

- **完整的多语种 UI**：本次仅做底层架构 ready，不实现日语 / 韩语单词本的创建与导入
- **艾宾浩斯记忆算法**：留在后续版本
- **iCloud 同步**：不在本次范围
- **统计与打卡**：不在本次范围
- **真人发音库**：继续基于系统 TTS
- **"正在播放"持续视觉指示**：仅做点击脉冲反馈，不接入 SpeechService delegate 实时状态

## Decisions

### Decision 1: 发音配置 keyed by language（方案 B + 多语言 ready）

**选择**：删除独立的"英式 / 美式"单选，用 `voiceNameByLanguage: [String: String]` 字典替代；语音选择器按语言分区展示，v0.1.1 只有英语分区。

**放弃的方案 A**（保留英 / 美 + 加语音下拉）：两个控件表达同一件事（选语音隐含了口音），概念冗余；且英 / 美这种"口音"概念是英语特有的，无法推广到日语 / 法语等语种。

**权衡**：
- ✓ 架构语种无关，新增语种零成本（UI 自动按单词本 source_lang 出分区）
- ✓ 数据模型更简洁（一个 dict 替代 enum + bool）
- × v0.1 用户迁移需要一次性转换（老字段 `useAmericanAccent` 删除）

### Decision 2: 语速作为全局设置，不分语言

**选择**：`speechRateMultiplier: Double` 为全局单一值，作用于所有语言的发音。

**替代方案**：每语言独立语速。
- 放弃原因：用户通常期望"慢速 / 正常"跨语言一致；独立配置增加 UI 复杂度，v0.1.1 没有足够场景证明值得。

### Decision 3: 试听用固定示例句

**选择**：试听按钮播放固定句子 `"Hello, this is a preview."`。

**替代方案**：
- (a) 让用户输入任意词试听：更灵活，但需要额外的文本输入框，对 0.1.1 过度设计
- (b) 用单个词如 "Hello"：太短，不足以体现语音特质（如节奏、连读）
- 固定句子兼顾"足够展示语音特征"与"实现简单"

### Decision 4: ▶ 按钮放在收藏 ♡ 之后、反馈按钮之前

**选择**：`[ ♡ ] [ ▶ ] [ ✓ ] [ ✗ ]`

**替代方案**：
- (a) `[ ▶ ] [ ♡ ] [ ✓ ] [ ✗ ]`：播报放最前
- 放弃原因：播报与收藏都是"关于这个词"的动作，✓ / ✗ 是"反馈"动作；按"辅助动作 / 反馈动作"分组更清晰，且与 v0.1 的 `[ ♡ ] [ 认识 ] [ 不认识 ]` 相比，只在中间插入一个，位置扰动最小

### Decision 5: 播报按钮使用 Unicode ▶，非 SF Symbol

**选择**：`▶`（U+25B6 BLACK RIGHT-POINTING TRIANGLE），与 ♡ / ♥ / ✓ / ✗ 同属单色 Unicode 符号，视觉语言一致。

**放弃的方案**：SF Symbol `speaker.wave.2.fill`
- 虽然 SF Symbol 可支持"播放中"动画（wave.1 ↔ wave.2 ↔ wave.3 循环），但会破坏"全 Unicode 文字按钮"的统一模式
- 且本次明确不做"持续播放态指示"，SF Symbol 的优势用不上
- `NSButton` 从 `title: String` 改为 `image: NSImage(systemSymbolName:)` 需要重构 `configureButton`，改动面不必要地扩大

### Decision 6: ✓ / ✗ 而非其他候选

**选择**：认识 = ✓ (U+2713)，不认识 = ✗ (U+2717)

**考虑的替代**：
- ▶ / ↺（音乐播放器风格）：语义偏"前进 / 回头"，不如 ✓ / ✗ 直觉对应"认识 / 不认识"
- 👍 / ❓：emoji 风格，与 ♡ / ♥ 不统一
- SF Symbol checkmark / xmark：同 Decision 5 的考量

**toolTip 必须加**：图标失去文字自解释性，靠 macOS toolTip（hover 1-2s 显示）补足，零学习成本。

### Decision 7: 行号 = 原始 TXT 真实行号（含空行）

**选择**：`sourceLineNumber` 存储词条在原 TXT 中的真实行号，包含被跳过的空行。

**放弃的方案**：显示序号（`orderIndex + 1`）
- 用户字面说"行号"而非"序号"
- v0.1 工作流是"外部编辑 TXT → 重新导入"，用户需要的是"回到 TXT 第 N 行"，不是"第 N 个词"
- 真实行号让预览与 TXT 文件双向可定位

### Decision 8: 老数据行号显示 "-"，不回填

**选择**：v0.1 已导入的词条 `sourceLineNumber = 0`，UI 显示为 `-`。不做回填，用户重新导入后自然获得准确行号。

**考虑的替代方案**：回填为 `orderIndex + 1`（近似值）
- 放弃原因：不准确（TXT 有空行时 `orderIndex + 1 ≠ 真实行号`），给用户错误的定位信息比"无信息"更糟

### Decision 9: 菜单用 SwiftUI `.commands` 重写 `.appSettings`

**选择**：

```swift
Settings { EmptyView() }
.commands {
    CommandGroup(replacing: .appSettings) {
        Button("HoverWord 设置…") {
            AppDelegate.shared.showSettingsWindow()
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
```

**为什么不替换 Scene 类型**：`Settings { EmptyView() }` 保留，仅替换其默认菜单项。`Settings` scene 本身不创建可见窗口（EmptyView 无 intrinsic size），删除它反而会让 SwiftUI 不生成 app menu。

### Decision 10: Core Data 轻量迁移

**选择**：新建 `.xcdatamodel` 版本，`WordEntry` 新增 `sourceLineNumber: Int32` attribute（default 0）。使用轻量迁移（additive，不丢失数据）。

**不选重量迁移**：本次仅添加一个 attribute，无 schema 重构，轻量迁移足够。

## Risks / Trade-offs

### Risk 1: 系统语音在不同 macOS 版本差异

**风险**：`AVSpeechSynthesisVoice.speechVoices()` 返回的语音列表因 macOS 版本而异；某些"premium"语音需要用户手动下载。
**缓解**：
- 语音下拉仅展示 `speechVoices()` 当前返回的列表
- 用户选中的语音若未来不可用，`SpeechService` 降级到该语言系统默认语音
- 不持久化"系统不存在的语音"——每次启动用 `availableVoices(for:)` 重新过滤

### Risk 2: 老用户迁移的边界情况

**风险**：极少数老用户可能修改过系统语音，`useAmericanAccent` 字段的迁移可能与他们的实际预期不符。
**缓解**：迁移逻辑明确（true→Samantha / false→Daniel），且用户随时可在设置中改选。影响可控。

### Risk 3: 轻量迁移的 iOS/macOS 兼容性

**风险**：Core Data 轻量迁移要求新旧模型版本差异符合 Apple 规定的"轻量"条件。
**缓解**：仅新增一个 optional-ish attribute（Int32 有默认值 0），完全符合轻量迁移规则。测试时验证 v0.1 数据能无损升级。

### Trade-off 1: 行号不回填

**权衡**：老数据行号显示 "-"，用户可能困惑。
**缓解**：预览视图保持简洁，不加说明文字；用户重新导入一次即可获得准确行号。相比"近似值回填"，"无信息"更诚实。

### Trade-off 2: 试听按钮用固定句子

**权衡**：无法让用户听自定义单词的效果。
**缓解**：示例句 `"Hello, this is a preview."` 足够展示语音特征；未来若有强烈需求，再扩展为可输入。

### Trade-off 3: 不做"持续播放态指示"

**权衡**：用户无法通过按钮视觉判断当前是否正在播放。
**缓解**：发音通常很短（单词 1-2 秒），持续指示的收益不大；如未来需要，可单独作为 0.1.2 引入，不影响本次架构。

### Risk 4: 悬浮窗按钮数量增加可能挤压释义空间

**风险**：从 3 个按钮增加到 4 个（反馈模式），悬浮窗宽度固定 300pt，可能挤压释义列。
**缓解**：图标按钮（♡ / ▶ / ✓ / ✗）比文字按钮（"认识" / "不认识"）视觉宽度显著减小；实际占用空间比 v0.1 更少。实现时若仍有问题，可通过减小按钮内边距或字号微调。
