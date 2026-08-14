## 1. 死通知清理

- [x] 1.1 删除 `NotificationNames.swift` 中 11 个死通知的定义（5 个完全死 + 6 个只 post 不 observe），仅保留 `appSettingsDidChange` 和 `wordbookEnablementDidChange`
- [x] 1.2 删除 `WordbookService.swift` 中 `wordbookListDidChange` 的 5 处 post 调用和 `favoriteStateDidChange` 的 2 处 post 调用
- [x] 1.3 删除 `SettingsWindowController.swift` 中 `settingsWindowWillHide` 和 `settingsWindowWillShow` 的 2 处 post 调用
- [x] 1.4 删除 `AppDelegate.swift` 中 `floatWindowWillHideForFullscreen` 和 `floatWindowDidRestoreFromFullscreen` 的 2 处 post 调用
- [x] 1.5 构建验证：确认无编译错误

## 2. 收藏夹背记链路

- [x] 2.1 `WordbookService` 新增 `getFavoriteCount() -> Int` 方法，查询 `Favorite` 实体总数
- [x] 2.2 `WordbookService` 新增 `favoriteToWordEntry(_:sectionIndex:)` 私有方法，将 `Favorite.wordDetail` JSON 反序列化为游离 `WordEntry`（不写入 Core Data）
- [x] 2.3 修改 `WordbookService.getEntryCount(for:)`：当 wordbook 为系统收藏夹时，返回 `getFavoriteCount()`
- [x] 2.4 修改 `WordbookService.getSectionCount(for:)`：当 wordbook 为系统收藏夹时，按 `ceil(favoriteCount / sectionSize)` 计算
- [x] 2.5 修改 `WordbookService.getEntries(for:sectionIndex:)`：当 wordbook 为系统收藏夹时，查询 `Favorite` 并按 section 分页，调用 `favoriteToWordEntry` 转换
- [x] 2.6 修改 `WordbookService.setWordbookEnabled`：`getEntryCount` 已特判收藏夹，无需单独修改
- [x] 2.7 `WordbookTabView` 无需改动：`refreshList()` 调用 `getEntryCount(for:)`，自动适配收藏夹
- [x] 2.8 构建验证：确认无编译错误

## 3. 测试

- [x] 3.1 新增 `testFavoritesWordbookRecitation`：收藏 3 个单词 → 启用收藏夹单词本 → 验证 getEntryCount 返回 3、getSectionCount 返回正确值、getEntries 返回可消费的 WordEntry 数组
- [x] 3.2 新增 `testFavoritesWordbookEnableWithEmpty`：收藏 0 个单词时，验证启用收藏夹单词本返回 false
- [x] 3.3 运行全部测试，确认 0 失败（36 tests, 0 failures）

## 4. 验证

- [x] 4.1 人工冒烟测试：启动 app → 收藏若干单词 → 在设置中启用收藏夹单词本 → 悬浮窗背记收藏夹单词 → 确认单词正常展示和调度
