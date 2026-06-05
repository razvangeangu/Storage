import Foundation
import System

enum PermissionService {
    private static let fdaVerificationPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Safari/Bookmarks.plist",
        ]
    }()

    private static let settingsURLs = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
    ]

    /// True when macOS grants read access to TCC-protected locations (optional extended visibility).
    nonisolated static func hasFullDiskAccess() -> Bool {
        fdaVerificationPaths.contains { canReadFile(at: $0) }
    }

    /// Whether the app can list or read this path right now (no admin required — only macOS privacy gates).
    nonisolated static func canAccess(path: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return false }

        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDirectory) else { return false }

        if isDirectory.boolValue {
            return (try? fm.contentsOfDirectory(atPath: path)) != nil
        }
        return fm.isReadableFile(atPath: path)
    }

    nonisolated static func fullDiskAccessSettingsURLs() -> [URL] {
        settingsURLs.compactMap { URL(string: $0) }
    }

    private nonisolated static func canReadFile(at path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        do {
            let descriptor = try FileDescriptor.open(path, .readOnly)
            try descriptor.close()
            return true
        } catch {
            return false
        }
    }
}
