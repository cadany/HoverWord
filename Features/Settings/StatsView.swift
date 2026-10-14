import SwiftUI

/// 学习统计 Tab 视图（只读）
///
/// 主视图跟随全局背记模式（change feat05 D1）：
/// - 记忆反馈模式：掌握度总览卡 + 各启用词本掌握卡 + 无记录词本的走马灯历史行
/// - 走马灯模式：背记进度卡（合流 Section 队列进度）+ 锚点行 / 异常行 / 空态卡 + 历史掌握度行
///
/// 只读约束：仅消费 ReviewState 聚合、引擎进度读数与锚点状态判定，
/// SHALL NOT 写 ReviewState / 背记进度 / 续背锚点（见 D4/D7）。
/// 刷新时机：onAppear + reviewStateDidChange / appSettingsDidChange /
/// 词本启停 / 词本内容 / 收藏变更（页面常驻层级，切换 Tab 不重建，靠通知保活数据）。
struct StatsView: View {

    // MARK: - 展示状态（refresh() 一次性快照，只读渲染）

    /// 词本统计行数据（含展示名与 Section 数，锚点历史行取数用）
    private struct WordbookRowData {
        let id: String
        let name: String
        let sectionCount: Int
        let summary: ReviewStateService.MasterySummary

        /// 是否已有掌握度记录（区分掌握卡与历史行的依据）
        var hasRecord: Bool {
            summary.mastered + summary.inProgress > 0
        }
    }

    @State private var reciteMode: ReciteMode = AppSettings.shared.reciteMode
    @State private var totalSummary = ReviewStateService.MasterySummary()
    @State private var wordbookRows: [WordbookRowData] = []
    @State private var anchorState: ReciteEngine.ContinuationAnchorState = .none
    @State private var sectionProgress: (index: Int, total: Int) = (0, 0)
    @State private var showsExplanation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {
                header
                if reciteMode == .memoryFeedback {
                    masterySection
                } else {
                    progressSection
                }
                Spacer()
            }
            .padding(Constants.settingsContentPadding)
        }
        .scrollContentBackground(.hidden)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .reviewStateDidChange)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .appSettingsDidChange)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .wordbookEnablementDidChange)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .wordbookContentDidChange)) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .favoritesDidChange)) { _ in refresh() }
    }

    // MARK: - 页头与口径说明

    private var header: some View {
        HStack(spacing: 6) {
            Text(L10n.t("stats.title"))
                .font(.system(size: 17, weight: .semibold))
            Button {
                showsExplanation = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .accessibilityLabel(Text(L10n.t("stats.explanation")))
            .popover(isPresented: $showsExplanation, arrowEdge: .bottom) {
                explanationContent
            }
            Spacer()
        }
    }

    /// 口径说明 popover（D5 定稿文案，用户侧无实现隐喻）
    private var explanationContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(explanationLines, id: \.self) { line in
                Text(line)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(width: 330, alignment: .leading)
    }

    private var explanationLines: [String] {
        [
            L10n.t("stats.popover.mastered"),
            L10n.t("stats.popover.inProgress"),
            L10n.t("stats.popover.unlearned"),
            L10n.t("stats.popover.dueForReview"),
            L10n.t("stats.popover.intervalNote"),
            L10n.t("stats.popover.reappearanceNote"),
            L10n.t("stats.popover.boundaryNote"),
        ]
    }

    // MARK: - 状态 A：掌握度（记忆反馈模式）

    @ViewBuilder
    private var masterySection: some View {
        // 总览卡：三态堆叠条 + 待复习 / 累计曝光指标
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("stats.overview.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            MasteryBar(summary: totalSummary)
            MasteryLegend(summary: totalSummary)
            HStack(spacing: 24) {
                metricBlock(label: L10n.t("stats.mastery.dueForReview"),
                            value: "\(totalSummary.dueForReview)",
                            valueColor: .orange)
                metricBlock(label: L10n.t("stats.metric.totalExposures"),
                            value: "\(totalSummary.totalExposures)",
                            valueColor: .primary)
                Spacer()
            }
        }
        .glassCard()

        // 词本掌握卡（有记录）+ 走马灯历史行（无记录）
        ForEach(wordbookRows, id: \.id) { row in
            if row.hasRecord {
                wordbookMasteryCard(row)
            } else {
                Text(historyRowText(for: row))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .glassCard()
            }
        }
    }

    /// 词本掌握卡：词名 + 已学完徽标 + 三态堆叠条 + 最近学习 / 待复习 meta 行
    private func wordbookMasteryCard(_ row: WordbookRowData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(row.name)
                    .font(.system(size: 13, weight: .medium))
                if isFullyMastered(row) {
                    Text(L10n.t("stats.badge.allMastered"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.green.opacity(0.15)))
                }
                Spacer()
                Text(L10n.t("stats.wordCount.format", row.summary.wordCount))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            MasteryBar(summary: row.summary)
            MasteryLegend(summary: row.summary)
            if let reviewedAt = row.summary.lastReviewedAt {
                metaLine(row: row, reviewedAt: reviewedAt)
            }
        }
        .glassCard()
    }

    /// meta 行：「最近学习 〈相对时间〉 · 待复习 N」（待复习为 0 时不显示该段）
    private func metaLine(row: WordbookRowData, reviewedAt: Date) -> some View {
        HStack(spacing: 0) {
            Text(L10n.t("stats.meta.lastReviewed.format", relativeTimeString(for: reviewedAt)))
            if row.summary.dueForReview > 0 {
                Text(" · ")
                Text(L10n.t("stats.meta.dueForReview.format", row.summary.dueForReview))
                    .foregroundColor(.orange)
            }
        }
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }

    /// 走马灯历史行：锚点指向且有效时展示上次背完的 Section，否则「未开始」
    private func historyRowText(for row: WordbookRowData) -> String {
        let words = L10n.t("stats.wordCount.format", row.summary.wordCount)
        let suffix: String
        if case .valid(let anchorWordbookId, _, let sectionIndex) = anchorState,
           anchorWordbookId == row.id {
            suffix = L10n.t("stats.history.progress.format", sectionIndex + 1, row.sectionCount)
        } else {
            suffix = L10n.t("stats.history.notStarted")
        }
        return "\(row.name) · \(words) · \(suffix)"
    }

    private func metricBlock(label: String, value: String, valueColor: Color) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }

    /// 词本全部词条均已掌握时显示「已学完」徽标（复用引擎判定语义：全部词 boxLevel 达上限）
    private func isFullyMastered(_ row: WordbookRowData) -> Bool {
        row.summary.wordCount > 0 && row.summary.mastered == row.summary.wordCount
    }

    // MARK: - 状态 B：背记进度（走马灯模式）

    @ViewBuilder
    private var progressSection: some View {
        // 背记进度卡：合流 Section 队列进度
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("stats.progress.title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            ProgressView(value: progressFraction)
            Text(L10n.t("stats.progress.format", sectionProgress.index, sectionProgress.total))
                .font(.system(size: 13))
            Text(L10n.t("stats.progress.subtitle.format", wordbookRows.count, sectionProgress.total))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .glassCard()

        // 锚点行 / 异常行 / 空态卡（判定矩阵见 D3，与引擎 restore 同源）
        anchorView

        // 历史掌握度折叠行（有 ReviewState 记录的词本）
        ForEach(wordbookRows.filter { $0.hasRecord }, id: \.id) { row in
            Text("\(row.name) · " + L10n.t(
                "stats.history.mastery.format",
                row.summary.mastered,
                row.summary.inProgress,
                row.summary.unlearned
            ))
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .glassCard()
        }
    }

    private var progressFraction: Double {
        guard sectionProgress.total > 0 else { return 0 }
        return Double(sectionProgress.index) / Double(sectionProgress.total)
    }

    @ViewBuilder
    private var anchorView: some View {
        switch anchorState {
        case .valid(_, let wordbookName, let sectionIndex):
            Text(L10n.t("stats.anchor.format", wordbookName, sectionIndex + 1))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .glassCard()
        case .wordbookMissing:
            Text(L10n.t("stats.anchor.wordbookDeleted"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .glassCard()
        case .wordbookDisabled:
            Text(L10n.t("stats.anchor.wordbookDisabled"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .glassCard()
        case .none, .sectionInvalid:
            VStack(spacing: 4) {
                Text(L10n.t("stats.empty.title"))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text(L10n.t("stats.empty.hint"))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .glassCard()
        }
    }

    // MARK: - 数据刷新（只读快照）

    private func refresh() {
        reciteMode = AppSettings.shared.reciteMode

        let enabled = WordbookService.shared.getEnabledWordbooks()
        let ids = enabled.map { $0.wordbookId }
        let result = ReviewStateService.shared.masterySummaries(wordbookIds: ids)
        totalSummary = result.total
        wordbookRows = enabled.map { wordbook in
            let id = wordbook.wordbookId
            return WordbookRowData(
                id: id,
                name: wordbook.isSystem ? L10n.t("wordbook.favorites.name") : wordbook.name,
                sectionCount: WordbookService.shared.getSectionCount(for: wordbook),
                summary: result.wordbooks[id] ?? ReviewStateService.MasterySummary()
            )
        }

        if let controller = AppDelegate.shared?.floatWindowController {
            sectionProgress = controller.carouselSectionProgress
            anchorState = controller.continuationAnchorState
        } else {
            sectionProgress = (0, 0)
            anchorState = .none
        }
    }

    /// 相对时间文案（「3 小时前」；每次调用重建 formatter，保证语言切换即时生效）
    private func relativeTimeString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(
            identifier: L10n.effectiveLanguage == L10n.englishLanguage ? "en_US" : "zh_CN"
        )
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - 三态堆叠条与图例

/// 三态堆叠条：已掌握（绿）/ 进行中（蓝）/ 未学（中性），零段不绘制
private struct MasteryBar: View {
    let summary: ReviewStateService.MasterySummary

    var body: some View {
        GeometryReader { geometry in
            let total = max(summary.mastered + summary.inProgress + summary.unlearned, 1)
            let spacing: CGFloat = 2
            let visibleCount = [summary.mastered, summary.inProgress, summary.unlearned]
                .filter { $0 > 0 }.count
            let gaps = CGFloat(max(visibleCount - 1, 0)) * spacing
            let usable = max(geometry.size.width - gaps, 0)
            HStack(spacing: spacing) {
                if summary.mastered > 0 {
                    Capsule().fill(Color.green)
                        .frame(width: usable * CGFloat(summary.mastered) / CGFloat(total))
                }
                if summary.inProgress > 0 {
                    Capsule().fill(Color.accentColor)
                        .frame(width: usable * CGFloat(summary.inProgress) / CGFloat(total))
                }
                if summary.unlearned > 0 {
                    Capsule().fill(Color.primary.opacity(0.15))
                        .frame(width: usable * CGFloat(summary.unlearned) / CGFloat(total))
                }
            }
        }
        .frame(height: 8)
    }
}

/// 三态图例：色点 + 术语 + 计数
private struct MasteryLegend: View {
    let summary: ReviewStateService.MasterySummary

    var body: some View {
        HStack(spacing: 12) {
            legendItem(color: .green, termKey: "stats.mastery.mastered", count: summary.mastered)
            legendItem(color: .accentColor, termKey: "stats.mastery.inProgress", count: summary.inProgress)
            legendItem(color: .primary.opacity(0.35), termKey: "stats.mastery.unlearned", count: summary.unlearned)
            Spacer()
        }
    }

    private func legendItem(color: Color, termKey: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(L10n.t(termKey))
            Text("\(count)")
                .foregroundColor(.primary)
        }
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
}
