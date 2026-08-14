## Context

悬浮窗当前实现为 `NSPanel` 子类，styleMask 为 `[.nonactivatingPanel, .fullSizeContentView, .borderless]`，宽度固定 300px（`Constants.floatWindowWidth`），不可缩放。右键菜单固定包含"打开设置"和"退出程序"两项，由 `FloatWindowController.rightMouseDown` 构建。

位置记忆已实现：`saveWindowPosition()` 将完整 `NSRect` 序列化存入 UserDefaults，重启后恢复。尺寸的持久化几乎零成本——只需在保存位置时同时包含尺寸信息（已经是整个 frame）。

玻璃背景 `GlassBackgroundView` 通过 Auto Layout 四边约束 pin 到父视图，`layout()` 中已动态更新圆角 path，天然支持尺寸变化。

## Goals / Non-Goals

**Goals:**
- "已学完"状态下右键菜单动态包含"重新开始"菜单项
- 悬浮窗支持拖拽边框/角落自由缩放，保持玻璃材质与圆角完整
- 窗口尺寸随位置一起持久化记忆与恢复

**Non-Goals:**
- 不改变内容视图的自适应逻辑（释义仍最多 3 组截断，超出宽度自动换行）
- 不改变窗口拖拽移动行为（`isMovableByWindowBackground` 保持不变）
- 不在设置窗口中增加悬浮窗尺寸设置项

## Decisions

### Decision 1: styleMask 添加 `.resizable` 实现缩放

在 `FloatWindowController.init` 中为 NSPanel 的 styleMask 添加 `.resizable`，通过 `contentMinSize` 和 `contentMaxSize` 限制缩放边界。

**替代方案**：手动实现 `mouseDown`/`mouseDragged` 边缘检测与 resize 逻辑。
**选择理由**：NSPanel 的 `.resizable` + borderless 组合由系统提供边缘 resize 热区，无需自写边缘检测。`isMovableByWindowBackground` 与 resize handles 在系统层互不冲突——边缘 resize 优先，其余区域拖拽移动。

**缩放边界**：
- 最小：200 × 120（紧凑模式下仍可阅读单词 + 1 组释义）
- 最大：600 × 500（不超过典型屏幕面积的 1/3）
- 默认：300 × 自适应（与当前行为一致）

### Decision 2: 右键菜单根据引擎状态动态构建

在 `FloatWindowController.rightMouseDown` 中检查 `engine.isAllComplete`，当处于完成状态时，在菜单顶部插入"重新开始"项。

**替代方案**：始终显示"重新开始"项（非完成状态时 disabled）。
**选择理由**：动态增删菜单项更简洁，避免用户看到不可用的灰色选项。

### Decision 3: 尺寸记忆复用现有 frame 持久化

`saveWindowPosition()` 已序列化完整 `NSRect`（包含 origin + size），无需新增存储字段。新增 `windowDidEndLiveResize` 通知触发保存。

### Decision 4: ReciteEngine 暴露状态属性

在 ReciteEngine 中新增 `isAllComplete: Bool` 只读属性，返回当前是否处于 allComplete 状态，供 FloatWindowController 查询构建右键菜单。

### Decision 5: 内容视图布局适配

`FloatContentView` 已使用 Auto Layout，内容容器通过 `greaterThanOrEqualTo` / `lessThanOrEqualTo` 保持 padding，释义行使用 `lineBreakMode = .byWordWrapping`。窗口宽度变化时内容自动换行，无需修改布局。

玻璃背景 `GlassBackgroundView` 四边约束 + `layout()` 动态更新圆角，缩放时自动跟随。

## Risks / Trade-offs

- **[borderless + resizable 边缘热区过小]** → 16px 圆角可能使角落 resize 热区难以命中。缓解：系统对 borderless resizable 窗口有默认 edge detection 区域，实测后如体验不佳可增加不可见 resize handle view。
- **[大窗口遮挡内容]** → 用户可能将窗口拉得过大导致单词显示空旷。缓解：最大尺寸限制 600×500，单词字号不随窗口缩放。
- **[拖拽移动与 resize 手势冲突]** → `isMovableByWindowBackground` 在边缘区域可能与 resize 热区竞争。缓解：系统层 resize 优先级高于 background drag，预期不冲突。
