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

    /// 走马灯模式：当前 Section 已完成的轮次
    private var completedLoops: Int = 0

    // MARK: - 记忆反馈（SRS 全局复习队列）状态

    /// 记忆反馈批次单词状态
    private enum MemoryWordState: Int, Codable {
        /// 待展示
        case pending = 0
        /// 待重现（延迟计数隐含于批次展示列表插入位置，持久化即保序）
        case pendingRedisplay = 1
        /// 已通过（认识）
        case passed = 2
        /// 已放行（曝光达标）
        case released = 3
    }

    /// 当前记忆反馈批次
    private struct MemoryBatch {
        /// 有序展示列表：含重现插入的重复实例，位置即含延迟语义
        var wordIds: [String] = []
        /// 各单词会话状态
        var states: [String: MemoryWordState] = [:]
        /// 本会话曝光计数
        var exposures: [String: Int] = [:]
        /// 当前展示索引
        var index: Int = 0
    }

    /// 启用词库的 wordId → 词条 映射（记忆反馈取词用）
    private var entryByWordId: [String: WordEntry] = [:]
    /// 当前记忆反馈批次
    private var memoryBatch: MemoryBatch?
    /// 当前批次序号（delegate 报告用）
    private var memoryBatchIndex: Int = 0
    /// 预计总批次数（delegate 报告用）
    private var memoryTotalBatches: Int = 0

    /// 本会话剩余可调度的到期复习词预算（nil = 不限）
    ///
    /// 会话级：新开始由 AppSettings.sessionReviewCap 初始化（0 = 不限），
    /// 随进度持久化，中断恢复后按剩余预算继续，累计至预算耗尽。
    private var sessionReviewBudgetRemaining: Int?

    // MARK: - Timer

    private var timer: Timer?

    /// 瞬时暂停源：鼠标悬停悬浮窗 / 动效预览（两种背记模式一致生效，默认常开无设置开关）
    ///
    /// 该来源随鼠标位置与窗口可见性起伏，窗口隐藏时调用方须以 false 归位。
    private var isTransientPaused = false

    /// 用户暂停源：右键菜单主动发起的"暂停背记"
    ///
    /// 与瞬时暂停的区别：不随鼠标进出、不随窗口隐藏而解除，仅由用户再次点击菜单解除；
    /// 纯内存态，不跨应用重启保留。
    private(set) var isUserPaused = false

    /// 是否存在任一暂停来源
    private var isPaused: Bool {
        isTransientPaused || isUserPaused
    }

    /// 是否处于用户暂停（供调用方判断发音挂起能否安全解除）
    var isUserPausedActive: Bool {
        isUserPaused
    }

    /// 暂停时的剩余停留时长（nil 表示无暂停记录）
    private var pausedRemaining: TimeInterval?

    /// 挂起自动发音（全屏隐藏静音 / 用户暂停路径）
    ///
    /// 仅拦新播报、不暂停切词进度：窗口隐藏静音期间引擎照常流转，
    /// 显示恢复后下一个单词自然恢复发音
    private var isSpeechSuppressed = false

    /// 设置/清除发音挂起（挂起前调用方须同时停止在播语音）
    func setSpeechSuppressed(_ suppressed: Bool) {
        isSpeechSuppressed = suppressed
    }

    /// 设置/清除瞬时暂停（悬停 / 预览）
    ///
    /// 暂停：记录当前单词剩余停留时长并停止计时器；
    /// 恢复：按剩余时长重新调度（不重计整段）。
    /// 悬浮窗隐藏路径（orderOut 不保证补发 mouseExited）须以 false 调用本方法，
    /// 防止暂停状态残留导致背记永久卡住。
    func setHoverPaused(_ paused: Bool) {
        let wasPaused = isPaused
        guard isTransientPaused != paused else { return }
        isTransientPaused = paused
        applyPauseState(wasPaused: wasPaused)
    }

    /// 设置/清除用户暂停（右键菜单"暂停背记 / 继续背记"）
    ///
    /// 计时副作用与瞬时暂停完全一致（冻结 + 剩余时长续计）；
    /// 发音挂起由调用方成对处理（挂起时停止在播语音，解除时视静音状态决定是否恢复）。
    func setUserPaused(_ paused: Bool) {
        let wasPaused = isPaused
        guard isUserPaused != paused else { return }
        isUserPaused = paused
        applyPauseState(wasPaused: wasPaused)
    }

    /// 合并各暂停来源后施加计时副作用
    ///
    /// 按 `wasPaused → isPaused` 的**迁移边沿**判定，不能用"合并值未变即跳过"做守卫：
    /// 否则瞬时暂停已为真时叠加用户暂停（true → true）会吞掉这次切换，
    /// 剩余时长停留在更早的取值上。
    /// 标志本身无条件记录——引擎可能随时被 start/restart，
    /// 重启路径经 startTimer 的暂停分支保持暂停语义（新词整段时长入账）。
    private func applyPauseState(wasPaused: Bool) {
        guard state == .playing else { return }

        if isPaused, !wasPaused {
            if let activeTimer = timer {
                pausedRemaining = max(activeTimer.fireDate.timeIntervalSinceNow, 0)
                stopTimer()
            } else if pausedRemaining == nil {
                // 防御性兜底：无活动计时也无既有记录时按整段时长入账
                pausedRemaining = TimeInterval(AppSettings.shared.stayDuration)
            }
        } else if !isPaused, wasPaused {
            // 缺失记录时按整段时长兜底，杜绝"无计时器又无剩余记录"的永久停住
            let remaining = pausedRemaining ?? TimeInterval(AppSettings.shared.stayDuration)
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

    /// 启动背记（优先续背锚点 → 进行中进度 → 按策略新开始）
    func start() {
        buildQueue()
        guard !sectionQueue.isEmpty else {
            state = .allComplete
            delegate?.engineDidCompleteAll()
            return
        }

        // 记忆反馈模式：全局复习队列主体，不走 Section 逐节流转
        if AppSettings.shared.reciteMode == .memoryFeedback {
            startMemoryFeedback()
            return
        }

        // 优先级 1：续背锚点（上一轮全部完成后记录的离开位置）
        if resumeFromContinuationAnchor() { return }

        // 优先级 2：进行中进度（含队列布局还原）
        if restoreProgress() { return }

        // 优先级 3：按当前策略新开始（随机化在此执行）
        applySectionOrderStrategy()
        currentSectionQueueIndex = 0
        prepareCurrentSection()
        state = .playing
        displayCurrentWord()
    }

    /// 重新开始（清除续背锚点与进度，按当前策略从策略起点开始）
    ///
    /// 记忆反馈模式下仅清除会话进度并重排，ReviewState（掌握度）保留。
    func restart() {
        clearProgress()
        start()
    }

    /// 重置学习记录（清除全部 ReviewState + 会话进度，按当前策略重新开始）
    ///
    /// 与 restart() 语义区分：restart 保留掌握度，本方法彻底清空跨会话复习记录。
    func resetLearningRecord() {
        ReviewStateService.shared.resetAll()
        clearProgress()
        start()
    }

    /// 停止引擎
    func stop() {
        stopTimer()
        state = .idle
    }

    // MARK: - 用户交互（记忆反馈模式）

    /// 用户标记当前单词为"认识"（✓）
    func markKnown() {
        guard state == .playing,
              AppSettings.shared.reciteMode == .memoryFeedback,
              let word = currentWord() else { return }

        handleMemoryFeedback(.known, for: word.wordId)
    }

    /// 用户标记当前单词为"模糊"（↺ 按钮）
    func markVague() {
        guard state == .playing,
              AppSettings.shared.reciteMode == .memoryFeedback,
              let word = currentWord() else { return }

        handleMemoryFeedback(.vague, for: word.wordId)
    }

    // MARK: - 当前单词访问

    /// 获取当前单词
    ///
    /// 返回 nil 表示当前状态无效（队列空 / 索引越界），调用方须安全处理。
    /// 记忆反馈模式从当前批次取词；走马灯模式从 Section 队列取词。
    func currentWord() -> WordEntry? {
        if AppSettings.shared.reciteMode == .memoryFeedback {
            return currentMemoryWord()
        }
        guard currentSectionQueueIndex < sectionQueue.count else { return nil }
        guard currentWordIndex < currentWordOrder.count else { return nil }
        let section = sectionQueue[currentSectionQueueIndex]
        let index = currentWordOrder[currentWordIndex]
        guard index < section.entries.count else { return nil }
        return section.entries[index]
    }

    /// 记忆反馈模式当前批次词
    private func currentMemoryWord() -> WordEntry? {
        guard let batch = memoryBatch, batch.index < batch.wordIds.count else { return nil }
        return entryByWordId[batch.wordIds[batch.index]]
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

    /// 从启用的单词本构建 Section 队列（确定性基础队列，不含策略应用）
    private func buildQueue() {
        sectionQueue = []
        let wordbooks = WordbookService.shared.getEnabledWordbooks()

        for wordbook in wordbooks {
            let sections = WordbookService.shared.getAllEntriesGroupedBySection(for: wordbook)
            for (sectionIndex, entries) in sections.enumerated() where !entries.isEmpty {
                sectionQueue.append((
                    wordbookId: wordbook.wordbookId,
                    sectionIndex: sectionIndex,
                    entries: entries
                ))
            }
        }
    }

    /// 按当前 Section 顺序策略应用随机化（仅新开始路径调用）
    ///
    /// sequential 恒等；randomStart 随机选起点 rotate（环形语义由 rotate 表达，
    /// 推进逻辑零改动）；shuffled 整体打乱。单 Section 队列无随机空间，天然退化。
    private func applySectionOrderStrategy() {
        guard sectionQueue.count > 1 else { return }

        switch AppSettings.shared.sectionOrder {
        case .sequential:
            break
        case .randomStart:
            let start = Int.random(in: 0..<sectionQueue.count)
            sectionQueue.rotate(toStartAt: start)
        case .shuffled:
            sectionQueue.shuffle()
        }
    }

    // MARK: - 私有：Section 流转

    /// 准备当前 Section（重置内部状态、确定单词顺序）
    private func prepareCurrentSection() {
        completedLoops = 0
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
            // 全部 Section 完成：记录续背锚点（进度保留，下次 start 从下一组继续）
            state = .allComplete
            stopTimer()
            clearProgress()
            saveContinuationAnchor()
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
        switch AppSettings.shared.reciteMode {
        case .memoryFeedback:
            advanceMemoryFeedback()
        case .carousel:
            guard currentSectionQueueIndex < sectionQueue.count else { return }
            advanceCarousel(section: sectionQueue[currentSectionQueueIndex])
        }

        // 单词切换后保存进度（若仍在播放状态）
        if state == .playing {
            saveProgress()
        }
    }

    /// 记忆反馈模式的单词推进（批次内线性展示 + 重现词已预插于列表）
    private func advanceMemoryFeedback() {
        guard var batch = memoryBatch else { return }
        batch.index += 1

        // 批次末尾：说明批内单词均已解决（认识/放行）或重现词已耗尽
        if batch.index >= batch.wordIds.count {
            memoryBatch = nil
            delegate?.engineDidCompleteSection(
                sectionIndex: memoryBatchIndex,
                totalSections: memoryTotalBatches
            )
            memoryBatchIndex += 1
            guard buildNextMemoryBatch() else {
                finishMemoryAllComplete()
                return
            }
            state = .playing
            displayCurrentWord()
            saveProgress()
            return
        }

        memoryBatch = batch
        displayCurrentWord()
    }

    /// 走马灯模式的单词推进
    private func advanceCarousel(section: (wordbookId: String, sectionIndex: Int, entries: [WordEntry])) {
        currentWordIndex += 1

        if currentWordIndex >= currentWordOrder.count {
            // 当前轮次结束
            completedLoops += 1

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

        // 记忆反馈模式：展示计数计入本会话曝光量（阈值放行判定依据）
        if AppSettings.shared.reciteMode == .memoryFeedback, var batch = memoryBatch {
            batch.exposures[word.wordId] = (batch.exposures[word.wordId] ?? 0) + 1
            memoryBatch = batch
        }

        startTimer()
        delegate?.engineDidAdvanceToWord(word)

        // 自动播放发音（语种取自当前词条所属单词本的 sourceLang）；
        // 全屏静音挂起期间跳过
        if AppSettings.shared.autoPlaySpeech, !isSpeechSuppressed {
            SpeechService.shared.speak(word.sourceWord, language: word.wordbook?.sourceLang ?? Constants.defaultSourceLang)
        }
    }

    // MARK: - 私有：Timer

    private func startTimer() {
        stopTimer()
        let duration = TimeInterval(AppSettings.shared.stayDuration)

        // 暂停态（瞬时 / 用户任一来源）：不启动计时，新词整段时长入账（恢复时从整段继续）。
        // 该分支同时覆盖"暂停中手动切词"与"暂停期间引擎重启"两条路径
        if isPaused {
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
            // 停留时长耗尽自动记为「不认识」，立即推进至下一单词
            if let word = currentWord() {
                handleMemoryFeedback(.unknown, for: word.wordId)
            } else {
                advanceToNextWord()
            }
        case .carousel:
            // 走马灯模式：正常推进
            advanceToNextWord()
        }
    }

    // MARK: - 记忆反馈调度（全局复习队列）

    /// 启动记忆反馈会话：尝试恢复进度，否则按全局复习队列构建首批
    private func startMemoryFeedback() {
        // 新词分批须按 sectionOrder 策略组织（randomStart 旋转 / shuffled 打乱），
        // 与走马灯共用同一策略应用入口；restoreMemoryProgress 会以保存的批次覆盖会话状态
        applySectionOrderStrategy()
        buildEntryByWordId()
        computeMemoryPlan()

        if restoreMemoryProgress() { return }

        // 无有效进度：开启新会话，重置会话复习预算（0 = 不限）
        let cap = AppSettings.shared.sessionReviewCap
        sessionReviewBudgetRemaining = cap > 0 ? cap : nil
        memoryBatchIndex = 0
        guard buildNextMemoryBatch(rebuildPlan: false) else {
            finishMemoryAllComplete()
            return
        }
        state = .playing
        displayCurrentWord()
    }

    /// 构建 wordId → 词条 映射（启用词库池）
    private func buildEntryByWordId() {
        entryByWordId = [:]
        for section in sectionQueue {
            for entry in section.entries {
                entryByWordId[entry.wordId] = entry
            }
        }
    }

    /// 计算预计总批次数（delegate 报告用）
    private func computeMemoryPlan() {
        let now = Date()
        let dueCount = ReviewStateService.shared.dueStates(at: now).filter { entryByWordId[$0.wordId] != nil }.count
        let newCount = enabledWordIdsInOrder().filter { ReviewStateService.shared.state(for: $0) == nil }.count
        let size = max(AppSettings.shared.sectionSize, 1)
        memoryTotalBatches = max(1, Int(ceil(Double(dueCount + newCount) / Double(size))))
    }

    /// 启用词库按词源构建顺序的 wordId 列表（新词分批池）
    private func enabledWordIdsInOrder() -> [String] {
        var ids: [String] = []
        for section in sectionQueue {
            for entry in section.entries {
                ids.append(entry.wordId)
            }
        }
        return ids
    }

    /// 处理一次记忆反馈：更新 ReviewState + 会话内状态 + 推进
    private func handleMemoryFeedback(_ feedback: ReviewFeedback, for wordId: String) {
        guard var batch = memoryBatch else { return }

        // 跨会话：记录掌握度（即时落盘）
        ReviewStateService.shared.record(feedback: feedback, for: wordId)

        let currentIndex = batch.index
        if feedback == .known {
            batch.states[wordId] = .passed
        } else {
            let exposure = batch.exposures[wordId] ?? 0
            if exposure >= AppSettings.shared.maxExposureRounds {
                // 曝光达标放行：本会话不再重现
                batch.states[wordId] = .released
            } else {
                // 延迟重现：插入到当前索引之后 delay+1 个位置（当前实例随后被推进越过）
                batch.states[wordId] = .pendingRedisplay
                let delay = feedback == .vague ? Constants.vagueRetryDelay : Constants.unknownRetryDelay
                let insertPos = min(currentIndex + delay + 1, batch.wordIds.count)
                if insertPos >= 0 && insertPos <= batch.wordIds.count {
                    batch.wordIds.insert(wordId, at: insertPos)
                }
            }
        }

        memoryBatch = batch
        advanceToNextWord()
    }

    /// 构建下一记忆反馈批次；无词可调度时返回 false（由调用方决定收尾）
    ///
    /// `rebuildPlan` 默认 false：记忆反馈批次流转到下一批时沿用启动时的批次估算，
    /// 避免每次转批都重算 `memoryTotalBatches`（估算值即可满足 delegate 报告需求）。
    private func buildNextMemoryBatch(rebuildPlan: Bool = false) -> Bool {
        if rebuildPlan { computeMemoryPlan() }
        let excluded = Set(memoryBatch?.wordIds ?? [])
        return buildMemoryBatchExcluding(excluded)
    }

    /// 按排除集构建一批（先到期复习词、后新词补足）
    private func buildMemoryBatchExcluding(_ excluded: Set<String>) -> Bool {
        let size = max(AppSettings.shared.sectionSize, 1)
        let now = Date()

        // 到期复习词：存在 ReviewState 且 dueAt <= now，按 dueAt 升序（服务已排序）
        let due = ReviewStateService.shared.dueStates(at: now)
            .map { $0.wordId }
            .filter { entryByWordId[$0] != nil && !excluded.contains($0) }

        // 会话复习预算：本次批次纳入的到期词数受剩余预算约束（预算耗尽后不再拉取到期词）
        var scheduledDueCount = min(due.count, size)
        if let budget = sessionReviewBudgetRemaining {
            scheduledDueCount = min(scheduledDueCount, budget)
            sessionReviewBudgetRemaining = budget - scheduledDueCount
        }
        let dueWords = Array(due.prefix(scheduledDueCount))

        // 新词：无 ReviewState，按词源构建顺序
        var news = enabledWordIdsInOrder().filter {
            !excluded.contains($0) &&
            entryByWordId[$0] != nil &&
            ReviewStateService.shared.state(for: $0) == nil
        }
        if AppSettings.shared.playOrder == .shuffled {
            news.shuffle()
        }

        var wordIds: [String] = []
        wordIds.append(contentsOf: dueWords)
        let fill = size - wordIds.count
        if fill > 0 { wordIds.append(contentsOf: news.prefix(fill)) }

        guard !wordIds.isEmpty else { return false }

        var batch = MemoryBatch()
        batch.wordIds = wordIds
        for wordId in wordIds {
            batch.states[wordId] = .pending
            batch.exposures[wordId] = 0
        }
        memoryBatch = batch
        return true
    }

    /// 记忆反馈全队列完成：清除进度、进入已学完（不写续背锚点）
    private func finishMemoryAllComplete() {
        state = .allComplete
        stopTimer()
        clearMemoryProgress()
        delegate?.engineDidCompleteAll()
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

    private let progressSectionKey = "ReciteProgressSectionIdentity"
    private let progressWordKey = "ReciteProgressWordIndex"
    private let progressFeedbackSetKey = "ReciteProgressFeedbackSet"
    private let progressCompletedLoopsKey = "ReciteProgressCompletedLoops"
    private let progressOrderKey = "ReciteProgressWordOrder"
    private let progressLayoutKey = "ReciteProgressQueueLayout"
    private let continuationAnchorKey = "ReciteProgressLastCompleted"
    private let memoryProgressKey = "ReciteProgressBatchState"

    /// 记忆反馈进度载荷版本（不兼容改动时递增）
    ///
    /// v1：批次展示列表 + 会话状态 + 曝光计数
    /// v2：新增 reviewBudgetRemaining（会话复习预算随进度持久化）
    private let memoryProgressFormatVersion = 2

    /// 记忆反馈进度载荷（专用新键，formatVersion 标记）
    ///
    /// 与走马灯既有键位隔离；批次展示列表保序即含重现延迟语义，
    /// 恢复时据此还原到确切单词且重试节奏不断。
    private struct MemoryProgress: Codable {
        let formatVersion: Int
        let batchWordIds: [String]
        let wordStates: [String: MemoryWordState]
        let exposureCounts: [String: Int]
        let index: Int
        let batchIndex: Int
        /// 本会话剩余复习预算（nil = 不限）
        let reviewBudgetRemaining: Int?
    }

    /// Section 身份标识（身份寻址，队列索引的替代）
    ///
    /// Codable 存 UserDefaults；同一词本内 sectionIndex 天然唯一。
    struct SectionIdentity: Codable, Equatable, Hashable {
        let wordbookId: String
        let sectionIndex: Int
    }

    /// 队列布局快照（恢复时套用到确定性重建的基础队列）
    enum QueueLayout: Codable {
        /// sequential：布局即基础队列，无需存储
        case identity
        /// randomStart：起点身份，恢复时 rotate 至该起点
        case randomStart(SectionIdentity)
        /// shuffled：完整身份列表，恢复时按列表重排（消失身份剔除）
        case shuffled([SectionIdentity])
    }

    /// 保存当前背记进度到 UserDefaults（身份寻址）
    ///
    /// 保存时机：单词切换、Section 完成、App 退出。
    /// 存储内容：当前 Section 身份、单词索引、当前轮次播放顺序（wordId）、
    /// 走马灯已完成轮次、队列布局快照。
    func saveProgress() {
        // 记忆反馈模式走专用进度键；其余走马灯既有路径
        guard AppSettings.shared.reciteMode == .memoryFeedback else {
            saveCarouselProgress()
            return
        }
        saveMemoryProgress()
    }

    /// 保存走马灯进度（身份寻址）
    private func saveCarouselProgress() {
        let defaults = UserDefaults.standard

        guard currentSectionQueueIndex < sectionQueue.count else { return }
        let section = sectionQueue[currentSectionQueueIndex]

        // 当前 Section 身份
        let identity = SectionIdentity(
            wordbookId: section.wordbookId,
            sectionIndex: section.sectionIndex
        )
        encodeToDefaults(identity, forKey: progressSectionKey)

        // 队列布局快照（sequential 不存，缺省即 identity）
        let layout = currentQueueLayout()
        if case .identity = layout {
            defaults.removeObject(forKey: progressLayoutKey)
        } else {
            encodeToDefaults(layout, forKey: progressLayoutKey)
        }

        defaults.set(currentWordIndex, forKey: progressWordKey)
        defaults.set(completedLoops, forKey: progressCompletedLoopsKey)

        // 持久化当前轮次的播放顺序（按 wordId）。
        // currentWordIndex 的语义依赖 currentWordOrder（shuffle 顺序），
        // 不保存顺序就无法还原到确切的单词。
        let entries = section.entries
        let orderIds = currentWordOrder.compactMap { index -> String? in
            guard index >= 0 && index < entries.count else { return nil }
            return entries[index].wordId
        }
        defaults.set(orderIds, forKey: progressOrderKey)
    }

    /// 保存记忆反馈进度（专用新键，含批次展示列表 + 会话状态 + 曝光计数）
    private func saveMemoryProgress() {
        guard let batch = memoryBatch, !batch.wordIds.isEmpty else {
            clearMemoryProgress()
            return
        }
        let progress = MemoryProgress(
            formatVersion: memoryProgressFormatVersion,
            batchWordIds: batch.wordIds,
            wordStates: batch.states,
            exposureCounts: batch.exposures,
            index: batch.index,
            batchIndex: memoryBatchIndex,
            reviewBudgetRemaining: sessionReviewBudgetRemaining
        )
        encodeToDefaults(progress, forKey: memoryProgressKey)
    }

    /// 计算当前队列的布局快照
    private func currentQueueLayout() -> QueueLayout {
        switch AppSettings.shared.sectionOrder {
        case .sequential:
            return .identity
        case .randomStart:
            guard let first = sectionQueue.first else { return .identity }
            return .randomStart(SectionIdentity(
                wordbookId: first.wordbookId,
                sectionIndex: first.sectionIndex
            ))
        case .shuffled:
            return .shuffled(sectionQueue.map {
                SectionIdentity(wordbookId: $0.wordbookId, sectionIndex: $0.sectionIndex)
            })
        }
    }

    /// 清除持久化的进度数据（含续背锚点与旧索引格式残留）
    func clearProgress() {
        let defaults = UserDefaults.standard
        // 旧版本索引寻址键一并清除（一次性迁移）
        defaults.removeObject(forKey: "ReciteProgressSectionIndex")
        defaults.removeObject(forKey: progressSectionKey)
        defaults.removeObject(forKey: progressWordKey)
        defaults.removeObject(forKey: progressFeedbackSetKey)
        defaults.removeObject(forKey: progressCompletedLoopsKey)
        defaults.removeObject(forKey: progressOrderKey)
        defaults.removeObject(forKey: progressLayoutKey)
        defaults.removeObject(forKey: continuationAnchorKey)
        // 记忆反馈专用进度键一并清除
        clearMemoryProgress()
    }

    /// 清除记忆反馈进度键（含旧记忆反馈残留键）
    private func clearMemoryProgress() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: memoryProgressKey)
        // 旧记忆反馈 feedbackSet 键位残留一次性清理
        defaults.removeObject(forKey: progressFeedbackSetKey)
        memoryBatch = nil
    }

    /// 尝试从 UserDefaults 恢复记忆反馈进度（专用键 + formatVersion 校验）
    ///
    /// 校验批次词单中的 wordId 均存在于当前启用词库、会话状态与曝光计数
    /// 均不越界（key 属于批次词单）；失败则清除并回退重建。恢复时跳过
    /// 已通过/已放行单词，直达仍然待展示的词。
    ///
    /// - Returns: 恢复成功返回 true，无有效进度或校验失败返回 false
    private func restoreMemoryProgress() -> Bool {
        // 旧格式（无 formatVersion 的记忆反馈进度）一次性失效清零
        guard let saved = decodeFromDefaults(MemoryProgress.self, forKey: memoryProgressKey) else {
            // 键缺失（首次/已清）与旧格式/损坏载荷统一在此清零，避免残留影响后续启动
            clearMemoryProgress()
            return false
        }
        guard saved.formatVersion == memoryProgressFormatVersion else {
            clearMemoryProgress()
            return false
        }

        // 记忆反馈批次允许重复 wordId（延迟重现会向展示列表插入第二副本），
        // 故不做唯一性校验；仅用 Set 集合作 key 包含性判定
        let batchWordIdSet = Set(saved.batchWordIds)
        // wordId 均存在于当前启用词库
        for wordId in saved.batchWordIds where entryByWordId[wordId] == nil {
            clearMemoryProgress()
            return false
        }
        // 会话状态与曝光计数 key 均属于批次词单
        for key in saved.wordStates.keys where !batchWordIdSet.contains(key) {
            clearMemoryProgress()
            return false
        }
        for key in saved.exposureCounts.keys where !batchWordIdSet.contains(key) {
            clearMemoryProgress()
            return false
        }
        guard saved.index >= 0, saved.index <= saved.batchWordIds.count else {
            clearMemoryProgress()
            return false
        }

        memoryBatchIndex = max(saved.batchIndex, 0)
        var batch = MemoryBatch()
        batch.wordIds = saved.batchWordIds
        batch.states = saved.wordStates
        batch.exposures = saved.exposureCounts

        // 跳过已通过/放行词，直达待展示位置
        var idx = saved.index
        while idx < batch.wordIds.count {
            let wordId = batch.wordIds[idx]
            if let state = batch.states[wordId], state == .passed || state == .released {
                idx += 1
            } else {
                break
            }
        }
        guard idx < batch.wordIds.count else {
            clearMemoryProgress()
            return false
        }
        batch.index = idx
        memoryBatch = batch
        // 会话复习预算随进度恢复（nil = 不限；负数视为无效清 0）
        sessionReviewBudgetRemaining = saved.reviewBudgetRemaining.map { max($0, 0) }

        state = .playing
        displayCurrentWord()
        return true
    }

    /// 尝试从 UserDefaults 恢复历史进度（身份寻址 + 布局还原）
    ///
    /// 校验流程：
    /// 1. 检查是否存在已保存的进度（新身份键；旧索引键存在即视为失效清零）
    /// 2. 套用保存的队列布局到确定性重建的基础队列（身份失效剔除，全失效则回退）
    /// 3. 按身份定位当前 Section（找不到即回退）
    /// 4. 保存的播放顺序（wordId）无重复，且每个单词都存在于当前 Section
    /// 5. 单词索引不越界（对还原后的顺序校验）
    /// 6. 走马灯已完成轮次不越界
    ///
    /// 任意校验失败则清除进度，返回 false 由调用方按策略新开始。
    ///
    /// - Returns: 恢复成功返回 true，无有效进度或校验失败返回 false
    private func restoreProgress() -> Bool {
        let defaults = UserDefaults.standard

        // 旧版本索引寻址进度：一次性失效，清零后按策略开始
        if defaults.object(forKey: "ReciteProgressSectionIndex") != nil,
           defaults.object(forKey: progressSectionKey) == nil {
            clearProgress()
            return false
        }

        // 无已保存的进度（首次启动或进度已清除）
        guard let savedIdentity = decodeFromDefaults(SectionIdentity.self, forKey: progressSectionKey) else {
            return false
        }

        // 套用保存的队列布局（身份失效剔除；全失效回退由后续定位判定兜底）
        applySavedLayout()

        // 按身份定位当前 Section
        guard let queueIndex = sectionQueue.firstIndex(where: {
            $0.wordbookId == savedIdentity.wordbookId && $0.sectionIndex == savedIdentity.sectionIndex
        }) else {
            // 身份不在队列（词本停用/Section 消失）：回退新开始
            return resetProgressAndFail()
        }

        currentSectionQueueIndex = queueIndex
        prepareCurrentSection()

        let section = sectionQueue[currentSectionQueueIndex]
        let savedWordIndex = defaults.integer(forKey: progressWordKey)
        let savedCompletedLoops = defaults.integer(forKey: progressCompletedLoopsKey)

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

        // 校验走马灯已完成轮次
        let loopCount = AppSettings.shared.carouselLoopCount
        guard savedCompletedLoops >= 0 && savedCompletedLoops < loopCount else {
            return resetProgressAndFail()
        }

        // 恢复状态
        currentWordIndex = savedWordIndex
        completedLoops = savedCompletedLoops
        state = .playing
        displayCurrentWord()
        return true
    }

    /// 将保存的队列布局套用到确定性重建的基础队列上
    ///
    /// 布局身份不在队列中的（词本停用/删除）：randomStart 起点失效回退 identity；
    /// shuffled 列表剔除失效项后重排（全部失效则保持基础队列，由后续身份定位兜底回退）。
    private func applySavedLayout() {
        guard let layout = decodeFromDefaults(QueueLayout.self, forKey: progressLayoutKey) else {
            return // 无布局（sequential 或旧进度），基础队列即布局
        }

        switch layout {
        case .identity:
            break
        case .randomStart(let start):
            if let index = sectionQueue.firstIndex(where: {
                $0.wordbookId == start.wordbookId && $0.sectionIndex == start.sectionIndex
            }) {
                sectionQueue.rotate(toStartAt: index)
            }
            // 起点身份失效：保持基础队列，身份定位失败会走回退路径
        case .shuffled(let identities):
            var byIdentity: [SectionIdentity: (wordbookId: String, sectionIndex: Int, entries: [WordEntry])] = [:]
            for section in sectionQueue {
                byIdentity[SectionIdentity(wordbookId: section.wordbookId, sectionIndex: section.sectionIndex)] = section
            }
            // 按保存顺序重排，仅保留仍存在于队列的 Section
            let restored = identities.compactMap { byIdentity[$0] }
            if restored.count == sectionQueue.count {
                sectionQueue = restored
            } else {
                // 布局部分失效：保持基础队列（部分重排会产生与身份定位不一致的语义，
                // 交由身份定位失败兜底回退到策略新开始，行为更可预测）
            }
        }
    }

    /// 全部完成时记录续背锚点（最后完成 Section 的身份）
    ///
    /// 在 clearProgress 之后调用：进行中进度已清除，仅留锚点键，
    /// 与进行中进度天然互斥。
    private func saveContinuationAnchor() {
        guard currentSectionQueueIndex - 1 >= 0, currentSectionQueueIndex - 1 < sectionQueue.count else { return }
        let section = sectionQueue[currentSectionQueueIndex - 1]
        encodeToDefaults(
            SectionIdentity(wordbookId: section.wordbookId, sectionIndex: section.sectionIndex),
            forKey: continuationAnchorKey
        )
    }

    /// 续背锚点恢复：从锚点的下一 Section（环形）开始新的一轮
    ///
    /// - Returns: 成功恢复返回 true；无锚点或锚点身份失效返回 false（回退正常启动路径）
    private func resumeFromContinuationAnchor() -> Bool {
        guard let anchor = decodeFromDefaults(SectionIdentity.self, forKey: continuationAnchorKey) else {
            return false
        }

        // 锚点身份定位（基础队列即可，续背轮的推进顺序与布局无关紧要）
        guard let anchorIndex = sectionQueue.firstIndex(where: {
            $0.wordbookId == anchor.wordbookId && $0.sectionIndex == anchor.sectionIndex
        }) else {
            // 词本已停用等：锚点失效，清除后走正常路径
            UserDefaults.standard.removeObject(forKey: continuationAnchorKey)
            return false
        }

        // 下一 Section 环形绕回；锚点清除（新轮进度由正常保存路径接管）
        UserDefaults.standard.removeObject(forKey: continuationAnchorKey)
        currentSectionQueueIndex = (anchorIndex + 1) % sectionQueue.count
        prepareCurrentSection()
        state = .playing
        displayCurrentWord()
        saveProgress()
        return true
    }

    /// 清除进度并重置到初始状态，返回 false 供 restoreProgress 校验失败时使用
    private func resetProgressAndFail() -> Bool {
        clearProgress()
        applySectionOrderStrategy()
        currentSectionQueueIndex = 0
        prepareCurrentSection()
        return false
    }

    // MARK: - 私有：Codable 与 UserDefaults 桥接

    private func encodeToDefaults<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func decodeFromDefaults<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Array Rotate

extension Array {
    /// 将数组元素循环右移，使指定索引成为新首元素（randomStart 环形语义的实现基础）
    ///
    /// [A, B, C, D] rotate(toStartAt: 2) → [C, D, A, B]
    mutating func rotate(toStartAt index: Int) {
        guard count > 1, index > 0, index < count else { return }
        let suffix = self[index...]
        let prefix = self[..<index]
        self = Array(suffix) + Array(prefix)
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
