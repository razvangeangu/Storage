import Foundation

enum ScanCacheStore {
    /// Bump when scan output shape or permission model changes so old caches are ignored.
    static let schemaVersion = 4

    static var cacheFileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Storage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last-scan.json")
    }

    private struct CachedScan: Codable {
        let schemaVersion: Int
        let result: ScanResult
    }

    nonisolated static func load() -> ScanResult? {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let cached = try? JSONDecoder().decode(CachedScan.self, from: data),
              cached.schemaVersion == schemaVersion else {
            return nil
        }
        return cached.result
    }

    nonisolated static func save(_ result: ScanResult) {
        let cached = CachedScan(schemaVersion: schemaVersion, result: result)
        guard let data = try? JSONEncoder().encode(cached) else { return }
        try? data.write(to: cacheFileURL, options: .atomic)
    }

    nonisolated static func clear() {
        try? FileManager.default.removeItem(at: cacheFileURL)
    }
}
