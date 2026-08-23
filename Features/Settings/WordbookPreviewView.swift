import SwiftUI
import CoreData

/// 单词本词条预览视图
///
/// Sheet 形式展示单词本内词条列表，支持：
/// - 分页展示（每页 100 条）
/// - 内联编辑（单词 / 音标 / 词性 / 释义）
/// - 逐条删除
/// - 空状态提示
///
/// 系统收藏夹单词本为只读预览：仅展示收藏快照（按收藏时间排序），
/// 不提供编辑与删除（收藏词条的编辑在源单词本进行，快照自动同步）。
struct WordbookPreviewView: View {

    let wordbook: Wordbook
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [EntryItem] = []
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 1
    @State private var totalEntries: Int = 0
    @State private var isEmpty: Bool = false

    private let pageSize = 100

    /// 系统收藏夹：词条为游离对象，编辑/删除服务匹配不到实体，呈只读态
    private var isReadOnly: Bool { wordbook.isSystem }

    /// 表格行数据（值类型快照，避免持有 NSManagedObject 引用）
    struct EntryItem: Identifiable {
        let id: String        // wordId
        var lineNumber: Int   // 原 TXT 真实行号（0 表示老数据缺失，显示 "-"）
        var sourceWord: String
        var phonetic: String
        var pos1: String
        var meaning1: String
        var pos2: String
        var meaning2: String
        var pos3: String
        var meaning3: String

        /// 释义列拼接展示文本：各组以 " / " 连接（与悬浮窗展示一致），空组跳过
        var joinedMeaning: String {
            var parts: [String] = []
            if !pos1.isEmpty || !meaning1.isEmpty {
                parts.append([pos1, meaning1].filter { !$0.isEmpty }.joined(separator: " "))
            }
            if !pos2.isEmpty || !meaning2.isEmpty {
                parts.append([pos2, meaning2].filter { !$0.isEmpty }.joined(separator: " "))
            }
            if !pos3.isEmpty || !meaning3.isEmpty {
                parts.append([pos3, meaning3].filter { !$0.isEmpty }.joined(separator: " "))
            }
            return parts.joined(separator: " / ")
        }

        /// 从编辑文本解析回 3 组词性/释义：按 " / " 拆分，每组内首个空格分隔词性与释义（无空格则全作释义）
        static func parse(joined text: String) -> (pos1: String, meaning1: String, pos2: String, meaning2: String, pos3: String, meaning3: String) {
            let groups = text
                .components(separatedBy: " / ")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            func split(_ group: String) -> (String, String) {
                guard let spaceIdx = group.firstIndex(where: { $0 == " " || $0 == "　" }) else {
                    return ("", group)
                }
                let pos = String(group[..<spaceIdx]).trimmingCharacters(in: .whitespaces)
                let meaning = String(group[group.index(after: spaceIdx)...]).trimmingCharacters(in: .whitespaces)
                return (pos, meaning)
            }

            let g1 = groups.count > 0 ? split(groups[0]) : ("", "")
            let g2 = groups.count > 1 ? split(groups[1]) : ("", "")
            let g3 = groups.count > 2 ? split(groups[2]) : ("", "")
            return (g1.0, g1.1, g2.0, g2.1, g3.0, g3.1)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerBar

            if isEmpty {
                emptyState
            } else {
                // 表头
                tableHeader

                // 词条列表
                entryList

                // 分页控件
                paginationBar
            }
        }
        .frame(width: 720, height: 520)
        .onAppear { loadPage(0) }
    }

    // MARK: - 子视图

    private var headerBar: some View {
        HStack {
            Text(L10n.t("preview.title.format", wordbook.name ?? ""))
                .font(.headline)
            Spacer()
            Text(L10n.t("preview.total.format", totalEntries))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Button(L10n.t("common.close")) { dismiss() }
                .glassButtonStyle()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.book.closed")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(L10n.t("preview.empty"))
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text(L10n.t("preview.col.lineNumber"))
                .frame(width: Constants.previewLineNumberColumnWidth, alignment: .trailing)
            Text(L10n.t("preview.col.word"))
                .frame(width: 140, alignment: .leading)
            Text(L10n.t("preview.col.phonetic"))
                .frame(width: 110, alignment: .leading)
            Text(L10n.t("preview.col.meaning"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("")
                .frame(width: 32)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    EntryRowView(
                        entry: entry,
                        isReadOnly: isReadOnly,
                        onSave: { item in saveEntry(item) },
                        onDelete: { item in deleteEntry(item) }
                    )
                    Divider()
                        .opacity(0.3)
                }
            }
        }
    }

    private var paginationBar: some View {
        HStack(spacing: 12) {
            Button {
                loadPage(currentPage - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .glassButtonStyle()
            .disabled(currentPage <= 0)

            Text(L10n.t("preview.page.format", currentPage + 1, totalPages))
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Button {
                loadPage(currentPage + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .glassButtonStyle()
            .disabled(currentPage >= totalPages - 1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: - 数据操作

    private func loadPage(_ page: Int) {
        let result = WordbookService.shared.getEntriesPaginated(
            for: wordbook,
            page: page,
            pageSize: pageSize
        )

        entries = result.entries.map { entry in
            EntryItem(
                id: entry.wordId,
                lineNumber: Int(entry.sourceLineNumber),
                sourceWord: entry.sourceWord ?? "",
                phonetic: entry.phonetic ?? "",
                pos1: entry.pos1 ?? "",
                meaning1: entry.meaning1 ?? "",
                pos2: entry.pos2 ?? "",
                meaning2: entry.meaning2 ?? "",
                pos3: entry.pos3 ?? "",
                meaning3: entry.meaning3 ?? ""
            )
        }
        totalPages = result.totalPages
        totalEntries = result.totalCount
        currentPage = page
        isEmpty = (result.entries.isEmpty && page == 0)
    }

    private func saveEntry(_ entry: EntryItem) {
        WordbookService.shared.updateEntry(
            wordId: entry.id,
            sourceWord: entry.sourceWord,
            phonetic: entry.phonetic.isEmpty ? nil : entry.phonetic,
            pos1: entry.pos1.isEmpty ? nil : entry.pos1,
            meaning1: entry.meaning1.isEmpty ? nil : entry.meaning1,
            pos2: entry.pos2.isEmpty ? nil : entry.pos2,
            meaning2: entry.meaning2.isEmpty ? nil : entry.meaning2,
            pos3: entry.pos3.isEmpty ? nil : entry.pos3,
            meaning3: entry.meaning3.isEmpty ? nil : entry.meaning3,
            replaceSecondaryMeanings: true
        )
        // 更新本地数据快照
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx] = entry
        }
    }

    private func deleteEntry(_ entry: EntryItem) {
        WordbookService.shared.deleteEntry(wordId: entry.id)

        // 从本地列表中移除
        entries.removeAll { $0.id == entry.id }
        totalEntries = max(0, totalEntries - 1)

        if entries.isEmpty {
            // 当前页已清空
            if currentPage > 0 {
                // 退回上一页
                loadPage(currentPage - 1)
            } else if totalEntries == 0 {
                // 第一页已空且无更多数据
                isEmpty = true
            }
        }
    }
}

// MARK: - 词条行视图

/// 单条词条的内联编辑行
///
/// 三个 TextField 分别对应单词 / 音标 / 释义（多组释义以 " / " 拼接编辑，
/// 保存时解析回 3 组词性+释义字段），回车或失焦时自动保存。右侧一个删除按钮。
/// 只读态（系统收藏夹）渲染纯文本、无删除按钮。
private struct EntryRowView: View {
    let entry: WordbookPreviewView.EntryItem
    let isReadOnly: Bool
    let onSave: (WordbookPreviewView.EntryItem) -> Void
    let onDelete: (WordbookPreviewView.EntryItem) -> Void

    enum Field: Hashable { case word, phonetic, meaning }

    @State private var editWord: String = ""
    @State private var editPhonetic: String = ""
    @State private var editMeaning: String = ""
    @FocusState private var focusedField: Field?

    var body: some View {
        HStack(spacing: 8) {
            // 原 TXT 行号（不可编辑；0 表示老数据缺失/收藏词条无行号）
            Text(entry.lineNumber == 0 ? "-" : "\(entry.lineNumber)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: Constants.previewLineNumberColumnWidth, alignment: .trailing)

            if isReadOnly {
                Text(entry.sourceWord)
                    .frame(width: 140, alignment: .leading)
                Text(entry.phonetic)
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
                Text(entry.joinedMeaning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("", text: $editWord, onCommit: save)
                    .textFieldStyle(.plain)
                    .frame(width: 140)
                    .focused($focusedField, equals: .word)

                TextField("", text: $editPhonetic, onCommit: save)
                    .textFieldStyle(.plain)
                    .frame(width: 110)
                    .focused($focusedField, equals: .phonetic)

                TextField("", text: $editMeaning, onCommit: save)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .focused($focusedField, equals: .meaning)
                    .help(L10n.t("preview.meaning.editHint"))

                Button {
                    onDelete(currentSnapshot())
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .frame(width: 32)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .onAppear {
            editWord = entry.sourceWord
            editPhonetic = entry.phonetic
            editMeaning = entry.joinedMeaning
        }
        .onChange(of: focusedField) { _, newValue in
            // 焦点离开当前行（变为 nil）时自动保存，避免未提交的编辑丢失
            if newValue == nil {
                save()
            }
        }
    }

    private func currentSnapshot() -> WordbookPreviewView.EntryItem {
        let parsed = WordbookPreviewView.EntryItem.parse(joined: editMeaning)
        return WordbookPreviewView.EntryItem(
            id: entry.id,
            lineNumber: entry.lineNumber,
            sourceWord: editWord,
            phonetic: editPhonetic,
            pos1: parsed.pos1,
            meaning1: parsed.meaning1,
            pos2: parsed.pos2,
            meaning2: parsed.meaning2,
            pos3: parsed.pos3,
            meaning3: parsed.meaning3
        )
    }

    private func save() {
        let snapshot = currentSnapshot()
        // 光标在字段间切换会频繁触发失焦保存；内容未变化时必须跳过，
        // 否则会发 wordbookContentDidChange 通知导致背记引擎重载、悬浮窗重复发音
        guard snapshot.joinedMeaning != entry.joinedMeaning
            || snapshot.sourceWord != entry.sourceWord
            || snapshot.phonetic != entry.phonetic
        else { return }
        onSave(snapshot)
    }
}
