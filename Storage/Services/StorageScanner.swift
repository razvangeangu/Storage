import Foundation

actor StorageScanner {
    private var cancelled = false

    func cancel() {
        cancelled = true
    }

    func scan() -> AsyncStream<ScanProgress> {
        cancelled = false
        return AsyncStream { continuation in
            Task {
                await self.runScan(continuation: continuation)
            }
        }
    }

    private func runScan(continuation: AsyncStream<ScanProgress>.Continuation) async {
        let hasFullDiskAccess = PermissionService.hasFullDiskAccess()
        let partialCategoryIDs = Self.partialCategoryIDs(
            from: KnownPaths.inaccessibleScanRoots()
        )
        continuation.yield(.started)

        guard let disk = DiskSpaceService.bootVolumeInfo() else {
            continuation.yield(.failed("Could not read disk capacity"))
            continuation.finish()
            return
        }

        let plan = await buildScanPlan()
        if cancelled {
            continuation.finish()
            return
        }

        var itemsByCategory: [String: [StorageItem]] = [:]
        var seenPaths: Set<String> = []
        let counter = ScanStepCounter(total: max(1, plan.entries.count))

        await collectSizedEntries(
            plan.entries,
            into: &itemsByCategory,
            seenPaths: &seenPaths,
            counter: counter,
            continuation: continuation
        )

        if cancelled {
            continuation.finish()
            return
        }

        var categories = buildCategories(from: itemsByCategory, partialCategoryIDs: partialCategoryIDs)
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

        if hidden > 0 {
            categories.append(StorageCategory(
                id: "hidden",
                name: "Other & system",
                icon: "externaldrive.fill.badge.questionmark",
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

    // MARK: - Scan plan

    private struct ScanPlan {
        let entries: [URL]
    }

    private func buildScanPlan() async -> ScanPlan {
        async let appBundles = findAllAppBundles()
        async let documentEntries = listEntries(
            for: KnownPaths.documentDirectoryRoots,
            includeHiddenEntries: false
        )
        async let developerEntries = listDeveloperEntries()
        async let libraryEntries = listLibraryEntries()

        var uniquePaths = Set<String>()
        var entries: [URL] = []

        func appendUnique(_ urls: [URL]) {
            for url in urls {
                if uniquePaths.insert(url.path).inserted {
                    entries.append(url)
                }
            }
        }

        appendUnique(await appBundles)
        appendUnique(await documentEntries)
        appendUnique(await developerEntries)
        appendUnique(await libraryEntries)

        let deduped = Self.dropNestedPaths(entries)
        return ScanPlan(entries: deduped)
    }

    /// If both a parent and child are scheduled, keep only the parent (one `du` walk).
    private nonisolated static func dropNestedPaths(_ urls: [URL]) -> [URL] {
        let sorted = urls.sorted { $0.path.count < $1.path.count }
        var kept: [URL] = []

        for url in sorted {
            let path = url.path
            let isNested = kept.contains { parent in
                path != parent.path && path.hasPrefix(parent.path + "/")
            }
            if !isNested {
                kept.append(url)
            }
        }
        return kept
    }

    private func findAllAppBundles() async -> [URL] {
        let roots = KnownPaths.applicationBundleRoots.filter {
            PermissionService.canAccess(path: $0.path)
        }
        guard !roots.isEmpty else { return [] }
        return await withTaskGroup(of: [URL].self) { group in
            for root in roots {
                group.addTask(priority: .utility) {
                    Self.findAppBundles(in: root)
                }
            }

            var bundles: [URL] = []
            for await found in group {
                bundles.append(contentsOf: found)
            }
            return bundles
        }
    }

    private func listDeveloperEntries() async -> [URL] {
        let projectsRoot = KnownPaths.home.appendingPathComponent("Developer", isDirectory: true)
        var entries: [URL] = []

        for root in KnownPaths.developerDirectoryRoots {
            let includeHidden = root.url.standardized == projectsRoot.standardized
            let found = await listEntries(for: [root], includeHiddenEntries: includeHidden)
            entries.append(contentsOf: found)
        }
        return entries
    }

    private func listEntries(
        for roots: [KnownPaths.CategoryRoot],
        includeHiddenEntries: Bool
    ) async -> [URL] {
        let accessibleRoots = roots.filter { PermissionService.canAccess(path: $0.url.path) }
        guard !accessibleRoots.isEmpty else { return [] }
        return await withTaskGroup(of: [URL].self) { group in
            for root in accessibleRoots {
                group.addTask(priority: .utility) {
                    Self.plannedEntries(at: root.url, includeHiddenEntries: includeHiddenEntries)
                }
            }

            var entries: [URL] = []
            for await found in group {
                entries.append(contentsOf: found)
            }
            return entries
        }
    }

    private func listLibraryEntries() async -> [URL] {
        let roots = KnownPaths.accessibleScanRoots()
        return await withTaskGroup(of: [URL].self) { group in
            for root in roots {
                group.addTask(priority: .utility) {
                    Self.plannedEntries(at: root, includeHiddenEntries: false)
                }
            }

            var entries: [URL] = []
            for await found in group {
                entries.append(contentsOf: found)
            }
            return entries
        }
    }

    private nonisolated static func plannedEntries(at url: URL, includeHiddenEntries: Bool) -> [URL] {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return [] }

        if !isDir.boolValue { return [url] }

        let options: FileManager.DirectoryEnumerationOptions = includeHiddenEntries ? [] : [.skipsHiddenFiles]
        if let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: options
        ), !contents.isEmpty {
            return contents
        }
        return [url]
    }

    // MARK: - Parallel sizing

    private func collectSizedEntries(
        _ entries: [URL],
        into itemsByCategory: inout [String: [StorageItem]],
        seenPaths: inout Set<String>,
        counter: ScanStepCounter,
        continuation: AsyncStream<ScanProgress>.Continuation
    ) async {
        guard !entries.isEmpty else { return }

        let limit = ScanConcurrency.sizingLimit
        for chunkStart in stride(from: 0, to: entries.count, by: limit) {
            if cancelled { return }
            let chunk = Array(entries[chunkStart..<min(chunkStart + limit, entries.count)])

            await withTaskGroup(of: (URL, Int64).self) { group in
                for url in chunk {
                    group.addTask(priority: .utility) {
                        (url, PathSizer.size(at: url))
                    }
                }

                for await (url, size) in group {
                    if cancelled { return }
                    yieldProgress(for: url.path, counter: counter, continuation: continuation)
                    addItem(url: url, size: size, seenPaths: &seenPaths, into: &itemsByCategory)
                }
            }
        }
    }

    private func yieldProgress(
        for path: String,
        counter: ScanStepCounter,
        continuation: AsyncStream<ScanProgress>.Continuation
    ) {
        let step = counter.advance()
        continuation.yield(.scanning(
            path: path,
            fraction: counter.fraction(for: step),
            itemsChecked: step
        ))
    }

    private nonisolated static func findAppBundles(in root: URL) -> [URL] {
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

    private func buildCategories(
        from itemsByCategory: [String: [StorageItem]],
        partialCategoryIDs: Set<String>
    ) -> [StorageCategory] {
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
                isPartial: partialCategoryIDs.contains(categoryID)
            ))
        }

        return categories
    }

    private nonisolated static func partialCategoryIDs(from inaccessibleRoots: [URL]) -> Set<String> {
        var ids = Set<String>()
        for root in inaccessibleRoots {
            let meta = CategoryClassifier.category(for: root.path)
            ids.insert(meta.id)
        }
        return ids
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
}

private final class ScanStepCounter: @unchecked Sendable {
    let total: Int
    private var completed = 0

    init(total: Int) {
        self.total = max(total, 1)
    }

    func advance() -> Int {
        completed += 1
        return completed
    }

    func fraction(for step: Int) -> Double {
        min(0.99, Double(step) / Double(total))
    }
}
