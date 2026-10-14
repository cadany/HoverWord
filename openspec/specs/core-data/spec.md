## Purpose

管理应用核心数据的持久化层：单词本、词条、收藏夹三个实体的存储与读取，以及全局背记设置的持久化。数据模型采用语种无关设计，通过源/目标语言字段标识语种，为未来多语种扩展预留结构。
## Requirements
### Requirement: Core Data 栈初始化与生命周期
系统 SHALL 在应用启动时初始化 Core Data 持久化栈（NSPersistentContainer），栈对象作为单例在整个应用生命周期内可用，支持主上下文与后台上下文进行并发安全的读写操作。持久化栈 SHALL 同步加载（自愈在启动初始化返回前完成）。加载失败时系统 SHALL 记录日志、销毁损坏 store 并重建重试（词库数据丢失但应用可用）；仅重建后仍失败才终止启动。全局设置存储于 UserDefaults，不受 store 重建影响。

#### Scenario: 应用启动时栈可用
- **WHEN** 应用启动完成
- **THEN** 数据栈已就绪，任意服务层组件可通过单例获取主上下文执行查询

#### Scenario: 栈加载失败可感知
- **WHEN** 持久化栈因文件损坏或权限问题无法加载
- **THEN** 系统 SHALL 记录诊断日志并执行自愈（销毁重建），不静默吞异常

#### Scenario: store 损坏自愈
- **WHEN** 持久化 store 文件损坏或轻量迁移失败导致首次加载出错
- **THEN** 系统 SHALL 销毁该 store 重建空库继续启动（不崩溃循环），并记录诊断日志；用户设置与偏好保留，词库数据丢失

#### Scenario: 重建后仍失败
- **WHEN** 销毁重建后第二次加载仍失败（极端环境故障）
- **THEN** 系统 SHALL 终止启动并报告错误（维持 fatalError 兜底）

### Requirement: 单词本实体持久化
系统 SHALL 提供 Wordbook 实体，支持存储单词本名称、源语言、目标语言、启用状态、是否系统内置、创建时间等字段，支持增删改查操作。

#### Scenario: 新建单词本
- **WHEN** 用户新建一个单词本
- **THEN** 系统 SHALL 在持久化层创建一条 Wordbook 记录，默认启用状态为 false，系统内置标记为 false

#### Scenario: 删除单词本
- **WHEN** 用户删除一个非系统的单词本
- **THEN** 系统 SHALL 级联删除该单词本下的所有词条记录

#### Scenario: 禁止删除系统单词本
- **WHEN** 调用方尝试删除系统内置单词本
- **THEN** 系统 SHALL 拒绝该操作并返回错误

### Requirement: 词条实体持久化
系统 SHALL 提供 WordEntry 实体，存储所属单词本 ID、Section 序号、源语言词条、注音、最多 3 组词性与释义。字段不绑定具体语种。

#### Scenario: 存储含完整信息的词条
- **WHEN** 导入一个包含词条、音标、3 组词性释义的行
- **THEN** 系统 SHALL 将全部字段写入 WordEntry 对应字段

#### Scenario: 存储仅必填字段的词条
- **WHEN** 导入一个仅包含词条和第 1 组释义的行
- **THEN** 系统 SHALL 写入词条与第 1 组释义，第 2、3 组字段留空

### Requirement: 收藏夹实体持久化
系统 SHALL 提供 Favorite 实体，按源语言词条精确匹配，存储词条完整信息 JSON 与收藏时间。同一词条在全应用范围内仅保留一条收藏记录。

#### Scenario: 收藏一个新词条
- **WHEN** 用户对某个尚未收藏的词条执行收藏
- **THEN** 系统 SHALL 创建一条 Favorite 记录，写入词条完整信息与当前时间戳

#### Scenario: 重复收藏同一词条
- **WHEN** 用户对已收藏的词条再次执行收藏
- **THEN** 系统 SHALL 取消收藏，删除对应的 Favorite 记录

### Requirement: 全局设置持久化
系统 SHALL 将全局背记设置（模式、轮次、停留时长、外观参数、发音参数等）作为可序列化配置对象持久化存储，支持应用重启后恢复。设置 JSON 解码失败（文件损坏或 schema 不兼容）时，系统 SHALL 使用默认值继续并记录诊断日志，与"无历史数据"的正常路径区分。

#### Scenario: 修改设置后重启
- **WHEN** 用户修改某项设置后关闭应用再重新启动
- **THEN** 系统 SHALL 恢复修改后的设置值，而非默认值

#### Scenario: 首次启动使用默认值
- **WHEN** 应用首次启动（无任何历史配置）
- **THEN** 系统 SHALL 使用预设的默认设置值

#### Scenario: 设置数据损坏
- **WHEN** UserDefaults 中的设置 JSON 解码失败
- **THEN** 系统 SHALL 回退默认值运行并 NSLog 记录解码错误，不留静默失败

### Requirement: 语种无关的数据结构
所有数据实体 SHALL 通过 source_lang / target_lang 字段标识语种，禁止在实体字段名或存储逻辑中硬编码特定语种。

#### Scenario: 查询词条不依赖语种硬编码
- **WHEN** 业务层查询某单词本的词条列表
- **THEN** 查询逻辑 SHALL 基于单词本 ID 与 Section 序号，不出现针对特定语种的条件分支

### Requirement: 复习状态实体持久化

系统 SHALL 提供 ReviewState 实体，按 wordId 唯一寻址，存储单词的复习调度状态：Leitner 盒级（1-5，默认 1）、下次到期时间（dueAt）、最近反馈时间（可空）、最近反馈等级（认识 / 模糊 / 不认识）、累计曝光次数。字段设计 SHALL 语种无关（不绑定具体语种，仅以 wordId 关联词条）。模型变更 SHALL 通过轻量迁移完成（新增实体加表，不触碰既有实体）。ReviewState 的读写 SHALL 由服务层封装：按 wordId 取得或创建记录、反馈时原子更新盒级与到期时间、按 dueAt 查询到期记录。

#### Scenario: 首次反馈创建记录

- **WHEN** 某词条在记忆反馈模式下首次收到反馈且无既有 ReviewState 记录
- **THEN** 系统 SHALL 创建一条 ReviewState 记录，以该词条 wordId 唯一寻址，写入反馈对应的盒级、到期时间、最近反馈等级与时间、累计曝光 1

#### Scenario: 再次反馈更新记录

- **WHEN** 某词条已有 ReviewState 记录并再次收到反馈
- **THEN** 系统 SHALL 原子更新该记录的盒级、到期时间、最近反馈等级与时间，并累加曝光计数，SHALL NOT 产生重复记录

#### Scenario: 轻量迁移加表

- **WHEN** 旧版本数据文件在含 ReviewState 实体的新版本应用中首次加载
- **THEN** 系统 SHALL 通过轻量迁移自动完成加表，既有 Wordbook / WordEntry / Favorite 数据不受影响

#### Scenario: 到期查询

- **WHEN** 引擎构建全局复习队列
- **THEN** 服务层 SHALL 支持按 dueAt 不晚于当前时间的条件查询 ReviewState 记录，供队列取到期复习词

#### Scenario: 词条失效后记录成为孤儿

- **WHEN** 词条因词库重新导入或删除导致其 wordId 不再存在于任何启用单词库
- **THEN** 对应 ReviewState 记录 SHALL 保留在存储中但 SHALL NOT 参与调度（查询不到对应词条即不入队），系统 SHALL NOT 因孤儿记录崩溃或报错

#### Scenario: store 损坏自愈覆盖新实体

- **WHEN** 持久化 store 损坏触发自愈重建
- **THEN** ReviewState 数据 SHALL 与其他实体一致按"重建后丢失"处理，应用可用（用户设置保留）

