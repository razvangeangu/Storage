import Foundation

struct ScanResult: Codable, Sendable {
    let scannedAt: Date
    let volumeName: String
    let totalBytes: Int64
    let availableBytes: Int64
    let categories: [StorageCategory]
    let hiddenBytes: Int64

    var usedBytes: Int64 { totalBytes - availableBytes }
    var accountedBytes: Int64 { categories.reduce(0) { $0 + $1.size } }
}

enum ScanProgress: Sendable {
    case started
    case scanning(path: String, fraction: Double, itemsChecked: Int)
    case completed(ScanResult)
    case failed(String)
}
