---
baseline_version: "v0-1-1"
change_sub_version: "v0-1-1-patch01"
---

## Why

fix02 review 轮报告中确认、但未在当时授权范围内处理的三个遗留缺陷：① 词条级变更（编辑/删除词条、重新导入词库）不通知背记引擎，启用中的单词本内容变化后队列过期，引擎继续轮换已删除的词条；② 全屏自动隐藏功能检测逻辑无效——`NSApp.windows` 仅含本应用窗口，其他应用的全屏状态永远检测不到，功能实际不触发；③ `SpeechService` 的可用语音列表仅在进程启动时加载一次，用户后续下载/变更系统语音后不生效。

另修复两项 review 轮边界确认后纳入的收藏一致性问题：④ 编辑词条 sourceWord 后关联收藏记录不同步（收藏孤儿）；⑤ 删除已收藏词条后收藏记录残留。

## What Changes

- 新增 `.wordbookContentDidChange` 通知：词条更新、词条删除、词库导入成功落盘后在主线程发送，userInfo 携带 wordbookId；无实际变更的路径不发送；导入链路中该通知晚于 `.favoritesDidChange` 发送
- 引擎监听该通知（与收藏变更同一处理入口）：来源单词本启用、且引擎处于播放或 Section 完成态时，保存进度 → 重建队列 → 尽量恢复原位（wordId 稳定的进度持久化天然支持）；未启用或空闲/已学完时忽略；处理幂等
- 收藏一致性：编辑 sourceWord 同步更新该词本范围内关联收藏记录；删除词条按"无其他词本包含同词"条件移除关联收藏，并同步发送 `.favoritesDidChange`
- 全屏检测重写：触发源改为活跃空间切换 + NSWorkspace 任意应用激活（替换原"本应用激活"监听）；检测改用 `CGWindowListCopyWindowInfo` 屏幕级判定（其他进程、layer 0、bounds 覆盖整个屏幕 frame）；不读窗口标题，无需屏幕录制权限
- 全屏隐藏/恢复动画落地：改造 `hideWindowWithAnimation`（原死代码）为双向 0.2s 透明度渐变 + 轻微缩放动画，替代瞬时 orderOut/orderFront
- `SpeechService` 语音列表按需刷新（节流：距上次刷新超过 60 秒才重新枚举），`speak` 前自动生效新下载语音

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `wordbook`: 新增「词条变更通知」需求（携带 wordbookId、成功落盘后发送、导入链路发送次序）；新增「词条变更与收藏一致性」需求
- `recite-engine`: 新增「引擎响应词条内容变更」需求（启用过滤、含 Section 完成态、幂等）
- `app-lifecycle`: 「全屏自动隐藏悬浮窗」需求修订为屏幕级检测 + 任意前台应用激活触发
- `speech`: 新增「语音列表动态刷新」需求

## Impact

- **代码**：修改 `WordbookService.swift`、`ReciteEngine.swift`、`AppDelegate.swift`、`FloatWindowController.swift`（双向动画改造）、`SpeechService.swift`、`NotificationNames.swift`，约 6 个文件
- **行为变更**：① 词条编辑/删除/重导入后背记队列实时反映新内容（原先需重启或改设置才刷新）；② 全屏自动隐藏从"从不触发"变为真实生效，隐藏/恢复带 0.2s 动画（开启该设置的用户可感知）；③ 新下载系统语音无需重启即生效；④ 编辑/删除已收藏词条后收藏状态保持一致
- **性能**：CGWindowList 查询仅在空间切换/应用激活时执行（低频），单次毫秒级；语音列表刷新 60 秒节流
- **兼容**：无数据迁移、无设置字段变化
- **测试**：词条变更通知与引擎恢复、收藏一致性的单元测试；全屏检测为系统交互逻辑，以人工验证为主
