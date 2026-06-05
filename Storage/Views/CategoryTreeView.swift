import SwiftUI

struct CategoryTreeView: View {
    let categories: [StorageCategory]
    let totalBytes: Int64
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onSelectAllDeletable: (StorageCategory) -> Void

    @State private var expandedCategoryIDs: Set<String> = []

    var body: some View {
        List {
            ForEach(categories) { category in
                CategoryDisclosure(
                    category: category,
                    totalBytes: totalBytes,
                    isExpanded: expansionBinding(for: category.id),
                    selectedItemIDs: selectedItemIDs,
                    onToggle: onToggle,
                    onSelectAllDeletable: onSelectAllDeletable,
                    expandedCategoryIDs: $expandedCategoryIDs
                )
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Expand All") { expandAll() }
                Button("Collapse All") { expandedCategoryIDs.removeAll() }
            }
        }
    }

    private func expansionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedCategoryIDs.contains(id) },
            set: { expanded in
                if expanded {
                    expandedCategoryIDs.insert(id)
                } else {
                    expandedCategoryIDs.remove(id)
                }
            }
        )
    }

    private func expandAll() {
        var ids = Set<String>()
        for category in categories {
            ids.insert(category.id)
            for sub in category.subcategories {
                ids.insert(sub.id)
            }
        }
        expandedCategoryIDs = ids
    }
}

// MARK: - Category

private struct CategoryDisclosure: View {
    let category: StorageCategory
    let totalBytes: Int64
    @Binding var isExpanded: Bool
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onSelectAllDeletable: (StorageCategory) -> Void
    @Binding var expandedCategoryIDs: Set<String>

    private var style: CategoryStyle.Appearance {
        CategoryStyle.appearance(for: category.id)
    }

    private var itemCount: Int {
        category.allItems.count
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if !category.subcategories.isEmpty {
                ForEach(category.subcategories) { sub in
                    SubcategoryDisclosure(
                        category: sub,
                        totalBytes: totalBytes,
                        isExpanded: subExpansionBinding(for: sub.id),
                        selectedItemIDs: selectedItemIDs,
                        onToggle: onToggle,
                        onSelectAllDeletable: onSelectAllDeletable
                    )
                }
            } else {
                ForEach(category.children) { item in
                    ItemRow(item: item, isSelected: selectedItemIDs.contains(item.id), onToggle: onToggle)
                }
            }
        } label: {
            CategoryLabel(
                name: category.name,
                style: style,
                size: category.size,
                totalBytes: totalBytes,
                itemCount: itemCount,
                isPartial: category.isPartial,
                onSelectAll: { onSelectAllDeletable(category) }
            )
        }
    }

    private func subExpansionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedCategoryIDs.contains(id) },
            set: { expanded in
                if expanded {
                    expandedCategoryIDs.insert(id)
                } else {
                    expandedCategoryIDs.remove(id)
                }
            }
        )
    }
}

// MARK: - Subcategory

private struct SubcategoryDisclosure: View {
    let category: StorageCategory
    let totalBytes: Int64
    @Binding var isExpanded: Bool
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onSelectAllDeletable: (StorageCategory) -> Void

    private var style: CategoryStyle.Appearance {
        CategoryStyle.appearance(for: category.id)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(category.children) { item in
                ItemRow(item: item, isSelected: selectedItemIDs.contains(item.id), onToggle: onToggle)
                    .padding(.leading, 4)
            }
        } label: {
            CategoryLabel(
                name: category.name,
                style: style,
                size: category.size,
                totalBytes: totalBytes,
                itemCount: category.children.count,
                isPartial: category.isPartial,
                compact: true,
                onSelectAll: { onSelectAllDeletable(category) }
            )
        }
        .padding(.leading, 8)
    }
}

// MARK: - Shared label

private struct CategoryLabel: View {
    let name: String
    let style: CategoryStyle.Appearance
    let size: Int64
    let totalBytes: Int64
    let itemCount: Int
    let isPartial: Bool
    var compact: Bool = false
    let onSelectAll: () -> Void

    private var share: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(size) / Double(totalBytes)
    }

    var body: some View {
        HStack(spacing: compact ? 8 : 12) {
            CategoryIconBadge(icon: style.icon, color: style.color, compact: compact)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(compact ? .subheadline.weight(.medium) : .body.weight(.semibold))
                    if isPartial {
                        Text("Partial")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                if itemCount > 0 {
                    Text("\(itemCount) items · \(Int(share * 100))% of disk")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(ByteFormatting.string(for: size))
                .font(compact ? .caption.monospacedDigit().weight(.medium) : .subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(style.color)

            Menu {
                Button("Select All Deletable") { onSelectAll() }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(compact ? .caption : .body)
                    .foregroundStyle(.tertiary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, compact ? 2 : 4)
    }
}

private struct CategoryIconBadge: View {
    let icon: String
    let color: Color
    var compact: Bool = false

    var body: some View {
        Image(systemName: icon)
            .font(compact ? .caption.weight(.semibold) : .body.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: compact ? 24 : 32, height: compact ? 24 : 32)
            .background(color.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
    }
}

// MARK: - Item row

private struct ItemRow: View {
    let item: StorageItem
    let isSelected: Bool
    let onToggle: (StorageItem) -> Void

    private var appearance: CategoryStyle.ItemAppearance {
        CategoryStyle.itemAppearance(for: item)
    }

    var body: some View {
        HStack(spacing: 12) {
            selectionControl

            Image(systemName: appearance.icon)
                .font(.body)
                .foregroundStyle(appearance.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                Text(item.path)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(ByteFormatting.string(for: item.size))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if item.isDeletable { onToggle(item) }
        }
    }

    @ViewBuilder
    private var selectionControl: some View {
        if item.isDeletable {
            Toggle(isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle(item) }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
        } else if item.isLocked {
            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 18)
                .help("System-owned — cannot delete without admin")
        } else {
            Color.clear.frame(width: 18)
        }
    }
}
