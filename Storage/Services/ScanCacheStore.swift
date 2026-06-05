import Foundation

enum ScanCacheStore {
    private static var cacheURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Storage", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("last-scan.json")
    }

    nonisolated static func load() -> ScanResult? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? JSONDecoder().decode(ScanResult.self, from: data)
    }

    nonisolated static func save(_ result: ScanResult) {
        guard let data = try? JSONEncoder().encode(result) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}
