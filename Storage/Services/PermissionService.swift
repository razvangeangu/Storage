import Foundation

enum PermissionService {
    private static let fdaProbePath = "/Library/Application Support/com.apple.TCC/TCC.db"

    nonisolated static func hasFullDiskAccess() -> Bool {
        FileManager.default.isReadableFile(atPath: fdaProbePath)
    }

    static var fullDiskAccessSettingsURL: URL? {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")
    }
}
