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
        var seenPaths: Set<String> = []
        var directoriesVisited = 0
        let dedicatedPasses = 3
        let totalRoots = roots.count + dedicatedPasses
        var passIndex = 0

        continuation.yield(.scanning(path: "/Applications", fraction: 0))
        await collectApplicationBundles(
            into: &itemsByCategory,
            seenPaths: &seenPaths,
            continuation: continuation
        )
        passIndex += 1

        continuation.yield(.scanning(path: "Documents", fraction: Double(passIndex) / Double(totalRoots)))
        await collectCategoryDirectoryEntries(
            roots: KnownPaths.documentDirectoryRoots,
            into: &itemsByCategory,
            seenPaths: &seenPaths
        )
        passIndex += 1

        continuation.yield(.scanning(path: "Developer", fraction: Double(passIndex) / Double(totalRoots)))
        await collectCategoryDirectoryEntries(
            roots: KnownPaths.developerDirectoryRoots,
            includeHiddenEntries: true,
            into: &itemsByCategory,
            seenPaths: &seenPaths
        )
        passIndex += 1

        for (index, root) in roots.enumerated() {
            if cancelled { return }

            let fraction = Double(passIndex + index) / Double(totalRoots)
            continuation.yield(.scanning(path: root.path, fraction: fraction))

            await collectItems(
                at: root,
                into: &itemsByCategory,
                seenPaths: &seenPaths,
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
        nestGroupedCategory(
            parentID: "documents",
            roots: KnownPaths.documentDirectoryRoots,
            into: &categories
        )
        nestGroupedCategory(
            parentID: "developer",
            roots: KnownPaths.developerDirectoryRoots,
            into: &categories
        )
        ensureWellKnownCategories(into: &categories)

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

    private func collectApplicationBundles(
        into itemsByCategory: inout [String: [StorageItem]],
        seenPaths: inout Set<String>,
        continuation: AsyncStream<ScanProgress>.Continuation
    ) async {
        for root in KnownPaths.applicationBundleRoots {
            if cancelled { return }
            continuation.yield(.scanning(path: root.path, fraction: 0.05))

            for bundle in findAppBundles(in: root) {
                if cancelled { return }
                let size = PathSizer.size(at: bundle)
                addItem(url: bundle, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
            }
        }
    }

    private func collectCategoryDirectoryEntries(
        roots: [KnownPaths.CategoryRoot],
        includeHiddenEntries: Bool = false,
        into itemsByCategory: inout [String: [StorageItem]],
        seenPaths: inout Set<String>
    ) async {
        let fm = FileManager.default
        let listingOptions: FileManager.DirectoryEnumerationOptions = includeHiddenEntries ? [] : [.skipsHiddenFiles]

        for root in roots {
            if cancelled { return }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: root.url.path, isDirectory: &isDir) else { continue }

            if isDir.boolValue {
                guard let contents = try? fm.contentsOfDirectory(
                    at: root.url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: listingOptions
                ) else { continue }

                if contents.isEmpty {
                    let size = PathSizer.size(at: root.url)
                    addItem(url: root.url, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
                    continue
                }

                for entry in contents {
                    if cancelled { return }
                    let size = PathSizer.size(at: entry)
                    addItem(url: entry, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
                }
            } else {
                let size = PathSizer.size(at: root.url)
                addItem(url: root.url, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
            }
        }
    }

    private func findAppBundles(in root: URL) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: root.path, isDirectory: &isDir), isDir.boolValue else {
            return []
        }

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var bundles: [URL] = []
        for case let url as URL in enumerator {
            if url.lastPathComponent.hasSuffix(".app") {
                bundles.append(url)
                enumerator.skipDescendants()
            }
        }
        return bundles
    }

    private func collectItems(
        at root: URL,
        into itemsByCategory: inout [String: [StorageItem]],
        seenPaths: inout Set<String>,
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
                let size = PathSizer.size(at: root)
                addItem(url: root, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
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
                        let size = PathSizer.size(at: entry)
                        addItem(url: entry, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
                    } else if shouldRecurse(into: entry, root: root) {
                        await collectItems(
                            at: entry,
                            into: &itemsByCategory,
                            seenPaths: &seenPaths,
                            directoriesVisited: &directoriesVisited,
                            continuation: continuation,
                            rootFraction: rootFraction,
                            rootWeight: rootWeight
                        )
                    }
                } else {
                    let size = fileSize(at: entry)
                    if size > 0 {
                        addItem(url: entry, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
                    }
                }
            }
        } else {
            let size = fileSize(at: root)
            addItem(url: root, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
        }
    }

    private func shouldTreatAsLeaf(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        if name.hasSuffix(".app") { return true }
        if KnownPaths.packageSuffixes.contains(where: { name.hasSuffix($0) }) {
            return true
        }
        if url.pathExtension == "photoslibrary" { return true }
        if isApplicationSupportEntry(url) { return true }
        if isDocumentOrDeveloperEntry(url) { return true }
        return false
    }

    private func isApplicationSupportEntry(_ url: URL) -> Bool {
        url.deletingLastPathComponent().path == KnownPaths.applicationSupportDirectory.path
    }

    private func isDocumentOrDeveloperEntry(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent().path
        return KnownPaths.documentDirectoryRoots.contains { $0.url.path == parent }
            || KnownPaths.developerDirectoryRoots.contains { $0.url.path == parent }
    }

    private func shouldRecurse(into url: URL, root: URL) -> Bool {
        let path = url.path
        if path.contains("/dev/") || path.contains("/.git/") { return false }
        if url.lastPathComponent == "Volumes" { return false }
        if url.lastPathComponent.hasSuffix(".app") { return false }

        for appRoot in KnownPaths.applicationBundleRoots {
            let appRootPath = appRoot.path
            if path == appRootPath || path.hasPrefix(appRootPath + "/") {
                return false
            }
        }

        if KnownPaths.isUnderDocumentRoot(path: path) || KnownPaths.isUnderDeveloperRoot(path: path) {
            return false
        }

        if path == KnownPaths.home.appendingPathComponent("Library").path {
            return true
        }
        let depth = path.split(separator: "/").count - root.path.split(separator: "/").count
        if depth > 6 { return false }
        return true
    }

    private func addItem(
        url: URL,
        size: Int64,
        seenPaths: inout Set<String>,
        into itemsByCategory: inout [String: [StorageItem]]
    ) {
        guard size > 0 else { return }
        let path = url.path
        guard seenPaths.insert(path).inserted else { return }
        let meta = CategoryClassifier.category(for: path)
        let locked = CleanupService.isLocked(path: path)
        let deletable = CleanupService.isUserDeletable(path: path)

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

    private func nestGroupedCategory(
        parentID: String,
        roots: [KnownPaths.CategoryRoot],
        into categories: inout [StorageCategory]
    ) {
        guard let index = categories.firstIndex(where: { $0.id == parentID }) else { return }

        var parent = categories.remove(at: index)
        var subcategories: [StorageCategory] = []
        var groupedIDs = Set<String>()

        for root in roots {
            let prefix = root.url.path + "/"
            let matching = parent.children.filter {
                $0.path.hasPrefix(prefix) || $0.path == root.url.path
            }
            guard !matching.isEmpty else { continue }

            groupedIDs.formUnion(matching.map(\.id))
            let size = matching.reduce(Int64(0)) { $0 + $1.size }
            subcategories.append(StorageCategory(
                id: root.id,
                name: root.name,
                icon: root.icon,
                size: size,
                children: matching.sorted { $0.size > $1.size },
                subcategories: [],
                isPartial: parent.isPartial
            ))
        }

        let ungrouped = parent.children.filter { !groupedIDs.contains($0.id) }
        parent.children = ungrouped
        parent.subcategories = subcategories.sorted { $0.size > $1.size }
        parent.size = parent.children.reduce(Int64(0)) { $0 + $1.size }
            + parent.subcategories.reduce(Int64(0)) { $0 + $1.size }

        categories.append(parent)
    }

    private func ensureWellKnownCategories(into categories: inout [StorageCategory]) {
        let fm = FileManager.default

        let specs: [(id: String, name: String, icon: String, roots: [KnownPaths.CategoryRoot])] = [
            ("documents", "Documents", "doc.fill", KnownPaths.documentDirectoryRoots),
            ("developer", "Developer", "hammer.fill", KnownPaths.developerDirectoryRoots),
        ]

        for spec in specs {
            guard !categories.contains(where: { $0.id == spec.id }) else { continue }
            guard spec.roots.contains(where: { fm.fileExists(atPath: $0.url.path) }) else { continue }

            categories.append(StorageCategory(
                id: spec.id,
                name: spec.name,
                icon: spec.icon,
                size: 0,
                children: [],
                subcategories: [],
                isPartial: false
            ))
        }
    }

    private func fileSize(at url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

}
