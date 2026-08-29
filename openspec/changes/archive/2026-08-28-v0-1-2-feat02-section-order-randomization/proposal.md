---
baseline_version: "v0-1-2"
change_sub_version: "v0-1-2-feat02"
---

## Why

当前背记引擎的 Section 队列按「词本顺序 × Section 索引升序」固定构建，重新开始或开始新单词本时永远从第一个 Section 的第一个单词开始（`currentSectionQueueIndex = 0`）。在典型词书（如 CET 词汇表）上导致"只要刚开始一定先背 abandon"：序数靠前的 Section 被过度重复曝光，靠后的 Section 在碎片化使用模式下几乎不可达。

现有「展示顺序（playOrder）」仅作用于 Section **内部**（PlayOrder 枚举注释明确"Section 之间的先后顺序固定不变"），Section 间顺序完全无随机化手段。

## What Changes

### 1. Section 间顺序策略（SectionOrder 枚举）

新增 `SectionOrder`（顺序从第一个 Section / 随机起点 / 随机打乱），作用于 Section 队列层面：

- **从第一个 Section 开始（`sequential`，默认）**：行为同现状，按词书顺序推进
- **随机起点（`randomStart`）**：新开始时随机选起点 Section，之后按顺序**环形**推进（背到末尾后绕回第一个 Section）——保留词书相邻段落局部性（词频排序词书难度连续）
- **随机打乱（`shuffled`）**：新开始时打乱全部 Section 顺序——曝光分布最均匀，打散词书结构

**触发时机**（"新开始"定义）：无有效进度冷启动、`restart()`、进度校验失败回退。**不改变**背记中（`restoreProgress` 成功）的既有队列——恢复进度时队列按确定性规则重建（见 design），保证恢复正确性。

### 2. 进度持久化身份寻址

进度存储从「队列索引」改为「身份寻址」（`wordbookId + sectionIndex`），恢复时在重建后的队列中查找位置。修复既有隐患：词本启停/顺序调整导致队列索引漂移后，现行为恢复到错误的 Section。

### 3. 进度续背（一轮完成后）

全部完成时不再 `clearProgress`，改为记录「上次离开的 Section 身份 + 完成标记」；下次新会话从**离开位置的下一 Section** 继续（环形语义，末尾绕回第一个 Section），形成跨会话的持续循环。「重新开始」按钮仍清除全部进度从策略起点重新来过。

### 4. 设置界面

背记设置页「Section 设置」与原「展示顺序」之间新增「Section 顺序（Section 间）」卡片（radioGroup 三选一，默认"从第一个 Section 开始"）；原「展示顺序」更名「Section 内展示顺序」消除歧义。进度续背为引擎行为，无 UI。

## Capabilities

### New Capabilities

无（扩展现有能力）。

### Modified Capabilities

- `recite-engine` — Section 队列构建（策略化）、进度持久化（身份寻址 + 续背）、全队列完成检测（完成不清零改续背标记）
- `settings-window` — 背记设置页新增「Section 顺序」设置项、原「展示顺序」更名

## Impact

**受影响文件：**
- `Models/Enums/SectionOrder.swift` — 新增枚举
- `Models/AppSettings.swift` — `sectionOrder` 配置项（Codable + 迁移）
- `Services/ReciteEngine.swift` — 队列构建策略、进度保存/恢复身份寻址、续背逻辑
- `Features/Settings/ReciteSettingsView.swift` — 新卡片 + 更名
- `Resources/Localizable.xcstrings` — 新词条（zh/en）
- `HoverWordTests/` — 引擎策略/进度寻址/续背测试

**兼容性：**
- 默认值 `sequential` 保持既有行为，用户无感知升级
- 旧进度数据（索引寻址）迁移：升级后首次启动旧进度视为失效，从策略起点开始（一次性代价，与既有「旧版本进度数据一次性失效」场景一致）
- `playOrder`（Section 内）语义不变，仅设置页文案更名

**多语种约束：** 枚举与策略不涉及任何语种判断，词书无关设计保持。
