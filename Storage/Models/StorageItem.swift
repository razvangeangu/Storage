import Foundation

struct StorageItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let path: String
    let name: String
    var size: Int64
    let categoryID: String
    let isDeletable: Bool
    let isLocked: Bool

    var url: URL { URL(fileURLWithPath: path) }
}
