import Foundation

enum KnownPaths {
    nonisolated static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    nonisolated static var tmp: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    nonisolated static func scanRoots(hasFullDiskAccess: Bool) -> [URL] {
        var roots: [URL] = [
            home,
            URL(fileURLWithPath: "/Applications", isDirectory: true),
        ]

        if hasFullDiskAccess {
            roots.append(contentsOf: [
                URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
                URL(fileURLWithPath: "/Library/Logs", isDirectory: true),
            ])
        }

        return roots
    }

    nonisolated static let cleanupWhitelistPrefixes: [String] = [
        home.appendingPathComponent("Library/Caches").path + "/",
        home.appendingPathComponent("Library/Logs").path + "/",
        home.appendingPathComponent(".Trash").path + "/",
        home.appendingPathComponent("Downloads").path + "/",
        home.appendingPathComponent("Developer/Xcode/DerivedData").path + "/",
    ]

    nonisolated static let neverDeletablePrefixes: [String] = [
        "/System/",
        "/usr/",
        "/bin/",
        "/sbin/",
        "/Library/",
        "/private/var/vm/",
    ]

    nonisolated static let packageSuffixes = [".app", ".photoslibrary", ".framework", ".xcodeproj", ".xcworkspace"]
}
