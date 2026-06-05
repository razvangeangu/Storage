import Foundation

actor StorageScanner {
    private var cancelled = false

    func cancel() {
        cancelled = true
    }

    func scan(hasFullDiskAccess: Bool) -> AsyncStream<ScanProgress> {
        cancelled = false
        return AsyncStream { continuation in
            Task {
                await self.runScan(hasFullDiskAccess: hasFullDiskAccess, continuation: continuation)
            }
        }
    }

    private func runScan(hasFullDiskAccess: Bool, continuation: AsyncStream<ScanProgress>.Continuation) async {
        continuation.yield(.started)

        guard let disk = DiskSpaceService.bootVolumeInfo() else {
            continuation.yield(.failed("Could not read disk capacity"))
            continuation.finish()
            return
        }

        let roots = KnownPaths.scanRoots(hasFullDiskAccess: hasFullDiskAccess)
        var itemsByCategory: [String: [StorageItem]] = [:]
        var directoriesVisited = 0
        let totalRoots = roots.count

        for (index, root) in roots.enumerated() {
            if cancelled { return }

            let fraction = Double(index) / Double(totalRoots)
            continuation.yield(.scanning(path: root.path, fraction: fraction))

            await collectItems(
                at: root,
                into: &itemsByCategory,
                directoriesVisited: &directoriesVisited,
                continuation: continuation,
                rootFraction: fraction,
                rootWeight: 1.0 / Double(totalRoots)
            )
        }

        if cancelled {
            continuation.finish()
            return
        }

        var categories = buildCategories(from: itemsByCategory, isPartial: !hasFullDiskAccess)
        nestSystemData(into: &categories)

        let accounted = categories.reduce(Int64(0)) { $0 + $1.size }
        let hidden = max(0, disk.usedBytes - accounted)

        if !hasFullDiskAccess, hidden > 0 {
            categories.append(StorageCategory(
                id: "hidden",
                name: "Other / System (scan with Full Disk Access)",
                icon: "questionmark.folder.fill",
                size: hidden,
                children: [],
                subcategories: [],
                isPartial: true
            ))
        }

        let result = ScanResult(
            scannedAt: Date(),
            volumeName: disk.volumeName,
            totalBytes: disk.totalBytes,
            availableBytes: disk.availableBytes,
            categories: categories.sorted { lhs, rhs in
                let li = CategoryClassifier.categoryOrder.firstIndex(of: lhs.id) ?? 999
                let ri = CategoryClassifier.categoryOrder.firstIndex(of: rhs.id) ?? 999
                return li < ri
            },
            hasFullDiskAccess: hasFullDiskAccess,
            hiddenBytes: hidden
        )

        ScanCacheStore.save(result)
        continuation.yield(.completed(result))
        continuation.finish()
    }

    private func collectItems(
        at root: URL,
        into itemsByCategory: inout [String: [StorageItem]],
        directoriesVisited: inout Int,
        continuation: AsyncStream<ScanProgress>.Continuation,
        rootFraction: Double,
        rootWeight: Double
    ) async {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir) else { return }

        if isDir.boolValue {
            if shouldTreatAsLeaf(root) {
                let size = directorySize(at: root)
                addItem(url: root, size: size, into: &itemsByCategory)
                return
            }

            guard let contents = try? fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            for entry in contents {
                if cancelled { return }
                directoriesVisited += 1
                if directoriesVisited % 50 == 0 {
                    continuation.yield(.scanning(path: entry.path, fraction: min(0.99, rootFraction + rootWeight * 0.5)))
                }

                var entryIsDir: ObjCBool = false
                fm.fileExists(atPath: entry.path, isDirectory: &entryIsDir)

                if entryIsDir.boolValue {
                    if shouldTreatAsLeaf(entry) {
                        let size = directorySize(at: entry)
                        addItem(url: entry, size: size, into: &itemsByCategory)
                    } else if shouldRecurse(into: entry, root: root) {
                        await collectItems(
                            at: entry,
                            into: &itemsByCategory,
                            directoriesVisited: &directoriesVisited,
                            continuation: continuation,
                            rootFraction: rootFraction,
                            rootWeight: rootWeight
                        )
                    }
                } else {
                    let size = fileSize(at: entry)
                    if size > 0 {
                        addItem(url: entry, size: size, into: &itemsByCategory)
                    }
                }
            }
        } else {
            let size = fileSize(at: root)
            addItem(url: root, size: size, into: &itemsByCategory)
        }
    }

    private func shouldTreatAsLeaf(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if KnownPaths.packageSuffixes.contains(where: { name.hasSuffix($0) }) {
            return true
        }
        if url.pathExtension == "photoslibrary" { return true }
        return false
    }

    private func shouldRecurse(into url: URL, root: URL) -> Bool {
        let path = url.path
        if path.contains("/dev/") || path.contains("/.git/") { return false }
        if url.lastPathComponent == "Volumes" { return false }
        if path == KnownPaths.home.appendingPathComponent("Library").path {
            return true
        }
        if path.hasPrefix("/Applications/") && url.pathExtension == "app" {
            return false
        }
        let depth = path.split(separator: "/").count - root.path.split(separator: "/").count
        if depth > 6 { return false }
        return true
    }

    private func addItem(url: URL, size: Int64, into itemsByCategory: inout [String: [StorageItem]]) {
        guard size > 0 else { return }
        let path = url.path
        let meta = CategoryClassifier.category(for: path)
        let locked = CleanupService.isLocked(path: path)
        let deletable = CleanupService.isWhitelisted(path: path) && CleanupService.isWritable(path: path)

        let item = StorageItem(
            id: path,
            path: path,
            name: url.lastPathComponent,
            size: size,
            categoryID: meta.id,
            isDeletable: deletable && !locked,
            isLocked: locked
        )

        itemsByCategory[meta.id, default: []].append(item)
    }

    private func buildCategories(from itemsByCategory: [String: [StorageItem]], isPartial: Bool) -> [StorageCategory] {
        var categories: [StorageCategory] = []

        for (categoryID, items) in itemsByCategory {
            let sorted = items.sorted { $0.size > $1.size }
            let meta = sorted.first.map { CategoryClassifier.category(for: $0.path) }
                ?? (categoryID, categoryID, "folder.fill")
            let total = sorted.reduce(Int64(0)) { $0 + $1.size }

            categories.append(StorageCategory(
                id: categoryID,
                name: meta.1,
                icon: meta.2,
                size: total,
                children: sorted,
                subcategories: [],
                isPartial: isPartial && ["system_data", "caches", "logs", "containers"].contains(categoryID)
            ))
        }

        return categories
    }

    private func nestSystemData(into categories: inout [StorageCategory]) {
        let systemChildIDs = Set(["containers", "caches", "logs", "snapshots"])
        var systemChildren: [StorageCategory] = []
        var remaining: [StorageCategory] = []

        for category in categories {
            if systemChildIDs.contains(category.id) {
                systemChildren.append(category)
            } else {
                remaining.append(category)
            }
        }

        guard !systemChildren.isEmpty else {
            categories = remaining
            return
        }

        let systemSize = systemChildren.reduce(Int64(0)) { $0 + $1.size }
        let systemCategory = StorageCategory(
            id: "system_data_group",
            name: "System Data",
            icon: "gearshape.2.fill",
            size: systemSize,
            children: [],
            subcategories: systemChildren.sorted { $0.size > $1.size },
            isPartial: systemChildren.contains { $0.isPartial }
        )

        categories = remaining + [systemCategory]
    }

    private func fileSize(at url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    private func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        var count = 0
        for case let fileURL as URL in enumerator {
            if cancelled { break }
            count += 1
            if count > 10_000 { break }
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}
