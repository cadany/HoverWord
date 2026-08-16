## 1. 本地化基建

- [x] 1.1 新建 `Shared/L10n.swift`：`t(_:)` / `t(_:args…)` 查词接口，按 `uiLanguage` 选 .lproj Bundle，回退链 锁定语言 → 系统语言 → en → key
- [x] 1.2 新建 `Localizable.xcstrings`（zh-Hans + en），初始收录全部 85 条文案，key 按 `{模块}.{元素}.{用途}` 命名
- [x] 1.3 `AppSettings` 新增 `uiLanguage`（默认 "system"，Codable 向后兼容）与 `postLanguageChange()`
- [x] 1.4 `NotificationNames` 新增 `.appLanguageDidChange`
- [x] 1.5 project.pbxproj：knownRegions 增加 zh-Hans，xcstrings 纳入 target
- [x] 1.6 L10n 单元测试：锁定语言解析、系统语言回退、词条缺失回退、插值格式化

## 2. "通用"设置页

- [x] 2.1 `SidebarItem` 新增第 5 项"通用"（gearshape），标签走 L10n
- [x] 2.2 新建 `GeneralSettingsView`：界面语言三选一（跟随系统/简体中文/English），卡片分组样式与其他页一致
- [x] 2.3 `SettingsWindowController` 接入新 Tab 与 `LanguageManager`（ObservableObject）environmentObject 注入

## 3. 文案全量替换

- [x] 3.1 Settings 各视图（WordbookTab/Appearance/Recite/Speech/Preview）硬编码文案替换为 L10n key
- [x] 3.2 悬浮窗：FloatContentView（认识/不认识/收藏/已学完）、FloatWindowController（右键菜单）替换并监听 `.appLanguageDidChange` 刷新
- [x] 3.3 服务层错误提示（WordbookImportService 全部 ImportError 文案）替换为带插值的 L10n key
- [x] 3.4 枚举 displayName（ReciteMode/PlayOrder）替换为 L10n 查词
- [x] 3.5 `WordbookService.isFavoritesWordbook` 判定去除 name 条件；系统收藏夹列表显示名走词条映射
- [x] 3.6 完成门槛：全局扫描字符串字面量中的中文字符（排除注释/NSLog/xcstrings），剩余为 0

## 4. 刷新与联动

- [x] 4.1 语言切换后设置窗口（含 sidebar 标签）即时重渲染
- [x] 4.2 语言切换后悬浮窗文案即时刷新，当前单词与释义不丢失
- [x] 4.3 语言切换即时刷新单元测试（通知发出后查词结果变化）

## 5. 版本与收尾

- [x] 5.1 marketing version 0.1.0 → 0.1.1
- [x] 5.2 运行全部单元测试并修复受中文字面量断言影响的用例
- [x] 5.3 人工验证（用户已确认全部通过）：跟随系统默认、锁定中/英即时切换、悬浮窗刷新、收藏夹显示名、重启保持设置、空文件导入报错

## 6. 实施中补充的性能与体验修复（人工验证反馈）

- [x] 6.1 修复"通用"页崩溃：根视图补充 `.environmentObject(languageManager)` 注入
- [x] 6.2 设置页切换性能：内容区改为懒加载后常驻（ZStack + 透明度切换），消除每次切换整页销毁重建（外观页 ColorPicker/字体菜单反复实例化是卡顿主因）；@State 与滚动位置跨切换保留
- [x] 6.3 外观页首次构建优化：字体菜单行移除建页时 `.font(.custom)` 全量字体实例化；打开设置窗后错峰（60ms 间隔）预热未访问页面
- [x] 6.4 字体选择器重构为 `FontPickerField` 懒加载 popover：每行以该字体真实渲染作预览、可视区增量构建、选中项带勾选标记
- [x] 6.5 内容区过渡动画收紧为 spring 0.2s（原 0.3s 贡献延时感）；修复 SF Symbol 名为 `chevron.up.chevron.down`
- [x] 6.6 用户验收：切换流畅度、字体选择器预览与生效、无异常日志，全部通过
