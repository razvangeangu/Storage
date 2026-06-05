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
        "xcode": Appearance(icon: "chevron.left.forwardslash.chevron.right", color: .purple),
        "xcode_caches": Appearance(icon: "clock.arrow.circlepath", color: .orange),
        "android_sdk": Appearance(icon: "smartphone", color: .green),
        "android_data": Appearance(icon: "smartphone", color: .green),
        "gradle": Appearance(icon: "square.stack.3d.up.fill", color: .orange),
        "npm": Appearance(icon: "shippingbox.fill", color: .red),
        "pnpm": Appearance(icon: "square.grid.3x3.fill", color: .orange),
        "pnpm_store": Appearance(icon: "square.grid.3x3.fill", color: .orange),
        "yarn": Appearance(icon: "link.circle.fill", color: .blue),
        "yarn_cache": Appearance(icon: "link.circle.fill", color: .blue),
        "bun": Appearance(icon: "hare.fill", color: .yellow),
        "expo": Appearance(icon: "atom", color: .purple),
        "react_native": Appearance(icon: "rectangle.stack.fill", color: .cyan),
        "nvm": Appearance(icon: "server.rack", color: .green),
        "fnm": Appearance(icon: "server.rack", color: .green),
        "flutter": Appearance(icon: "bird.fill", color: .cyan),
        "cocoapods": Appearance(icon: "capsule.fill", color: .red),
        "maven": Appearance(icon: "cube.fill", color: .brown),
        "watchman": Appearance(icon: "eye.fill", color: .mint),
        "node_gyp_cache": Appearance(icon: "wrench.and.screwdriver.fill", color: .gray),
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
        if let style = styles[categoryID] {
            return style
        }
        if categoryID.hasPrefix("android_studio") {
            return Appearance(icon: "smartphone", color: .green)
        }
        if categoryID.hasPrefix("developer") || categoryID.hasPrefix("xcode") {
            return styles["developer"]!
        }
        return styles["other"]!
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
        if item.path.contains("/.npm") || name == "npm" || name == "_cacache" {
            return ItemAppearance(icon: "shippingbox.fill", color: .red)
        }
        if item.path.contains("/.gradle") || (name == "caches" && item.path.contains(".gradle")) {
            return ItemAppearance(icon: "square.stack.3d.up.fill", color: .orange)
        }
        if item.path.contains("/.expo") {
            return ItemAppearance(icon: "atom", color: .purple)
        }
        if item.path.contains("node_modules") {
            return ItemAppearance(icon: "shippingbox.fill", color: .green)
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
