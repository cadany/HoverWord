## 1. 悬浮窗位置恢复 bug 修复

- [x] 1.1 `FloatWindowController.init()` 新增 `NSWindow.didMoveNotification` 观察者
- [x] 1.2 验证：拖拽窗口移动后，重启应用能正确恢复到移动后的位置

## 2. 背记进度持久化

- [x] 2.1 在 `ReciteEngine` 新增 `saveProgress()` 方法：保存 Section 索引 / 单词索引 / feedbackSet 到 UserDefaults
- [x] 2.2 在 `ReciteEngine.advanceToNextWord()` 和 `completeCurrentSection()` 中调用 `saveProgress()`
- [x] 2.3 在 `AppDelegate.applicationWillTerminate` 中调用 `engine.saveProgress()`
- [x] 2.4 在 `ReciteEngine.start()` 新增进度恢复逻辑：读取 UserDefaults → 校验有效性 → 恢复到历史进度
- [x] 2.5 进度校验逻辑：Section 索引越界 / 单词索引越界 / feedbackSet 中单词不存在时，清除进度从头开始
- [x] 2.6 在 `ReciteEngine` 完成全部 Section 时清除进度数据
- [x] 2.7 在 `handleMenuAction(.restart)` 手动重新开始时清除进度数据
- [x] 2.8 验证：背记中途退出 → 重启 → 从上次位置继续；修改单词本后 → 重启 → 从头开始

## 3. 单词本预览

- [x] 3.1 创建 `Features/Settings/WordbookPreviewView.swift`：Sheet 视图，包含分页词条列表
- [x] 3.2 在 `WordbookService` 新增分页 fetch 方法：`getEntries(for:page:pageSize:) -> (entries, totalPages)`
- [x] 3.3 在 `WordbookTabView` 操作栏新增"预览"按钮，选中单词本后可用
- [x] 3.4 预览 Sheet 内实现词条字段内联编辑（单词 / 音标 / 词性 / 释义）
- [x] 3.5 预览 Sheet 内实现每行删除按钮，删除后刷新列表
- [x] 3.6 实现分页控件（上一页 / 页码 / 下一页），每页 100 条
- [x] 3.7 空单词本预览时显示空状态提示
- [x] 3.8 验证：预览中编辑词条 → Core Data 保存成功；删除词条 → 列表刷新；分页导航正常

## 4. 测试

- [x] 4.1 新增 `ReciteEngineProgressTests`：测试进度保存 / 恢复 / 校验 / 清除逻辑
- [x] 4.2 新增 `WordbookPreviewTests`：测试分页 fetch 逻辑
- [x] 4.3 全量构建通过，所有测试通过
