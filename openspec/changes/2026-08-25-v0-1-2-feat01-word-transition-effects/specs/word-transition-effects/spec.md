Change-Sub-Version: v0-1-2-feat01

## Purpose

可扩展的单词切换动效系统。用户可从多种创意动效中选择自己喜欢的风格，部分动效支持参数微调，设置界面提供预览功能。架构采用协议注册模式，支持未来便捷扩展新动效。

## ADDED Requirements

### Requirement: 动效协议定义
系统提供 `WordTransitionEffect` 协议，所有动效必须实现统一接口，包括唯一标识、显示名称、分类、可调参数、以及执行动画的核心方法。

#### Scenario: 协议接口
- **WHEN** 实现一个新的动效
- **THEN** 该动效 SHALL 实现 `WordTransitionEffect` 协议，提供 `id`、`displayName`、`category`、`adjustableParameters`、`animate(from:to:in:parameters:completion:)` 成员

#### Scenario: 显示名称本地化
- **WHEN** 界面语言切换
- **THEN** 动效显示名称与参数名称 SHALL 实时跟随新语言，SHALL NOT 冻结于首次访问时的语言

### Requirement: 动效注册表
系统提供 `TransitionRegistry` 单例，管理所有可用动效的注册与发现。

#### Scenario: 注册动效
- **WHEN** 应用启动
- **THEN** `TransitionRegistry` SHALL 自动注册所有内置动效实现

#### Scenario: 获取所有动效
- **WHEN** 设置界面请求动效列表
- **THEN** `TransitionRegistry` SHALL 返回所有已注册动效的数组

#### Scenario: 根据 ID 获取动效
- **WHEN** 根据用户选择的 ID 请求动效
- **THEN** `TransitionRegistry` SHALL 返回对应的动效实例，未找到时返回 nil

### Requirement: 动效分类
每个动效 SHALL 属于一个分类（`TransitionCategory`），用于设置界面的分组展示。

#### Scenario: 分类枚举
- **WHEN** 定义动效分类
- **THEN** SHALL 支持 `.minimal`（简约）、`.playful`（趣味）、`.immersive`（沉浸）三种分类

### Requirement: 无动效选项
动效选择 SHALL 提供"无"选项，选中后切换单词时不执行任何过渡动画。

#### Scenario: 选择"无"
- **WHEN** 用户选择"无"动效并切换单词
- **THEN** 单词 SHALL 立即切换为新内容，不执行任何过渡动画

#### Scenario: 列表展示
- **WHEN** 设置界面渲染动效下拉列表
- **THEN** "无" SHALL 置顶显示为第一项，且 SHALL NOT 归入任何分类分组

### Requirement: 内置动效：经典淡入
提供"经典淡入"动效，作为默认选项，保持与当前行为一致。

#### Scenario: 动效效果
- **WHEN** 用户选择"经典淡入"并切换单词
- **THEN** 旧内容 SHALL 以 0.15s ease-out 淡出并向下位移 1px，新内容从上方 1px 淡入至正常位置

#### Scenario: 默认选择
- **WHEN** 首次启动应用（无历史配置）
- **THEN** 动效选择 SHALL 默认为"经典淡入"

### Requirement: 内置动效：卡片翻转
提供"卡片翻转"动效，沿 Y 轴 180° 3D 翻转，旧内容翻走，新内容翻入。

#### Scenario: 动效效果
- **WHEN** 用户选择"卡片翻转"并切换单词
- **THEN** 旧内容 SHALL 沿 Y 轴翻转 180° 消失，新内容从 180° 翻转至 0° 出现，带轻微透视变形，总时长 0.35s

#### Scenario: 可调参数
- **WHEN** 用户在设置中调整"卡片翻转"的参数
- **THEN** SHALL 提供"翻转速度"参数，范围 0.2s-0.5s，默认 0.35s

### Requirement: 内置动效：打字机
提供"打字机"动效，旧内容瞬间消失，新内容逐字符出现，模拟打字节奏。

#### Scenario: 动效效果
- **WHEN** 用户选择"打字机"并切换单词
- **THEN** 旧内容 SHALL 立即消失，新内容 SHALL 逐字符出现，每个字符间隔 50-80ms（根据单词长度自适应）

#### Scenario: 可调参数
- **WHEN** 用户在设置中调整"打字机"的参数
- **THEN** SHALL 提供"字符间隔"参数，范围 30ms-100ms，默认 60ms

### Requirement: 内置动效：弹跳入场
提供"弹跳入场"动效，新内容从下方弹入，带弹簧物理效果，有轻微过冲和回弹。

#### Scenario: 动效效果
- **WHEN** 用户选择"弹跳入场"并切换单词
- **THEN** 旧内容 SHALL 淡出，新内容 SHALL 从下方 20px 位置以弹簧动画弹入至正常位置，使用 `CASpringAnimation`，总时长 0.5s

#### Scenario: 可调参数
- **WHEN** 用户在设置中调整"弹跳入场"的参数
- **THEN** SHALL 提供"弹性强度"参数，范围 0.5-2.0（控制过冲幅度），默认 1.0

### Requirement: 内置动效：翻页效果
提供"翻页效果"动效，模拟翻书效果，旧内容向右翻走，新内容从右侧翻入。

#### Scenario: 动效效果
- **WHEN** 用户选择"翻页效果"并切换单词
- **THEN** 旧内容 SHALL 沿右边缘为轴翻转 90° 消失，新内容从 90° 翻转至 0° 出现，带轻微阴影，总时长 0.4s

### Requirement: 内置动效：液体融合
提供"液体融合"动效，旧内容融化收缩至中心，新内容从中心"滴落"展开。

#### Scenario: 动效效果
- **WHEN** 用户选择"液体融合"并切换单词
- **THEN** 旧内容 SHALL 向中心缩放至 0 并淡出，新内容 SHALL 从 scale=0 缩放至 1 并淡入，配合轻微模糊过渡，总时长 0.4s

### Requirement: 内置动效：星体黑洞
提供"星体黑洞"动效，旧内容的字母被"吸入"中心黑洞消失，新内容的字母从黑洞喷发而出。

#### Scenario: 动效效果
- **WHEN** 用户选择"星体黑洞"并切换单词
- **THEN** 旧内容的字母 SHALL 向窗口中心移动并缩小至消失，新内容的字母 SHALL 从中心向外移动并放大至正常位置，带轻微旋转，总时长 0.5s

### Requirement: 内置动效：字母变形
提供"字母变形"动效，旧字母通过形变过渡为新字母，而非消失和出现。

#### Scenario: 动效效果
- **WHEN** 用户选择"字母变形"并切换单词
- **THEN** 旧单词的字母 SHALL 通过 scale 和 opacity 过渡逐渐变为新单词的字母，旧字母缩小淡出同时新字母放大淡入，形成"变形"视觉效果，总时长 0.4s

### Requirement: 动效参数持久化
用户选择的动效 ID 及其参数 SHALL 保存到 UserDefaults，应用重启后恢复。

#### Scenario: 保存动效选择
- **WHEN** 用户在设置中选择动效
- **THEN** 动效 ID SHALL 立即持久化到 UserDefaults

#### Scenario: 保存动效参数
- **WHEN** 用户在设置中调整动效参数
- **THEN** 参数值 SHALL 立即持久化到 UserDefaults

#### Scenario: 恢复配置
- **WHEN** 应用启动
- **THEN** SHALL 从 UserDefaults 恢复上次使用的动效 ID 及其参数

### Requirement: 动效预览功能
设置界面 SHALL 提供预览功能，用户点击动效旁的 [预览] 按钮时，在悬浮窗实际演示该动效。

#### Scenario: 点击预览
- **WHEN** 用户在设置界面点击某动效的 [预览] 按钮
- **THEN** 悬浮窗 SHALL 执行一次该动效的演示，演示 SHALL 优先使用悬浮窗当前正在显示的单词；无当前单词时 SHALL 回退使用内置示例词对，预览期间不影响正常背记流程

#### Scenario: 预览完成
- **WHEN** 动效预览完成
- **THEN** 悬浮窗 SHALL 恢复显示当前背记单词

### Requirement: 动效执行性能
所有动效执行 SHALL 满足性能约束，不阻塞主线程，保持流畅体验。

#### Scenario: 切换延迟
- **WHEN** 触发单词切换
- **THEN** 动效启动延迟 SHALL ≤ 10ms，总切换延迟（含动效） SHALL ≤ 100ms（符合项目性能指标）

#### Scenario: 帧率
- **WHEN** 执行复杂动效（如字母变形、星体黑洞）
- **THEN** 动画帧率 SHALL ≥ 60fps，无明显卡顿

### Requirement: 动效与背记模式兼容
所有动效 SHALL 在记忆反馈模式和走马灯模式下正常工作。

#### Scenario: 记忆反馈模式
- **WHEN** 处于记忆反馈模式并触发单词切换
- **THEN** 动效 SHALL 正常执行，不影响按钮浮现逻辑

#### Scenario: 走马灯模式
- **WHEN** 处于走马灯模式并自动切换单词
- **THEN** 动效 SHALL 正常执行，不打断自动切换节奏
