Change-Sub-Version: v0-1-1-patch02

## Purpose

store 加载失败的崩溃循环消除：损坏或迁移失败时自愈重建，仅重建仍失败才终止；设置解码失败留诊断日志。

## MODIFIED Requirements

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
