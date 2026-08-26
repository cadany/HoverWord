# 设计：动效内容切换收归视图层

## 问题回顾

当前 `animate(from:to:in:parameters:completion:)` 把"新内容落位"隐式交给动效实现：动效在动画中点自己写 `wordLabel.stringValue` / `phoneticLabel`。9 个动效各自实现导致两处发散：

- 时机不一致：5 个动效不换音标，残留旧音标到动画结束由 `applyWordContent` 兜底跳变
- 代码重复：每动效重复 tag 查找 + 词/音标/显隐三段式写入，新动效易漏

## 方案

### 协议签名

```swift
func animate(
    from oldContent: TransitionContent,
    to newContent: TransitionContent,
    in containerView: NSView,
    parameters: TransitionParameters,
    swapContent: () -> Void,
    completion: @escaping () -> Void
)
```

`swapContent` 语义：**在旧内容视觉上不可辨的时点调用一次**（调用方完成新内容落位）。调用时点的判定由各动效自己掌握（翻转侧立、缩放为零、淡出完成、开始打字前），这与动效的动画编排天然耦合，无法也不应在视图层统一。

约束：
- 动效 SHALL 恰好调用一次（含 guard 失败立即 completion 的路径——由视图层在 completion 兜底前保证 swap 已发生或内容幂等）
- 视图层 SHALL 保证 swapContent 幂等（重复调用无害）

### 视图层实现（FloatContentView）

```swift
// 统一闭包：单词 + 音标同步落位
let swap = { [weak self] in
    wordLabel.stringValue = newContent.word
    phoneticLabel.stringValue = newContent.phonetic ?? ""
    phoneticLabel.isHidden = (newContent.phonetic == nil)
}
```

切词路径与预览路径各自构造（预览的 newContent 来自当前词或示例词），动效无感知。

### 动效迁移模式（以 CardFlip 为例）

```swift
CATransaction.setCompletionBlock {
    // 中点：先复位模型 transform，再让视图层落位新内容
    wordLayer.transform = CATransform3DIdentity
    phoneticLayer.transform = CATransform3DIdentity
    swapContent()
    containerView.layoutSubtreeIfNeeded()
    // ... 第二阶段动画
}
```

各动效迁移点：
| 动效 | swapContent 调用时点 |
|---|---|
| ClassicFade / CardFlip / PageFlip / NoTransition | 中点（现状已是，改调用） |
| LiquidMerge / LetterMorph / BlackHole | 中点（新增音标同步） |
| BounceIn | 弹入开始前（淡出完成后） |
| Typewriter | 清空后、逐字符开始前 |

### 不做的事

- 不把 layer 引用传出给动效：动效仍按 tag 契约自取需要的 layer（单词标签），音标动画所需 layer 由动效同样按 tag 获取——本 change 只收"内容写入"，不动"动画对象发现"
- 不改 `completion` 链路与代际守卫：`applyWordContent` 兜底不变
- 不改 `TransitionContent` 模型

## 备选与权衡

- **提取协议扩展 helper（不动签名）**：重复可减，但"未来动效不换音标"的根因仍在——一致性靠约定维持。已否决。
- **swapContent 携带 layer 引用返回**：类型污染（元组/结构体），且 PageFlip 等需要在 swap 后同步布局拿新宽度，闭包无返回值更简单。已否决。

## 回归策略

1. 9 个动效逐一验证切词（重点：音标同步、无残留跳变）
2. Typewriter 空词条、打断场景回归（本 change 前置已修，需保持不回归）
3. 预览路径：当前词演示、无当前词回退示例词
4. 代际打断：动画中切词、预览中切词
