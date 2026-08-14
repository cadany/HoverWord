## 1. 常量与引擎状态

- [x] 1.1 在 Constants.swift 中新增悬浮窗最小/最大尺寸常量：floatWindowMinWidth (200)、floatWindowMaxWidth (600)、floatWindowMinHeight (120)、floatWindowMaxHeight (500)
- [x] 1.2 在 ReciteEngine 中暴露 `isAllComplete: Bool` 只读属性，返回当前是否处于全部完成状态

## 2. 已学完状态右键菜单扩展

- [x] 2.1 修改 FloatWindowController.rightMouseDown：当 `engine.isAllComplete` 为 true 时，在菜单顶部插入"重新开始"菜单项（action 连接 engine.restart），然后依次为"打开设置"、分隔线、"退出程序"

## 3. 窗口边框拖拽缩放

- [x] 3.1 修改 FloatWindowController.init：NSPanel styleMask 添加 `.resizable`
- [x] 3.2 设置 panel.contentMinSize 和 panel.contentMaxSize，使用 Constants 中定义的边界值
- [x] 3.3 验证 GlassBackgroundView 在缩放过程中圆角与玻璃材质正确自适应（预期 layout() 已处理，无需修改）
- [x] 3.4 验证 FloatContentView 在不同窗口宽度下内容正确排布（释义自动换行、padding 保持）

## 4. 窗口尺寸记忆与恢复

- [x] 4.1 在 FloatWindowController 中监听 windowDidEndLiveResize 通知，拖拽缩放结束时调用 saveWindowPosition 保存完整 frame（含尺寸）
- [x] 4.2 验证重启后悬浮窗恢复到上次的大小与位置

## 5. 验证与回归

- [x] 5.1 构建运行，手动验证 spec 中全部 10 个 scenario 通过
- [x] 5.2 运行 XCTest 确保现有 29 个测试无回归
