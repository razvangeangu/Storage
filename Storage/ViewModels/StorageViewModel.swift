import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class StorageViewModel {
    var scanResult: ScanResult?
    var isScanning = false
    var scanProgress: Double = 0
    var scanStatusText = ""
    var scanPhase = "Storage"
    var scanCurrentPath = ""
    var scanPathFeed: [ScanPathEntry] = []
    var scanItemsChecked = 0
    var hasFullDiskAccess = false

    private var lastRecordedPath = ""
    private var lastFeedUpdate = Date.distantPast
    var selectedItemIDs: Set<String> = []
    var cleanupError: String?
    var showCleanupConfirmation = false

    // MARK: - Browser navigation (Finder-style drill-down)

    var selectedCategoryID: String?
    var selectedSubcategoryID: String?
    var browserPathStack: [String] = []
    var folderListings: [String: [StorageItem]] = [:]
    var isLoadingFolder = false
    var browserRows: [BrowserRow] = []

    private let scanner = StorageScanner()
    private var scanTask: Task<Void, Never>?
    private var folderLoadTask: Task<Void, Never>?

    var diskInfo: DiskSpaceInfo? {
        if let result = scanResult {
            return DiskSpaceInfo(
                volumeName: result.volumeName,
                totalBytes: result.totalBytes,
                availableBytes: result.availableBytes
            )
        }
        return DiskSpaceService.bootVolumeInfo()
    }

    var selectedItems: [StorageItem] {
        var byID: [String: StorageItem] = [:]
        if let result = scanResult {
            for item in result.categories.flatMap(\.allItems) {
                byID[item.id] = item
            }
        }
        for items in folderListings.values {
            for item in items {
                byID[item.id] = item
            }
        }
        return selectedItemIDs.compactMap { byID[$0] }.filter(\.isDeletable)
    }

    var canNavigateBack: Bool {
        !browserPathStack.isEmpty || selectedSubcategoryID != nil
    }

    var breadcrumbSegments: [BrowserBreadcrumb] {
        guard let result = scanResult,
              let categoryID = selectedCategoryID,
              let category = result.categories.first(where: { $0.id == categoryID }) else {
            return []
        }

        var segments: [BrowserBreadcrumb] = [BrowserBreadcrumb(index: 0, title: category.name)]
        if let subID = selectedSubcategoryID,
           let sub = category.subcategories.first(where: { $0.id == subID }) {
            segments.append(BrowserBreadcrumb(index: segments.count, title: sub.name))
        }
        for path in browserPathStack {
            segments.append(BrowserBreadcrumb(
                index: segments.count,
                title: URL(fileURLWithPath: path).lastPathComponent
            ))
        }
        return segments
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    var selectionRiskSummary: DeletionRiskSummary {
        DeletionRiskService.summarize(items: selectedItems)
    }

    func deletionRisk(for item: StorageItem) -> DeletionRiskAssessment {
        DeletionRiskService.assess(path: item.path)
    }

    func onAppear() {
        hasFullDiskAccess = PermissionService.hasFullDiskAccess()
        if AppSettings.showCachedResultsOnLaunch,
           let cached = ScanCacheStore.load(),
           cached.hasFullDiskAccess == hasFullDiskAccess {
            scanResult = cached
            scanStatusText = "Last scanned \(Self.formatDate(cached.scannedAt))"
            bootstrapBrowser(for: cached)
        } else {
            scanStatusText = "Ready to scan"
        }
    }

    func clearCache() {
        ScanCacheStore.clear()
        scanResult = nil
        scanStatusText = "Ready to scan"
    }

    func refreshPermissions() {
        hasFullDiskAccess = PermissionService.hasFullDiskAccess()
    }

    func handleAppDidBecomeActive() {
        refreshPermissions()
    }

    func rescan() {
        scanTask?.cancel()
        scanTask = Task {
            await scanner.cancel()
            isScanning = true
            scanProgress = 0
            scanStatusText = "Starting scan…"
            scanPhase = "Storage"
            scanCurrentPath = ""
            scanPathFeed = []
            scanItemsChecked = 0
            lastRecordedPath = ""
            lastFeedUpdate = .distantPast
            selectedItemIDs.removeAll()
            resetBrowser()
            hasFullDiskAccess = PermissionService.hasFullDiskAccess()

            let stream = await scanner.scan(hasFullDiskAccess: hasFullDiskAccess)
            for await progress in stream {
                applyScanProgress(progress)
            }
        }
    }

    private func applyScanProgress(_ progress: ScanProgress) {
        switch progress {
        case .started:
            scanStatusText = "Scanning…"
            scanPhase = "Storage"
        case .scanning(let path, let fraction, let itemsChecked):
            scanProgress = fraction
            scanItemsChecked = max(scanItemsChecked, itemsChecked)
            scanPhase = ScanActivityFormatter.phase(for: path)
            scanCurrentPath = path
            scanStatusText = "Scanning \(URL(fileURLWithPath: path).lastPathComponent)…"
            recordScanPath(path)
        case .completed(let result):
            scanResult = result
            isScanning = false
            scanProgress = 1
            scanStatusText = "Last scanned \(Self.formatDate(result.scannedAt))"
            scanPathFeed = []
            bootstrapBrowser(for: result)
        case .failed(let message):
            isScanning = false
            scanStatusText = message
            scanPathFeed = []
        }
    }

    private func recordScanPath(_ path: String) {
        let now = Date()
        guard path != lastRecordedPath,
              now.timeIntervalSince(lastFeedUpdate) >= 0.04 else { return }

        lastRecordedPath = path
        lastFeedUpdate = now

        let entry = ScanActivityFormatter.entry(for: path)
        scanPathFeed.insert(entry, at: 0)
        if scanPathFeed.count > 8 {
            scanPathFeed.removeLast(scanPathFeed.count - 8)
        }
    }

    func toggleSelection(for item: StorageItem) {
        guard !item.isLocked, item.isDeletable else { return }
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    // MARK: - Browser

    func selectCategory(_ id: String?) {
        selectedCategoryID = id
        selectedSubcategoryID = nil
        browserPathStack = []
        refreshBrowserRows()
    }

    func openBrowserRow(_ row: BrowserRow) {
        switch row {
        case .group(let category):
            selectedSubcategoryID = category.id
            browserPathStack = []
            refreshBrowserRows()
        case .item(let item):
            guard FolderBrowserService.isDirectory(at: item.path) else { return }
            openFolder(path: item.path)
        }
    }

    func navigateBack() {
        if !browserPathStack.isEmpty {
            browserPathStack.removeLast()
            refreshBrowserRows()
        } else if selectedSubcategoryID != nil {
            selectedSubcategoryID = nil
            refreshBrowserRows()
        }
    }

    func navigateToBreadcrumb(index: Int) {
        guard index >= 0, index < breadcrumbSegments.count else { return }

        if index == 0 {
            selectedSubcategoryID = nil
            browserPathStack = []
            refreshBrowserRows()
            return
        }

        if index == 1, selectedSubcategoryID != nil {
            browserPathStack = []
            refreshBrowserRows()
            return
        }

        let pathBaseIndex = selectedSubcategoryID == nil ? 1 : 2
        let pathIndex = index - pathBaseIndex
        guard pathIndex >= 0, pathIndex < browserPathStack.count else { return }
        browserPathStack = Array(browserPathStack.prefix(pathIndex + 1))
        refreshBrowserRows()
    }

    func onCategorySelectionChanged() {
        selectedSubcategoryID = nil
        browserPathStack = []
        refreshBrowserRows()
    }

    private func openFolder(path: String) {
        browserPathStack.append(path)
        refreshBrowserRows()
        folderLoadTask?.cancel()
        folderLoadTask = Task {
            await loadFolderIfNeeded(path: path)
        }
    }

    private func loadFolderIfNeeded(path: String) async {
        if folderListings[path] != nil {
            refreshBrowserRows()
            return
        }
        isLoadingFolder = true
        let url = URL(fileURLWithPath: path)
        let items = await FolderBrowserService.listContents(at: url)
        if Task.isCancelled { return }
        folderListings[path] = items
        isLoadingFolder = false
        refreshBrowserRows()
    }

    private func resetBrowser() {
        folderLoadTask?.cancel()
        selectedCategoryID = nil
        selectedSubcategoryID = nil
        browserPathStack = []
        folderListings = [:]
        isLoadingFolder = false
        browserRows = []
    }

    private func bootstrapBrowser(for result: ScanResult) {
        if selectedCategoryID == nil,
           let largest = result.categories.max(by: { $0.size < $1.size }) {
            selectedCategoryID = largest.id
        }
        refreshBrowserRows()
    }

    private func refreshBrowserRows() {
        guard let result = scanResult,
              let categoryID = selectedCategoryID,
              let category = result.categories.first(where: { $0.id == categoryID }) else {
            browserRows = []
            return
        }

        if let folderPath = browserPathStack.last {
            browserRows = (folderListings[folderPath] ?? []).map { .item($0) }
            return
        }

        if let subID = selectedSubcategoryID,
           let sub = category.subcategories.first(where: { $0.id == subID }) {
            browserRows = rowsForItems(sub.children)
            return
        }

        if !category.subcategories.isEmpty {
            var rows = category.subcategories.map { BrowserRow.group($0) }
            rows.append(contentsOf: rowsForItems(category.children))
            browserRows = rows.sorted { $0.size > $1.size }
            return
        }

        browserRows = rowsForItems(category.children)
    }

    private func rowsForItems(_ items: [StorageItem]) -> [BrowserRow] {
        items.map { .item($0) }.sorted { $0.size > $1.size }
    }

    func toggleCategorySelection(for category: StorageCategory) {
        let selectable = category.allItems.filter { !$0.isLocked }
        guard !selectable.isEmpty else { return }

        let allSelected = selectable.allSatisfy { selectedItemIDs.contains($0.id) }
        if allSelected {
            for item in selectable {
                selectedItemIDs.remove(item.id)
            }
        } else {
            for item in selectable {
                selectedItemIDs.insert(item.id)
            }
        }
    }

    func clearSelection() {
        selectedItemIDs.removeAll()
    }

    func requestCleanup() {
        guard !selectedItems.isEmpty else { return }
        showCleanupConfirmation = true
    }

    func performCleanup() {
        let items = selectedItems
        let result = CleanupService.moveToTrash(items: items)
        selectedItemIDs.subtract(result.succeeded.map(\.id))

        if !result.failed.isEmpty {
            cleanupError = result.failed.map { "\($0.0.name): \($0.1)" }.joined(separator: "\n")
        }

        showCleanupConfirmation = false
        rescan()
    }

    func openFullDiskAccessSettings() {
        PermissionService.registerForFullDiskAccess()
        for url in PermissionService.fullDiskAccessSettingsURLs() {
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private static func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
