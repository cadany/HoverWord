# spec.md — settings-window delta

## MODIFIED Requirements

### Requirement: 背记规则设置
背记设置 Tab 配置项包含：背记模式、Section 设置（Section 词数 + 走马灯循环轮次 + Section 顺序 + Section 内展示顺序）、停留时长、全屏自动隐藏。Section 设置卡片内：Section 顺序与Section 内展示顺序为「左标签 + 右分段选择」行（Section 顺序分段三选项：顺序开始 / 随机起点 / 随机打乱，默认顺序开始；Section 内展示顺序分段两选项：顺序播放 / 随机播放）。

#### Scenario: Section 顺序设置
- **WHEN** 用户在背记设置页切换 Section 顺序策略
- **THEN** 选择 SHALL 即时持久化，触发背记进度重置并按新策略重新开始

#### Scenario: Section 内展示顺序
- **WHEN** 用户在背记设置页选择Section 内展示顺序（顺序/随机）
- **THEN** 仅 SHALL 影响 Section 内部单词顺序（语义与Section 间策略正交）
