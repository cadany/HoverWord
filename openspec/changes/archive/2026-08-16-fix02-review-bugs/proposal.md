## Why

代码 review 发现 4 个功能缺陷与 1 处遗留调试代码：进度恢复在随机播放与记忆反馈后续轮次下指向错误单词；空文件导入会静默清空目标单词本全部词条（数据丢失）；收藏增删后背记队列不重建（收藏夹启用时轮换内容过期）；"已学完"状态的"重新开始"按钮从未加入视图层级导致完全不可见，且显隐逻辑不随鼠标移出复位；悬浮窗每次加入窗口时输出 6 行调试 NSLog。

## What Changes

- 修复进度恢复错位：`saveProgress` 增加持久化当前轮次播放顺序（wordId 列表），`restoreProgress` 按 wordId 映射还原顺序后再套用单词索引，任何校验失败安全回退从头开始
- 修复收藏夹启用时进度恢复必然失效：`favoriteToWordEntry` 改用持久化的 `favoriteId` 作为 wordId（原实现每次转换生成临时 UUID，重启后标识全部变化，进度被整体重置）
- 修复空文件导入数据丢失：`parse` 在无任何有效词条（空文件或仅空白行）时抛出 `emptyFile`，导入中断、原词条保留。**行为变更**：原 spec 规定空文件清空原词条，本次改为拒绝导入
- 修复收藏变更队列过期：新增 `.favoritesDidChange` 通知，收藏切换与导入后收藏夹同步完成时发送（主线程）；引擎仅在收藏夹单词本启用且播放中时响应：保存进度 → 重建队列 → 尽量恢复原位置
- 移除完成状态"重新开始"按钮（用户裁决：右键菜单已提供同功能入口，窗口内按钮冗余），完成态不显示任何操作按钮
- 移除 `FloatContentView` 的 `debugPrintIntrinsicSizes` 调试日志及 `viewDidMoveToWindow` 触发点

## Capabilities

### New Capabilities

（无新增能力）

### Modified Capabilities

- `recite-engine`: 进度持久化包含播放顺序并精确恢复（含收藏夹词条场景）；新增引擎对收藏内容变更的响应行为
- `wordbook`: 空文件导入由"清空原词条"改为"中断导入并提示"；收藏词条转换使用稳定 favoriteId 标识；收藏夹同步完成后通知引擎
- `floating-window`: 完成状态不显示任何操作按钮，重开入口仅保留右键菜单

## Impact

- **代码**：修改 `ReciteEngine.swift`、`WordbookImportService.swift`、`WordbookService.swift`、`NotificationNames.swift`、`FloatContentView.swift`，共 5 个源文件 + 2 个测试文件
- **API**：新增 `Notification.Name.favoritesDidChange`
- **依赖**：无新增
- **行为变更**：① 空文件导入从"清空词库"变为"报错保留原数据"；② 升级后首次启动，旧版本已保存的背记进度因缺少顺序数据一次性失效、从头开始；③ 完成状态不再显示"重新开始"按钮，重开入口仅保留右键菜单
- **性能**：进度保存增加一个 wordId 数组写入，量级为单 Section 单词数（≤500），可忽略
- **测试**：更新空文件导入 2 条测试为预期抛错；新增进度恢复回归测试 3 条（记忆反馈后续轮次、随机播放、收藏夹启用场景）
