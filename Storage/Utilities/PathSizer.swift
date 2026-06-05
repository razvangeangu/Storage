import Foundation

enum PathSizer {
    /// Best-effort byte size for a file or directory.
    nonisolated static func size(at url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return 0
        }

        if isDir.boolValue {
            return directorySize(at: url)
        }
        return fileSize(at: url)
    }

    // MARK: - Files

    private nonisolated static func fileSize(at url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .totalFileAllocatedSizeKey]
        if let values = try? url.resourceValues(forKeys: keys) {
            if let allocated = values.totalFileAllocatedSize, allocated > 0 {
                return Int64(allocated)
            }
            if let fileSize = values.fileSize { return Int64(fileSize) }
        }
        return 0
    }

    // MARK: - Directories

    /// Directories never use `totalFileSizeKey` — on macOS that walks the full tree in-process
    /// (e.g. `node_modules`) and blocks far longer than `/usr/bin/du`.
    private nonisolated static func directorySize(at url: URL) -> Int64 {
        let timeout = HeavyPathDetector.duTimeout(for: url)
        if let du = duSize(at: url, timeout: timeout), du > 0 {
            return du
        }
        return shallowDirectorySize(at: url)
    }

    private nonisolated static func shallowDirectorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        let children = (try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        if children.isEmpty {
            return duSize(at: url, timeout: 15) ?? 0
        }

        var total: Int64 = 0
        let perChildTimeout: TimeInterval = HeavyPathDetector.isHeavyDirectory(url) ? 90 : 30

        for chunk in children.chunked(into: 16) {
            let paths = chunk.map(\.path)
            let sizes = duSizeBatch(paths: paths, timeout: perChildTimeout)
            for path in paths {
                total += sizes[path] ?? 0
            }
        }

        return total
    }

    // MARK: - du

    private nonisolated static func duSize(at url: URL, timeout: TimeInterval) -> Int64? {
        duSizeBatch(paths: [url.path], timeout: timeout)[url.path]
    }

    private nonisolated static func duSizeBatch(paths: [String], timeout: TimeInterval) -> [String: Int64] {
        guard !paths.isEmpty else { return [:] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        process.arguments = ["-sk"] + paths
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return [:]
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            return [:]
        }

        guard process.terminationStatus == 0 else { return [:] }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [:] }

        var sizes: [String: Int64] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard parts.count == 2,
                  let kb = Int64(parts[0]) else { continue }
            let path = String(parts[1])
            sizes[path] = kb * 1024
        }
        return sizes
    }
}

// MARK: - Heavy paths (node_modules, dev projects, caches)

enum HeavyPathDetector {
    nonisolated static let heavyDirectoryNames: Set<String> = [
        "node_modules",
        ".git",
        "DerivedData",
        "build",
        "dist",
        ".next",
        ".turbo",
        "Pods",
        "Carthage",
        "vendor",
        "__pycache__",
        ".venv",
        "target",
        ".gradle",
        ".pnpm-store",
        ".npm",
        ".yarn",
        ".bun",
        ".cache",
        "Caches",
    ]

    nonisolated static func isHeavyDirectory(_ url: URL) -> Bool {
        if heavyDirectoryNames.contains(url.lastPathComponent) {
            return true
        }
        return isDeveloperProjectRoot(url)
    }

    nonisolated static func isDeveloperProjectRoot(_ url: URL) -> Bool {
        url.deletingLastPathComponent().standardized.path
            == KnownPaths.home.appendingPathComponent("Developer").standardized.path
    }

    nonisolated static func duTimeout(for url: URL) -> TimeInterval {
        if isHeavyDirectory(url) { return 180 }
        if url.pathComponents.contains("Developer") { return 120 }
        return 60
    }
}

private extension Array {
    nonisolated func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        var chunks: [[Element]] = []
        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }
        return chunks
    }
}
