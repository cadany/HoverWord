import SwiftUI
import AppKit

/// 单词本管理 Tab 视图
///
/// 展示单词本列表（名称、单词总数、Section 数量、启用勾选框）。
/// 行内操作（悬停/选中时行尾浮现）：预览直达 + `...` 菜单（导入/重命名/删除，删除带确认）；
/// "新建"入口位于列表标题行右侧。使用玻璃卡片分组样式。
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
    /// 待确认删除的单词本（非 nil 时弹确认对话框）
    @State private var pendingDeleteWordbook: WordbookInfo?
    /// 导出失败信息（非 nil 时弹 alert）
    @State private var exportError: String?
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
                    HStack {
                        Text(L10n.t("sidebar.wordbook"))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            showingNewPanel = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .glassButtonStyle()
                        .help(L10n.t("wordbook.toolbar.new"))
                    }
                    .padding(.bottom, 6)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(wordbooks) { wb in
                                WordbookRow(
                                    wordbook: wb,
                                    isOn: binding(for: wb),
                                    isSelected: selection == wb.id,
                                    onSelect: { selection = wb.id },
                                    // 预览对全部词本开放（收藏夹为只读预览）
                                    onPreview: {
                                        selection = wb.id
                                        showingPreviewPanel = true
                                    },
                                    onImport: wb.isSystem ? nil : {
                                        selection = wb.id
                                        showingImportPanel = true
                                    },
                                    onExport: {
                                        selection = wb.id
                                        exportWordbook(wb)
                                    },
                                    onRename: wb.isSystem ? nil : {
                                        selection = wb.id
                                        showingRenamePanel = true
                                    },
                                    onDelete: wb.isSystem ? nil : {
                                        selection = wb.id
                                        pendingDeleteWordbook = wb
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(minHeight: 200)
                    // 导出失败 alert 挂在列表子树，与删除确认/导入失败 alert 分离
                    .alert(L10n.t("wordbook.export.failed"), isPresented: Binding(
                        get: { exportError != nil },
                        set: { if !$0 { exportError = nil } }
                    )) {
                        Button(L10n.t("common.ok"), role: .cancel) { exportError = nil }
                    } message: {
                        Text(exportError ?? "")
                    }

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
                // 删除确认挂在列表子树，与外层导入失败 alert 分离，避免同节点多 alert 冲突
                .alert(
                    L10n.t("wordbook.delete.confirm.title"),
                    isPresented: Binding(
                        get: { pendingDeleteWordbook != nil },
                        set: { if !$0 { pendingDeleteWordbook = nil } }
                    )
                ) {
                    Button(L10n.t("common.cancel"), role: .cancel) {}
                    Button(L10n.t("wordbook.toolbar.delete"), role: .destructive) {
                        confirmDelete()
                    }
                } message: {
                    if let pending = pendingDeleteWordbook {
                        Text(L10n.t("wordbook.delete.confirm.message", pending.name, pending.wordCount))
                    }
                }

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
        .alert(L10n.t("wordbook.import.failed"), isPresented: .init(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button(L10n.t("common.ok")) { importError = nil }
        } message: {
            Text(importError ?? "")
        }
    }

    // MARK: - Subviews

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
            Text(L10n.t("wordbook.new.title")).font(.headline)
            TextField(L10n.t("wordbook.new.placeholder"), text: $newWordbookName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(L10n.t("common.cancel")) { showingNewPanel = false }
                    .glassButtonStyle()
                Button(L10n.t("common.create")) {
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
            Text(L10n.t("wordbook.rename.title")).font(.headline)
            TextField(L10n.t("wordbook.rename.placeholder"), text: $renameWordbookName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button(L10n.t("common.cancel")) {
                    showingRenamePanel = false
                    renameWordbookName = ""
                }
                .glassButtonStyle()
                Button(L10n.t("common.ok")) {
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
                // macOS 列表惯例：点击 checkbox 视为对该行的交互，同步选中
                selection = wb.id
                let context = DataStack.shared.viewContext
                let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
                request.predicate = NSPredicate(format: "wordbookId == %@", wb.id)
                request.fetchLimit = 1
                if let wordbook = (try? context.fetch(request))?.first {
                    let success = WordbookService.shared.setWordbookEnabled(wordbook, enabled: newValue)
                    if !success {
                        enableHint = L10n.t("wordbook.favorites.enableHint")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            enableHint = nil
                        }
                    }
                    refreshList()
                }
            }
        )
    }

    /// 确认删除待删单词本（由删除确认 alert 的destructive 按钮触发）
    private func confirmDelete() {
        guard let pending = pendingDeleteWordbook else { return }
        let context = DataStack.shared.viewContext
        let request: NSFetchRequest<Wordbook> = Wordbook.fetchRequest()
        request.predicate = NSPredicate(format: "wordbookId == %@", pending.id)
        request.fetchLimit = 1
        if let wordbook = (try? context.fetch(request))?.first {
            _ = WordbookService.shared.deleteWordbook(wordbook)
        }
        selection = nil
        pendingDeleteWordbook = nil
        refreshList()
    }

    /// 导出单词本：保存面板确认后后台序列化写文件，失败弹 alert（成功无提示）
    private func exportWordbook(_ wb: WordbookInfo) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        let baseName = wb.isSystem ? L10n.t("wordbook.favorites.name") : wb.name
        panel.nameFieldStringValue = WordbookExportService.sanitizedFileName(from: baseName) + ".txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            do {
                let data = try await WordbookExportService.export(wordbookId: wb.id)
                try data.write(to: url)
            } catch {
                await MainActor.run {
                    exportError = error.localizedDescription
                }
            }
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
                importError = L10n.t("wordbook.error.notFound")
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
/// 中部文本区（Button .plain）负责选中单词本，
/// 右侧行内操作区（悬停/选中时浮现）负责预览、导入、重命名、删除。
/// 点行内操作时同步选中该行（macOS 列表惯例：点行内任意处均选中）。
private struct WordbookRow: View {
    let wordbook: WordbookTabView.WordbookInfo
    let isOn: Binding<Bool>
    let isSelected: Bool
    let onSelect: () -> Void
    /// 行内操作回调，nil 表示该词本不提供此操作（系统词本全 nil，不渲染操作区）
    let onPreview: (() -> Void)?
    let onImport: (() -> Void)?
    let onExport: (() -> Void)?
    let onRename: (() -> Void)?
    let onDelete: (() -> Void)?
    @State private var isHovering = false

    /// 是否存在任一行内操作（决定操作区是否可出现）
    private var hasActions: Bool {
        onPreview != nil || onImport != nil || onExport != nil || onRename != nil || onDelete != nil
    }

    private var showActions: Bool {
        hasActions && (isHovering || isSelected)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox 列：仅负责启用/禁用，不拦截行选中
            Toggle("", isOn: isOn)
                .toggleStyle(.checkbox)
                .disabled(wordbook.wordCount == 0 && !wordbook.isSystem)

            // 文本区：Button(.plain) 负责行选中。
            // padding 与背景移入 Button 内部 + contentShape，
            // 使点击热区覆盖整行视觉区域（含留白与背景），而非仅文本。
            // 行内操作区以 overlay 叠加在行尾（Spacer 区域），
            // 不嵌套进本 Button，避免嵌套按钮手势冲突，也不引起行宽跳动。
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wordbook.isSystem ? L10n.t("wordbook.favorites.name") : wordbook.name)
                            .font(.system(size: 13))
                        Text(L10n.t("wordbook.meta.format", wordbook.wordCount, wordbook.sectionCount))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    if wordbook.isSystem {
                        Text(L10n.t("wordbook.badge.system"))
                            .font(.system(size: 10))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.08))
                            )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minHeight: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .overlay(alignment: .trailing) {
                if showActions {
                    rowActions
                        .transition(.opacity)
                        .padding(.trailing, 4)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .onHover { hovering in isHovering = hovering }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    // MARK: - 行内操作区

    /// 预览直达图标 + `...` 菜单（导入 / 重命名 / 删除）
    private var rowActions: some View {
        HStack(spacing: Constants.rowActionSpacing) {
            if let onPreview {
                Button(action: onPreview) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: Constants.rowActionIconSize, weight: .medium))
                        .foregroundColor(Color.primary.opacity(Constants.rowActionIconAlpha))
                        .frame(width: Constants.rowActionHitSize, height: Constants.rowActionHitSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L10n.t("wordbook.toolbar.preview"))
            }

            if onImport != nil || onExport != nil || onRename != nil || onDelete != nil {
                // SwiftUI Menu 的 borderless 样式在 macOS 26 上不渲染自定义 label，
                // 改用 Button + NSMenu 原生弹出（Button 自定义 label 渲染可靠）
                Button(action: showMoreMenu) {
                    VStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle()
                                .fill(Color.primary.opacity(Constants.rowActionIconAlpha))
                                .frame(width: 3, height: 3)
                        }
                    }
                    .frame(width: Constants.rowActionHitSize, height: Constants.rowActionHitSize)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - 更多操作菜单

    /// 闭包包装为 NSMenuItem 的 target/action 载体
    private final class MenuActionTarget: NSObject {
        let handler: () -> Void
        init(_ handler: @escaping () -> Void) {
            self.handler = handler
            super.init()
        }
        @objc func menuActionFired() { handler() }
    }

    /// 在鼠标位置弹出"更多"操作菜单（导入 / 重命名 / 删除）
    ///
    /// popUp 为同步阻塞调用，局部 targets 数组在菜单追踪期间保持强引用，生命周期安全
    private func showMoreMenu() {
        // 点操作即选中该行（与 checkbox/预览行为一致）
        onSelect()

        let menu = NSMenu()
        var targets: [MenuActionTarget] = []

        func addMenuItem(_ title: String, handler: @escaping () -> Void) {
            let target = MenuActionTarget(handler)
            targets.append(target)
            let item = NSMenuItem(title: title, action: #selector(MenuActionTarget.menuActionFired), keyEquivalent: "")
            item.target = target
            menu.addItem(item)
        }

        if let onImport {
            addMenuItem(L10n.t("wordbook.toolbar.import"), handler: onImport)
        }
        if let onExport {
            let target = MenuActionTarget(onExport)
            targets.append(target)
            let item = NSMenuItem(title: L10n.t("wordbook.toolbar.export"), action: #selector(MenuActionTarget.menuActionFired), keyEquivalent: "")
            item.target = target
            // 空词本导出项禁用（避免导出空文件）
            item.isEnabled = wordbook.wordCount > 0
            menu.addItem(item)
        }
        if let onRename {
            addMenuItem(L10n.t("wordbook.toolbar.rename"), handler: onRename)
        }
        if let onDelete {
            menu.addItem(.separator())
            let target = MenuActionTarget(onDelete)
            targets.append(target)
            let deleteTitle = L10n.t("wordbook.toolbar.delete")
            let item = NSMenuItem(title: deleteTitle, action: #selector(MenuActionTarget.menuActionFired), keyEquivalent: "")
            item.target = target
            // destructive 样式：红色文字（对齐 SwiftUI Menu 的 role: .destructive 视觉）
            item.attributedTitle = NSAttributedString(
                string: deleteTitle,
                attributes: [.foregroundColor: NSColor.systemRed]
            )
            menu.addItem(item)
        }

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
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
