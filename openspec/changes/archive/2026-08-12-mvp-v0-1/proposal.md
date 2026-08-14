## Why

HoverWord 目前仅有 PRD v0.1 与 UI 规范文档，没有任何可运行代码。本 change 从零构建整个 v0.1 MVP，交付一个可安装运行的 macOS 桌面端悬浮背词应用，使用户立即获得"无感碎片化背记"的核心价值。

## What Changes

- 新增 AppKit + SwiftUI 混合应用的完整工程骨架（App 入口、AppDelegate、目录分层）
- 新增 Core Data 持久化栈（DataStack），实现 Wordbook / WordEntry / Favorite 三个实体与全局设置存储
- 新增 TXT 词库全量导入服务（UTF-8 解析、Tab 分隔校验、错误行号精准提示、Section 自动拆分、收藏夹同步）
- 新增背记核心引擎 ReciteEngine（双模式调度、Section 队列流转、单词轮换、完成检测）
- 新增无边框圆角玻璃悬浮窗 FloatWindowController（拖拽、全局置顶、位置记忆、多显示器、右键菜单、内容展示、双模式交互、完成状态）
- 新增主设置窗口 SettingsWindowController（SwiftUI Tab 页：单词本管理 / 背记规则 / 外观 / 发音，含实时预览）
- 新增系统 TTS 发音服务 SpeechService（AVSpeechSynthesizer、英美音切换、离线可用）
- 新增应用生命周期管理（关闭主窗口隐藏 Dock 图标、悬浮窗为唯一退出入口、全屏自动隐藏）
- 新增 Liquid Glass 视觉体系（macOS 14+ liquid / 12-13 hudWindow 降级、深浅色自适应、三套预设主题）

## Capabilities

### New Capabilities

- `core-data`: Core Data 持久化栈（DataStack）、Wordbook / WordEntry / Favorite 实体定义、AppSettings 全局配置的 JSON 读写
- `wordbook`: 单词本 CRUD（新建 / 删除 / 重命名 / 启用停用）、TXT 词库全量覆盖导入（解析 / 校验 / Section 自动拆分）、系统收藏夹单词本管理
- `recite-engine`: 背记核心引擎，Section 队列构建与流转、记忆反馈模式与走马灯模式的双模式调度、单词轮换与完成检测、顺序 / 随机播放
- `floating-window`: 无边框圆角玻璃悬浮窗，拖拽 / 全局置顶 / 位置记忆 / 多显示器 / 右键菜单 / 单词内容展示 / 双模式交互（悬停按钮浮现 / 认识不认识 / 收藏）/ 完成状态
- `settings-window`: 主设置窗口（标准标题栏 + Liquid Glass 内容区），4 个 SwiftUI Tab 页（单词本管理 / 背记规则 / 外观 / 发音）、悬浮窗实时预览
- `speech`: 系统 TTS 发音服务，AVSpeechSynthesizer 封装，英式 / 美式发音切换，降级容错
- `app-lifecycle`: 应用生命周期与窗口状态管理，启动默认打开主窗口、关闭主窗口隐藏 Dock 图标、全屏自动隐藏悬浮窗、悬浮窗右键菜单退出

### Modified Capabilities

（无，这是全新项目）

## Impact

- **代码**：全新 Xcode 项目，所有目录（App / Models / Services / Controllers / Views / Utils / Resources）从零创建
- **API**：无外部 API 依赖，纯本地应用
- **依赖**：零第三方依赖，全部使用系统原生框架（AppKit / SwiftUI / CoreData / AVFoundation）
- **系统**：最低支持 macOS 12.0（Monterey），适配 Intel / Apple Silicon 双架构
- **性能约束**：后台内存 ≤ 100MB，单词切换延迟 ≤ 100ms，10000 条单词导入 ≤ 3s
