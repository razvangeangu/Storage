import SwiftUI

enum CategoryStyle {
    struct Appearance: Sendable {
        let icon: String
        let color: Color
    }

    struct ItemAppearance: Sendable {
        let icon: String
        let color: Color
    }

    private static let styles: [String: Appearance] = [
        "applications": Appearance(icon: "macwindow.on.rectangle", color: .blue),
        "documents": Appearance(icon: "doc.text.fill", color: .indigo),
        "documents_folder": Appearance(icon: "doc.fill", color: .indigo),
        "desktop": Appearance(icon: "desktopcomputer", color: .blue),
        "downloads": Appearance(icon: "arrow.down.circle.fill", color: .cyan),
        "icloud_drive": Appearance(icon: "icloud.fill", color: .teal),
        "photos": Appearance(icon: "photo.on.rectangle.angled", color: .pink),
        "developer": Appearance(icon: "hammer.fill", color: .purple),
        "developer_projects": Appearance(icon: "folder.fill", color: .purple),
        "xcode_support": Appearance(icon: "chevron.left.forwardslash.chevron.right", color: .purple),
        "xcode_caches": Appearance(icon: "clock.arrow.circlepath", color: .orange),
        "ios_backups": Appearance(icon: "iphone.gen3", color: .teal),
        "mail": Appearance(icon: "envelope.fill", color: .cyan),
        "messages": Appearance(icon: "bubble.left.and.bubble.right.fill", color: .green),
        "trash": Appearance(icon: "trash.fill", color: .gray),
        "caches": Appearance(icon: "externaldrive.fill.badge.timemachine", color: .orange),
        "logs": Appearance(icon: "list.bullet.rectangle.fill", color: .brown),
        "containers": Appearance(icon: "shippingbox.fill", color: .mint),
        "system_data": Appearance(icon: "gearshape.2.fill", color: .secondary),
        "system_data_group": Appearance(icon: "internaldrive.fill", color: .gray),
        "snapshots": Appearance(icon: "clock.arrow.circlepath", color: .yellow),
        "hidden": Appearance(icon: "eye.slash.fill", color: .secondary),
        "other": Appearance(icon: "folder.fill", color: .primary.opacity(0.7)),
    ]

    nonisolated static func appearance(for categoryID: String) -> Appearance {
        styles[categoryID] ?? styles["other"]!
    }

    nonisolated static func itemAppearance(for item: StorageItem) -> ItemAppearance {
        let name = item.name.lowercased()
        let category = appearance(for: item.categoryID)

        if name.hasSuffix(".app") {
            return ItemAppearance(icon: "app.fill", color: .blue)
        }
        if name.hasSuffix(".photoslibrary") {
            return ItemAppearance(icon: "photo.stack.fill", color: .pink)
        }
        if name.hasSuffix(".dmg") || name.hasSuffix(".pkg") {
            return ItemAppearance(icon: "shippingbox.fill", color: .orange)
        }
        if name.hasSuffix(".log") {
            return ItemAppearance(icon: "doc.text.fill", color: .brown)
        }
        if name.hasSuffix(".xcworkspace") || name.hasSuffix(".xcodeproj") {
            return ItemAppearance(icon: "chevron.left.forwardslash.chevron.right", color: .purple)
        }
        if name.hasSuffix(".framework") {
            return ItemAppearance(icon: "puzzlepiece.extension.fill", color: .purple)
        }
        if item.path.hasSuffix("/Caches") || name == "Cache" || name == "Caches" {
            return ItemAppearance(icon: "clock.arrow.circlepath", color: .orange)
        }
        if !name.contains(".") || name.hasPrefix(".") {
            return ItemAppearance(icon: "folder.fill", color: category.color)
        }
        return ItemAppearance(icon: "doc.fill", color: .secondary)
    }

    static func barPalette(for categories: [StorageCategory]) -> [String: Color] {
        Dictionary(uniqueKeysWithValues: categories.map { ($0.id, appearance(for: $0.id).color) })
    }
}
