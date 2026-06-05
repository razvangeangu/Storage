import SwiftUI

struct CategoryTreeView: View {
    let categories: [StorageCategory]
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onSelectAllDeletable: (StorageCategory) -> Void

    var body: some View {
        List {
            ForEach(categories) { category in
                CategorySection(
                    category: category,
                    selectedItemIDs: selectedItemIDs,
                    onToggle: onToggle,
                    onSelectAllDeletable: onSelectAllDeletable
                )
            }
        }
        .listStyle(.inset)
    }
}

private struct CategorySection: View {
    let category: StorageCategory
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onSelectAllDeletable: (StorageCategory) -> Void

    var body: some View {
        Section {
            if !category.subcategories.isEmpty {
                ForEach(category.subcategories) { sub in
                    SubcategorySection(
                        category: sub,
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
        } header: {
            HStack {
                Image(systemName: category.icon)
                Text(category.name)
                if category.isPartial {
                    Text("(partial)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(ByteFormatting.string(for: category.size))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Menu {
                    Button("Select All Deletable") {
                        onSelectAllDeletable(category)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }
}

private struct SubcategorySection: View {
    let category: StorageCategory
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onSelectAllDeletable: (StorageCategory) -> Void

    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(category.children) { item in
                ItemRow(item: item, isSelected: selectedItemIDs.contains(item.id), onToggle: onToggle)
                    .padding(.leading, 8)
            }
        } label: {
            HStack {
                Image(systemName: category.icon)
                    .foregroundStyle(.secondary)
                Text(category.name)
                Spacer()
                Text(ByteFormatting.string(for: category.size))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ItemRow: View {
    let item: StorageItem
    let isSelected: Bool
    let onToggle: (StorageItem) -> Void

    var body: some View {
        HStack(spacing: 10) {
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
                    .frame(width: 16)
            } else {
                Color.clear.frame(width: 16)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
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
        }
        .padding(.vertical, 2)
    }
}
