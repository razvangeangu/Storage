import Foundation
import System

enum PermissionService {
    private static let fdaProbePath = "/Library/Application Support/com.apple.TCC/TCC.db"

    private static let fdaRegistrationPaths: [String] = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Safari/Bookmarks.plist",
            "\(home)/Library/Mail",
        ]
    }()

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

    /// True when the app can read TCC-protected locations (Full Disk Access granted).
    nonisolated static func hasFullDiskAccess() -> Bool {
        fdaVerificationPaths.contains { canReadProtectedFile(at: $0) }
    }

    /// Opens protected paths so macOS adds this app to the Full Disk Access list.
    nonisolated static func registerForFullDiskAccess() {
        for path in fdaRegistrationPaths {
            if canReadProtectedFile(at: path) {
                return
            }
            _ = attemptOpen(path: path)
        }
    }

    nonisolated static func fullDiskAccessSettingsURLs() -> [URL] {
        settingsURLs.compactMap { URL(string: $0) }
    }

    private nonisolated static func canReadProtectedFile(at path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        return attemptOpen(path: path)
    }

    @discardableResult
    private nonisolated static func attemptOpen(path: String) -> Bool {
        do {
            let descriptor = try FileDescriptor.open(path, .readOnly)
            try descriptor.close()
            return true
        } catch {
            return false
        }
    }
}
