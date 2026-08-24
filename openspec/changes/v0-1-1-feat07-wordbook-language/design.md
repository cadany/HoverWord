# Design: 词本语言自动识别与手动设置

## Context

UI 建词本硬编码 en/zh-Hans，多语种词库经 UI 导入后语言标签错误，发音分区（数据源=启用词本 sourceLang）无法出现新语种。实测（2026-08-23，NLLanguageRecognizer + 桌面真实词库）确定了检测策略。

## Goals / Non-Goals

- Goals: 导入自动识别语言对、手动编辑入口（含存量词本）、发音分区联动刷新
- Non-Goals: 不做语种白名单拦截（任意语种词库均可导入）、不做检测置信度 UI、不做语种统计

## Decisions

### D1: 检测策略（实测驱动）

- `detect(from: [String]) -> (code, confidence)`：样本去空格拼接后送 NLLanguageRecognizer；`dominantLanguage.rawValue` 直接是 BCP-47 代码（"en"/"zh-Hans"），与 sourceLang 存储同构，零映射
- **识别器候选约束到注册表语种**（languageConstraints）：单测实测发现小词汇量/重复样本会带置信度误判到注册表外语种（4 词循环英语释义→丹麦语），约束后排除噪声语种
- **样本 = 前 20 条源词列 / 前 20 条释义列**（常量 `languageDetectionSampleCount`）
- **注音列不参与**（IPA 实测污染：英语词+IPA → da）
- 置信度 < `languageDetectionConfidenceThreshold`(0.7，实测校准) 或无结果 → 回退（source 回退 en、target 回退 zh-Hans，即现有默认）
- 注册表同时用于编辑下拉选项与检测约束（语种无关；注册表外语种不再可能成为检测结果）

### D2: 导入即检测（内容即真相）

`importFromFile` 在导入落库后、用解析内存中的 ParsedEntry 前 20 条检测并回写词本语言对（source 列/meaning 列分别检测），发 `.wordbookLanguageDidChange`。全量覆盖导入的语义下，重导入重算覆盖手动设置是预期行为，spec 明示。

### D3: 手动编辑（菜单"语言…"）

- 仅普通词本（收藏夹不提供）：行内 NSMenu 在"导出"后加"语言…"
- Sheet（对齐 rename sheet 模式）：源/目标两个 Picker，选项 = 注册表，label 用 `Locale.current.localizedString(forLanguageCode:)` 系统本地化名（零新增词条）；"自动检测"按钮调 `WordbookService.detectLanguages(for:)`（查库取前 20 条词条 → D1 策略）回填两个 Picker；确认调 `updateWordbookLanguages(_:source:target:)`
- 保存/自动回写均发 `.wordbookLanguageDidChange`（主线程）

### D4: 发音分区联动

SpeechSettingsView 的启停通知 onReceive 扩为同时监听 `.wordbookLanguageDidChange`（refreshActiveLanguages + loadSettings）。语言编辑不重启引擎（不影响背记队列），仅刷新发音配置。

## Risks / Trade-offs

- 英语基础词表检测误判（→id）：阈值兜底回退 en，实测覆盖；用户可手改
- 中日汉字词表消歧依赖假名混排：纯汉字短样本可能误判 zh-Hans/ja——"自动检测"按钮 + 手选兜底
- NLLanguageRecognizer 结果随系统版本浮动：策略按"建议值"定位，非唯一真相

## Migration Plan

无数据迁移；存量词本语言对可经"语言…"手动修正（或重导入触发检测）。

## Open Questions

无。
