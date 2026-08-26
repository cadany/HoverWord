import AppKit
import ObjectiveC

/// 打字机动效（Typewriter）
///
/// ## 效果描述
/// 模拟打字机逐字符输入。旧内容瞬间消失，新内容一个字符一个字符地出现，
/// 营造出打字的节奏感。
///
/// ## 技术实现
/// - **字符间隔**: `DispatchWorkItem` 按时间调度每个字符，可取消
/// - **接管即哑化**: 双保险——新一轮 `animate` 先取消上一轮任务（接管路径）；
///   每个任务写入前校验 label 内容仍等于当前字符流（覆盖不经 `animate` 的
///   接管方，如 `applyWordContent` 直接换词、其它动效中点改写）
/// - **内容落位**: 先经 `swapContent` 让音标就位（打字机无中点语义，
///   逐字符开始前即"旧内容不可辨"时点），再清空单词标签开始打字
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
/// - 空词条（无字符可打）直接回调 completion，不调度任务
/// - 当前实现仅动画化单词，注音（phonetic）未参与动画
struct TypewriterEffect: WordTransitionEffect {
    let id = "typewriter"
    var displayName: String {
        return L10n.t("settings.transition.effect.typewriter")
    }
    let category: TransitionCategory = .playful

    var adjustableParameters: [TransitionParameter] {
        return [
            TransitionParameter(
                id: "interval",
                displayName: L10n.t("settings.transition.parameter.interval"),
                range: Constants.typewriterIntervalRange,
                defaultValue: Constants.typewriterDefaultInterval,
                step: 0.01
            )
        ]
    }

    /// 挂在 containerView 上的待执行任务存储键（动效本身无状态，任务挂在容器上）
    private static var pendingTasksKey: UInt8 = 0

    func animate(
        from oldContent: TransitionContent,
        to newContent: TransitionContent,
        in containerView: NSView,
        parameters: TransitionParameters,
        swapContent: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        let interval = parameters.get("interval", defaultValue: Constants.typewriterDefaultInterval)

        guard let wordLabel = containerView.viewWithTag(Constants.transitionWordLabelTag) as? NSTextField else {
            completion()
            return
        }

        // 接管即取消：新一轮动效开始，上一轮残留的字符流立即哑化
        Self.cancelPendingTasks(on: containerView)

        // 音标先于字符流就位（swapContent 同步写入完整词，
        // 随后立即清空由打字流接管单词呈现，同一 runloop 内无中间渲染）
        swapContent()

        // 立即清空
        wordLabel.stringValue = ""

        let characters = Array(newContent.word)

        // 空词条：无字符可打，直接完成（否则 completion 永不回调）
        guard !characters.isEmpty else {
            completion()
            return
        }

        var currentText = ""
        var tasks: [DispatchWorkItem] = []

        for (index, char) in characters.enumerated() {
            let task = DispatchWorkItem {
                // 内容校验：label 已被其它接管方改写（applyWordContent 换词 /
                // 其它动效中点设置新词）时，本字符流不再属于当前显示，立即哑化
                guard wordLabel.stringValue == currentText else { return }

                currentText.append(char)
                wordLabel.stringValue = currentText

                // 最后一个字符时完成
                if index == characters.count - 1 {
                    completion()
                }
            }
            tasks.append(task)
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(index), execute: task)
        }

        // 任务列表挂到容器上，供下一轮 animate 取消
        objc_setAssociatedObject(containerView, &Self.pendingTasksKey, tasks, .OBJC_ASSOCIATION_RETAIN)
    }

    /// 取消容器上挂着的上一轮打字任务
    private static func cancelPendingTasks(on containerView: NSView) {
        let pending = objc_getAssociatedObject(containerView, &pendingTasksKey) as? [DispatchWorkItem]
        pending?.forEach { $0.cancel() }
    }
}
