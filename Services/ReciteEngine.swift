import Foundation
import CoreData

/// 背记核心引擎
///
/// 负责：
/// - Section 队列构建与流转
/// - 双模式调度（记忆反馈 / 走马灯）
/// - 单词轮换与完成检测
/// - 设置变化重置
///
/// 通过 ReciteEngineDelegate 向 UI 层发送状态变化通知。
class ReciteEngine {

    // MARK: - 状态

    /// 引擎状态
    enum State: Equatable {
        /// 空闲（未启动或已重置）
        case idle
        /// 正在播放
        case playing
        /// 当前 Section 完成，等待流转
        case sectionComplete
        /// 全部完成
        case allComplete
    }

    /// 当前状态
    private(set) var state: State = .idle

    /// 是否处于全部完成状态
    var isAllComplete: Bool {
        return state == .allComplete
    }

    /// 委托，接收状态变化通知
    weak var delegate: ReciteEngineDelegate?

    // MARK: - 队列数据

    /// Section 队列：每个元素为 (wordbookId, sectionIndex, entries)
    private var sectionQueue: [(wordbookId: String, sectionIndex: Int, entries: [WordEntry])] = []

    /// 当前 Section 在队列中的索引
    private var currentSectionQueueIndex: Int = 0

    /// 当前 Section 内的单词顺序（受 playOrder 影响）
    private var currentWordOrder: [Int] = []

    /// 当前单词在 currentWordOrder 中的索引
    private var currentWordIndex: Int = 0

    /// 记忆反馈模式：已反馈的单词 ID 集合
    private var feedbackSet: Set<String> = []

    /// 走马灯模式：当前 Section 已完成的轮次
    private var completedLoops: Int = 0

    /// 当前轮次中已播放的单词数
    private var wordsPlayedInCurrentLoop: Int = 0

    // MARK: - Timer

    private var timer: Timer?

    /// 鼠标悬停悬浮窗时暂停切词计时（两种背记模式一致生效，默认常开无设置开关）
    private var isHoverPaused = false

    /// 暂停时的剩余停留时长（nil 表示无暂停记录）
    private var pausedRemaining: TimeInterval?

    /// 设置/清除悬停暂停
    ///
    /// 暂停：记录当前单词剩余停留时长并停止计时器；
    /// 恢复：按剩余时长重新调度（不重计整段）。
    /// 仅 playing 态操作计时器；标志本身无条件记录——引擎可能随时被 start/restart，
    /// 重启路径经 startTimer 的暂停分支保持暂停语义（新词整段时长入账）。
    ///
    /// 悬浮窗隐藏路径（orderOut 不保证补发 mouseExited）须以 false 调用本方法，
    /// 防止暂停状态残留导致背记永久卡住。
    func setHoverPaused(_ paused: Bool) {
        guard isHoverPaused != paused else { return }
        isHoverPaused = paused

        guard state == .playing else { return }

        if paused {
            if let activeTimer = timer {
                pausedRemaining = max(activeTimer.fireDate.timeIntervalSinceNow, 0)
                stopTimer()
            } else if pausedRemaining == nil {
                // 防御性兜底：无活动计时也无既有记录时按整段时长入账
                pausedRemaining = TimeInterval(AppSettings.shared.stayDuration)
            }
        } else if let remaining = pausedRemaining {
            pausedRemaining = nil
            scheduleTimer(after: max(remaining, 0.05))
        }
    }

    // MARK: - 公开接口

    /// 初始化引擎，监听设置变更
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChange),
            name: .appSettingsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTimingChange),
            name: .appTimingDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWordbookChange),
            name: .wordbookEnablementDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange(_:)),
            name: .favoritesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange(_:)),
            name: .wordbookContentDidChange,
            object: nil
        )
    }

    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
    }

    /// 启动背记（尝试恢复历史进度，无有效进度则从第一个 Section 开始）
    func start() {
        buildQueue()
        guard !sectionQueue.isEmpty else {
            state = .allComplete
            delegate?.engineDidCompleteAll()
            return
        }

        // 尝试从 UserDefaults 恢复历史进度
        if !restoreProgress() {
            currentSectionQueueIndex = 0
            prepareCurrentSection()
            state = .playing
            displayCurrentWord()
        }
    }

    /// 重新开始（从队列第一个 Section 重新开始）
    func restart() {
        clearProgress()
        start()
    }

    /// 停止引擎
    func stop() {
        stopTimer()
        state = .idle
    }

    // MARK: - 用户交互（记忆反馈模式）

    /// 用户标记当前单词为"认识"
    func markKnown() {
        guard state == .playing,
              AppSettings.shared.reciteMode == .memoryFeedback,
              let word = currentWord() else { return }

        feedbackSet.insert(word.wordId)
        advanceToNextWord()
    }

    /// 用户标记当前单词为"不认识"
    ///
    /// 不加入 feedbackSet，保持未反馈状态，单词将在后续轮次重试。
    func markUnknown() {
        guard state == .playing,
              AppSettings.shared.reciteMode == .memoryFeedback,
              currentWord() != nil else { return }

        // 不加入 feedbackSet，单词将在后续轮次再次出现
        advanceToNextWord()
    }

    // MARK: - 当前单词访问

    /// 获取当前单词
    ///
    /// 返回 nil 表示当前状态无效（队列空 / 索引越界），调用方须安全处理。
    func currentWord() -> WordEntry? {
        guard currentSectionQueueIndex < sectionQueue.count else { return nil }
        guard currentWordIndex < currentWordOrder.count else { return nil }
        let section = sectionQueue[currentSectionQueueIndex]
        let index = currentWordOrder[currentWordIndex]
        guard index < section.entries.count else { return nil }
        return section.entries[index]
    }

    /// 获取当前 Section 总单词数
    func currentSectionWordCount() -> Int {
        guard currentSectionQueueIndex < sectionQueue.count else { return 0 }
        return sectionQueue[currentSectionQueueIndex].entries.count
    }

    /// 获取当前 Section 索引（在队列中的位置）
    func currentSectionPosition() -> (index: Int, total: Int) {
        return (currentSectionQueueIndex, sectionQueue.count)
    }

    // MARK: - 私有：队列构建

    /// 从启用的单词本构建 Section 队列
    private func buildQueue() {
        sectionQueue = []
        let wordbooks = WordbookService.shared.getEnabledWordbooks()

        for wordbook in wordbooks {
            let sectionCount = WordbookService.shared.getSectionCount(for: wordbook)
            for sectionIndex in 0..<sectionCount {
                let entries = WordbookService.shared.getEntries(for: wordbook, sectionIndex: sectionIndex)
                if !entries.isEmpty {
                    sectionQueue.append((
                        wordbookId: wordbook.wordbookId,
                        sectionIndex: sectionIndex,
                        entries: entries
                    ))
                }
            }
        }
    }

    // MARK: - 私有：Section 流转

    /// 准备当前 Section（重置内部状态、确定单词顺序）
    private func prepareCurrentSection() {
        feedbackSet.removeAll()
        completedLoops = 0
        wordsPlayedInCurrentLoop = 0
        rebuildWordOrder()
    }

    /// 重建当前 Section 的单词顺序
    private func rebuildWordOrder() {
        guard currentSectionQueueIndex < sectionQueue.count else { return }
        let count = sectionQueue[currentSectionQueueIndex].entries.count
        currentWordOrder = Array(0..<count)

        if AppSettings.shared.playOrder == .shuffled {
            currentWordOrder.shuffle()
        }
        currentWordIndex = 0
    }

    /// 进入下一个 Section
    private func advanceToNextSection() {
        currentSectionQueueIndex += 1
        if currentSectionQueueIndex >= sectionQueue.count {
            // 全部 Section 完成，清除进度
            state = .allComplete
            stopTimer()
            clearProgress()
            delegate?.engineDidCompleteAll()
            return
        }
        state = .playing
        prepareCurrentSection()
        displayCurrentWord()
        // 新 Section 开始后保存进度
        saveProgress()
    }

    // MARK: - 私有：单词切换

    /// 切换到下一个单词
    private func advanceToNextWord() {
        guard currentSectionQueueIndex < sectionQueue.count else { return }

        let section = sectionQueue[currentSectionQueueIndex]
        let mode = AppSettings.shared.reciteMode

        switch mode {
        case .memoryFeedback:
            advanceMemoryFeedback(section: section)
        case .carousel:
            advanceCarousel(section: section)
        }

        // 单词切换后保存进度（若仍在播放状态）
        if state == .playing {
            saveProgress()
        }
    }

    /// 记忆反馈模式的单词推进
    private func advanceMemoryFeedback(section: (wordbookId: String, sectionIndex: Int, entries: [WordEntry])) {
        let totalWords = section.entries.count

        // 当前轮次已完成所有单词的展示
        currentWordIndex += 1

        if currentWordIndex >= currentWordOrder.count {
            // 当前轮次结束
            // 检查是否所有单词都已反馈
            let allFeedback = section.entries.allSatisfy { feedbackSet.contains($0.wordId) }

            if allFeedback {
                // Section 完成
                delegate?.engineDidCompleteSection(
                    sectionIndex: currentSectionQueueIndex,
                    totalSections: sectionQueue.count
                )
                advanceToNextSection()
                return
            }

            // 开始新轮次：仅展示未反馈的单词
            let unfeedbackIndices = currentWordOrder.filter { idx in
                !feedbackSet.contains(section.entries[idx].wordId)
            }
            currentWordOrder = unfeedbackIndices
            if AppSettings.shared.playOrder == .shuffled {
                currentWordOrder.shuffle()
            }
            currentWordIndex = 0
        }

        displayCurrentWord()
    }

    /// 走马灯模式的单词推进
    private func advanceCarousel(section: (wordbookId: String, sectionIndex: Int, entries: [WordEntry])) {
        wordsPlayedInCurrentLoop += 1
        currentWordIndex += 1

        if currentWordIndex >= currentWordOrder.count {
            // 当前轮次结束
            completedLoops += 1
            wordsPlayedInCurrentLoop = 0

            if completedLoops >= AppSettings.shared.carouselLoopCount {
                // Section 完成
                delegate?.engineDidCompleteSection(
                    sectionIndex: currentSectionQueueIndex,
                    totalSections: sectionQueue.count
                )
                advanceToNextSection()
                return
            }

            // 开始新轮次
            rebuildWordOrder()
        }

        displayCurrentWord()
    }

    /// 展示当前单词（启动 Timer、通知 delegate、自动播放发音）
    ///
    /// 不修改 currentWordIndex，仅负责展示索引当前指向的单词。
    /// 用于首次展示（start / 新 Section / 新轮次）和推进后的展示。
    private func displayCurrentWord() {
        guard let word = currentWord() else { return }
        startTimer()
        delegate?.engineDidAdvanceToWord(word)

        // 自动播放发音（语种取自当前词条所属单词本的 sourceLang）
        if AppSettings.shared.autoPlaySpeech {
            SpeechService.shared.speak(word.sourceWord, language: word.wordbook?.sourceLang ?? "en")
        }
    }

    // MARK: - 私有：Timer

    private func startTimer() {
        stopTimer()
        let duration = TimeInterval(AppSettings.shared.stayDuration)

        // 悬停暂停态：不启动计时，新词整段时长入账（恢复时从整段继续）。
        // 该分支同时覆盖"暂停中手动切词"与"鼠标在窗内时引擎重启"两条路径
        if isHoverPaused {
            pausedRemaining = duration
            return
        }
        pausedRemaining = nil
        scheduleTimer(after: duration)
    }

    private func scheduleTimer(after interval: TimeInterval) {
        timer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(timerFired),
            userInfo: nil,
            repeats: false
        )
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func timerFired() {
        guard state == .playing else { return }

        let mode = AppSettings.shared.reciteMode

        switch mode {
        case .memoryFeedback:
            // 超时未反馈，不加入 feedbackSet，直接进入下一单词
            advanceToNextWord()
        case .carousel:
            // 走马灯模式：正常推进
            advanceToNextWord()
        }
    }

    // MARK: - 通知处理

    @objc private func handleSettingsChange() {
        // 背记规则变化时清除进度并重新开始
        stopTimer()
        clearProgress()
        start()
    }

    @objc private func handleTimingChange() {
        // 计时参数变化时仅热更新计时器，不重置进度
        guard state == .playing else { return }
        startTimer()
    }

    @objc private func handleWordbookChange() {
        // 单词本启用状态变化时清除进度并重建队列
        stopTimer()
        clearProgress()
        start()
    }

    /// 队列数据源变更统一入口（favoritesDidChange / wordbookContentDidChange）
    ///
    /// 两个通知的处理体一致（保存进度 → 重建 → 尽量恢复），仅进入条件不同；
    /// 处理幂等：同一变更引发的连续通知先后到达时，
    /// 每次处理均以前次结果为基线，最终状态与单次处理一致。
    @objc private func handleDataChange(_ notification: Notification) {
        if notification.name == .wordbookContentDidChange {
            // 词条内容变更：来源单词本启用、引擎处于播放 / Section 完成态才处理。
            // sectionComplete 视同播放态（当前代码该状态不可达，属 spec 预留），
            // 避免将来可达时该状态下后续 Section 继续使用过期队列
            guard let wordbookId = notification.userInfo?["wordbookId"] as? String,
                  isWordbookEnabled(wordbookId),
                  state == .playing || state == .sectionComplete else { return }
        } else {
            // 收藏内容变化只影响收藏夹单词本对应的 Section：
            // 收藏夹未启用时队列不变，直接忽略，避免不必要的进度重置
            guard WordbookService.shared.getFavoritesWordbook()?.isEnabled == true,
                  state == .playing else { return }
        }

        // 保存当前进度后重建队列；restoreProgress 校验失败
        //（如当前单词已被删除、词库重新导入）则自动从头开始
        saveProgress()
        stopTimer()
        start()
    }

    /// 判断指定单词本是否处于启用状态
    private func isWordbookEnabled(_ wordbookId: String) -> Bool {
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "wordbookId == %@ AND isEnabled == YES", wordbookId)
        request.fetchLimit = 1
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    // MARK: - 进度持久化

    private let progressSectionKey = "ReciteProgressSectionIndex"
    private let progressWordKey = "ReciteProgressWordIndex"
    private let progressFeedbackSetKey = "ReciteProgressFeedbackSet"
    private let progressCompletedLoopsKey = "ReciteProgressCompletedLoops"
    private let progressOrderKey = "ReciteProgressWordOrder"

    /// 保存当前背记进度到 UserDefaults
    ///
    /// 保存时机：单词切换、Section 完成、App 退出。
    /// 存储内容：Section 索引、单词索引、当前轮次播放顺序（wordId）、已反馈集合、走马灯已完成轮次。
    func saveProgress() {
        let defaults = UserDefaults.standard
        defaults.set(currentSectionQueueIndex, forKey: progressSectionKey)
        defaults.set(currentWordIndex, forKey: progressWordKey)
        defaults.set(Array(feedbackSet), forKey: progressFeedbackSetKey)
        defaults.set(completedLoops, forKey: progressCompletedLoopsKey)

        // 持久化当前轮次的播放顺序（按 wordId）。
        // currentWordIndex 的语义依赖 currentWordOrder（shuffle 顺序、记忆反馈后续轮次的
        // "未反馈子集"顺序），不保存顺序就无法还原到确切的单词。
        if currentSectionQueueIndex < sectionQueue.count {
            let entries = sectionQueue[currentSectionQueueIndex].entries
            let orderIds = currentWordOrder.compactMap { index -> String? in
                guard index >= 0 && index < entries.count else { return nil }
                return entries[index].wordId
            }
            defaults.set(orderIds, forKey: progressOrderKey)
        } else {
            defaults.removeObject(forKey: progressOrderKey)
        }
    }

    /// 清除持久化的进度数据
    func clearProgress() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: progressSectionKey)
        defaults.removeObject(forKey: progressWordKey)
        defaults.removeObject(forKey: progressFeedbackSetKey)
        defaults.removeObject(forKey: progressCompletedLoopsKey)
        defaults.removeObject(forKey: progressOrderKey)
    }

    /// 尝试从 UserDefaults 恢复历史进度
    ///
    /// 校验流程：
    /// 1. 检查是否存在已保存的进度
    /// 2. Section 索引不越界
    /// 3. 保存的播放顺序（wordId）无重复，且每个单词都存在于当前 Section
    /// 4. 单词索引不越界（对还原后的顺序校验）
    /// 5. feedbackSet 中的单词 ID 均存在于当前 Section
    /// 6. 走马灯已完成轮次不越界
    ///
    /// 任意校验失败则清除进度，返回 false 由调用方从头开始。
    /// 旧版本进度缺少播放顺序数据时同样视为失效，从头开始（一次性迁移代价）。
    ///
    /// - Returns: 恢复成功返回 true，无有效进度或校验失败返回 false
    private func restoreProgress() -> Bool {
        let defaults = UserDefaults.standard

        // 无已保存的进度（首次启动或进度已清除）
        guard defaults.object(forKey: progressSectionKey) != nil else {
            return false
        }

        let savedSectionIndex = defaults.integer(forKey: progressSectionKey)
        let savedWordIndex = defaults.integer(forKey: progressWordKey)
        let savedFeedbackSet = defaults.stringArray(forKey: progressFeedbackSetKey) ?? []
        let savedCompletedLoops = defaults.integer(forKey: progressCompletedLoopsKey)

        // 校验 Section 索引（此时 currentSectionQueueIndex 尚未修改，仅需 clearProgress）
        guard savedSectionIndex >= 0 && savedSectionIndex < sectionQueue.count else {
            clearProgress()
            return false
        }

        // 移到目标 Section 并重置轮次状态（单词顺序稍后用保存值覆盖）
        currentSectionQueueIndex = savedSectionIndex
        prepareCurrentSection()

        let section = sectionQueue[currentSectionQueueIndex]

        // 还原保存时的播放顺序：wordId 映射回 Section 内索引
        guard let savedOrderIds = defaults.stringArray(forKey: progressOrderKey),
              !savedOrderIds.isEmpty,
              savedOrderIds.count == Set(savedOrderIds).count else {
            return resetProgressAndFail()
        }

        var indexByWordId: [String: Int] = [:]
        for (index, entry) in section.entries.enumerated() {
            if indexByWordId[entry.wordId] == nil {
                indexByWordId[entry.wordId] = index
            }
        }
        let restoredOrder = savedOrderIds.compactMap { indexByWordId[$0] }
        guard restoredOrder.count == savedOrderIds.count else {
            // 词库已变化（如重新导入），保存顺序中的单词不存在
            return resetProgressAndFail()
        }
        currentWordOrder = restoredOrder

        // 校验单词索引（对还原后的顺序）
        guard savedWordIndex >= 0 && savedWordIndex < currentWordOrder.count else {
            return resetProgressAndFail()
        }

        // 校验 feedbackSet 中所有单词 ID 存在于当前 Section
        let sectionWordIds = Set(section.entries.map { $0.wordId })
        for wordId in savedFeedbackSet {
            if !sectionWordIds.contains(wordId) {
                return resetProgressAndFail()
            }
        }

        // 校验走马灯已完成轮次
        let loopCount = AppSettings.shared.carouselLoopCount
        guard savedCompletedLoops >= 0 && savedCompletedLoops < loopCount else {
            return resetProgressAndFail()
        }

        // 恢复状态
        feedbackSet = Set(savedFeedbackSet)
        currentWordIndex = savedWordIndex
        completedLoops = savedCompletedLoops
        state = .playing
        displayCurrentWord()
        return true
    }

    /// 清除进度并重置到初始状态，返回 false 供 restoreProgress 校验失败时使用
    private func resetProgressAndFail() -> Bool {
        clearProgress()
        currentSectionQueueIndex = 0
        prepareCurrentSection()
        return false
    }
}

// MARK: - Delegate Protocol

/// 背记引擎委托
///
/// FloatWindowController 实现此协议以接收引擎事件。
protocol ReciteEngineDelegate: AnyObject {
    /// 引擎推进到新单词
    func engineDidAdvanceToWord(_ word: WordEntry)

    /// 当前 Section 完成
    func engineDidCompleteSection(sectionIndex: Int, totalSections: Int)

    /// 所有 Section 完成
    func engineDidCompleteAll()
}
