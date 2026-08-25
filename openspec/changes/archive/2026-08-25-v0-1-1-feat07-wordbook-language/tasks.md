## 1. 服务层

- [x] 1.1 `Shared/Constants.swift`：`supportedWordLanguages` 注册表、`languageDetectionSampleCount=20`、置信度阈值（初值 0.5，4.4 诊断轮实测校准为 0.7：噪声样本 0.63 / 真实语种 0.88-0.99）
- [x] 1.2 新建 `Services/LanguageDetectionService.swift`：`detect(from: [String]) -> (code, confidence)?`（拼接 + NLLanguageRecognizer，rawValue 直用）；注音不参与由调用方保证
- [x] 1.3 `Shared/NotificationNames.swift`：`.wordbookLanguageDidChange`
- [x] 1.4 `Services/WordbookService.swift`：
  - `importFromFile` 导入落库后按 ParsedEntry 检测回写语言对 + 发通知
  - `updateWordbookLanguages(_:source:target:)`（主线程，发通知）
  - `detectLanguages(for:)`（查前 20 条词条 → 检测，供编辑页"自动检测"）

## 2. UI

- [x] 2.1 `WordbookTabView`：`...` 菜单加"语言…"项（普通词本，位于导出后）；`showingLanguagePanel` + `languageEditingWordbook` 状态 + Sheet
- [x] 2.2 语言编辑 Sheet：源/目标 Picker（注册表，Locale 显示名）+ 自动检测按钮（回填）+ 取消/确定
- [x] 2.3 `SpeechSettingsView`：onReceive 增监听 `.wordbookLanguageDidChange`（刷新分区 + loadSettings）

## 3. 文案

- [x] 3.1 `Localizable.xcstrings`：`wordbook.menu.language`（语言…/Language…）、`wordbook.language.title/source/target/autodetect`（zh-Hans/en）

## 4. 测试与验证

- [x] 4.1 新建 `LanguageDetectionServiceTests`：法语/西语/日语假名语料、英语基础词兜底、日语释义、空输入
- [x] 4.2 新建 `WordbookImportLanguageTests`：法语 TXT 导入 → fr→en；重新导入英语内容 → 重算
- [x] 4.3 构建 + 全量测试无回归
- [x] 4.4 诊断轮（自动触发 + 日志）验证：日志证实 语言编辑 fr→["fr"] / 还原 es→["es"] 分区即时刷新（另发现并修复：注册表约束 + 阈值 0.7 实测校准，噪声 0.63/真实 0.88-0.99）；探针已移除
- [x] 4.5 手动验证（用户）：导入多语种 TXT → 发音页出现新分区；菜单"语言…"修改 → 分区即时变化；收藏夹无语言项——用户验证通过（2026-08-25）
