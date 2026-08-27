# spec.md — word-transition-effects delta

## ADDED Requirements

### Requirement: 动效与注音可见性协同
动效 SHALL NOT 动画或改写注音图层（不向其添加动画、不改写其模型状态）。注音的呈现完全由视图层负责：文本经 `swapContent` 在动效中点瞬时切换，可见性全程按 content-visibility 配置维护——注音在动效期间 SHALL 保持其配置语义，SHALL NOT 因动效短暂呈现或跳变。

#### Scenario: 注音不可见时切词
- **WHEN** 注音显示模式为 `.hidden` 或 `.hover`（鼠标在悬浮窗外）
- **AND** 触发单词切换动效
- **THEN** 注音 SHALL 全程保持不可见（alpha = 0），无闪现

#### Scenario: 注音可见时切词
- **WHEN** 注音显示模式为 `.always` 或 `.hover`（鼠标在悬浮窗内）
- **AND** 触发单词切换动效
- **THEN** 注音 SHALL 在动效中点瞬时切换为新词条的注音文本（不随单词参与动画），alpha 保持 1

#### Scenario: 预览演示
- **WHEN** 设置界面触发动效预览
- **THEN** 预览 SHALL 全量展示内容（注音可见，文本随演示切换），不受注音显示模式影响
