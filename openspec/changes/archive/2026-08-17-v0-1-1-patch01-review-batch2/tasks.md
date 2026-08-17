## 1. 词条变更通知与引擎响应

- [x] 1.1 `NotificationNames` 新增 `.wordbookContentDidChange`（文档注明：userInfo 携带 wordbookId、主线程发送约束）
- [x] 1.2 `WordbookService`：`updateEntry` / `deleteEntry` 成功落盘后各发送一次通知（携带所属词本 wordbookId；wordId 不存在等无变更路径不发送）；`importFromFile` 完成后经主线程队列发送，且派发顺序晚于 `.favoritesDidChange`（FIFO 保序）
- [x] 1.3 `ReciteEngine`：注册 `.wordbookContentDidChange` 到与收藏变更相同的处理 selector；处理前 guard 两项——来源 wordbookId 对应词本启用、state ∈ {playing, sectionComplete}；处理保持幂等（保存进度 → 重建 → 尽量恢复）
- [x] 1.4 单元测试：编辑词条后停留原位、删除当前词后回退、重导入后从头开始、空闲/已学完忽略、未启用词本忽略、sectionComplete 状态处理、连续双通知（favorites + content）幂等（注：sectionComplete 在当前代码中不可达，以 guard 条件预留，不做单测，见 `WordbookContentChangeTests.swift` 头部注释）

## 2. 收藏一致性

- [x] 2.1 `updateEntry`：sourceWord 变化时同步更新该词本范围内以旧 sourceWord 匹配的收藏记录（favoriteId 不变）；收藏状态实际变化时主线程补发 `.favoritesDidChange`
- [x] 2.2 `deleteEntry`：按 `anyOtherWordbookContains` 隔离语义——无其他词本包含相同 sourceWord 时移除对应收藏，并在主线程补发 `.favoritesDidChange`
- [x] 2.3 单元测试：编辑已收藏词的 sourceWord 后收藏跟随新文本、删除已收藏词且无其他词本含同词时收藏移除、其他词本含同词时收藏保留

## 3. 全屏检测重写

- [x] 3.1 触发源替换：`NSWorkspace.activeSpaceDidChangeNotification` + `NSWorkspace.didActivateApplicationNotification`，移除 `NSApplication.didBecomeActiveNotification` 监听
- [x] 3.2 `AppDelegate.checkFullscreenState` 改为 CGWindowList 屏幕级检测（ownerPID != 本进程、layer 0、bounds 覆盖 NSScreen.frame），移除 NSApp.windows 遍历
- [x] 3.3 改造 `FloatWindowController.hideWindowWithAnimation` 为隐藏/恢复双向 0.2s 透明度渐变 + 轻微缩放动画，接入检测显隐路径（替代 orderOut/orderFront）
- [x] 3.4 人工验证：其他 App 进/出全屏（单屏 + 外接屏）、切换前台应用触发检测、最大化窗口不误判、功能关闭不隐藏、动效符合 0.2s 要求（2026-08-17 用户核验通过）

## 4. 语音列表动态刷新

- [x] 4.1 `SpeechService`：记录上次枚举时间（初始化首次枚举为起点），`speak` 前 >60s 重枚举，`applySettings` 无条件刷新
- [x] 4.2 人工验证：系统设置下载语音后无需重启即可选中（如可测）（2026-08-17 用户核验通过）

## 5. 最终验证

- [x] 5.1 运行全部单元测试，确认 0 失败（2026-08-17 全量通过：TEST SUCCEEDED）
- [x] 5.2 人工验证全部通过后归档（2026-08-17 归档）
