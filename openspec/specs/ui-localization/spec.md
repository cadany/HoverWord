# ui-localization Specification

## Purpose
界面层多语言能力：语言设置项、字符串本地化解析、切换即时刷新、系统单词本显示名映射。v0.1.1 先支持简体中文与英文，机制语种无关，后续新增语种仅需补充词条文件与语言选项。
## Requirements
### Requirement: 界面语言设置
系统 SHALL 提供界面语言设置项，位于设置窗口"通用"导航页。选项 SHALL 包含"跟随系统"（默认）与所有已提供词条的语言；语言列表为数据驱动，新增语种仅需补充词条文件与选项登记，不改动解析机制。v0.1.1 提供简体中文与 English 两项语言选项。选择 SHALL 持久化到全局配置（`uiLanguage` 字段，默认 "system"），重启后保持。

#### Scenario: 默认跟随系统
- **WHEN** 用户从未修改过界面语言
- **THEN** 系统 SHALL 使用"跟随系统"模式，界面语言与 macOS 系统语言一致（系统语言无匹配词条时回退英文）

#### Scenario: 手动锁定语言
- **WHEN** 用户将界面语言设为已提供的语言（如"简体中文"或"English"）
- **THEN** 系统 SHALL 忽略系统语言，始终使用所选语言渲染界面

#### Scenario: 设置持久化
- **WHEN** 用户修改界面语言后退出并重启应用
- **THEN** 系统 SHALL 保持上次选择的语言设置

#### Scenario: 新增语种免改机制
- **WHEN** 后续版本为某新语种补充词条文件并在语言列表登记
- **THEN** 解析层与设置页 SHALL 无需代码改动即可提供该语言，现有语言行为不受影响

### Requirement: 字符串本地化解析
系统 SHALL 使用 String Catalog（Localizable.xcstrings）管理界面文案，v0.1.1 提供 zh-Hans 与 en 两组词条。运行时 SHALL 按语言设置解析：锁定语言时加载对应语言词条；跟随系统时按系统语言解析，无匹配词条的语言回退英文。词条 key 在当前语言缺失时 SHALL 回退英文原文，不显示原始 key。

#### Scenario: 锁定语言解析
- **WHEN** 界面语言设为 English，系统语言为中文
- **THEN** 界面所有文案 SHALL 使用 en 词条渲染

#### Scenario: 系统语言回退
- **WHEN** 界面语言为"跟随系统"，系统语言为日语
- **THEN** 系统 SHALL 回退使用 en 词条渲染界面

#### Scenario: 词条缺失回退
- **WHEN** 当前语言词条中缺少某个 key
- **THEN** 系统 SHALL 显示该 key 的英文词条，不显示 key 原文

#### Scenario: 带插值文案
- **WHEN** 渲染含变量的文案（如导入错误行号、分页页码）
- **THEN** 系统 SHALL 按当前语言的格式化规则插入变量值

### Requirement: 语言切换即时刷新
用户修改界面语言后，界面 SHALL 立即切换到新语言，无需重启应用。系统 SHALL 通过语言变更通知刷新所有界面文案：SwiftUI 视图随语言状态重渲染，悬浮窗（AppKit）监听通知手动刷新。

#### Scenario: 设置窗口即时切换
- **WHEN** 用户在"通用"页将语言从中文切换为 English
- **THEN** 设置窗口（含 sidebar 导航项标签）SHALL 立即以英文重新渲染

#### Scenario: 悬浮窗即时切换
- **WHEN** 界面语言变更时悬浮窗正在展示单词
- **THEN** 悬浮窗内文案（按钮、右键菜单、"已学完"等）SHALL 立即以新语言刷新，单词内容与释义不因语言切换丢失

### Requirement: 系统单词本显示名映射
"我的收藏"系统单词本的名称为持久化数据，界面显示名 SHALL 走词条表映射（zh-Hans 显示"我的收藏"，en 显示 "Favorites"），Core Data 存储名与查询逻辑（`isSystem == YES`）SHALL 不受界面语言影响。

#### Scenario: 显示名跟随语言
- **WHEN** 界面语言在中文与英文间切换
- **THEN** 单词本列表中系统收藏夹的显示名 SHALL 相应显示"我的收藏"或 "Favorites"

#### Scenario: 存储与查询不受影响
- **WHEN** 界面语言任意切换
- **THEN** Core Data 中系统单词本记录 SHALL 保持创建时的名称不变，启用/停用与收藏同步等查询逻辑行为不变

### Requirement: RTL 布局预留
界面布局 SHALL 采用语义化方向属性（leading/trailing），不硬编码左右方向，为从右到左（RTL）语种预留适配能力，v0.1.1 不引入 RTL 语种。

#### Scenario: 无硬编码方向
- **WHEN** 检查界面布局代码
- **THEN** 间距与对齐 SHALL 使用 leading/trailing 语义属性，不出现 left/right 硬编码

