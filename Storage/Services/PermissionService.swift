import Foundation
import System

enum PermissionService {
    private static let fdaProbePath = "/Library/Application Support/com.apple.TCC/TCC.db"

    private static let fdaRegistrationPaths = [
        "/Library/Application Support/com.apple.TCC/TCC.db",
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Safari/Bookmarks.plist").path,
    ]

    private static let settingsURLs = [
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
        "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
    ]

    nonisolated static func hasFullDiskAccess() -> Bool {
        FileManager.default.isReadableFile(atPath: fdaProbePath)
    }

    /// Attempts to read protected paths so macOS registers this app in Full Disk Access.
    nonisolated static func registerForFullDiskAccess() {
        for path in fdaRegistrationPaths {
            do {
                let descriptor = try FileDescriptor.open(path, .readOnly)
                try descriptor.close()
                return
            } catch {
                continue
            }
        }
    }

    nonisolated static func fullDiskAccessSettingsURLs() -> [URL] {
        settingsURLs.compactMap { URL(string: $0) }
    }
}
