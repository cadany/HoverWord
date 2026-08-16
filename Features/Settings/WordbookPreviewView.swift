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
/// 不支持系统收藏夹单词本（仅用于普通单词本的导入词条预览）。
struct WordbookPreviewView: View {

    let wordbook: Wordbook
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [EntryItem] = []
    @State private var currentPage: Int = 0
    @State private var totalPages: Int = 1
    @State private var totalEntries: Int = 0
    @State private var isEmpty: Bool = false

    private let pageSize = 100

    /// 表格行数据（值类型快照，避免持有 NSManagedObject 引用）
    struct EntryItem: Identifiable {
        let id: String        // wordId
        var sourceWord: String
        var phonetic: String
        var pos1: String
        var meaning1: String
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
            Text("词条预览 — \(wordbook.name ?? "")")
                .font(.headline)
            Spacer()
            Text("共 \(totalEntries) 条")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Button("关闭") { dismiss() }
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
            Text("该单词本暂无词条")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var tableHeader: some View {
        HStack(spacing: 8) {
            Text("单词")
                .frame(width: 140, alignment: .leading)
            Text("音标")
                .frame(width: 110, alignment: .leading)
            Text("词性")
                .frame(width: 50, alignment: .leading)
            Text("释义")
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

            Text("第 \(currentPage + 1) / \(totalPages) 页")
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
                sourceWord: entry.sourceWord ?? "",
                phonetic: entry.phonetic ?? "",
                pos1: entry.pos1 ?? "",
                meaning1: entry.meaning1 ?? ""
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
            meaning1: entry.meaning1.isEmpty ? nil : entry.meaning1
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
/// 四个 TextField 分别对应单词 / 音标 / 词性 / 释义，
/// 回车或失焦时自动保存。右侧一个删除按钮。
private struct EntryRowView: View {
    let entry: WordbookPreviewView.EntryItem
    let onSave: (WordbookPreviewView.EntryItem) -> Void
    let onDelete: (WordbookPreviewView.EntryItem) -> Void

    enum Field: Hashable { case word, phonetic, pos, meaning }

    @State private var editWord: String = ""
    @State private var editPhonetic: String = ""
    @State private var editPos: String = ""
    @State private var editMeaning: String = ""
    @FocusState private var focusedField: Field?

    var body: some View {
        HStack(spacing: 8) {
            TextField("", text: $editWord, onCommit: save)
                .textFieldStyle(.plain)
                .frame(width: 140)
                .focused($focusedField, equals: .word)

            TextField("", text: $editPhonetic, onCommit: save)
                .textFieldStyle(.plain)
                .frame(width: 110)
                .focused($focusedField, equals: .phonetic)

            TextField("", text: $editPos, onCommit: save)
                .textFieldStyle(.plain)
                .frame(width: 50)
                .focused($focusedField, equals: .pos)

            TextField("", text: $editMeaning, onCommit: save)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
                .focused($focusedField, equals: .meaning)

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
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .onAppear {
            editWord = entry.sourceWord
            editPhonetic = entry.phonetic
            editPos = entry.pos1
            editMeaning = entry.meaning1
        }
        .onChange(of: focusedField) { _, newValue in
            // 焦点离开当前行（变为 nil）时自动保存，避免未提交的编辑丢失
            if newValue == nil {
                save()
            }
        }
    }

    private func currentSnapshot() -> WordbookPreviewView.EntryItem {
        WordbookPreviewView.EntryItem(
            id: entry.id,
            sourceWord: editWord,
            phonetic: editPhonetic,
            pos1: editPos,
            meaning1: editMeaning
        )
    }

    private func save() {
        onSave(currentSnapshot())
    }
}
