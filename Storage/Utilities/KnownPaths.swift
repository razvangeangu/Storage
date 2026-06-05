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

    /// Path suffixes under the home directory classified as Developer (before Applications / Caches).
    nonisolated static let developerPathSuffixes: [String] = [
        "Developer/",
        "Library/Developer/",
        "Library/Caches/com.apple.dt.Xcode/",
        "Library/Caches/Yarn/",
        "Library/Caches/watchman/",
        "Library/pnpm/",
        "Library/Android/",
        "Library/Application Support/Google/AndroidStudio",
        "Library/Caches/Google/AndroidStudio",
        "Library/Application Support/expo/",
        ".npm/",
        ".pnpm-store/",
        ".local/share/pnpm/",
        ".yarn/",
        ".bun/",
        ".expo/",
        ".android/",
        ".gradle/",
        ".nvm/",
        ".fnm/",
        ".local/share/fnm/",
        ".pub-cache/",
        ".cocoapods/",
        ".m2/",
        ".react-native/",
        ".metro/",
        ".cache/node-gyp/",
        ".cache/typescript/",
        ".cache/pnpm/",
    ]

    nonisolated static var developerDirectoryRoots: [CategoryRoot] {
        var roots: [CategoryRoot] = [
            CategoryRoot(id: "developer_projects", name: "Projects", icon: "folder.fill",
                         url: home.appendingPathComponent("Developer", isDirectory: true)),
            CategoryRoot(id: "xcode", name: "Xcode", icon: "hammer.fill",
                         url: home.appendingPathComponent("Library/Developer", isDirectory: true)),
            CategoryRoot(id: "xcode_caches", name: "Xcode Caches", icon: "clock.arrow.circlepath",
                         url: home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode", isDirectory: true)),
            CategoryRoot(id: "android_sdk", name: "Android SDK", icon: "smartphone",
                         url: home.appendingPathComponent(".android", isDirectory: true)),
            CategoryRoot(id: "android_data", name: "Android", icon: "smartphone",
                         url: home.appendingPathComponent("Library/Android", isDirectory: true)),
            CategoryRoot(id: "gradle", name: "Gradle", icon: "square.stack.3d.up.fill",
                         url: home.appendingPathComponent(".gradle", isDirectory: true)),
            CategoryRoot(id: "npm", name: "npm", icon: "shippingbox.fill",
                         url: home.appendingPathComponent(".npm", isDirectory: true)),
            CategoryRoot(id: "pnpm", name: "pnpm", icon: "square.grid.3x3.fill",
                         url: home.appendingPathComponent("Library/pnpm", isDirectory: true)),
            CategoryRoot(id: "pnpm_store", name: "pnpm Store", icon: "square.grid.3x3.fill",
                         url: home.appendingPathComponent(".pnpm-store", isDirectory: true)),
            CategoryRoot(id: "yarn", name: "Yarn", icon: "link.circle.fill",
                         url: home.appendingPathComponent(".yarn", isDirectory: true)),
            CategoryRoot(id: "yarn_cache", name: "Yarn Cache", icon: "link.circle.fill",
                         url: home.appendingPathComponent("Library/Caches/Yarn", isDirectory: true)),
            CategoryRoot(id: "bun", name: "Bun", icon: "hare.fill",
                         url: home.appendingPathComponent(".bun", isDirectory: true)),
            CategoryRoot(id: "expo", name: "Expo", icon: "atom",
                         url: home.appendingPathComponent(".expo", isDirectory: true)),
            CategoryRoot(id: "react_native", name: "React Native", icon: "rectangle.stack.fill",
                         url: home.appendingPathComponent(".react-native", isDirectory: true)),
            CategoryRoot(id: "nvm", name: "nvm", icon: "server.rack",
                         url: home.appendingPathComponent(".nvm", isDirectory: true)),
            CategoryRoot(id: "fnm", name: "fnm", icon: "server.rack",
                         url: home.appendingPathComponent(".fnm", isDirectory: true)),
            CategoryRoot(id: "flutter", name: "Flutter/Dart", icon: "bird.fill",
                         url: home.appendingPathComponent(".pub-cache", isDirectory: true)),
            CategoryRoot(id: "cocoapods", name: "CocoaPods", icon: "capsule.fill",
                         url: home.appendingPathComponent(".cocoapods", isDirectory: true)),
            CategoryRoot(id: "maven", name: "Maven", icon: "cube.fill",
                         url: home.appendingPathComponent(".m2", isDirectory: true)),
            CategoryRoot(id: "watchman", name: "Watchman", icon: "eye.fill",
                         url: home.appendingPathComponent("Library/Caches/watchman", isDirectory: true)),
            CategoryRoot(id: "node_gyp_cache", name: "node-gyp Cache", icon: "wrench.and.screwdriver.fill",
                         url: home.appendingPathComponent(".cache/node-gyp", isDirectory: true)),
        ]
        roots.append(contentsOf: discoveredAndroidStudioRoots())
        return roots
    }

    nonisolated static var developerPathPrefixes: [String] {
        developerPathSuffixes.map { suffix in
            home.appendingPathComponent(suffix).path
        }
    }

    nonisolated private static func discoveredAndroidStudioRoots() -> [CategoryRoot] {
        var roots: [CategoryRoot] = []
        let fm = FileManager.default

        let supportGoogle = home.appendingPathComponent("Library/Application Support/Google", isDirectory: true)
        if let names = try? fm.contentsOfDirectory(atPath: supportGoogle.path) {
            for name in names where name.hasPrefix("AndroidStudio") {
                roots.append(CategoryRoot(
                    id: "android_studio_\(name)",
                    name: "Android Studio",
                    icon: "smartphone",
                    url: supportGoogle.appendingPathComponent(name, isDirectory: true)
                ))
            }
        }

        let cachesGoogle = home.appendingPathComponent("Library/Caches/Google", isDirectory: true)
        if let names = try? fm.contentsOfDirectory(atPath: cachesGoogle.path) {
            for name in names where name.hasPrefix("AndroidStudio") {
                roots.append(CategoryRoot(
                    id: "android_studio_cache_\(name)",
                    name: "Android Studio Cache",
                    icon: "smartphone",
                    url: cachesGoogle.appendingPathComponent(name, isDirectory: true)
                ))
            }
        }

        return roots
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

    /// Shallow library and media folders — avoids walking the entire home directory tree.
    nonisolated static var libraryScanRoots: [URL] {
        let library = home.appendingPathComponent("Library", isDirectory: true)
        let candidates = [
            library.appendingPathComponent("Application Support", isDirectory: true),
            library.appendingPathComponent("Caches", isDirectory: true),
            library.appendingPathComponent("Containers", isDirectory: true),
            library.appendingPathComponent("Group Containers", isDirectory: true),
            library.appendingPathComponent("Mail", isDirectory: true),
            library.appendingPathComponent("Messages", isDirectory: true),
            library.appendingPathComponent("Logs", isDirectory: true),
            home.appendingPathComponent("Movies", isDirectory: true),
            home.appendingPathComponent("Music", isDirectory: true),
            home.appendingPathComponent("Pictures", isDirectory: true),
            home.appendingPathComponent(".Trash", isDirectory: true),
        ]
        let fm = FileManager.default
        return candidates.filter { fm.fileExists(atPath: $0.path) }
    }

    nonisolated static var extendedSystemScanRoots: [URL] {
        [
            URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
            URL(fileURLWithPath: "/Library/Logs", isDirectory: true),
        ]
    }

    nonisolated static var allScanRootCandidates: [URL] {
        libraryScanRoots + extendedSystemScanRoots
    }

    /// Roots the app can read right now — skips macOS-protected folders instead of requiring Full Disk Access up front.
    nonisolated static func accessibleScanRoots() -> [URL] {
        allScanRootCandidates.filter { PermissionService.canAccess(path: $0.path) }
    }

    nonisolated static func inaccessibleScanRoots() -> [URL] {
        allScanRootCandidates.filter {
            FileManager.default.fileExists(atPath: $0.path) && !PermissionService.canAccess(path: $0.path)
        }
    }

    nonisolated static let cleanupWhitelistPrefixes: [String] = [
        home.appendingPathComponent("Library/Caches").path + "/",
        home.appendingPathComponent("Library/Logs").path + "/",
        home.appendingPathComponent("Library/Containers").path + "/",
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
        home.appendingPathComponent(".npm").path + "/",
        home.appendingPathComponent(".pnpm-store").path + "/",
        home.appendingPathComponent("Library/pnpm").path + "/",
        home.appendingPathComponent(".yarn").path + "/",
        home.appendingPathComponent(".bun").path + "/",
        home.appendingPathComponent(".expo").path + "/",
        home.appendingPathComponent(".android").path + "/",
        home.appendingPathComponent("Library/Android").path + "/",
        home.appendingPathComponent(".gradle").path + "/",
        home.appendingPathComponent(".nvm").path + "/",
        home.appendingPathComponent(".fnm").path + "/",
        home.appendingPathComponent(".pub-cache").path + "/",
        home.appendingPathComponent(".cocoapods").path + "/",
        home.appendingPathComponent(".m2").path + "/",
        home.appendingPathComponent(".react-native").path + "/",
        home.appendingPathComponent(".cache/node-gyp").path + "/",
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
