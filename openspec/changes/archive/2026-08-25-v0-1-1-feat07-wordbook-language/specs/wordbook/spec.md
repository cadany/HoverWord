Change-Sub-Version: v0-1-1-feat07

## Purpose

词本语言对（sourceLang/targetLang）从硬编码默认升级为"导入自动识别 + 手动可编辑"，打通多语种词库经 UI 导入后的语言标签链路。

## ADDED Requirements

### Requirement: 语言自动识别与设置
系统 SHALL 在 TXT 全量导入完成后，基于导入内容自动识别并回写词本语言对：源词列前 20 条拼接检测 sourceLang，释义列前 20 条拼接检测 targetLang（NaturalLanguage 框架，离线）；注音列 SHALL NOT 参与检测。检测置信度低于 0.7 或无结果时 SHALL 回退默认值（sourceLang=en，targetLang=zh-Hans）。重新导入（全量覆盖）SHALL 按新内容重算语言对。语言对变化时系统 SHALL 发送 `.wordbookLanguageDidChange` 通知。

用户 SHALL 可通过普通词本行内菜单"语言…"手动设置语言对（源/目标语言下拉 + 自动检测回填），系统收藏夹 SHALL NOT 提供语言编辑。

#### Scenario: 导入自动识别
- **WHEN** 用户将 50 个法语词条（释义为英语）的 TXT 导入某普通单词本
- **THEN** 导入完成后词本语言对 SHALL 自动设置为 fr→en，发音设置的语言分区数据源随之更新

#### Scenario: 低置信度回退
- **WHEN** 导入内容的源词列为高频英语基础词（检测置信度低于阈值）
- **THEN** sourceLang SHALL 回退为 en，导入流程不中断、无错误提示

#### Scenario: 重新导入重算
- **WHEN** 用户对已手动设置语言对的词本重新导入另一语种的内容
- **THEN** 语言对 SHALL 按新导入内容重算覆盖（全量覆盖导入的内容即真相语义）

#### Scenario: 手动设置语言对
- **WHEN** 用户在某普通词本行内菜单点击"语言…"，选择源语言=es、目标语言=ja 并确认
- **THEN** 词本语言对 SHALL 更新为 es→ja 并广播语言变更通知；收藏夹词本 SHALL NOT 出现"语言…"菜单项

#### Scenario: 编辑页自动检测回填
- **WHEN** 用户在语言编辑 Sheet 点击"自动检测"
- **THEN** 两个下拉 SHALL 回填按当前词本内容检测出的语言对（低置信度同样回退默认）
