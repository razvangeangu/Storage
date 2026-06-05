import Foundation

enum CategoryClassifier {
    struct Rule: Sendable {
        let categoryID: String
        let name: String
        let icon: String
        let pathPrefixes: [String]
    }

    static let rules: [Rule] = [
        Rule(categoryID: "applications", name: "Applications", icon: "app.fill", pathPrefixes: [
            "/Applications/", homePrefix("Applications/"),
        ]),
        Rule(categoryID: "documents", name: "Documents", icon: "doc.fill", pathPrefixes: [
            homePrefix("Documents/"), homePrefix("Desktop/"), homePrefix("Downloads/"),
        ]),
        Rule(categoryID: "photos", name: "Photos", icon: "photo.fill", pathPrefixes: [
            homePrefix("Pictures/"),
        ]),
        Rule(categoryID: "developer", name: "Developer", icon: "hammer.fill", pathPrefixes: [
            homePrefix("Developer/"), homePrefix("Library/Developer/"),
        ]),
        Rule(categoryID: "ios_backups", name: "iOS Backups", icon: "iphone", pathPrefixes: [
            homePrefix("Library/Application Support/MobileSync/"),
        ]),
        Rule(categoryID: "mail", name: "Mail", icon: "envelope.fill", pathPrefixes: [
            homePrefix("Library/Mail/"),
        ]),
        Rule(categoryID: "messages", name: "Messages", icon: "message.fill", pathPrefixes: [
            homePrefix("Library/Messages/"),
        ]),
        Rule(categoryID: "trash", name: "Trash", icon: "trash.fill", pathPrefixes: [
            homePrefix(".Trash/"),
        ]),
        Rule(categoryID: "caches", name: "Caches", icon: "externaldrive.fill", pathPrefixes: [
            homePrefix("Library/Caches/"), "/Library/Caches/",
        ]),
        Rule(categoryID: "logs", name: "Logs", icon: "doc.text.fill", pathPrefixes: [
            homePrefix("Library/Logs/"), "/Library/Logs/",
        ]),
        Rule(categoryID: "containers", name: "Containers", icon: "shippingbox.fill", pathPrefixes: [
            homePrefix("Library/Containers/"), homePrefix("Library/Group Containers/"),
        ]),
        Rule(categoryID: "system_data", name: "System Data", icon: "gearshape.fill", pathPrefixes: [
            homePrefix("Library/Application Support/"),
            "/private/var/folders/",
        ]),
        Rule(categoryID: "snapshots", name: "Time Machine Snapshots", icon: "clock.arrow.circlepath", pathPrefixes: [
            "/.MobileBackups/", "/.MobileBackups.trash/",
        ]),
    ]

    nonisolated static let categoryOrder = [
        "applications", "documents", "photos", "developer", "ios_backups",
        "mail", "messages", "system_data", "containers", "caches", "logs",
        "snapshots", "trash", "other",
    ]

    nonisolated static func category(for path: String) -> (id: String, name: String, icon: String) {
        let normalized = path.hasSuffix("/") ? path : path + "/"
        for rule in rules {
            for prefix in rule.pathPrefixes {
                if normalized.hasPrefix(prefix) || path == String(prefix.dropLast()) {
                    return (rule.categoryID, rule.name, rule.icon)
                }
            }
        }
        if path.hasPrefix(KnownPaths.home.path) {
            return ("other", "Other", "folder.fill")
        }
        return ("other", "Other", "folder.fill")
    }

    nonisolated private static func homePrefix(_ suffix: String) -> String {
        KnownPaths.home.appendingPathComponent(suffix).path
    }
}
