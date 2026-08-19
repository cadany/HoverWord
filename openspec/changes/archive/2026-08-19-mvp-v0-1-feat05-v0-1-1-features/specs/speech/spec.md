Change-Sub-Version: mvp-v0-1-feat05

## Purpose

本次变更重构发音服务的架构与用户可配置项，从 v0.1 的"英式/美式"二元选择升级为**按语言分区的具体语音选择 + 全局语速控制 + 试听预览**，同时将底层数据结构调整为语种无关的 `language → voice` 映射，为未来多语种扩展铺路。

## MODIFIED Requirements

### Requirement: 发音语音选择（替代 v0.1 英式/美式切换）

系统 SHALL 在发音设置中按语言分区展示当前系统可用的 TTS 语音下拉列表，用户可为每种语言独立选择具体的语音。v0.1.1 中仅显示英语分区（过滤系统语音中 language code 以 `en-` 开头的语音），未来当用户单词本中出现其他语种（如日语、韩语）时，系统 SHALL 自动在发音设置中新增对应的语言分区。

#### Scenario: 英语语音列表展示
- **WHEN** 用户打开发音设置 Tab，且当前已启用的单词本中包含英语（source_lang 以 `en` 开头）
- **THEN** 系统 SHALL 显示"英语 (English)"分区，下拉列出当前 macOS 系统中所有可用的英语语音（按口音分组，如美式 / 英式），默认选中系统首个美式语音（若存在 Samantha 则优先）

#### Scenario: 用户选择具体语音
- **WHEN** 用户在英语分区的下拉中选择某语音（如 Daniel）
- **THEN** 系统 SHALL 将 `voiceNameByLanguage["en"]` 设置为该语音名称，后续英语单词发音使用该语音

#### Scenario: 无匹配语音降级
- **WHEN** 用户选中的语音在当前系统不可用（如被卸载或尚未下载完成）
- **THEN** 系统 SHALL 回退到该语言的系统默认语音，发音设置界面提示用户当前语音不可用

#### Scenario: 未来新增语言单词本
- **WHEN** 用户导入一个非英语单词本（如 source_lang = "ja"）
- **THEN** 发音设置 SHALL 在下次打开时自动新增"日语 (日本語)"分区，展示系统可用的日语语音列表

### Requirement: 语速控制

系统 SHALL 提供全局语速滑块，控制所有语言单词的发音语速。取值范围 0.5x – 1.5x，步进 0.1，默认值 1.0x（系统默认语速）。实际 `utterance.rate` SHALL 等于 `AVSpeechUtteranceDefaultSpeechRate × speechRateMultiplier`。

#### Scenario: 调整语速
- **WHEN** 用户拖动语速滑块到 0.8x
- **THEN** 系统 SHALL 将 `speechRateMultiplier` 设置为 0.8，后续所有单词发音以 80% 系统默认语速播放

#### Scenario: 语速影响所有语言
- **WHEN** 用户调整语速，且当前有多个语言的单词本
- **THEN** 语速设置 SHALL 全局生效，影响所有语言的发音语速

### Requirement: 试听按钮

发音设置的每个语言分区 SHALL 提供"试听"按钮。点击后使用**当前分区的语音 + 当前语速**播放固定示例句 `"Hello, this is a preview."`，让用户在确认前听到实际效果。

#### Scenario: 点击试听
- **WHEN** 用户在英语分区点击"试听"按钮，当前选中语音为 Samantha，语速为 1.0x
- **THEN** 系统 SHALL 使用 Samantha 语音以 1.0x 语速播放示例句

#### Scenario: 切换语音后试听
- **WHEN** 用户将英语语音切换为 Daniel，立即点击"试听"
- **THEN** 系统 SHALL 使用 Daniel 语音播放示例句，呈现英式发音效果

### Requirement: 发音服务架构重构

`SpeechService` SHALL 删除与英语绑定的 `Accent` enum，公开接口改为语言参数化：`speak(_:language:)`、`availableVoices(for:)`、`setVoice(for:voiceName:)`、`preview(language:)`。配置存储从单一布尔 `useAmericanAccent` 迁移为 `voiceNameByLanguage: [String: String]` 字典 + `speechRateMultiplier: Double`。

#### Scenario: 老用户设置迁移
- **WHEN** v0.1 用户首次启动 v0.1.1，其 `useAmericanAccent = true`
- **THEN** 系统 SHALL 将其迁移为 `voiceNameByLanguage["en"] = "Samantha"`（或系统首个美式语音），并删除旧字段

#### Scenario: 老用户迁移（英式偏好）
- **WHEN** v0.1 用户首次启动 v0.1.1，其 `useAmericanAccent = false`
- **THEN** 系统 SHALL 将其迁移为 `voiceNameByLanguage["en"] = "Daniel"`（或系统首个英式语音），并删除旧字段

#### Scenario: 新用户默认
- **WHEN** 新用户首次启动应用
- **THEN** `voiceNameByLanguage` SHALL 为空字典，`speechRateMultiplier` SHALL 为 1.0；发音时由 `SpeechService` 选择系统默认语音

> 注：「TTS 不可用降级」「发音不阻塞背记流程」两项需求与 v0.1 完全一致（见主规格 openspec/specs/speech/spec.md），本次无行为变更，不纳入 delta。
