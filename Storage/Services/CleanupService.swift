import Foundation

struct CleanupResult: Sendable {
    let succeeded: [StorageItem]
    let failed: [(StorageItem, String)]
    let freedBytes: Int64
}

enum CleanupService {
    nonisolated static func canDelete(item: StorageItem) -> Bool {
        isUserDeletable(path: item.path)
    }

    nonisolated static func isUserDeletable(path: String) -> Bool {
        guard isWritable(path: path), !isLocked(path: path) else { return false }

        if DeletionRiskService.isSystemProtected(path: path) {
            return false
        }

        if KnownPaths.neverDeletableExactPaths.contains(path) {
            return false
        }

        let normalized = path.hasSuffix("/") ? path : path + "/"
        if KnownPaths.neverDeletablePrefixes.contains(where: { normalized.hasPrefix($0) || path == String($0.dropLast()) }) {
            return false
        }

        return KnownPaths.cleanupWhitelistPrefixes.contains { normalized.hasPrefix($0) }
    }

    nonisolated static func isWhitelisted(path: String) -> Bool {
        isUserDeletable(path: path)
    }

    nonisolated static func isWritable(path: String) -> Bool {
        FileManager.default.isWritableFile(atPath: path)
    }

    nonisolated static func isLocked(path: String) -> Bool {
        if KnownPaths.neverDeletablePrefixes.contains(where: { path.hasPrefix($0) }) {
            return true
        }
        if path.hasPrefix("/Library/") || path.hasPrefix("/private/var/") {
            return !isWritable(path: path)
        }
        return !isWritable(path: path) && !path.hasPrefix(KnownPaths.home.path)
    }

    static func moveToTrash(items: [StorageItem]) -> CleanupResult {
        let fm = FileManager.default
        var succeeded: [StorageItem] = []
        var failed: [(StorageItem, String)] = []
        var freed: Int64 = 0

        for item in items {
            guard canDelete(item: item) else {
                failed.append((item, "Not deletable"))
                continue
            }
            do {
                try fm.trashItem(at: item.url, resultingItemURL: nil)
                succeeded.append(item)
                freed += item.size
            } catch {
                failed.append((item, error.localizedDescription))
            }
        }

        return CleanupResult(succeeded: succeeded, failed: failed, freedBytes: freed)
    }
}
