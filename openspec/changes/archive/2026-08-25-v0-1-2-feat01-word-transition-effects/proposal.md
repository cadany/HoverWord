---
baseline_version: "v0-1-2"
change_sub_version: "v0-1-2-feat01"
---

## Why

当前的单词切换动效（淡入淡出 + 1px 垂直位移）过于保守，缺乏设计感和记忆点。作为一款强调"碎片化高频视觉曝光"的背单词应用，单词切换是用户最频繁经历的交互瞬间。一个有趣、有创意的动效不仅能提升产品质感，还能让每次切换都成为微小的愉悦体验，增强用户粘性和使用意愿。

此外，动效需求因人而异，单一动效无法满足所有用户。需要构建一个可扩展的动效系统，让用户可以选择自己喜欢的风格，同时为未来持续加入新动效预留架构空间。

## What Changes

### 新增功能
1. **可扩展的动效架构**：基于协议注册的动效系统，每个动效独立实现统一接口，支持未来便捷扩展
2. **8 个内置创意动效**：
   - 经典淡入（当前方案，保底选择）
   - 卡片翻转（Y 轴 3D 翻转）
   - 打字机（逐字符出现）
   - 弹跳入场（弹簧物理效果）
   - 翻页效果（模拟翻书）
   - 液体融合（融化 + 浮出）
   - 星体黑洞（字母被吸入/喷出）
   - 字母变形（旧字母变形为新字母）
3. **部分参数可调**：部分动效提供 1-2 个关键参数的用户自定义（如打字机的字符间隔、弹跳的弹性强度）
4. **预览功能**：设置界面内点击 [预览] 按钮，在悬浮窗实际演示动效
5. **新建"体验"设置 Tab**：独立 Tab 承载动效设置，为未来其他体验类设置预留空间

### 技术变更
- 新增 `WordTransitionEffect` 协议，定义动效统一接口
- 新增 `TransitionRegistry` 注册表，管理所有可用动效
- 新增 `Effects/` 目录，每个动效独立文件
- `FloatContentView` 重构 `showWord` 方法，调用动效系统而非硬编码动画
- 新增 `ExperienceSettingsView.swift`（体验设置 Tab）
- `AppSettings` 扩展动效选择与参数存储

## Capabilities

### New Capabilities
- `word-transition-effects`：单词切换动效系统（动效协议、注册表、8 个内置动效、参数配置、预览、设置界面）

### Modified Capabilities
- `floating-window`：`showWord` 方法改为调用动效系统
- `settings-window`：新增"体验" Tab 入口

## Impact

### 文件变更
- **新增**：
  - `Services/Transitions/WordTransitionEffect.swift`（协议定义）
  - `Services/Transitions/TransitionRegistry.swift`（注册表）
  - `Services/Transitions/Effects/*.swift`（8 个动效实现文件）
  - `Features/Settings/ExperienceSettingsView.swift`（体验设置视图）
- **修改**：
  - `Features/FloatingWindow/FloatContentView.swift`（showWord 方法重构）
  - `Models/AppSettings.swift`（新增动效配置字段）
  - `Features/Settings/SettingsWindowController.swift`（新增体验 Tab）
  - `Shared/Constants.swift`（新增动效相关常量）

### 性能影响
- 动效切换延迟 ≤ 100ms（与当前单词切换性能约束一致）
- 复杂动效（如字母变形）需控制帧率 ≥ 60fps
- 内存占用增量 < 5MB（动效资源缓存）

### 向后兼容
- 默认使用"经典淡入"，保持与当前行为一致
- 旧版本升级自动应用默认动效，无需迁移
