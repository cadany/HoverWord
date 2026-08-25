## Purpose

基于 macOS 系统 TTS 引擎（AVSpeechSynthesizer）的发音服务，提供单词发音播放能力，支持按语言分区选择具体语音、全局语速控制与试听预览，底层配置为语种无关的 language → voice 映射，离线可用，TTS 不可用时自动降级。
## Requirements
### Requirement: 单词发音播放
系统 SHALL 在切换至新单词时（根据自动播放设置）或用户主动触发时，播放该单词的系统 TTS 发音。

#### Scenario: 自动播放发音
- **WHEN** 自动播放开关开启，背记引擎切换至新单词
- **THEN** 系统 SHALL 自动播放该单词的发音

#### Scenario: 手动触发发音
- **WHEN** 自动播放开关关闭
- **THEN** 系统 SHALL 不自动播放发音，单词展示不受影响

### Requirement: 发音语音选择
系统 SHALL 在发音设置中按语言分区展示当前系统可用的 TTS 语音下拉列表（过滤系统趣味语音，按音质排序并标记 premium / enhanced），用户可为每种语言独立选择具体的语音。分区数据源为启用中单词本的 sourceLang 去重；词本启用、停用或删除导致启用语言集合变化时，发音设置 SHALL 即时增删对应语言分区（含设置页面常驻场景），无启用词本时回退仅显示英语分区。

#### Scenario: 英语语音列表展示
- **WHEN** 用户打开发音设置 Tab，且当前已启用的单词本中包含英语（source_lang 以 `en` 开头）
- **THEN** 系统 SHALL 显示英语分区，下拉列出当前 macOS 系统中所有可用的英语语音，默认选中系统首个美式语音（若存在 Samantha 则优先）

#### Scenario: 用户选择具体语音
- **WHEN** 用户在英语分区的下拉中选择某语音（如 Daniel）
- **THEN** 系统 SHALL 将 `voiceNameByLanguage["en"]` 设置为该语音名称，后续英语单词发音使用该语音

#### Scenario: 无匹配语音降级
- **WHEN** 用户选中的语音在当前系统不可用（如被卸载或尚未下载完成）
- **THEN** 系统 SHALL 回退到该语言的系统默认语音，发音设置界面提示用户当前语音不可用

#### Scenario: 新语言单词本即时新增分区
- **WHEN** 用户启用一个非英语单词本（如 source_lang = "ja"）
- **THEN** 发音设置 SHALL 即时新增日语分区，展示系统可用的日语语音列表

#### Scenario: 停用或删除语言词本即时移除分区
- **WHEN** 用户停用或删除某语言唯一的启用单词本（如法语）
- **THEN** 发音设置 SHALL 即时移除对应的语言分区；其它语言的分区与已保存的语音配置不受影响（已保存配置保留在 voiceNameByLanguage，重新启用后恢复生效）

### Requirement: 语速控制
系统 SHALL 提供全局语速滑块，控制所有语言单词的发音语速。取值范围 0.5x – 1.5x，步进 0.1，默认值 1.0x（系统默认语速）。实际 `utterance.rate` SHALL 等于 `AVSpeechUtteranceDefaultSpeechRate × speechRateMultiplier`。

#### Scenario: 调整语速
- **WHEN** 用户拖动语速滑块到 0.8x
- **THEN** 系统 SHALL 将 `speechRateMultiplier` 设置为 0.8，后续所有单词发音以 80% 系统默认语速播放

#### Scenario: 语速影响所有语言
- **WHEN** 用户调整语速，且当前有多个语言的单词本
- **THEN** 语速设置 SHALL 全局生效，影响所有语言的发音语速

### Requirement: 试听按钮
发音设置的每个语言分区 SHALL 提供"试听"按钮。点击后使用当前分区的语音 + 当前语速播放固定示例句，让用户在确认前听到实际效果。

#### Scenario: 点击试听
- **WHEN** 用户在英语分区点击"试听"按钮，当前选中语音为 Samantha，语速为 1.0x
- **THEN** 系统 SHALL 使用 Samantha 语音以 1.0x 语速播放示例句

#### Scenario: 切换语音后试听
- **WHEN** 用户将英语语音切换为 Daniel，立即点击"试听"
- **THEN** 系统 SHALL 使用 Daniel 语音播放示例句，呈现英式发音效果

### Requirement: 发音服务架构（语言参数化）
`SpeechService` 公开接口 SHALL 为语言参数化：`speak(_:language:)`、`availableVoices(for:)`、`preview(language:)`。配置存储 SHALL 使用 `voiceNameByLanguage: [String: String]` 字典 + `speechRateMultiplier: Double`，不与具体语种耦合。播放状态通知 SHALL 携带试听来源标记（isPreview），避免悬浮窗自动播报干扰设置页试听按钮状态。

#### Scenario: 老用户设置迁移
- **WHEN** v0.1 用户首次启动 v0.1.1，其 `useAmericanAccent = true`
- **THEN** 系统 SHALL 将其迁移为 `voiceNameByLanguage["en"] = "Samantha"`（或系统首个美式语音），并立即持久化，后续启动不再重复迁移

#### Scenario: 老用户迁移（英式偏好）
- **WHEN** v0.1 用户首次启动 v0.1.1，其 `useAmericanAccent = false`
- **THEN** 系统 SHALL 将其迁移为 `voiceNameByLanguage["en"] = "Daniel"`（或系统首个英式语音）

#### Scenario: 新用户默认
- **WHEN** 新用户首次启动应用
- **THEN** `voiceNameByLanguage` SHALL 为空字典，`speechRateMultiplier` SHALL 为 1.0；发音时由 `SpeechService` 选择系统默认语音

#### Scenario: 自动播报不干扰试听按钮
- **WHEN** 设置窗口打开期间，悬浮窗自动播报单词发音
- **THEN** 设置页试听按钮 SHALL 不因该播放而进入"停止"状态（播放状态通知按来源过滤）

### Requirement: TTS 不可用降级
当系统 TTS 引擎不可用时，系统 SHALL 自动降级为不播放发音，不影响单词正常展示与背记流程。

#### Scenario: TTS 引擎初始化失败
- **WHEN** 系统 TTS 语音不可用（如语音数据未安装）
- **THEN** 系统 SHALL 静默跳过发音，单词照常展示，不弹出错误提示

#### Scenario: 发音过程中断
- **WHEN** 发音播放过程中被新单词切换打断
- **THEN** 系统 SHALL 中断当前发音，开始播放新单词发音

### Requirement: 发音不阻塞背记流程
发音播放 SHALL 不阻塞单词切换与背记调度。单词切换延迟不因发音播放而增加。

#### Scenario: 发音时长超过停留时长
- **WHEN** 单词发音时长超过用户设置的停留时长
- **THEN** 系统 SHALL 按停留时长正常切换单词，发音播放被中断，不影响背记节奏

### Requirement: 语音列表动态刷新
发音服务 SHALL 在每次播放前检查可用语音列表的新鲜度：距上次刷新超过 60 秒时重新枚举系统语音，未超时则使用缓存。设置口音（applySettings）时 SHALL 无条件刷新一次。

#### Scenario: 新下载语音即时生效
- **WHEN** 用户在系统设置中下载新的语音包后，悬浮窗切换单词触发发音
- **THEN** 发音服务 SHALL 在下次播放前的刷新中纳入新语音，无需重启应用

#### Scenario: 刷新节流
- **WHEN** 连续多次播放单词（间隔均在 60 秒内）
- **THEN** 发音服务 SHALL 复用缓存的语音列表，不重复枚举系统语音

### Requirement: 全屏隐藏期间静音
当全屏自动隐藏与"全屏隐藏时静音发音"（默认开启）均开启时，悬浮窗隐藏期间系统 SHALL 停止在播语音且不再发起自动发音；切词进度不受影响。该开关 SHALL 仅在全屏自动隐藏开启时可用（否则置灰）。设置项 `muteSpeechInFullscreen` SHALL 持久化，旧版本存储无此字段时按默认开启解码。

#### Scenario: 全屏观影不被打扰
- **WHEN** 用户进入全屏应用（看视频/演示），两项开关均开启
- **THEN** 悬浮窗隐藏后不再有单词朗读，退出全屏恢复显示后下一词起朗读恢复

#### Scenario: 用户偏好隐藏时继续听
- **WHEN** 用户关闭"全屏隐藏时静音发音"
- **THEN** 全屏隐藏期间自动发音照常（原有行为），设置重启后保持

