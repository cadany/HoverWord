## 1. Major 修复

- [x] 1.1 收藏同步竞态：`syncFavoritesAfterImport` 改 async（`await context.perform` 落库 → `await MainActor.run` 发 `favoritesDidChange`），`importFromFile` 调用点改 `await`，时序注释更新
- [x] 1.2 队列构建 N+1：`WordbookService.getAllEntriesGroupedBySection(for:)`（单次 fetch + 内存分桶，含收藏夹路径）；`ReciteEngine.buildQueue` 改用之
- [x] 1.3 全屏静音：`AppSettings.muteSpeechInFullscreen`（默认 true，Optional 解码向后兼容）；`ReciteEngine.setSpeechSuppressed`/`isSpeechSuppressed`（仅拦自动发音）；`FloatWindowController` 隐藏路径 `stopSpeaking` + 挂起、显示路径解除；`ReciteSettingsView` "其他"卡片 Toggle（联动置灰）；`recite.muteInFullscreen` 中英词条
- [x] 1.4 store 自愈：`DataStack` 同步加载 + 失败销毁重建重试 + NSLog，二次失败才 fatalError

## 2. Minor 修复

- [x] 2.1 `deleteWordbook` 快照 sourceWord → 复用 `anyOtherWordbookContains`/`removeFavorites` 清理孤儿收藏 + 补发 `favoritesDidChange`
- [x] 2.2 语言字面量统一：`ensureSystemFavorites`/`createWordbook`/`ReciteEngine.displayCurrentWord`/`FloatWindowController.onSpeakTap` 4 处改 `Constants.defaultSourceLang/defaultTargetLang`
- [x] 2.3 删除死状态 `wordsPlayedInCurrentLoop`（声明 + 3 处写操作）
- [x] 2.4 `DataStack` 陈旧注释更新（"骨架实现/模型未创建"与 v3 模型现状矛盾）
- [x] 2.5 `AppSettings.load` 解码失败 NSLog（区分"无历史数据"与"配置损坏"）
- [x] 2.6 `ImportError.wordbookMissing` 专用 case + `errorDescription` 接既有词条；`importEntries` 词本不存在改抛此 case
- [x] 2.7 `WordbookService.getStats(for:)` 合并查询；`WordbookTabView.refreshList` 改用之（收藏夹 count 2→1 次）

## 3. 跳过项（用户裁决）

- [ ] 3.1 `WordbookTabView`（695 行）/ `WordbookService`（744 行）/ `ReciteEngine`（645 行）超 500 行规范拆分——留档后续 refactor 变更

## 4. 最终验证

- [x] 4.1 `xcodebuild build` BUILD SUCCEEDED（修复 1 处中途编译错误：Int32/Int 参数类型）
- [x] 4.2 `xcodebuild build-for-testing` TEST BUILD SUCCEEDED（13 个测试文件与改动 API 编译兼容）
- [x] 4.3 `xcodebuild test` 全量回归——CLI 运行器挂起为环境问题（当日 5 次复现），用户 Xcode 全量测试通过（2026-08-25）
- [x] 4.4 手动验证（用户）：勾选全屏自动隐藏 → 子开关"全屏隐藏时静音发音"出现且默认开；进全屏 → 悬浮窗隐藏且停止朗读；退全屏 → 下一词恢复发音；删除词本 → 收藏夹内其独有词条消失——用户验证通过（2026-08-25）
