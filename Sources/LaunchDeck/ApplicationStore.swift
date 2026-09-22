import AppKit
import Observation

@MainActor
@Observable
final class ApplicationStore {
    static let pageSize = 35
    static let gridColumnCount = 7

    private(set) var applications: [ApplicationItem] = []
    private(set) var isLoading = false
    private(set) var layout: LauncherLayout
    private let layoutRepository: LayoutRepository

    var query = "" {
        didSet {
            currentPage = 0
            selectFirstApplication()
        }
    }
    var errorMessage: String?
    var currentPage = 0
    var selectedApplicationID: String?
    private(set) var pageTransitionDirection = 1

    init(
        layoutRepository: LayoutRepository = LayoutRepository(),
        initialApplications: [ApplicationItem] = []
    ) {
        self.layoutRepository = layoutRepository
        self.layout = layoutRepository.load()
        self.applications = initialApplications
        if !initialApplications.isEmpty {
            reconcileLayout(with: initialApplications)
            normalizePageAndSelection()
        }
    }

    var visibleApplications: [ApplicationItem] {
        orderedApplications.filter { !layout.hiddenApplicationIDs.contains($0.id) }
    }

    var hiddenApplications: [ApplicationItem] {
        orderedApplications.filter { layout.hiddenApplicationIDs.contains($0.id) }
    }

    var filteredApplications: [ApplicationItem] {
        let normalizedQuery = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        guard !normalizedQuery.isEmpty else { return visibleApplications }
        return visibleApplications.filter { $0.searchableText.contains(normalizedQuery) }
    }

    var pageCount: Int {
        max(1, Int(ceil(Double(filteredApplications.count) / Double(Self.pageSize))))
    }

    var pageApplications: [ApplicationItem] {
        let safePage = min(max(0, currentPage), pageCount - 1)
        let start = safePage * Self.pageSize
        guard start < filteredApplications.count else { return [] }
        let end = min(start + Self.pageSize, filteredApplications.count)
        return Array(filteredApplications[start..<end])
    }

    var selectedApplication: ApplicationItem? {
        guard let selectedApplicationID else { return nil }
        return filteredApplications.first { $0.id == selectedApplicationID }
    }

    private var orderedApplications: [ApplicationItem] {
        let byID = Dictionary(uniqueKeysWithValues: applications.map { ($0.id, $0) })
        let saved = layout.orderedApplicationIDs.compactMap { byID[$0] }
        let savedIDs = Set(saved.map(\.id))
        let new = applications.filter { !savedIDs.contains($0.id) }
        return saved + new
    }

    func reload() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            let results = await Task.detached(priority: .userInitiated) {
                ApplicationScanner().scan()
            }.value
            applications = results
            reconcileLayout(with: results)
            isLoading = false
            normalizePageAndSelection()
        }
    }

    func prepareForPresentation() {
        normalizePageAndSelection()
    }

    func launch(_ application: ApplicationItem, completion: (() -> Void)? = nil) {
        if NSWorkspace.shared.open(application.url) {
            completion?()
        } else {
            errorMessage = "无法打开“\(application.name)”。请确认应用仍然存在且可以运行。"
        }
    }

    func launchSelected(completion: (() -> Void)? = nil) {
        guard let selectedApplication else { return }
        launch(selectedApplication, completion: completion)
    }

    func select(_ application: ApplicationItem) {
        selectedApplicationID = application.id
    }

    func moveSelection(horizontal: Int = 0, vertical: Int = 0) {
        let items = pageApplications
        guard !items.isEmpty else {
            selectedApplicationID = nil
            return
        }

        let index = items.firstIndex { $0.id == selectedApplicationID } ?? 0
        let proposed = index + horizontal + vertical * Self.gridColumnCount
        let destination = min(max(0, proposed), items.count - 1)
        selectedApplicationID = items[destination].id
    }

    func changePage(by offset: Int) {
        let destination = min(max(0, currentPage + offset), pageCount - 1)
        guard destination != currentPage else { return }
        pageTransitionDirection = destination > currentPage ? 1 : -1
        currentPage = destination
        selectedApplicationID = pageApplications.first?.id
    }

    func setPage(_ page: Int) {
        let destination = min(max(0, page), pageCount - 1)
        if destination != currentPage {
            pageTransitionDirection = destination > currentPage ? 1 : -1
        }
        currentPage = destination
        selectedApplicationID = pageApplications.first?.id
    }

    func moveApplication(_ sourceID: String, before targetID: String) {
        guard sourceID != targetID,
              let sourceIndex = layout.orderedApplicationIDs.firstIndex(of: sourceID),
              let targetIndex = layout.orderedApplicationIDs.firstIndex(of: targetID) else {
            return
        }

        layout.orderedApplicationIDs.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        layout.orderedApplicationIDs.insert(sourceID, at: adjustedTarget)
        selectedApplicationID = sourceID
        saveLayout()
    }

    func moveApplication(_ sourceID: String, toPage page: Int) {
        let destinationPage = min(max(0, page), pageCount - 1)
        guard let sourceIndex = layout.orderedApplicationIDs.firstIndex(of: sourceID) else {
            return
        }

        layout.orderedApplicationIDs.remove(at: sourceIndex)
        let destinationIndex = min(
            destinationPage * Self.pageSize,
            layout.orderedApplicationIDs.count
        )
        layout.orderedApplicationIDs.insert(sourceID, at: destinationIndex)
        pageTransitionDirection = destinationPage > currentPage ? 1 : -1
        currentPage = destinationPage
        selectedApplicationID = sourceID
        saveLayout()
    }

    func hide(_ application: ApplicationItem) {
        layout.hiddenApplicationIDs.insert(application.id)
        saveLayout()
        normalizePageAndSelection()
    }

    func restore(_ application: ApplicationItem) {
        layout.hiddenApplicationIDs.remove(application.id)
        saveLayout()
        normalizePageAndSelection()
    }

    func restoreAllHiddenApplications() {
        layout.hiddenApplicationIDs.removeAll()
        saveLayout()
        normalizePageAndSelection()
    }

    private func reconcileLayout(with results: [ApplicationItem]) {
        let resultIDs = Set(results.map(\.id))
        layout.orderedApplicationIDs.removeAll { !resultIDs.contains($0) }
        let orderedIDs = Set(layout.orderedApplicationIDs)
        layout.orderedApplicationIDs.append(
            contentsOf: results.map(\.id).filter { !orderedIDs.contains($0) }
        )
        saveLayout()
    }

    private func normalizePageAndSelection() {
        currentPage = min(max(0, currentPage), pageCount - 1)
        let pageIDs = Set(pageApplications.map(\.id))
        if let selectedApplicationID, pageIDs.contains(selectedApplicationID) {
            return
        }
        selectFirstApplication()
    }

    private func selectFirstApplication() {
        currentPage = min(max(0, currentPage), pageCount - 1)
        selectedApplicationID = pageApplications.first?.id
    }

    private func saveLayout() {
        do {
            try layoutRepository.save(layout)
        } catch {
            errorMessage = "无法保存布局：\(error.localizedDescription)"
        }
    }
}
