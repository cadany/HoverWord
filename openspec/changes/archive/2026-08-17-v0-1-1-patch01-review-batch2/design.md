## Context

fix02 review 轮确认的三个遗留缺陷。其中全屏检测（`NSApp.windows` 只含本应用窗口）与队列过期（词条级变更无通知）是功能性缺陷，语音列表不刷新是体验缺陷。fix02 引入的 wordId 稳定进度持久化（普通词条 wordId 存储于 Core Data、收藏词条用 favoriteId）使"内容变更后尽量恢复原位"成为可能：词条仍在则 wordId 匹配、停留原位；重新导入生成全新 wordId 则校验失败、安全回退。

review 对齐轮新增两项授权：收藏一致性修复（编辑 sourceWord 同步收藏、删除词条清除关联收藏）纳入本次；`hideWindowWithAnimation` 由"仅记录死代码"升级为"改造为双向动画并接入全屏显隐路径"。

## Goals / Non-Goals

**Goals:**

- 词条编辑/删除/重导入后，背记队列实时反映新内容，且尽量不打断当前进度
- 全屏自动隐藏真实生效（检测其他应用的全屏状态），隐藏/恢复带 0.2s 双向动画
- 新下载系统语音无需重启即生效
- 词条变更与收藏记录保持一致（编辑 sourceWord、删除词条）
- 全部修改通过现有单元测试 + 新增通知/恢复/收藏一致性测试

**Non-Goals:**

- 不做全屏检测的自动化单元测试（系统窗口交互，人工验证）
- 不改动 `wordbookEnablementDidChange` 的"重置进度"语义
- 不做词条编辑器 UI 改进
- 不处理全屏隐藏期间用户手动显隐的意图冲突（见"已知边界"）

## Decisions

### Decision 1: 内容变更通知语义 — 新增 `.wordbookContentDidChange`（携带 wordbookId），引擎"过滤 + 保存进度重建 + 尽量恢复 + 幂等"

**方案：** 新通知名独立于启用状态通知；userInfo 携带变更所属 `wordbookId`，引擎处理前 guard 两项：来源单词本处于启用状态、引擎处于 playing 或 sectionComplete 状态（sectionComplete 视同播放态处理：后续流转的 Section 同样依赖队列数据，忽略会让修复缺口在该状态残留）。处理逻辑与 `.favoritesDidChange` 相同（保存进度 → 重建 → restoreProgress 校验），两个通知名注册到同一 selector，处理幂等。发送点收敛在 `WordbookService`：`updateEntry` / `deleteEntry` 成功落盘后各发一次（wordId 不存在等无变更路径不发送）、`importFromFile` 完成后发一次（主线程），批量导入不逐条发送。导入链路同时触发收藏同步（`.favoritesDidChange`）：两次通知均经主线程队列派发，按派发顺序 FIFO 保序，实现上保证 content 通知在 favorites 通知之后派发（最终到达，引擎以最新状态收尾）。

**替代方案：**

- 复用 `.wordbookEnablementDidChange` — 该通知语义是"重置进度"（spec 冻结），复用会让每次词条编辑清空用户进度，不可接受
- 通知不携带 wordbookId、引擎无条件重建 — 实现更简，但未启用词本的编辑也触发无谓重建；携带 ID 的过滤成本仅一次内存查询
- 发送端过滤（仅启用词本发通知）— 服务层承担引擎的关注点，收藏同步链路判断条件复杂
- 内容变更后仅打标记、下次 start 时重建 — 队列在本次会话内持续过期，没修到根上
- 导入链路合并为单通知（不发 favorites）— 触碰 fix02 已冻结的收藏通知语义

**已知行为：** 重新导入词库时所有 wordId 更新，进度必然回退从头开始——与"全量覆盖"语义一致，spec 场景已明确。

### Decision 2: 全屏检测 — CGWindowList 屏幕级查询 + 任意应用激活触发 + 双向动画

**方案：** 触发源为 `NSWorkspace.activeSpaceDidChangeNotification` + `NSWorkspace.didActivateApplicationNotification`（任意前台应用激活，替换现有 `NSApplication.didBecomeActiveNotification` 本应用激活监听——后者在悬浮窗场景下意义有限，无法覆盖"用户切换前台应用"入口）。检测时 `CGWindowListCopyWindowInfo(.optionOnScreenOnly)` 遍历屏幕窗口，判定条件：`ownerPID != 本进程`、`layer == 0`、窗口 bounds 完整覆盖某块 `NSScreen.frame`（含菜单栏区域，以此区分"最大化"与"全屏"）。满足即存在全屏 → 隐藏悬浮窗。显隐动画：改造现有 `hideWindowWithAnimation`（原死代码）为隐藏/恢复双向 0.2s 透明度渐变 + 轻微缩放动画，替代瞬时 orderOut/orderFront，满足 spec 冻结的动效要求。仅读取 bounds/layer/PID，不读窗口标题，无需屏幕录制权限。

**替代方案：**

- `screen.frame` 与 `visibleFrame` 差值推断 — Dock 自动隐藏、菜单栏常驻等场景误判率高，不可靠
- 检查前台应用是否全屏 — AppKit 无公开 API 获取其他应用的窗口全屏状态
- 仅监听 activeSpaceDidChange（不监听应用激活）— 监控点最少，但焦点跨屏移动等边缘场景无兜底
- 瞬时 orderOut/orderFront（无动画）— 实现最简，但违背 spec 冻结的 0.2s 动效场景
- 放弃该功能 — 已否决（PRD 明确要求该设置项）

**边界：** 检测频率为空间切换/应用激活事件驱动（低频），单次查询毫秒级，无需节流；多显示器按"任一屏幕存在全屏即隐藏"处理（spec 既有语义）。

### Decision 3: 语音列表刷新 — 60 秒节流 + 播放前懒刷新

**方案：** `SpeechService` 记录上次枚举时间（初始化时的首次枚举为时钟起点），`speak` 前超时则重枚举；`applySettings` 无条件刷新。避免每次发音都枚举（`speechVoices()` 有磁盘/服务开销，切词频率高）。`speak()` 为全项目唯一发音入口（仅 ReciteEngine 调用），无旁路。

**替代方案：** 监听系统语音变更通知 — 无公开通知可用；每次 speak 都枚举 — 高频路径上加无谓开销。

### Decision 4: 收藏一致性 — 编辑同步 + 删除隔离清除

**方案：** `updateEntry` 中 sourceWord 发生变化时，同步更新该单词本范围内以旧 sourceWord 匹配的收藏记录（`Favorite.sourceWord` 更新为新文本，收藏身份跟随词条而非文本快照）；`deleteEntry` 删除词条后，按 `anyOtherWordbookContains` 同款隔离语义判断——无其他单词本包含相同 sourceWord 时移除对应收藏记录。两条路径若实际改变了收藏状态，均在主线程补发 `.favoritesDidChange`（收藏夹 Section 若启用需重建）。收藏 sourceWord 更新后其 favoriteId 不变，引擎进度持久化（收藏词条按 favoriteId）不受影响。

**替代方案：**

- 仅记录不修（留待后续 review 轮）— 收藏孤儿会持续累积，且本 change 已引入"编辑词条"场景，spec 层面无法自洽
- 收藏改为按 wordId 关联 — 数据模型迁移，超范围

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|---------|
| CGWindowList 在部分环境下 bounds 坐标系差异（Retina 缩放） | 以全局显示坐标为准，与 NSScreen.frame 同坐标系比较；人工验证覆盖外接显示器 |
| 词条编辑高频操作导致通知风暴 | 编辑保存按操作粒度发送（每词一次），引擎处理轻量（重建队列 + 字典级校验）；如实测有压力再加防抖 |
| 通知在后台线程发送导致引擎非主线程操作 Timer/UI | 收敛在 WordbookService 主线程接口发送；导入链路已有切主线程先例（fix02 收藏同步） |
| 导入链路双通知连续触发两次重建 | 两者经主线程队列 FIFO 保序（favorites 先、content 后）；引擎处理幂等，第二次以前次结果为基线，最终状态一致 |
| 进度恢复依赖 wordId 稳定，收藏词条依赖 favoriteId | fix02 已建立该机制并有回归测试覆盖；收藏同步更新 sourceWord 不改变 favoriteId |
| 语音列表刷新与发音并发 | AVSpeechSynthesizer 内部线程安全，列表仅是选择参考，无共享可变状态问题 |
| 删除词条的收藏清除判断在主线程上下文执行查询 | 词库规模 ≤ 10000 条、单词删除低频，fetchLimit=1 查询开销可忽略 |

## 已知边界（本 change 不处理）

- 全屏隐藏期间用户通过其他途径手动隐藏/移动悬浮窗时，退出全屏后的自动恢复（orderFront + 动画）可能覆盖用户意图——留待后续显隐状态机梳理
- 分屏（Split View / Stage Manager）两应用各占半屏时 bounds 不覆盖整屏，不判定全屏、悬浮窗保持显示——当前按"仅真全屏隐藏"语义接受，如需调整另行立项
