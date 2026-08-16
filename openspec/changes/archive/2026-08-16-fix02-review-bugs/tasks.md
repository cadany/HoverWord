## 1. 进度恢复修复

- [x] 1.1 `saveProgress` 持久化当前轮次播放顺序（wordId 列表，key `ReciteProgressWordOrder`）
- [x] 1.2 `restoreProgress` 按 wordId 映射还原顺序：校验非空、无重复、全部存在于当前 Section，失败回退从头开始
- [x] 1.3 `clearProgress` 同步清除顺序数据
- [x] 1.4 新增回归测试：`testRestoreLaterLoopLandsOnCorrectWord`（记忆反馈后续轮次）、`testRestoreShuffledPreservesExactWord`（随机播放）、`testRestoreWithFavoritesWordbookEnabled`（收藏夹启用，修复前失败）

## 2. 空文件导入修复

- [x] 2.1 `parse` 在无有效词条（空文件 / 仅空白行）时抛 `ImportError.emptyFile`
- [x] 2.2 更新测试 `testParseEmptyFile` / `testParseOnlyBlankLines` 为预期抛 `emptyFile`

## 3. 收藏变更通知

- [x] 3.1 `NotificationNames` 新增 `.favoritesDidChange`（文档注明主线程发送约束）
- [x] 3.2 `toggleFavorite` 保存后发送通知
- [x] 3.3 收藏夹同步：保存失败记录日志（替换 `try?` 吞错）；后台完成后切主线程发送通知
- [x] 3.4 引擎监听通知：收藏夹启用且播放中时保存进度 → 重建队列 → 尽量恢复原位；其余情况忽略

## 4. 完成态操作入口（用户裁决：移除按钮）

- [x] 4.1 移除 `FloatContentView` 的 `restartButton` 及 `onRestartTap` 回调、`restartTapped`、`showCompleted` 中的按钮浮现逻辑
- [x] 4.2 移除 `FloatWindowController` 的 `onRestartTap` 绑定；右键菜单"重新开始"入口保留不动
- [x] 4.3 `activeButtons()` 完成态返回空集合，悬停/移出统一无操作

## 5. 收藏词条稳定标识（人工验证发现的回归）

- [x] 5.1 `favoriteToWordEntry` 的 wordId 改用持久化 `favoriteId`，替换临时 UUID

## 6. 调试代码清理

- [x] 6.1 删除 `debugPrintIntrinsicSizes()` 及 `viewDidMoveToWindow` 触发点

## 7. 最终验证

- [x] 7.1 运行全部单元测试：53 条，0 失败
- [x] 7.2 人工验证（用户已确认全部通过）：
  - 重启后进度恢复到确切单词（普通单词本 + 收藏夹启用两种配置）
  - 完成状态无操作按钮、右键菜单"重新开始"可用
  - 空文件导入报错且原词条保留
  - 收藏夹启用时切换收藏，队列实时更新
