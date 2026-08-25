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

