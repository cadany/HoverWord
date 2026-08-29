# 术语约定：Section

## 决策（2026-08-28，feat02 期间确认）

"Section" 是跨语言统一术语：**任何语言的界面中该术语词保持字面 "Section"，不翻译**；其组合措辞按各语言自然语序本地化。

## 规则

1. **术语词不翻**：zh「Section 设置」、ja「Section 設定」、de「Section-Einstellungen」——"Section" 字面在各语言保留
2. **组合措辞本地化**：zh「Section 词数」「从第一个 Section 开始」、ja「Section の単語数」、en「Words per Section」——围绕术语的组合句式按目标语言自然语序组织
3. **禁止引入语言特定同义词**：如 zh「组」、en「group」等替代词不得用于指代 Section 概念（代码注释、UI 文案、spec 文档一致）

## 理由

- 产品为多语种架构（sourceLang/targetLang 任意方向），界面将扩展多语言；Section 概念单一字面使新语种接入零术语决策
- 与代码实体（`sectionIndex`、`SectionOrder`）、spec 文档保持一一对应，消除心智映射
- 目标用户为语言学习者，对 "Section" 无理解门槛

## 现有词条基线（zh）

| key | zh |
| --- | --- |
| recite.section | Section 设置 |
| recite.sectionSize | Section 词数 |
| recite.sectionOrder | Section 顺序 |
| recite.playOrder | Section 内展示顺序 |
| enum.sectionOrder.sequential | 从第一个 Section 开始 |
| wordbook.meta.format | %d 词 · %d Section |
