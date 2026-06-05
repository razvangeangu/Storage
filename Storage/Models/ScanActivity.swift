import Foundation

struct ScanPathEntry: Identifiable, Equatable {
    let id: UUID
    let name: String
    let context: String
    let icon: String

    init(id: UUID = UUID(), name: String, context: String, icon: String) {
        self.id = id
        self.name = name
        self.context = context
        self.icon = icon
    }
}

enum ScanActivityFormatter {
    static func phase(for path: String) -> String {
        if path == "Documents" || path.hasSuffix("/Documents") { return "Documents" }
        if path == "Developer" { return "Developer" }

        let normalized = path.lowercased()
        if normalized.contains("/applications") || path.hasSuffix(".app") { return "Applications" }
        if normalized.contains("/documents/")
            || normalized.contains("/desktop/")
            || normalized.contains("/downloads/")
            || normalized.contains("mobile documents") {
            return "Documents"
        }
        if normalized.contains("/.npm")
            || normalized.contains("/.pnpm")
            || normalized.contains("/.yarn")
            || normalized.contains("/.bun")
            || normalized.contains("/.gradle")
            || normalized.contains("/.expo")
            || normalized.contains("/.android")
            || normalized.contains("androidstudio")
            || normalized.contains("/developer/")
            || normalized.contains("/.cache/")
            || normalized.contains("/.nvm")
            || normalized.contains("/.fnm")
            || normalized.contains("/.pub-cache")
            || normalized.contains("/.cocoapods") {
            return "Developer"
        }
        if normalized.contains("/library/caches") { return "Caches" }
        if normalized.contains("/library/logs") { return "Logs" }
        if normalized.contains("/library/containers") { return "Containers" }
        if normalized.contains("/library/application support") { return "App Data" }
        if normalized.contains("/library/") { return "Library" }
        if normalized.contains("/users/") { return "Home" }
        return "Storage"
    }

    static func entry(for path: String) -> ScanPathEntry {
        let url = URL(fileURLWithPath: path)
        let name = url.lastPathComponent.isEmpty ? path : url.lastPathComponent
        let context = shortenedContext(url.deletingLastPathComponent().path)
        return ScanPathEntry(name: name, context: context, icon: iconName(for: url))
    }

    private static func shortenedContext(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            let tail = String(path.dropFirst(home.count))
            return tail.isEmpty ? "~" : "~\(tail)"
        }
        if path.count > 48 {
            return "…" + String(path.suffix(44))
        }
        return path
    }

    private static func iconName(for url: URL) -> String {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".app") { return "app.fill" }
        if url.hasDirectoryPath { return "folder.fill" }
        switch url.pathExtension.lowercased() {
        case "dmg", "pkg", "zip", "tar", "gz", "xz", "7z":
            return "archivebox.fill"
        case "mov", "mp4", "m4v":
            return "film.fill"
        case "jpg", "jpeg", "png", "heic", "gif", "webp":
            return "photo.fill"
        case "swift", "m", "h", "c", "cpp", "rs", "go", "py", "js", "ts", "tsx", "jsx":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }
}
