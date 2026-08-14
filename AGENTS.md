# 项目规范

本文档为 Claude 提供 HoverWord 项目的完整开发基准，所有代码输出、方案设计、问题排查均需严格遵循本文档与配套 PRD 要求。

## 项目概述

### 基础信息
- 项目名称：HoverWord
- 产品定位：macOS 桌面端轻量悬浮式单词闪记原生应用
- 核心场景：办公 / 学习场景下，通过桌面悬浮窗高频视觉曝光，无感碎片化背记英文单词
- 设计原则：极简、轻量、低干扰、高自定义，纯本地运行无服务端依赖

### 版本功能边界
 - 当前版本：v0.1 @HoverWord 产品需求文档（PRD）v0.1.md

## 技术规范

### 核心技术栈

| 领域 | 技术选型 | 说明 |
| --- | --- | --- |
| 开发语言 | Swift 5.9+ |	全程使用现代 Swift 语法，兼容两类芯片 |
| UI 框架 | AppKit + SwiftUI 混合 |	窗口管理、悬浮窗自定义使用 AppKit；设置界面内容使用 SwiftUI 提升开发效率 |
| 数据持久化 | Core Data |	存储单词本、词条、收藏记录与全局配置，原生兼容 macOS |
| 发音引擎 | AVFoundation / AVSpeechSynthesizer |	调用系统原生 TTS，离线可用，支持英 / 美音切换 |
| 最低系统版本 | macOS 14.0 (Sonoma) |	使用最新 Liquid Glass 材质与 NavigationSplitView API |
| 开发工具 | Xcode 15+ |	使用最新版本的 Xcode 进行开发 |
| 依赖管理 | Swift Package Manager |	不引入任何第三方依赖，全部使用系统原生框架 |

### 架构模式

采用**功能模块制 + 服务层分层**架构：
- 功能层（Features/）：每个功能模块包含窗口控制器 + 视图，内聚完整交互逻辑
- 服务层（Services/）：负责背记引擎、导入解析、发音、数据存储等核心业务，与 UI 层解耦
- 模型层（Models/）：负责数据实体定义
- 共享层（Shared/）：常量、通知名等跨模块公共资源

### 项目目录结构
采用**功能模块制**：UI 按功能聚合在 Features/ 下，数据与服务保持全局分层。所有尺寸单位统一使用 **points (pt)**。
```text
HoverWord/
├── App/                          # 应用入口与生命周期
│   ├── HoverWordApp.swift
│   └── AppDelegate.swift         # Dock图标控制、全局生命周期、全屏监听
├── Features/                     # 功能模块（UI + 窗口控制器聚合）
│   ├── FloatingWindow/           # 悬浮背记窗口
│   │   ├── FloatWindowController.swift   # 窗口生命周期、位置记忆
│   │   ├── FloatContentView.swift        # 悬浮窗内容视图（AppKit）
│   │   └── GlassBackgroundView.swift     # 玻璃材质背景组件
│   └── Settings/                 # 主设置窗口
│       ├── SettingsWindowController.swift  # 设置窗口控制器
│       ├── WordbookTabView.swift           # 单词本管理 Tab
│       ├── ReciteSettingsView.swift        # 背记规则设置 Tab
│       ├── AppearanceView.swift            # 外观设置 Tab
│       └── SpeechSettingsView.swift        # 发音设置 Tab
├── Models/                       # 数据模型层
│   ├── Entities/                 # Core Data 实体类
│   │   ├── Wordbook+CoreDataClass.swift
│   │   ├── WordEntry+CoreDataClass.swift
│   │   └── Favorite+CoreDataClass.swift
│   ├── Enums/
│   │   ├── ReciteMode.swift      # 背记模式枚举
│   │   └── PlayOrder.swift       # 播放顺序枚举
│   └── AppSettings.swift         # 全局配置模型（Codable）
├── Services/                     # 业务服务层
│   ├── DataStack.swift           # Core Data 栈管理
│   ├── ReciteEngine.swift        # 背记核心引擎：Section流转、单词调度
│   ├── WordbookService.swift     # 单词本 CRUD 服务
│   ├── WordbookImportService.swift # TXT 文件导入解析服务
│   └── SpeechService.swift       # 系统 TTS 发音服务
├── Shared/                       # 跨模块共享
│   ├── Constants.swift           # 全局常量（UI 尺寸、颜色、动效参数）
│   └── NotificationNames.swift   # 通知名称
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

**组织原则：**
- 新功能在 `Features/` 下创建独立目录，包含该功能的所有窗口控制器、视图文件
- 通用 UI 组件（如 `GlassBackgroundView`）放在它所服务的 Feature 内；若多个 Feature 共用则移至 `Features/Components/`
- Models / Services / Shared 保持全局共享，不按功能拆分

### 开发规范

#### 代码风格
- 严格遵循 [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- 使用 4 空格缩进，禁止 Tab 字符
- 单文件长度原则上不超过 500 行，复杂逻辑拆分到扩展或独立文件
- 公共接口必须添加文档注释，核心业务逻辑需附带行内注释

#### 命名规范
- 通知名称、常量统一在 Constants.swift / NotificationNames.swift 中管理

### 构建与调试要点
- 项目使用 Xcode 直接构建，无需额外环境配置
- 调试悬浮窗时，可通过菜单或临时快捷键快速唤起设置窗口
- 测试导入功能需覆盖：正常文件、空文件、格式错误、编码错误、超大词库（10000 条）
- 性能指标硬约束：
- 后台常驻内存 ≤ 100MB
- 单词切换延迟 ≤ 100ms
- 10000 条单词导入耗时 ≤ 3s


## 交互界面设计规范
详细规范见 [docs/ui-spec.md](docs/ui-spec.md)，核心约束：
- 全应用以 Liquid Glass 玻璃材质为基础：macOS 14+ 使用 `.liquid`，12-13 降级 `.hudWindow`，自动跟随深浅色模式
- 悬浮窗为无边框圆角玻璃窗（8pt 连续圆角），设置窗为标准标题栏 + `.underWindowBackground`
- 所有可点击按钮（认识 / 不认识 / 收藏 / 重新开始）遵循玻璃质感四态交互（默认 / 悬停 / 点击 / 激活）
- 具体的 pt 值、颜色不透明度、动效时长等实现参数统一在 `Constants.swift` 中定义，以代码为准

## 多语种架构预留要求
- v0.1 仅实现英→中场景，但代码层必须做语种无关设计：
- 数据模型不硬编码语言，通过 source_lang / target_lang 字段标识
- 发音服务封装统一协议，不同语种仅需配置语言代码
- 界面渲染预留 RTL（从右到左）布局适配入口
- 禁止在业务逻辑中写入针对中英文的特殊判断逻辑

## 工作规范
- 任何会影响超过 3 个文件的改动，先列计划确认再执行
- 遇到不确定的需求，停下来问我，不要自己猜
- 遇到多种实现方案时，列出 2-3 个选项并说明各自的权衡，不要自行决定
- 每完成一个有意义的改动，自动运行测试验证没有引入回归
- 发现潜在的 bug 或改进点，可以提出来，但不要自行修改