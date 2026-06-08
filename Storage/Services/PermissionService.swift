import Foundation

enum PermissionService {
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
}
