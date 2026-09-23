# AGENTS.md — 团队规范（Agent 行为契约）

> 适用于任何 AI coding agent。本文件只规定「在本仓库如何工作」，不复述需求内容。
> 需求真源 → docs/HoverWord 产品需求文档（PRD）；VI 基础规范 → docs/ui-spec.md（改 UI 前必读，实现参数以 Constants.swift 为准）；领域规范 → openspec/specs/（立 change 时必读所涉文件）。

## 项目速览

macOS 原生悬浮单词闪记应用。Swift 5.9+ / AppKit+SwiftUI / Core Data / 零第三方依赖 / 最低 macOS 14.0。工程由 xcodegen 生成，版本号唯一真源是 project.yml。

架构分层：App / Features（功能模块）/ Services / Models / Shared。新功能在 Features/ 下建独立目录，跨 Feature 共用组件移至 Features/Components/，Models / Services / Shared 保持全局共享。

## 构建与验证

- 新增/删除源文件后先 `xcodegen generate` 再构建；项目用 Xcode 直接构建，无需额外环境配置
- 测试必须在用户本机 Xcode 运行（沙箱 test runner 因 XPC 限制挂起）；构建可在沙箱验证
- 完成定义 = 构建通过 + 相关测试通过 + 任务端到端交付；涉及 openspec change 时加跑 schema 自检命令

## 边界禁区（generated / 真源在别处）

- `HoverWord.entitlements`：generated 产物，真源在 project.yml 的 entitlements.properties，禁止手编
- 版本号：改 project.yml info 块（硬编码 CFBundleShortVersionString / CFBundleVersion），勿手改 pbxproj
- `Localizable.xcstrings`：4 空格缩进 + 固定键序；批量改动保持 diff 最小化，禁用 json.dump 全量重写
- 版本命名唯一真源：openspec/schemas/version-aware/schema.yaml（MANDATORY VERSION CONSTRAINT）

## 工作流（openspec 驱动）

1. 功能改动先立 change（proposal / design / tasks / specs delta）→ 用户确认 → 实施 → 用户验证通过 → 归档
2. proposal 必须列出本次涉及的 spec 文件并先行阅读
3. 方案有多选项：列出选项 + 权衡，等用户决策，禁止自行拍板后直接改代码；需求不明确时停下来问，不要自行猜测
4. 界面/产品措辞类改动属产品决策，交用户定夺
5. 影响超过 3 个文件的改动：先列计划确认再执行
6. 任务自闭环、端到端交付：任务范围内的阻塞问题（含测试暴露的 bug）就地修复并验证；范围外的潜在 bug / 改进点：只提出，不自行修改

## 代码约定（踩过的坑）

- 遵循 Swift API Design Guidelines；4 空格缩进禁 Tab；单文件原则上不超过 500 行；公共接口加文档注释
- L10n 词条 displayName 必须是计算属性（存储属性会冻结语言缓存）
- UI 术语以 openspec/specs/terminology.md 为准（"Section" 不翻译）
