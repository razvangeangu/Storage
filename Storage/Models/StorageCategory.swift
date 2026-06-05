import Foundation

struct StorageCategory: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let icon: String
    var size: Int64
    var children: [StorageItem]
    var subcategories: [StorageCategory]
    var isPartial: Bool

    var allItems: [StorageItem] {
        children + subcategories.flatMap(\.allItems)
    }
}
