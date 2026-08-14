import SwiftUI

/// 单词本管理 Tab 视图
///
/// 展示单词本列表（名称、单词总数、Section 数量、启用勾选框），
/// 支持新建 / 删除 / 重命名 / 导入操作，以及全局 Section 大小设置。
struct WordbookTabView: View {
    @State private var wordbooks: [WordbookInfo] = []
    @State private var selection: String?
    @State private var sectionSize: Int = Constants.defaultSectionSize
    @State private var showingImportPanel = false
    @State private var showingNewPanel = false
    @State private var showingRenamePanel = false
    @State private var newWordbookName = ""
    @State private var renameWordbookName = ""
    @State private var importError: String?
    /// 空收藏夹启用时的行内提示文字（2 秒自动淡出）
    @State private var enableHint: String?

    struct WordbookInfo: Identifiable {
        let id: String
        var name: String
        var wordCount: Int
        var sectionCount: Int
        var isEnabled: Bool
        var isSystem: Bool
    }

    var body: some View {
        VStack(spacing: 12) {
            // 单词本列表
            List(wordbooks, selection: $selection) { wb in
                HStack {
                    Toggle("", isOn: binding(for: wb))
                        .toggleStyle(.checkbox)
                        // 系统收藏夹单词本不禁用：空收藏时点击会触发行内提示
                        // 非系统单词本空时禁用（依赖导入，无提示需求）
                        .disabled(wb.wordCount == 0 && !wb.isSystem)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(wb.name)
                            .font(.body)
                        Text("\(wb.wordCount) 词 · \(wb.sectionCount) Section")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if wb.isSystem {
                        Text("系统")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(3)
                    }

                    Spacer()
                }
                .tag(wb.id)
            }

            // 行内提示（空收藏夹启用失败时短暂显示）
            if let hint = enableHint {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(hint)
                }
                .font(.caption)
                .foregroundColor(.orange)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: enableHint)
            }

            Divider()

            // 操作栏
            HStack(spacing: 8) {
                Button("新建") { showingNewPanel = true }
                Button("导入…") { showingImportPanel = true }
                    .disabled(selection == nil)
                Button("重命名") { showingRenamePanel = true }
                    .disabled(selection == nil)
                Button("删除") { deleteSelected() }
                    .disabled(selection == nil || isSystemSelected)
                Spacer()
                // Section 大小设置
                Text("Section 大小：")
                    .font(.body)
                Stepper(value: $sectionSize, in: Constants.minSectionSize...1000) {
                    TextField("", value: $sectionSize, format: .number)
                        .frame(width: 60)
                        .onChange(of: sectionSize) { _ in saveSectionSize() }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
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

    private var isSystemSelected: Bool {
        guard let sel = selection else { return true }
        return wordbooks.first(where: { $0.id == sel })?.isSystem ?? true
    }

    private var selectedWordbookName: String {
        guard let sel = selection else { return "" }
        return wordbooks.first(where: { $0.id == sel })?.name ?? ""
    }

    private var newWordbookSheet: some View {
        VStack(spacing: 16) {
            Text("新建单词本").font(.headline)
            TextField("名称", text: $newWordbookName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("取消") { showingNewPanel = false }
                Button("创建") {
                    if !newWordbookName.isEmpty {
                        _ = WordbookService.shared.createWordbook(name: newWordbookName)
                        refreshList()
                    }
                    showingNewPanel = false
                    newWordbookName = ""
                }
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
                .disabled(renameWordbookName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
        .onAppear {
            renameWordbookName = selectedWordbookName
        }
    }

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
                        // 启用失败：显示行内提示（空收藏夹 / 空单词本共用）
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
        sectionSize = AppSettings.shared.sectionSize
    }

    private func saveSectionSize() {
        AppSettings.shared.sectionSize = max(Constants.minSectionSize, sectionSize)
        AppSettings.shared.postDidChange()
    }

    private func handleImport(result: Result<[URL], Error>) {
        guard let sel = selection else { return }

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // 查找目标单词本
            let context = DataStack.shared.viewContext
            let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
            request.predicate = NSPredicate(format: "wordbookId == %@", sel)
            request.fetchLimit = 1

            guard let wordbook = (try? context.fetch(request))?.first else {
                importError = "找不到目标单词本"
                return
            }

            // 异步导入
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
