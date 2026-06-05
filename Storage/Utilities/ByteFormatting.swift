import Foundation

enum ByteFormatting {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useGB, .useMB, .useKB, .useBytes]
        return f
    }()

    static func string(for bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }
}
