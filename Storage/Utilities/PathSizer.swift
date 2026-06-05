import Foundation

enum PathSizer {
    /// Best-effort byte size for a file or directory, matching `du` more closely than a shallow walk.
    nonisolated static func size(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [
            .totalFileSizeKey,
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .isDirectoryKey,
        ]

        if let values = try? url.resourceValues(forKeys: keys) {
            if let total = values.totalFileSize, total > 0 {
                return Int64(total)
            }
            if let allocated = values.totalFileAllocatedSize, allocated > 0 {
                return Int64(allocated)
            }
            if values.isDirectory != true, let fileSize = values.fileSize {
                return Int64(fileSize)
            }
        }

        return enumerateSize(at: url)
    }

    private nonisolated static func enumerateSize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey, .isRegularFileKey]) else {
                continue
            }
            if values.isRegularFile == true {
                if let allocated = values.totalFileAllocatedSize {
                    total += Int64(allocated)
                } else if let fileSize = values.fileSize {
                    total += Int64(fileSize)
                }
            }
        }
        return total
    }
}
