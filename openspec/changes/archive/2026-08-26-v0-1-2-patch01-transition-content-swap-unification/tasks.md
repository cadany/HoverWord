## 1. 协议变更

- [x] 1.1 `WordTransitionEffect.animate` 签名增加 `swapContent: @escaping () -> Void` 参数（位于 parameters 与 completion 之间）
- [x] 1.2 协议文档注释更新：swapContent 契约（恰好一次、旧内容不可辨时点、幂等由视图层保证）；删除"动效负责呈现新内容"的旧表述
- [x] 1.3 更新协议扩展注释中的动效实现指引（协议头新增"职责边界"：动效 SHALL NOT 自行写入标签内容）

## 2. 视图层统一实现

- [x] 2.1 `FloatContentView` 提取私有方法 `makeContentSwap(for: TransitionContent) -> () -> Void`（单词 + 音标 + 显隐三段式落位，幂等）
- [x] 2.2 切词路径（`showWord`）构造 swap 闭包传入动效调用
- [x] 2.3 预览路径（`handlePreviewTransition`）构造 swap 闭包传入动效调用（当前词/示例词两分支复用同一构造）

## 3. 动效迁移（9 个）

- [x] 3.1 ClassicFadeEffect：中点改调 swapContent，删除自行换词/换音标
- [x] 3.2 CardFlipEffect：同上
- [x] 3.3 PageFlipEffect：同上（保留中点复位 transform → swap → 同步布局的顺序；删除音标 tag 查找）
- [x] 3.4 NoTransitionEffect：改调 swapContent（原直接写标签逻辑与标签查找全部删除）
- [x] 3.5 LiquidMergeEffect：中点改调 swapContent（新增音标同步）
- [x] 3.6 LetterMorphEffect：中点改调 swapContent（新增音标同步）；降级路径透传 swapContent
- [x] 3.7 BlackHoleEffect：中点改调 swapContent（新增音标同步）
- [x] 3.8 BounceInEffect：淡出完成回调改调 swapContent（新增音标同步）；修正"下方 20px"注释为实际的上方（y 负向）
- [x] 3.9 TypewriterEffect：清空后、逐字符开始前调用 swapContent（音标先于字符流就位）
- [x] 3.10 各动效删除不再需要的音标 tag 查找（仅动画仍需要音标 layer 的保留——ClassicFade/CardFlip 动画音标故保留）

## 4. 验证

- [x] 4.1 单元测试：动效 animate 调用 swapContent 恰好一次（含 guard 失败路径的优雅降级测试）
- [x] 4.2 集成验证：9 个动效切词音标同步无残留跳变（用户在 Xcode 环境执行）
- [x] 4.3 回归：Typewriter 空词条/打断哑化不回归；预览当前词演示正常；动画中切词代际守卫正常（用户在 Xcode 环境执行）
- ~~4.4 更新动效扩展文档（README 动效章节，与 feat01 遗留 8.1 合并处理）~~（用户决策取消：v0.1.2 不更新 README，见 feat01 任务 8.1）
