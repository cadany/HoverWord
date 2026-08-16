## Context

当前版本存在两个体验问题：
1. 悬浮窗位置恢复不完整 — 只监听 `didEndLiveResizeNotification`，不监听窗口移动事件
2. 背记进度不跨启动 — ReciteEngine 状态完全在内存中，重启后从头开始

此外需要新增单词本预览功能，让用户能在设置窗口查看和编辑词条。

## Goals / Non-Goals

**Goals:**
- 悬浮窗位置在移动和缩放后均能正确保存和恢复
- 背记进度（Section 索引 / 单词索引 / 已反馈集合）跨启动持久化
- 进度无效时安全回退到从头开始
- 单词本预览支持内联编辑和删除，每页 100 条分页

**Non-Goals:**
- 不改变 Core Data schema（进度存 UserDefaults）
- 不实现单词本预览的批量操作（全选 / 批量删除）
- 不实现进度同步到 iCloud（仅本地持久化）

## Decisions

### D1: 悬浮窗位置保存 — 新增 didMoveNotification 监听

**决定**：在 `FloatWindowController.init()` 中新增 `NSWindow.didMoveNotification` 观察者，窗口拖拽移动结束后调用 `saveWindowPosition()`。

**理由**：与现有的 `didEndLiveResizeNotification` 对称，覆盖位置变化的两种场景（移动 + 缩放）。`didMoveNotification` 在拖拽结束后触发，避免高频保存。

### D2: 进度持久化存储格式

**决定**：UserDefaults 使用三个 key 分别存储：
- `ReciteProgressSectionIndex: Int`
- `ReciteProgressWordIndex: Int`
- `ReciteProgressFeedbackSet: [String]`（单词 ID 数组）

**理由**：扁平 key-value 结构，读取简单，无需额外编解码。单词 ID 集合用字符串数组而非 Set，因为 UserDefaults 不直接支持 Set 类型。

### D3: 进度保存时机

**决定**：在以下时机保存进度：
1. 引擎切换到下一个单词时（`advanceToNextWord()`）
2. Section 完成时（`completeCurrentSection()`）
3. App 退出时（`applicationWillTerminate`）

**理由**：单词切换是最细粒度的进度节点，确保崩溃时也只丢失当前单词的进度。Section 完成时额外保存一次，减少高频写入。

### D4: 进度恢复与校验

**决定**：ReciteEngine `start()` 时检查历史进度：
1. 读取 UserDefaults 中的 Section 索引和单词索引
2. 校验 Section 索引 < 当前队列长度
3. 校验单词索引 < 当前 Section 的单词数
4. 校验 feedbackSet 中的单词 ID 在当前单词本中存在

任意一项校验失败则清除进度，从头开始。

**理由**：用户可能修改了单词本或 Section 大小，旧进度可能越界。防御性校验确保不会崩溃或显示异常。

### D5: 单词本预览 — Sheet + 分页表格

**决定**：
- 在 `WordbookTabView` 操作栏新增"预览"按钮（选中单词本后可用）
- 点击后弹出 `.sheet`，内部使用自定义分页表格（每页 100 条）
- 每条显示：单词（TextField）、音标（TextField）、词性 + 释义（只读文本）
- 每行右侧一个删除按钮（trash 图标）
- 底部显示分页控件（上一页 / 页码 / 下一页）

**理由**：Sheet 模式与现有的"新建"、"重命名" sheet 保持一致。内联编辑减少交互步骤，删除按钮直观。分页避免大词库一次性加载的性能问题。

### D6: 单词本预览的数据加载

**决定**：
- 预览 Sheet 通过 `WordbookService` 按分页参数 fetch 词条
- 编辑后直接调用 Core Data save，不额外通知引擎
- 删除词条后刷新当前页，若当前页为空且非第一页则退回上一页

**理由**：Core Data 直接持久化，编辑即时生效。预览是只读场景的补充，不影响正在进行的背记（引擎在启动时已加载词条到内存）。

## Risks / Trade-offs

| 风险 | 缓解 |
|---|---|
| 进度高频写入 UserDefaults 影响性能 | UserDefaults 写入是轻量操作；Section 完成时才额外保存，减少写入频率 |
| 反馈集合过大时 UserDefaults 体积增长 | 极端情况（10000 词全部已反馈）约 200KB，UserDefaults 可承受 |
| 单词本预览编辑与正在背记的引擎数据不一致 | 引擎在 `start()` 时加载词条到内存，预览编辑 Core Data 不影响当前轮次；下一轮次或重启后生效 |
| 分页编辑后页码状态丢失 |  Sheet 关闭时不保存页码，下次打开回到第一页（符合预期） |
