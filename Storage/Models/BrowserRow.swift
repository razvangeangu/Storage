import Foundation

struct BrowserBreadcrumb: Identifiable, Sendable {
    let index: Int
    let title: String

    var id: Int { index }
}

enum BrowserRow: Identifiable, Sendable {
    case group(StorageCategory)
    case item(StorageItem)

    var id: String {
        switch self {
        case .group(let category):
            return "group:\(category.id)"
        case .item(let item):
            return item.id
        }
    }

    var name: String {
        switch self {
        case .group(let category):
            return category.name
        case .item(let item):
            return item.name
        }
    }

    var size: Int64 {
        switch self {
        case .group(let category):
            return category.size
        case .item(let item):
            return item.size
        }
    }

    var path: String? {
        switch self {
        case .group:
            return nil
        case .item(let item):
            return item.path
        }
    }

    var storageItem: StorageItem? {
        if case .item(let item) = self { return item }
        return nil
    }

    var isDirectory: Bool {
        guard let path else { return false }
        return FolderBrowserService.isDirectory(at: path)
    }
}
