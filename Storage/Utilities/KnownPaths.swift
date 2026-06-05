import Foundation

enum KnownPaths {
    nonisolated static var home: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    nonisolated static var tmp: URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    nonisolated static var applicationBundleRoots: [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    nonisolated static var applicationSupportDirectory: URL {
        home.appendingPathComponent("Library/Application Support", isDirectory: true)
    }

    struct CategoryRoot: Sendable {
        let id: String
        let name: String
        let icon: String
        let url: URL
    }

    nonisolated static var documentDirectoryRoots: [CategoryRoot] {
        [
            CategoryRoot(id: "documents_folder", name: "Documents", icon: "doc.fill",
                         url: home.appendingPathComponent("Documents", isDirectory: true)),
            CategoryRoot(id: "desktop", name: "Desktop", icon: "desktopcomputer",
                         url: home.appendingPathComponent("Desktop", isDirectory: true)),
            CategoryRoot(id: "downloads", name: "Downloads", icon: "arrow.down.circle.fill",
                         url: home.appendingPathComponent("Downloads", isDirectory: true)),
            CategoryRoot(id: "icloud_drive", name: "iCloud Drive", icon: "icloud.fill",
                         url: home.appendingPathComponent("Library/Mobile Documents", isDirectory: true)),
        ]
    }

    nonisolated static var developerDirectoryRoots: [CategoryRoot] {
        [
            CategoryRoot(id: "developer_projects", name: "Developer", icon: "folder.fill",
                         url: home.appendingPathComponent("Developer", isDirectory: true)),
            CategoryRoot(id: "xcode_support", name: "Xcode", icon: "hammer.fill",
                         url: home.appendingPathComponent("Library/Developer", isDirectory: true)),
            CategoryRoot(id: "xcode_caches", name: "Xcode Caches", icon: "clock.arrow.circlepath",
                         url: home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode", isDirectory: true)),
        ]
    }

    nonisolated static func isUnderDocumentRoot(path: String) -> Bool {
        isUnder(roots: documentDirectoryRoots, path: path)
    }

    nonisolated static func isUnderDeveloperRoot(path: String) -> Bool {
        isUnder(roots: developerDirectoryRoots, path: path)
    }

    nonisolated private static func isUnder(roots: [CategoryRoot], path: String) -> Bool {
        roots.contains { root in
            path == root.url.path || path.hasPrefix(root.url.path + "/")
        }
    }

    nonisolated static func scanRoots(hasFullDiskAccess: Bool) -> [URL] {
        var roots: [URL] = [
            home,
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
        home.appendingPathComponent("Library/Application Support").path + "/",
        home.appendingPathComponent(".Trash").path + "/",
        home.appendingPathComponent("Downloads").path + "/",
        home.appendingPathComponent("Desktop").path + "/",
        home.appendingPathComponent("Documents").path + "/",
        home.appendingPathComponent("Movies").path + "/",
        home.appendingPathComponent("Music").path + "/",
        home.appendingPathComponent("Pictures").path + "/",
        home.appendingPathComponent("Developer").path + "/",
        home.appendingPathComponent("Library/Developer").path + "/",
    ]

    nonisolated static let neverDeletablePrefixes: [String] = [
        "/System/",
        "/usr/",
        "/bin/",
        "/sbin/",
        "/Applications/",
        "/Library/",
        "/private/var/vm/",
    ]

    nonisolated static let neverDeletableExactPaths: [String] = [
        home.path,
        home.appendingPathComponent("Library").path,
    ]

    nonisolated static let packageSuffixes = [".app", ".photoslibrary", ".framework", ".xcodeproj", ".xcworkspace"]
}
