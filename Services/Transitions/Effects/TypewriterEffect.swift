import AppKit

/// 打字机动效（Typewriter）
///
/// ## 效果描述
/// 模拟打字机逐字符输入。旧内容瞬间消失，新内容一个字符一个字符地出现，
/// 营造出打字的节奏感。
///
/// ## 技术实现
/// - **字符间隔**: 使用 `DispatchQueue.main.asyncAfter` 按时间调度每个字符
/// - **旧内容**: 立即清空（0ms）
/// - **新内容**: 逐字符追加，每个字符间隔可调
/// - **光标效果**: 未实现（简化版），可通过扩展添加闪烁光标
///
/// ## 分类
/// `.playful`（趣味类）— 增加趣味性和互动感
///
/// ## 可调参数
/// - **interval**（字符间隔）: 30ms - 100ms，默认 60ms
///   - 较短间隔（30ms）：快速打字，适合熟练用户
///   - 较长间隔（100ms）：慢速打字，更明显的打字机效果
///
/// ## 性能特性
/// - 逐字符更新，CPU 开销随单词长度线性增长
/// - 对于长单词（>20 字符），总时长可能超过预期
/// - 建议：对于超长单词可考虑降级为其他动效
///
/// ## 注意事项
/// - 当前实现仅动画化单词，注音（phonetic）未参与动画
/// - 可通过修改代码扩展注音和释义的打字效果
struct TypewriterEffect: WordTransitionEffect {
    let id = "typewriter"
    let displayName: String = {
        return L10n.t("settings.transition.effect.typewriter")
    }()
    let category: TransitionCategory = .playful

    let adjustableParameters = [
        TransitionParameter(
            id: "interval",
            displayName: L10n.t("settings.transition.parameter.interval"),
            range: Constants.typewriterIntervalRange,
            defaultValue: Constants.typewriterDefaultInterval,
            step: 0.01
        )
    ]

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        completion: @escaping () -> Void
    ) {
        let interval = parameters.get("interval", defaultValue: Constants.typewriterDefaultInterval)

        guard let wordLabel = containerView.viewWithTag(1001) as? NSTextField else {
            completion()
            return
        }

        // 立即清空
        wordLabel.stringValue = ""

        // 逐字符显示
        let characters = Array(newContent.word)
        var currentText = ""

        for (index, char) in characters.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(index)) {
                currentText.append(char)
                wordLabel.stringValue = currentText

                // 最后一个字符时完成
                if index == characters.count - 1 {
                    completion()
                }
            }
        }
    }
}
