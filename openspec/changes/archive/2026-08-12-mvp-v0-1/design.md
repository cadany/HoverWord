## Context

HoverWord 是一个全新项目，从零构建 macOS 原生悬浮背词应用。PRD v0.1 定义了完整的功能范围（详见 proposal.md），本设计聚焦如何在 AppKit + SwiftUI 混合技术栈上落地，选择关键架构模式，以及处理已识别的技术风险。

## Goals / Non-Goals

**Goals:**
- 清晰的分层边界：UI 层（View/Controller）与业务层（Service/Engine）解耦，便于测试与演进
- 悬浮窗体验流畅：单词切换 ≤ 100ms，动效平滑，内存 ≤ 100MB
- Liquid Glass 视觉一致：macOS 14+ 完整 liquid，12-13 优雅降级
- 语种无关的数据与业务层设计，v0.1 仅实现英→中但不留硬编码

**Non-Goals:**
- 不做 iCloud 同步、真人发音、记忆算法优化（v0.2+ 规划）
- 不做单元测试覆盖率目标（v0.1 聚焦功能交付，但保持可测试架构）
- 不做应用沙盒签名 / App Store 发布流程

## Decisions

### D1: 悬浮窗使用 NSPanel 而非 NSWindow

**选择**: FloatWindowController 基于 NSPanel 实现，设置 `.nonactivatingPanel` + `NSWindow.Level.floating`。

**理由**: NSPanel 天然支持悬浮层级、不抢夺主应用焦点、支持 mouse events 穿透到内容视图。NSWindow 需要额外配置 level 且可能干扰其他窗口的 key window 状态。

**替代方案**:
- NSWindow + 手动设置 level：可行但需额外处理 focus 行为，边缘 case 多
- SwiftUI Window：macOS 12 下控制力不足，无法实现无边框 + 自定义层级

### D2: ReciteEngine 采用状态机 + 定时器架构

**选择**: ReciteEngine 为独立 Service，内部维护状态机（idle / playing / sectionComplete / allComplete），使用 Timer 驱动单词切换。通过 Combine Publisher 或 delegate protocol 向 FloatWindowController 发布状态变化。

**理由**: 状态机让 Section 流转、模式切换、完成检测的逻辑集中在一个可推理的对象中。Timer 独立于 UI，避免 Controller 承担调度逻辑。

**替代方案**:
- 将调度逻辑放在 FloatWindowController 内：UI 与业务耦合，难以测试
- 使用 Swift Concurrency (async/await + Task)：语法更现代，但 Timer 在此场景已足够直观，且与 AppKit 生命周期配合更直接

### D3: UI 与 Engine 通信使用 delegate protocol + Notification 双通道

**选择**:
- ReciteEngine → FloatWindowController：delegate protocol（单词切换、状态变化等高频事件）
- Settings → Engine / Wordbook / 全局：Notification（设置变更、单词本变更等低频跨模块事件）

**理由**: delegate 保证类型安全与一对一关系，适合 Engine → UI 的紧密联动；Notification 解耦跨模块广播，适合"设置变了，多个组件需要知道"的场景。

**替代方案**:
- 全部使用 Combine Publisher：更现代但引入额外复杂度，v0.1 不需要
- 全部使用 Notification：丢失类型安全，Engine → UI 的高频交互不适合弱类型

### D4: 全局设置使用 UserDefaults + Codable AppSettings 封装

**选择**: AppSettings 为 Codable struct，通过 UserDefaults 存取（JSON 编码单值）。提供 computed properties 访问各配置项，变更时通过 Notification 广播。

**理由**: UserDefaults 是 macOS 原生键值存储，轻量无 IO 瓶颈，设置数据量极小（<1KB）。Codable struct 提供类型安全的读写接口。比 Core Data 或独立 JSON 文件更简单。

**替代方案**:
- Core Data 存储设置：过度工程化，设置是扁平 KV 不需要关系查询
- Application Support 目录 JSON 文件：可行但无必要，UserDefaults 已经是 macOS 的标配

### D5: 设置窗口使用 SwiftUI，悬浮窗使用 AppKit

**选择**: 主设置窗口（4 个 Tab 页）使用 SwiftUI 实现，悬浮窗使用 AppKit（NSPanel + NSVisualEffectView）实现。

**理由**: 设置窗口内容以表单/控件为主，SwiftUI 开发效率高，TabView / Form / ColorPicker / Slider 等组件开箱即用。悬浮窗需要精确控制窗口层级、无边框、玻璃材质、鼠标事件、右键菜单等，AppKit 控制力更强。

**替代方案**:
- 全部 SwiftUI：悬浮窗的窗口行为控制力不足（自定义 NSPanel、鼠标追踪、右键菜单等）
- 全部 AppKit：设置窗口的表单开发效率低，代码量大

**桥接方式**: SwiftUI 设置视图通过 NSHostingController 嵌入 NSWindow；悬浮窗预览在 SwiftUI 中通过 NSViewRepresentable 包装一个轻量 AppKit 视图实现。

### D6: Core Data 实体设计

**选择**:
- Wordbook：name, source_lang, target_lang, is_enabled, is_system, created_at, section_size (导入时的 Section 大小快照)
- WordEntry：wordbook (relationship), section_index, source_word, phonetic, pos_1..3, meaning_1..3
- Favorite：source_word (唯一约束), word_detail (Binary Data, Codable 编码), collected_at
- 关系：Wordbook 1:N WordEntry (cascade delete)

**理由**: 遵循 PRD 数据规范。Favorite 用 JSON 存储词条详情而非 relationship，因为收藏词条需要独立于原单词本存在（原单词本删除时收藏不受影响）。

**替代方案**:
- Favorite 直接关联 WordEntry：会导致原单词本删除时收藏丢失，违反 PRD 要求

### D7: TXT 导入采用后台队列 + 事务性写入

**选择**: 导入解析在后台队列执行，全部校验通过后在主上下文中通过 performBlockAndWait 事务性写入。校验失败整体回滚，不写入任何数据。

**理由**: 10000 条单词导入 ≤ 3s 的性能约束要求不在主线程解析。事务性写入保证"要么全部成功，要么全部失败"，符合 PRD 对格式错误的处理要求。

**替代方案**:
- 主线程同步导入：简单但会卡顿 UI，且 10000 条可能超时
- 逐条写入：校验失败时已有部分数据写入，无法干净回滚

### D8: Liquid Glass 分级适配

**选择**: 创建 GlassBackgroundView（NSVisualEffectView 子类），运行时检测系统版本：
- macOS 14+：material = .liquid
- macOS 12-13：material = .hudWindow + 自定义 1px 内描边（NSBezierPath stroke）

自定义背景色时，在 GlassBackgroundView 上叠加一层带透明度的 NSColor fill layer。透明度滑块控制整体 alpha。

**理由**: 与 UI spec 的分级适配要求一致。封装为统一视图组件，所有需要玻璃背景的地方复用。

## Risks / Trade-offs

### R1: NSPanel 的 focus 行为需要仔细调校
**风险**: NSPanel 默认不接收键盘焦点，可能影响按钮点击事件。
**缓解**: 使用 `.nonactivatingPanel` 样式使面板不抢夺 key window，同时确保 contentView 的 acceptsFirstMouse 返回 true，按钮使用 NSButton 标准实现。开发早期搭建原型验证。

### R2: 多显示器位置记忆的边缘情况
**风险**: 外接显示器断开后恢复位置可能导致窗口不可见。
**缓解**: 恢复位置前检查 NSScreen.screens 是否包含目标屏幕，不包含时 fallback 到主屏幕中心位置。

### R3: 10000 条单词导入的性能
**风险**: 解析 + Core Data 写入可能在低端 Intel 设备上超过 3s。
**缓解**: 后台队列解析 + 批量 insert（NSBatchInsertRequest），避免逐条 fault。开发时以 10000 条数据做性能基准测试。

### R4: SwiftUI 与 AppKit 的桥接复杂度
**风险**: 悬浮窗预览在 SwiftUI 中需要 NSViewRepresentable 包装，双向数据同步可能引入状态不一致。
**缓解**: 预览视图仅消费 AppSettings 的只读快照，通过 @Observable 或 Combine 驱动更新，单向数据流避免回写。

### R5: AVSpeechSynthesizer 的英美音可用性
**风险**: 某些 macOS 版本可能未安装对应英语语音。
**缓解**: 初始化时检查可用语音列表，若目标口音语音不存在则 fallback 到系统默认英语语音，不阻断使用。
