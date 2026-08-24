---
baseline_version: "v0-1-1"
change_sub_version: "v0-1-1-feat07"
---

## Why

UI 新建词本硬编码 `sourceLang="en"/targetLang="zh-Hans"`（WordbookService.createWordbook），用户通过正规导入路径导入多语种词库后，发音设置的语言分区数据源永远只有英语——多语种架构预留（PRD 2.3）在 UI 层断裂。实测验证（2026-08-23）：用户自行导入"西班牙语-日语"词库后无法获得西语发音分区。

## What Changes

1. **语种自动识别服务**：新建 `LanguageDetectionService`，基于系统 `NLLanguageRecognizer`（NaturalLanguage 框架，离线、零依赖）。实测结论驱动的策略：
   - 源词列**前 20 条拼接**检测 sourceLang（单词检测实测不可靠：water→nl、水→zh-Hans）
   - 释义列前 20 条拼接检测 targetLang（实测 4/4 全对，置信度 0.62-1.00）
   - **注音列不参与**（IPA 符号实测会把识别器带偏到丹麦语）
   - 置信度 < 0.7 回退默认（source=en / target=zh-Hans；英语基础词表实测会误判成印尼语，en 兜底正好覆盖）
2. **导入后自动设置**：`importFromFile` 全量导入完成后按内容自动检测并回写语言对，发 `.wordbookLanguageDidChange` 通知
3. **语言对手动编辑**：普通词本行内 `...` 菜单新增"语言…"项，弹出编辑 Sheet（源/目标语言下拉 + "自动检测"按钮回填），保存后发通知——覆盖检测翻车场景与存量词本
4. **发音分区联动**：SpeechSettingsView 除启停通知外监听语言变更通知，即时增删分区
5. **语言注册表**：常量管理的支持语种列表（en/fr/es/de/ja/ko/zh-Hans/it/pt/ru），下拉显示名用 `Locale.localizedString(forLanguageCode:)` 系统本地化，不新增词条、保持语种无关

## Capabilities

### Modified Capabilities

- `wordbook`: 新增"语言自动识别与设置"Requirement（导入检测 + 手动编辑）
- `settings-window`: 行内菜单新增"语言…"项 + 语言对编辑 Sheet
- `speech`: 语言分区刷新触发源扩展（词本启停 + 语言变更）

## Impact

### 影响文件

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Services/LanguageDetectionService.swift` | 新增 | NLLanguageRecognizer 封装（拼接检测、置信度阈值、回退） |
| `Shared/Constants.swift` | 修改 | 支持语种注册表、检测样本数/置信度阈值常量 |
| `Shared/NotificationNames.swift` | 修改 | `.wordbookLanguageDidChange` |
| `Services/WordbookService.swift` | 修改 | importFromFile 导入后检测回写；updateWordbookLanguages；detectLanguages(for:) 供编辑页 |
| `Features/Settings/WordbookTabView.swift` | 修改 | 菜单项 + LanguageEditorSheet + 状态 |
| `Features/Settings/SpeechSettingsView.swift` | 修改 | onReceive 增加语言变更通知 |
| `Resources/Localizable.xcstrings` | 修改 | 菜单项/Sheet 标题/按钮词条（zh-Hans/en） |
| `HoverWordTests/Services/LanguageDetectionServiceTests.swift` | 新增 | 真实语料检测断言（含英语兜底、空输入） |
| `HoverWordTests/Services/WordbookImportLanguageTests.swift` | 新增 | 导入后语言对自动设置集成测试 |

### 已识别的取舍

- 导入为全量覆盖语义：重新导入会按新内容重算语言对，覆盖此前手动设置（内容即真相）；仅手动编辑（不重导入）时设置持久
- 检测置信度阈值固定常量，不暴露设置
- 收藏夹（系统词本）不提供语言编辑（跟随词条源词本语种播报）

### 测试覆盖

- 检测：法语/西语/日语（含假名）语料 → 对应语种；英语基础词表 → en 兜底；日语释义 → ja
- 导入集成：法语 TXT 导入后 sourceLang=fr / targetLang=en
- 全量回归
