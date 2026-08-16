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

        // 自动播放发音
        if AppSettings.shared.autoPlaySpeech {
            SpeechService.shared.speak(word.sourceWord)
        }
    }

    // MARK: - 私有：Timer

    private func startTimer() {
        stopTimer()
        let duration = TimeInterval(AppSettings.shared.stayDuration)
        timer = Timer.scheduledTimer(
            timeInterval: duration,
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

    // MARK: - 进度持久化

    private let progressSectionKey = "ReciteProgressSectionIndex"
    private let progressWordKey = "ReciteProgressWordIndex"
    private let progressFeedbackSetKey = "ReciteProgressFeedbackSet"
    private let progressCompletedLoopsKey = "ReciteProgressCompletedLoops"

    /// 保存当前背记进度到 UserDefaults
    ///
    /// 保存时机：单词切换、Section 完成、App 退出。
    /// 存储内容：Section 索引、单词索引、已反馈集合、走马灯已完成轮次。
    func saveProgress() {
        let defaults = UserDefaults.standard
        defaults.set(currentSectionQueueIndex, forKey: progressSectionKey)
        defaults.set(currentWordIndex, forKey: progressWordKey)
        defaults.set(Array(feedbackSet), forKey: progressFeedbackSetKey)
        defaults.set(completedLoops, forKey: progressCompletedLoopsKey)
    }

    /// 清除持久化的进度数据
    func clearProgress() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: progressSectionKey)
        defaults.removeObject(forKey: progressWordKey)
        defaults.removeObject(forKey: progressFeedbackSetKey)
        defaults.removeObject(forKey: progressCompletedLoopsKey)
    }

    /// 尝试从 UserDefaults 恢复历史进度
    ///
    /// 校验流程：
    /// 1. 检查是否存在已保存的进度
    /// 2. Section 索引不越界
    /// 3. 单词索引不越界
    /// 4. feedbackSet 中的单词 ID 均存在于当前 Section
    /// 5. 走马灯已完成轮次不越界
    ///
    /// 任意校验失败则清除进度，返回 false 由调用方从头开始。
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

        // 移到目标 Section 并重建单词顺序
        currentSectionQueueIndex = savedSectionIndex
        prepareCurrentSection()

        // 校验单词索引
        guard savedWordIndex >= 0 && savedWordIndex < currentWordOrder.count else {
            return resetProgressAndFail()
        }

        // 校验 feedbackSet 中所有单词 ID 存在于当前 Section
        let section = sectionQueue[currentSectionQueueIndex]
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
