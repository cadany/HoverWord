## 1. 引擎：用户暂停来源

- [x] 1.1 `ReciteEngine` 新增 `isUserPaused` 标志与 `setUserPaused(_:)`，`isHoverPaused` 语义收窄为"瞬时来源（悬停/预览）"并加注释说明
- [x] 1.2 抽出 `isPaused`（两来源合并）与 `applyPauseState(wasPaused:)`，计时副作用改按 `(wasPaused → isPaused)` 迁移边沿判定，移除"合并值未变即整体 return"的守卫
- [x] 1.3 `setHoverPaused` 重构后保持既有对外语义不变（`startTimer()` 暂停分支的整段入账逻辑复用）
- [x] 1.4 恢复分支保留 `pausedRemaining` 缺失时按 `stayDuration` 兜底，确保重启后解除不悬空
- [x] 1.5 暴露只读判定（如 `isUserPausedActive`）供控制器决定是否可解除发音挂起

## 2. 引擎：发音挂起

- [x] 2.1 `setUserPaused(true)` 时停止在播语音并置 `setSpeechSuppressed(true)`（副作用留在控制器还是引擎，按 1.1 落位保持一致，二选一并在代码注释说明）
- [x] 2.2 `setUserPaused(false)` 时仅在静音未生效（或窗口可见）时解除挂起
- [x] 2.3 `showWindowWithAnimation()` 的无条件 `setSpeechSuppressed(false)` 加"用户暂停未生效"保护

## 3. 控制器与菜单

- [x] 3.1 `FloatMenuTag` 新增 `pauseResume = 103`
- [x] 3.2 `FloatWindowController` 新增 `isUserPaused` 状态；`syncEnginePauseState()` 维持只合成 hover/preview 两源，用户暂停单独经 `setUserPaused` 下发
- [x] 3.3 `showContextMenu` 插入"暂停背记 / 继续背记"项（位于"打开设置"之前；`allComplete` 状态下不插入该项、菜单文案为"继续背记"时隐藏），顺序为 重新开始 → 暂停/继续 → 打开设置 → 退出程序
- [x] 3.4 `handleMenuAction` 新增分支：翻转 `isUserPaused` → 下发引擎 → 停止在播语音 / 解除挂起
- [x] 3.5 "重新开始"路径先清除用户暂停再 `engine.restart()`
- [x] 3.6 `hideWindowWithAnimation()` 保持仅重置悬停源，确认不清 `isUserPaused`

## 4. 文案

- [x] 4.1 `Localizable.xcstrings` 新增 `float.menu.pause`（暂停背记 / Pause Recitation）与 `float.menu.resume`（继续背记 / Resume Recitation）

## 5. 测试

- [x] 5.1 新增 `HoverWordTests/Services/ReciteEngineUserPauseTests.swift`：开启冻结并记录剩余时长、解除按剩余时长续计、非 playing 态解除不启动计时、暂停中手动切词保持暂停、暂停中 `stayDuration` 热更新
- [x] 5.2 组合用例：hover 先真 → user 后真（来源身份不被合并值吞掉，hover 解除后仍保持冻结；停表期间 `pausedRemaining` 不随墙钟衰减）；user 解除但 hover 仍在（保持暂停）
- [x] 5.3 重启用例：用户暂停中引擎 `start()` 重启后仍暂停，解除后能正常恢复计时（不悬空）
- [ ] 5.4 静音叠加场景改由手动验收覆盖（见 5.6）：解除挂起判定 `!isUserPausedActive && !shouldMuteSpeechNow()` 依赖 `window` 可见性与 `SpeechService.shared` 单例，当前无注入接缝，不为其重构控制器
- [x] 5.5 回归 `ReciteEngineHoverPauseTests` 全部既有用例
- [ ] 5.6 手动验收：右键暂停/继续文案翻转、已学完态菜单无暂停项、暂停中窗口隐藏再显示仍冻结、重启应用后不保留暂停；并覆盖 5.4 的静音叠加（暂停 + 全屏静音并存时解除暂停仍不播报，解除静音后正常播报）

## 6. 验证与收尾

- [x] 6.1 `xcodebuild` 全量测试通过，无新增编译告警（149 tests / 0 failures；仅 `ReciteEngine.swift:375` 的 `totalWords` 未使用告警，基线同一处已存在）
- [x] 6.2 `openspec validate v0-1-2-feat03-float-menu-pause-resume --strict` 通过
- [x] 6.3 按 schema 的落盘自检命令核对 `baseline_version` / `change_sub_version` 与 `MARKETING_VERSION` 一致（`BL=v0-1-2`，archive 内 feat01/feat02 已占用，feat03 无冲突）
- [x] 6.4 更新 `docs/ui-spec.md` 中右键菜单选项清单（若该文档列出了菜单项）—— 核对结论：该文档未列出右键菜单项清单，无需改动
