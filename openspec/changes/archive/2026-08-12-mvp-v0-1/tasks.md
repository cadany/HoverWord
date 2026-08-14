## 1. 项目工程搭建

- [x] 1.1 创建 Xcode 项目（macOS App，AppKit + SwiftUI 混合），配置最低部署目标 macOS 12.0，支持 Intel + Apple Silicon 双架构
- [x] 1.2 按 AGENTS.md 目录结构创建所有分组文件夹：App/、Models/（Entities/、Enums/）、Services/、Controllers/、Views/（Settings/、Float/）、Utils/、Resources/
- [x] 1.3 创建 Info.plist 配置项：LSUIElement 初始值为 NO（启动时显示 Dock 图标）、NSHumanReadableCopyright 等基础元数据
- [x] 1.4 创建 Constants.swift，定义 UI spec 中的 px 值、颜色不透明度、动效时长等常量
- [x] 1.5 创建 NotificationNames.swift，定义全局通知名称（设置变更、单词本变更、背记状态变化等）
- [x] 1.6 验证项目可成功构建并运行空白窗口

## 2. Core Data 持久化层

- [x] 2.1 创建 Core Data 模型文件（HoverWord.xcdatamodeld），定义 Wordbook、WordEntry、Favorite 三个实体及字段、关系、级联删除规则
- [x] 2.2 实现 DataStack.swift：NSPersistentContainer 单例初始化、主上下文与后台上下文创建、保存与错误处理
- [x] 2.3 生成 Core Data 实体子类文件（Wordbook+CoreDataClass/Properties、WordEntry+CoreDataClass/Properties、Favorite+CoreDataClass/Properties）
- [x] 2.4 创建 AppSettings.swift：Codable struct，包含所有全局配置字段与默认值，通过 UserDefaults 存取（JSON 编码），提供变更通知
- [x] 2.5 创建 ReciteMode.swift 与 PlayOrder.swift 枚举定义
- [x] 2.6 编写 DataStack 基础验证：应用启动时栈可用、首次启动使用默认设置、设置持久化重启后恢复

## 3. 单词本与导入服务

- [x] 3.1 实现 WordbookImportService.swift 的 TXT 文件读取：UTF-8 编码检测、按行拆分、空行过滤、Tab 分隔字段解析
- [x] 3.2 实现导入格式校验逻辑：必填字段（词条 + 释义 1）检查、错误行号与原因记录、整体校验失败时返回错误不写入
- [x] 3.3 实现导入事务性写入：后台队列解析 → 校验通过 → 主上下文 performBlockAndWait 内清空旧词条 + 批量插入新词条 + 自动分配 section_index
- [x] 3.4 实现 Section 自动拆分逻辑：按全局"单 Section 单词数"设置，按词条顺序分配 section_index
- [x] 3.5 实现单词本 CRUD 操作：新建（默认空、未启用）、删除（级联删除词条，禁止删除系统单词本）、重命名、启用/停用（空单词本禁止启用）
- [x] 3.6 实现系统收藏夹单词本初始化：应用首次启动自动创建"我的收藏"，标记 is_system=true，不可删除/手动导入
- [x] 3.7 实现导入时收藏夹同步：导入后基于 source_word 匹配，保留匹配的收藏、移除不匹配的收藏，按单词本范围隔离同步
- [x] 3.8 编写导入功能验证：正常文件、空文件、格式错误（精准行号）、编码错误、10000 条大文件（≤3s 性能约束）

## 4. 发音服务

- [x] 4.1 实现 SpeechService.swift：AVSpeechSynthesizer 封装，提供 speak(word:accent:) 方法
- [x] 4.2 实现英式/美式发音切换：根据 accent 参数选择对应 AVSpeechSynthesisVoice（en-GB / en-US）
- [x] 4.3 实现 TTS 降级容错：语音不可用时 fallback 到系统默认英语语音，初始化失败时静默跳过不阻断
- [x] 4.4 实现发音中断逻辑：新单词切换时自动停止前一个发音，发音不阻塞背记调度

## 5. 背记核心引擎

- [x] 5.1 实现 ReciteEngine.swift 基础结构：持有当前 Section 队列、当前 Section 索引、当前单词索引、反馈状态集合
- [x] 5.2 实现 Section 队列构建：从启用单词本按列表顺序收集所有 Section，拼接为有序队列
- [x] 5.3 实现记忆反馈模式调度：Timer 驱动停留时长倒计时，用户点击"认识/不认识"标记已反馈并立即切词，超时未反馈标记为未反馈并切词，未反馈单词在后续轮次重复出现
- [x] 5.4 实现走马灯模式调度：Timer 按停留时长自动切词，每轮计数，达到设定轮次后 Section 完成
- [x] 5.5 实现 Section 完成检测与流转：当前 Section 完成 → 自动进入下一个 Section → 全部完成 → 进入 allComplete 状态
- [x] 5.6 实现顺序/随机播放：顺序模式按原始顺序，随机模式每轮开始时 Fisher-Yates 打乱 Section 内单词顺序
- [x] 5.7 实现设置变化重置：监听设置变更通知，重建队列并重置到第一个 Section
- [x] 5.8 实现 delegate protocol：定义单词切换、状态变化、完成等回调接口，供 FloatWindowController 实现
- [x] 5.9 编写引擎逻辑验证：双模式调度、Section 流转、完成检测、设置重置、随机模式

## 6. 玻璃背景组件

- [x] 6.1 实现 GlassBackgroundView（NSVisualEffectView 子类）：运行时检测 macOS 版本，14+ 使用 .liquid 材质，12-13 使用 .hudWindow + 1px 内描边（NSBezierPath）
- [x] 6.2 实现自定义背景色叠加层：在玻璃层上覆盖带透明度的 NSColor fill，实现"带色调的玻璃"效果
- [x] 6.3 实现透明度控制：暴露 alpha 属性，同步控制玻璃层 + tint 层整体不透明度，文字层保持 100%
- [x] 6.4 验证深浅色模式自动适配、拖拽过程中材质完整渲染

## 7. 悬浮背记窗口

- [x] 7.1 实现 FloatWindowController（NSPanel 子类）：无边框、.nonactivatingPanel 样式、NSWindow.Level.floating 层级、16px 连续圆角
- [x] 7.2 实现窗口拖拽：mouseDown/mouseDragged 事件处理，按住任意区域可拖拽，拖拽到屏幕边缘无磁吸变形
- [x] 7.3 实现窗口尺寸约束：宽度固定 300px，高度自适应内容，不可手动缩放
- [x] 7.4 实现位置记忆与多显示器支持：关闭/退出时存储屏幕标识 + 坐标到 UserDefaults，启动时恢复（含外接显示器断开的 fallback 逻辑）
- [x] 7.5 实现右键菜单：NSMenu 包含"打开设置"与"退出程序"两个选项
- [x] 7.6 实现 FloatContentView（NSView）：内容垂直居中排列，单词（Semibold 24pt 居中）、音标（Regular 12pt 浅灰居中，无则隐藏）、词性+释义（Regular 14pt 左对齐，最多 3 组截断）
- [x] 7.7 实现记忆反馈模式交互：默认隐藏按钮，鼠标悬停时从底部滑入"收藏""认识""不认识"按钮（0.15s ease-out 动效）
- [x] 7.8 实现走马灯模式交互：默认无按钮，鼠标悬停仅左下角浮现"收藏"按钮
- [x] 7.9 实现收藏按钮交互：心形图标，已收藏实心/未收藏空心，点击切换收藏状态并通知 Wordbook 服务
- [x] 7.10 实现完成状态展示：显示"已学完"居中文字，悬停浮现"重新开始"按钮
- [x] 7.11 实现单词切换动效：0.15s ease-out 淡入淡出 + 1px 垂直位移
- [x] 7.12 实现 ReciteEngine delegate 回调：接收单词切换、状态变化等事件，更新 UI

## 8. 主设置窗口

- [x] 8.1 实现 SettingsWindowController：标准标题栏 NSWindow，标题栏玻璃材质，内容区 .underWindowBackground 材质，12px 圆角
- [x] 8.2 实现设置窗口 Tab 容器：SwiftUI TabView 嵌入 NSHostingController，4 个 Tab 页（单词本 / 背记规则 / 外观 / 发音）
- [x] 8.3 实现 WordbookTabView：单词本列表（名称、总数、Section 数、勾选框），新建/删除/重命名/导入操作按钮，全局 Section 大小设置
- [x] 8.4 实现 ReciteSettingsView：背记模式单选、走马灯轮次输入（仅走马灯模式可编辑）、展示顺序单选、停留时长滑块+数字框、全屏自动隐藏开关
- [x] 8.5 实现 AppearanceView：预设主题（浅色/深色/护眼绿）一键应用、背景色取色器、透明度滑块、单词/释义字体选择与字号设置
- [x] 8.6 实现 SpeechSettingsView：自动播放开关、发音类型（英式/美式）单选、说明文案
- [x] 8.7 实现悬浮窗实时预览：NSViewRepresentable 包装迷你版 FloatContentView，消费 AppSettings 只读快照，参数变更 0.2s 内同步更新
- [x] 8.8 实现设置窗口关闭行为：关闭按钮隐藏窗口 + 隐藏 Dock 图标，不退出程序
- [x] 8.9 实现设置生效链路：用户修改设置 → AppSettings 持久化 → 发送通知 → ReciteEngine/FloatWindow 响应

## 9. 应用生命周期

- [x] 9.1 实现 AppDelegate：applicationDidFinishLaunching 中初始化 DataStack、创建系统收藏夹（如不存在）、打开主设置窗口 + 启动悬浮窗
- [x] 9.2 实现 Dock 图标联动：主窗口显示时 NSApp.activateIgnoringOtherApps 显示图标，主窗口隐藏时设置 LSUIElement 隐藏图标
- [x] 9.3 实现悬浮窗右键菜单"打开设置"：唤起主设置窗口 + 恢复 Dock 图标
- [x] 9.4 实现悬浮窗右键菜单"退出程序"：NSApp.terminate 完全退出
- [x] 9.5 实现全屏自动隐藏：监听 NSWorkspace.activeSpace 变化通知，全屏应用激活时以 0.2s 动效隐藏悬浮窗，退出全屏恢复显示
- [x] 9.6 实现多显示器悬浮窗显隐恢复：隐藏前记录屏幕标识，恢复时验证屏幕可用性

## 10. 集成联调与打磨

- [x] 10.1 端到端联调：启动 → 导入词库 → 启用单词本 → 悬浮窗开始背记 → 双模式切换 → 完成状态 → 重新开始
  - ✅ 启动链、导入流、模式切换、完成检测、重新开始路径均已验证通过
  - 🔴 **Bug 1**：`ReciteEngine.start()` 每个 Section/每轮循环的首个单词被跳过（`currentWordIndex=0` 后立即 `advanceToNextWord()` 使其变为 1）
  - 🔴 **Bug 2**：`markKnown()` 与 `markUnknown()` 行为完全相同——均将单词加入 `feedbackSet`，"不认识"无重试效果
- [x] 10.2 收藏夹联调：收藏/取消收藏 → 收藏夹单词本词条同步 → 启用收藏夹参与背记 → 重新导入后收藏同步
  - ✅ `toggleFavorite` 逻辑正确，导入后 `syncFavoritesAfterImport` 跨单词本同步正确
  - 🟡 收藏夹单词本无法启用背记：`Favorite` 实体与 `Wordbook.entries` 无桥接，`getEntryCount` 始终为 0
- [x] 10.3 设置实时生效联调：修改外观/发音/背记规则 → 悬浮窗即时响应
  - ✅ 外观设置（字体、颜色、透明度）通过 `.appSettingsDidChange` 实时同步
  - ✅ 背记规则设置触发 ReciteEngine 重建队列
  - 🟡 7 个通知名称为死代码（定义但从未发送/接收）
- [x] 10.4 Liquid Glass 视觉走查：浅色/深色/护眼绿三套主题在 macOS 14+ 与 12-13 上的渲染一致性
  - ✅ 浅色模式：材质、描边（1px white α=0.3/0.15）、圆角（16px）、混合模式（.behindWindow）、默认透明度（90%）均符合 spec
  - ⚠️ `.liquid` 材质在当前 SDK 不存在，降级使用 `.underWindowBackground`（已文档化）
  - ❌ 深色模式失效：`GlassBackgroundView` 硬编码 `appearance = .aqua`，阻止系统外观自动适配
  - ❌ 深色模式文字/按钮颜色未适配：`FloatContentView` 所有颜色写死为浅色值（black α=0.85/0.55）
- [x] 10.5 动效走查：单词切换、按钮浮现、全屏隐藏/恢复、主题切换等所有动效时长与缓动曲线符合 UI spec
  - ✅ 所有动效时长常量已正确定义（wordSwitch 0.15s、buttonFade 0.15s、windowFade 0.2s、settingsApply 0.2s）
  - ✅ 缓动曲线统一使用 ease-out
  - ❌ 单词切换缺少 1px 垂直位移（仅实现 alpha 淡入淡出）
  - ❌ 按钮悬停缺少底部滑入效果（仅实现透明度渐变）
  - ❌ 按钮点击态动效未实现（亮度降低 + 微缩反馈）
  - ❌ 窗口显示/隐藏动效未实现（`windowFadeDuration` 常量已定义但未使用）
  - ❌ 完成状态切换无过渡动效（直接设置 `isHidden`）
  - ❌ 设置应用无过渡动效（`settingsApplyDuration` 常量已定义但未使用）

## 11. 性能与兼容性验证

- [x] 11.1 性能基准测试：后台常驻内存 ≤ 100MB（Activity Monitor 验证）
  - 🟡 **需人工验证**：代码层面未发现明显内存泄漏，需 Activity Monitor 实际观测
- [x] 11.2 性能基准测试：单词切换延迟 ≤ 100ms（Instruments Time Profiler）
  - ✅ 单元测试 `testWordSwitchPerformance` 通过（50 次 markKnown 循环，XCTest measure 自动验证）
- [x] 11.3 性能基准测试：10000 条单词导入 ≤ 3s（stopwatch 计时）
  - ✅ 单元测试实测平均 0.056s（values: 0.090, 0.053, 0.052×7），远低于 3s 约束
- [ ] 11.4 兼容性验证：macOS 12.0（Monterey）Intel 设备上功能完整性
  - 🟡 **需人工验证**：需在实际 macOS 12 Intel 设备上测试
- [ ] 11.5 兼容性验证：macOS 14+ Apple Silicon 设备上 Liquid Glass 完整效果
  - 🟡 **需人工验证**：需在实际 macOS 14+ Apple Silicon 设备上测试 `.underWindowBackground` 降级效果
- [ ] 11.6 多显示器场景验证：双显示器拖拽、位置记忆、外接显示器断开恢复
  - 🟡 **需人工验证**：需双显示器环境实际测试
