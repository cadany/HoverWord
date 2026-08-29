## 1. 模型层

- [x] 1.1 新增 `Models/Enums/SectionOrder.swift`：sequential / randomStart / shuffled，displayName 走 L10n（计算属性，勿缓存语言）
- [x] 1.2 `AppSettings` 集成 `sectionOrder`（默认 .sequential，Codable 存储 + 旧数据兼容缺省）

## 2. 引擎层

- [x] 2.1 `buildQueue()` 基础队列保持确定性；新增策略应用入口（rotate / shuffle / 单 Section 退化）
- [x] 2.2 进度持久化改身份寻址：保存 (wordbookId, sectionIndex)；恢复按布局还原队列后查找索引；旧索引格式检测失效清零
- [x] 2.3 队列布局持久化：randomStart 存起点身份、shuffled 存完整身份列表；恢复时套用到重建队列，身份失效剔除/回退
- [x] 2.4 续背：全部完成时记录锚点（不清进度）；start() 检测锚点从下一 Section 环形继续；restart() 清锚点
- [x] 2.5 策略变更走既有 handleSettingsChange 清进度重开路径确认无回归

## 3. 设置界面

- [x] 3.1 Section 顺序与Section 内展示顺序并入「Section 设置」卡片（各为「左标签 + 右分段选择」行；Section 间三选项：顺序开始/随机起点/随机打乱，默认顺序开始）
- [x] 3.2 原「展示顺序」更名「Section 内展示顺序」（仅文案，键名沿用）

## 4. 本地化

- [x] 4.1 新词条 zh/en：卡片标题、三个选项及副标题、「Section 内展示顺序」更名

## 5. 测试

- [x] 5.1 SectionOrder 应用：sequential 恒等；randomStart 为 rotate（性质断言）；shuffled 为排列；单 Section 退化
- [x] 5.2 进度身份寻址：恢复到确切 Section；词本停用后布局失效回退；旧格式清零
- [x] 5.3 续背：完成后 start 从下一个 Section 继续（含末个 Section 绕回）；restart 清锚点从策略起点开始
- [x] 5.4 既有引擎测试回归（进度持久化既有场景不受身份寻址破坏）

## 6. 验证

- [x] 6.1 构建 + 全量单测通过（用户 Xcode 执行确认；期间修复 TransitionRegistryTests 存量断言 8→9——feat01 加"无"动效时漏更新）
- [x] 6.2 手工验证（用户执行）：策略三选项切换后新开始行为符合预期；中途退出重启恢复进度；背完一轮后续背继续；重新开始回到策略起点
