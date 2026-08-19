---
baseline_version: "mvp-v0-1"
change_sub_version: "mvp-v0-1-feat05"
---

## Why

v0.1 MVP 交付后，背记流程本身可用，但围绕"发音控制"与"交互细节"的若干体验缺口在使用中逐渐显现：

1. **发音选择粒度过粗**：v0.1 仅提供英式 / 美式二元选择，无法挑选具体系统语音；不同语音的音质、口音、节奏差异显著，用户无法选到最顺耳的一个。语速也无法调节，对"慢速听清"这一背单词高频诉求无能为力。同时，当前 `SpeechService` 的 `Accent` 抽象与 v0.1 英中场景强绑定，不符合 AGENTS.md 中"多语种架构预留"的长期要求。
2. **悬浮窗无法主动重听**：自动播放一次即止，用户想再听一遍当前单词只能等下一轮循环或去设置里手动触发，打断了背记节奏。
3. **按钮视觉语言不统一**：收藏用 Unicode 字符 ♡/♥，"认识 / 不认识"却是完整中文字符串，两者风格割裂；后者在窄悬浮窗内视觉权重过高。
4. **设置入口不符合 Mac 习惯**：系统菜单栏"应用名 → 设置…"（⌘,）这一标准 Mac 入口点不到 HoverWord 自己的设置窗口。
5. **单词本预览缺失溯源信息**：v0.1 要求"外部编辑 TXT 再重新导入"，预览视图却不告诉用户每个词条在原 TXT 中的行号，用户定位回去编辑时只能肉眼逐行找。

## What Changes

本次变更围绕 **发音系统重构 + 悬浮窗交互打磨 + 工作流补全** 三条主线，共 5 项功能：

| # | 功能 | 主线 | 类型 |
|---|---|---|---|
| ① | TTS 发音风格设置（语音选择 + 语速 + 试听） | 发音重构 | 增强 |
| ② | 悬浮窗手动播报 ▶ 按钮 | 发音重构 | 新增 |
| ③ | "认识 / 不认识"改为图标 ✓ / ✗ | 交互打磨 | 调整 |
| ④ | 系统菜单"HoverWord 设置…"接入已有设置窗口 | 交互打磨 | 修复 |
| ⑤ | 单词本预览增加原始 TXT 行号 | 工作流补全 | 新增 |

## Capabilities

### New Capabilities

- **speech-voice-selection**：在发音设置中按语言分区展示系统可用语音的下拉选择器；v0.1.1 仅有英语分区，但数据模型以 language code 为键，未来加入新语种单词本时自动出现对应分区。
- **speech-rate-control**：全局语速滑块，0.5x – 1.5x，步进 0.1，1.0x = 系统默认语速。
- **speech-voice-preview**：试听按钮，使用当前选中的语言 / 语音 / 语速播放固定示例句，让用户在确认前听到实际效果。
- **float-window-manual-speak**：悬浮窗 hover 态新增 ▶ 按钮，点击重新播放当前单词发音，两种背记模式（记忆反馈 / 走马灯）下均显示；带一次性脉冲动画作为视觉反馈。
- **wordbook-preview-line-number**：单词本预览表格最左列显示该词条在原 TXT 文件中的真实行号（含被跳过的空行）；老数据（v0.1 已导入）显示为 "-"，重新导入后自动准确。

### Modified Capabilities

- **speech-service-architecture**：删除与英语绑定的 `Accent` enum 和 `useAmericanAccent` 设置项；`SpeechService.speak(_:)` 改为 `speak(_:language:)`；设置存储由单一布尔改为 `voiceNameByLanguage: [String: String]` 字典 + `speechRateMultiplier: Double`。对老用户做一次性迁移：`useAmericanAccent=true → "en": "Samantha"`（或首个美式语音），`false → "en": "Daniel"`（或首个英式语音）。
- **float-window-feedback-icons**：将反馈模式下"认识 / 不认识"文字按钮替换为 Unicode ✓（U+2713）/ ✗（U+2717）图标按钮，与 ♡ / ♥ / ▶ 保持同一视觉语言；加 toolTip = "认识" / "不认识" 保证零学习成本。
- **settings-menu-integration**：在 `HoverWordApp.swift` 的 Scene 中用 `.commands { CommandGroup(replacing: .appSettings) { ... } }` 重写系统默认设置菜单项，⌘, 触发 `AppDelegate.showSettingsWindow()`，标题为 "HoverWord 设置…"。

## Impact

**受影响文件（约 12 个）**

```
App/HoverWordApp.swift                                ④ 菜单
Models/AppSettings.swift                              ① 字段替换 + 迁移
Models/Entities/WordEntry+CoreDataProperties.swift    ⑤ 新字段
Resources/HoverWord.xcdatamodeld                      ⑤ 新模型版本（轻量迁移）
Services/SpeechService.swift                          ① 架构重构
Services/WordbookImportService.swift                  ⑤ 行号传递
Services/WordbookService.swift                        ⑤ 取数带上行号
Features/FloatingWindow/FloatContentView.swift        ②③ 按钮重构
Features/FloatingWindow/FloatWindowController.swift   ② onSpeakTap 回调
Features/Settings/SpeechSettingsView.swift            ① UI 重写
Features/Settings/WordbookPreviewView.swift           ⑤ 行号列
Shared/Constants.swift                                ②③ 可能需要新增常量
```

**数据迁移**：
- Core Data：WordEntry 新增 `sourceLineNumber: Int32` attribute（additive，轻量迁移）。老数据默认 0，UI 显示 "-"。
- AppSettings：删除 `useAmericanAccent`，新增 `voiceNameByLanguage`、`speechRateMultiplier`。`apply(stored:)` 做向后兼容转换。

**多语种架构影响**：
- 发音配置 keyed by language，与 AGENTS.md "多语种架构预留" 原则对齐。v0.1.1 UI 上仅显示英语分区，但底层结构已 ready，未来加新语种单词本无需再动数据层。

**性能 / 稳定性**：
- 所有改动均为 UI 与配置层，不影响背记引擎核心流程。
- 轻量 Core Data 迁移为 additive，不影响现有数据完整性。
- 不引入新依赖，不改变内存与 CPU 占用模式。

**不在本次范围内**：
- 完整的多语种 UI（日语 / 韩语单词本创建与导入）
- 艾宾浩斯记忆算法
- iCloud 同步
- 统计与打卡
