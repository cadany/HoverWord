import SwiftUI

/// 单词本管理 Tab 视图
///
/// 展示单词本列表（名称、单词总数、Section 数量、启用勾选框），
/// 支持新建 / 删除 / 重命名 / 导入操作，以及全局 Section 大小设置。
/// 使用玻璃卡片分组样式。
struct WordbookTabView: View {
    @State private var wordbooks: [WordbookInfo] = []
    @State private var selection: String?
    @State private var showingImportPanel = false
    @State private var showingNewPanel = false
    @State private var showingRenamePanel = false
    @State private var showingPreviewPanel = false
    @State private var newWordbookName = ""
    @State private var renameWordbookName = ""
    @State private var importError: String?
    /// 空收藏夹启用时的行内提示文字（2 秒自动淡出）
    @State private var enableHint: String?
    /// 缓存当前选中单词本的 Core Data 对象，避免每次 body 重绘都 fetch
    @State private var cachedPreviewWordbook: Wordbook?
    @State private var cachedPreviewWordbookId: String?

    struct WordbookInfo: Identifiable {
        let id: String
        var name: String
        var wordCount: Int
        var sectionCount: Int
        var isEnabled: Bool
        var isSystem: Bool
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.settingsCardSpacing) {

                // 单词本列表卡片
                VStack(alignment: .leading, spacing: 0) {
                    Text("单词本")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(wordbooks) { wb in
                                WordbookRow(
                                    wordbook: wb,
                                    isOn: binding(for: wb),
                                    isSelected: selection == wb.id,
                                    onSelect: { selection = wb.id }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: 200)

                    // 行内提示
                    if let hint = enableHint {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(hint)
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: enableHint)
                    }
                }
                .glassCard()

                // 操作栏卡片
                HStack(spacing: 6) {
                    Button("新建") { showingNewPanel = true }
                        .glassButtonStyle()
                        .fixedSize()
                    Button("导入…") { showingImportPanel = true }
                        .glassButtonStyle()
                        .fixedSize()
                        .disabled(selection == nil)
                    Button("重命名") { showingRenamePanel = true }
                        .glassButtonStyle()
                        .fixedSize()
                        .disabled(selection == nil)
                    Button("预览") { showingPreviewPanel = true }
                        .glassButtonStyle()
                        .fixedSize()
                        .disabled(selection == nil || isSystemSelected)
                    Button("删除") { deleteSelected() }
                        .glassButtonStyle()
                        .fixedSize()
                        .disabled(selection == nil || isSystemSelected)
                    Spacer()
                }
                .glassCard()

                Spacer()
            }
            .padding(Constants.settingsContentPadding)
        }
        .scrollContentBackground(.hidden)
        .onAppear { refreshList() }
        .onReceive(NotificationCenter.default.publisher(for: .settingsWindowDidBecomeKey)) { _ in
            refreshList()
        }
        .sheet(isPresented: $showingNewPanel) {
            newWordbookSheet
        }
        .sheet(isPresented: $showingRenamePanel) {
            renameWordbookSheet
        }
        .sheet(isPresented: $showingPreviewPanel) {
            if let wordbook = selectedWordbookObject {
                WordbookPreviewView(wordbook: wordbook)
            }
        }
        .fileImporter(
            isPresented: $showingImportPanel,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("导入失败", isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("确定") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Subviews

    private var isSystemSelected: Bool {
        guard let sel = selection else { return true }
        return wordbooks.first(where: { $0.id == sel })?.isSystem ?? true
    }

    private var selectedWordbookName: String {
        guard let sel = selection else { return "" }
        return wordbooks.first(where: { $0.id == sel })?.name ?? ""
    }

    /// 获取当前选中单词本的 Core Data 对象（用于传递给预览 Sheet）
    ///
    /// 使用缓存避免每次 body 重绘都执行 Core Data fetch，
    /// 仅在 selection 变化时重新获取。
    private var selectedWordbookObject: Wordbook? {
        if cachedPreviewWordbookId == selection, let cached = cachedPreviewWordbook {
            return cached
        }
        guard let sel = selection else { return nil }
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "wordbookId == %@", sel)
        request.fetchLimit = 1
        let result = (try? context.fetch(request))?.first
        // 更新缓存
        cachedPreviewWordbook = result
        cachedPreviewWordbookId = sel
        return result
    }

    private var newWordbookSheet: some View {
        VStack(spacing: 16) {
            Text("新建单词本").font(.headline)
            TextField("名称", text: $newWordbookName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showingNewPanel = false }
                    .glassButtonStyle()
                Button("创建") {
                    if !newWordbookName.isEmpty {
                        _ = WordbookService.shared.createWordbook(name: newWordbookName)
                        refreshList()
                    }
                    showingNewPanel = false
                    newWordbookName = ""
                }
                .glassButtonStyle()
                .disabled(newWordbookName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    private var renameWordbookSheet: some View {
        VStack(spacing: 16) {
            Text("重命名单词本").font(.headline)
            TextField("新名称", text: $renameWordbookName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") {
                    showingRenamePanel = false
                    renameWordbookName = ""
                }
                .glassButtonStyle()
                Button("确定") {
                    if !renameWordbookName.isEmpty, let sel = selection {
                        let context = DataStack.shared.viewContext
                        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
                        request.predicate = NSPredicate(format: "wordbookId == %@", sel)
                        request.fetchLimit = 1
                        if let wordbook = (try? context.fetch(request))?.first {
                            WordbookService.shared.renameWordbook(wordbook, to: renameWordbookName)
                            refreshList()
                        }
                    }
                    showingRenamePanel = false
                    renameWordbookName = ""
                }
                .glassButtonStyle()
                .disabled(renameWordbookName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
        .onAppear {
            renameWordbookName = selectedWordbookName
        }
    }

    // MARK: - Logic

    private func binding(for wb: WordbookInfo) -> Binding<Bool> {
        Binding(
            get: { wb.isEnabled },
            set: { newValue in
                let context = DataStack.shared.viewContext
                let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
                request.predicate = NSPredicate(format: "wordbookId == %@", wb.id)
                request.fetchLimit = 1
                if let wordbook = (try? context.fetch(request))?.first {
                    let success = WordbookService.shared.setWordbookEnabled(wordbook, enabled: newValue)
                    if !success {
                        enableHint = "请先收藏单词后再启用"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            enableHint = nil
                        }
                    }
                    refreshList()
                }
            }
        )
    }

    private func deleteSelected() {
        guard let sel = selection else { return }
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "wordbookId == %@", sel)
        request.fetchLimit = 1
        if let wordbook = (try? context.fetch(request))?.first {
            _ = WordbookService.shared.deleteWordbook(wordbook)
            selection = nil
            refreshList()
        }
    }

    private func refreshList() {
        wordbooks = WordbookService.shared.getAllWordbooks().map { wb in
            WordbookInfo(
                id: wb.wordbookId,
                name: wb.name,
                wordCount: WordbookService.shared.getEntryCount(for: wb),
                sectionCount: WordbookService.shared.getSectionCount(for: wb),
                isEnabled: wb.isEnabled,
                isSystem: wb.isSystem
            )
        }
    }

    private func handleImport(result: Result<[URL], Error>) {
        guard let sel = selection else { return }

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            let context = DataStack.shared.viewContext
            let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
            request.predicate = NSPredicate(format: "wordbookId == %@", sel)
            request.fetchLimit = 1

            guard let wordbook = (try? context.fetch(request))?.first else {
                importError = "找不到目标单词本"
                return
            }

            Task {
                do {
                    try await WordbookService.shared.importFromFile(fileURL: url, to: wordbook)
                    await MainActor.run {
                        refreshList()
                    }
                } catch {
                    await MainActor.run {
                        importError = error.localizedDescription
                    }
                }
            }

        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

// MARK: - Wordbook Row

/// 单词本列表行视图
///
/// 交互拆分：左侧 checkbox（Toggle）负责启用/禁用，
/// 右侧文本区（Button .plain）负责选中单词本。
/// 避免整行 onTapGesture 抢占 checkbox 点击事件。
private struct WordbookRow: View {
    let wordbook: WordbookTabView.WordbookInfo
    let isOn: Binding<Bool>
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox 列：仅负责启用/禁用，不拦截行选中
            Toggle("", isOn: isOn)
                .toggleStyle(.checkbox)
                .disabled(wordbook.wordCount == 0 && !wordbook.isSystem)

            // 文本区：Button(.plain) 负责行选中，不干扰 Toggle
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wordbook.name)
                            .font(.system(size: 13))
                        Text("\(wordbook.wordCount) 词 · \(wordbook.sectionCount) Section")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if wordbook.isSystem {
                        Text("系统")
                            .font(.system(size: 10))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.08))
                            )
                    }

                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .onHover { hovering in isHovering = hovering }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.10)
        } else if isHovering {
            return Color.primary.opacity(0.04)
        } else {
            return .clear
        }
    }
}
