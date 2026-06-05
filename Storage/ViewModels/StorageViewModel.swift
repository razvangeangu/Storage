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
    var hasFullDiskAccess = false
    var selectedItemIDs: Set<String> = []
    var cleanupError: String?
    var showCleanupConfirmation = false

    private let scanner = StorageScanner()
    private var scanTask: Task<Void, Never>?

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
        guard let result = scanResult else { return [] }
        return result.categories
            .flatMap { $0.allItems }
            .filter { selectedItemIDs.contains($0.id) && $0.isDeletable }
    }

    var selectedBytes: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }

    func onAppear() {
        hasFullDiskAccess = PermissionService.hasFullDiskAccess()
        if let cached = ScanCacheStore.load() {
            scanResult = cached
        }
        rescan()
    }

    func refreshPermissions() {
        hasFullDiskAccess = PermissionService.hasFullDiskAccess()
    }

    func rescan() {
        scanTask?.cancel()
        scanTask = Task {
            await scanner.cancel()
            isScanning = true
            scanProgress = 0
            scanStatusText = "Starting scan…"
            selectedItemIDs.removeAll()
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
        case .scanning(let path, let fraction):
            scanProgress = fraction
            scanStatusText = "Scanning \(URL(fileURLWithPath: path).lastPathComponent)…"
        case .completed(let result):
            scanResult = result
            isScanning = false
            scanProgress = 1
            scanStatusText = "Last scanned \(Self.formatDate(result.scannedAt))"
        case .failed(let message):
            isScanning = false
            scanStatusText = message
        }
    }

    func toggleSelection(for item: StorageItem) {
        guard item.isDeletable else { return }
        if selectedItemIDs.contains(item.id) {
            selectedItemIDs.remove(item.id)
        } else {
            selectedItemIDs.insert(item.id)
        }
    }

    func selectAllDeletable(in category: StorageCategory) {
        for item in category.allItems where item.isDeletable {
            selectedItemIDs.insert(item.id)
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
        guard let url = PermissionService.fullDiskAccessSettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    private static func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
