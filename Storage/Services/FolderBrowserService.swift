import Foundation

enum FolderBrowserService {
    /// Lists immediate children of a folder with sizes (parallel `du`, shallow only).
    static func listContents(at url: URL) async -> [StorageItem] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        let children = (try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        guard !children.isEmpty else { return [] }

        let limit = ScanConcurrency.sizingLimit
        var items: [StorageItem] = []

        for chunkStart in stride(from: 0, to: children.count, by: limit) {
            let chunk = Array(children[chunkStart..<min(chunkStart + limit, children.count)])
            let sized = await withTaskGroup(of: StorageItem?.self) { group in
                for child in chunk {
                    group.addTask(priority: .utility) {
                        item(for: child)
                    }
                }
                var batch: [StorageItem] = []
                for await entry in group {
                    if let entry { batch.append(entry) }
                }
                return batch
            }
            items.append(contentsOf: sized)
        }

        return items.sorted { $0.size > $1.size }
    }

    private static func item(for url: URL) -> StorageItem? {
        let path = url.path
        let size = PathSizer.size(at: url)
        guard size > 0 else { return nil }

        let meta = CategoryClassifier.category(for: path)
        let locked = CleanupService.isLocked(path: path)
        let deletable = CleanupService.isUserDeletable(path: path)

        return StorageItem(
            id: path,
            path: path,
            name: url.lastPathComponent,
            size: size,
            categoryID: meta.id,
            isDeletable: deletable && !locked,
            isLocked: locked
        )
    }

    nonisolated static func isDirectory(at path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
