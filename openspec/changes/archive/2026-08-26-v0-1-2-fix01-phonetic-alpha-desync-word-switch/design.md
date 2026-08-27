# 设计：注音 alpha 脱钩修复

## 根因链

见 proposal「Why」。核心矛盾：动效系统（Core Animation 显式动画）与内容可见性系统（AppKit `alphaValue`）分属两层，前者直接写 `layer.opacity` 不通知后者，后者的缓存去重机制在"缓存值 == 新值"时跳过 layer 写入。

## 修复位置取舍

| 方案 | 做法 | 否决理由 |
| --- | --- | --- |
| A. `applyAlpha` 非动画路径同步 layer（已选） | 设置 `alphaValue` 后显式写 `layer.opacity` | — |
| B. `resetTransitionLayerState` 里重设 alphaValue | 动效归位时先置 alphaValue = 1 再置目标值，强制缓存变化触发写入 | 依赖"两次赋值制造差异"的副作用语义，脆弱；且只覆盖 `applyWordContent` 路径，设置变更通知触发的 `updatePhoneticVisibility(animated: false)` 仍有脱钩窗口 |
| C. 动效协议传入可见性上下文 | 动效感知内容可见性，动画终态直接落到配置值 | 协议签名变更，波及 9 个动效；为 4 行能解决的回归引入架构改动，过度设计 |

选 A 的理由：脱钩的本质是"非动画路径写 alphaValue 时 layer 可能被动效污染"，在唯一入口 `applyAlpha` 处同步是最小且完备的修复——注音/释义两条路径、切词/设置变更两类触发全部覆盖。动画路径值有实际变化时 AppKit 正常写 layer，无需处理。

## 动效中闪现问题（不在本 change 处理）

动效进行中注音随动画短暂可见（约 0.15-0.5s）。若未来要修，方向是方案 C 类的协议感知可见性，或动效只动画单词、音标不参与动画。属于行为规格决策（动效期间的可见性语义 spec 未定义），应另立 change 讨论。
