import SwiftUI

struct CategoryTreeView: View {
    let categories: [StorageCategory]
    let totalBytes: Int64
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onToggleCategorySelection: (StorageCategory) -> Void

    @State private var expandedCategoryIDs: Set<String> = []

    var body: some View {
        List {
            ForEach(categories) { category in
                CategorySection(
                    category: category,
                    totalBytes: totalBytes,
                    isExpanded: expansionBinding(for: category.id),
                    selectedItemIDs: selectedItemIDs,
                    onToggle: onToggle,
                    onToggleCategorySelection: onToggleCategorySelection,
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

// MARK: - Layout metrics

private enum TreeMetrics {
    static let rowHeight: CGFloat = 36
    static let chevronWidth: CGFloat = 14
    static let chevronSpacing: CGFloat = 8
    static let checkboxWidth: CGFloat = 20
    static let checkboxSpacing: CGFloat = 8
    static let iconWidth: CGFloat = 28
    static let childIndent: CGFloat = chevronWidth + chevronSpacing
}

// MARK: - Category section

private struct CategorySection: View {
    let category: StorageCategory
    let totalBytes: Int64
    @Binding var isExpanded: Bool
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onToggleCategorySelection: (StorageCategory) -> Void
    @Binding var expandedCategoryIDs: Set<String>

    private var style: CategoryStyle.Appearance {
        CategoryStyle.appearance(for: category.id)
    }

    private var itemCount: Int {
        category.allItems.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CategoryHeaderRow(
                isExpanded: $isExpanded,
                name: category.name,
                style: style,
                size: category.size,
                totalBytes: totalBytes,
                itemCount: itemCount,
                isPartial: category.isPartial,
                selectionState: selectionState(for: category),
                onToggleSelection: { onToggleCategorySelection(category) }
            )

            if isExpanded {
                if !category.subcategories.isEmpty {
                    ForEach(category.subcategories) { sub in
                        SubcategorySection(
                            category: sub,
                            totalBytes: totalBytes,
                            isExpanded: subExpansionBinding(for: sub.id),
                            selectedItemIDs: selectedItemIDs,
                            onToggle: onToggle,
                            onToggleCategorySelection: onToggleCategorySelection
                        )
                    }
                } else {
                    ForEach(category.children) { item in
                        ItemRow(
                            item: item,
                            isSelected: selectedItemIDs.contains(item.id),
                            onToggle: onToggle
                        )
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
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

    private func selectionState(for category: StorageCategory) -> CheckboxState {
        let selectable = category.allItems.filter { !$0.isLocked }
        guard !selectable.isEmpty else { return .unavailable }
        let selected = selectable.filter { selectedItemIDs.contains($0.id) }.count
        if selected == 0 { return .off }
        if selected == selectable.count { return .on }
        return .mixed
    }
}

// MARK: - Subcategory

private struct SubcategorySection: View {
    let category: StorageCategory
    let totalBytes: Int64
    @Binding var isExpanded: Bool
    let selectedItemIDs: Set<String>
    let onToggle: (StorageItem) -> Void
    let onToggleCategorySelection: (StorageCategory) -> Void

    private var style: CategoryStyle.Appearance {
        CategoryStyle.appearance(for: category.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CategoryHeaderRow(
                isExpanded: $isExpanded,
                name: category.name,
                style: style,
                size: category.size,
                totalBytes: totalBytes,
                itemCount: category.children.count,
                isPartial: category.isPartial,
                compact: true,
                leadingIndent: TreeMetrics.childIndent,
                selectionState: selectionState(for: category),
                onToggleSelection: { onToggleCategorySelection(category) }
            )

            if isExpanded {
                ForEach(category.children) { item in
                    ItemRow(
                        item: item,
                        isSelected: selectedItemIDs.contains(item.id),
                        onToggle: onToggle,
                        leadingIndent: TreeMetrics.childIndent
                    )
                }
            }
        }
    }

    private func selectionState(for category: StorageCategory) -> CheckboxState {
        let selectable = category.allItems.filter { !$0.isLocked }
        guard !selectable.isEmpty else { return .unavailable }
        let selected = selectable.filter { selectedItemIDs.contains($0.id) }.count
        if selected == 0 { return .off }
        if selected == selectable.count { return .on }
        return .mixed
    }
}

// MARK: - Category header

private struct CategoryHeaderRow: View {
    @Binding var isExpanded: Bool
    let name: String
    let style: CategoryStyle.Appearance
    let size: Int64
    let totalBytes: Int64
    let itemCount: Int
    let isPartial: Bool
    var compact: Bool = false
    var leadingIndent: CGFloat = 0
    let selectionState: CheckboxState
    let onToggleSelection: () -> Void

    private var share: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(size) / Double(totalBytes)
    }

    var body: some View {
        HStack(spacing: TreeMetrics.chevronSpacing) {
            if leadingIndent > 0 {
                Spacer().frame(width: leadingIndent)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: TreeMetrics.chevronWidth, height: TreeMetrics.chevronWidth)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .buttonStyle(.plain)
            .frame(width: TreeMetrics.chevronWidth, height: TreeMetrics.rowHeight)

            SelectionCheckbox(state: selectionState, action: onToggleSelection)
                .frame(width: TreeMetrics.checkboxWidth, height: TreeMetrics.rowHeight)

            CategoryIconBadge(icon: style.icon, color: style.color, compact: compact)
                .frame(width: TreeMetrics.iconWidth, height: TreeMetrics.rowHeight)

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
        }
        .frame(minHeight: TreeMetrics.rowHeight)
    }
}

// MARK: - Shared views

private struct CategoryIconBadge: View {
    let icon: String
    let color: Color
    var compact: Bool = false

    var body: some View {
        Image(systemName: icon)
            .font(compact ? .caption.weight(.semibold) : .body.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
            .background(color.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
    }
}

private enum CheckboxState {
    case unavailable
    case off
    case mixed
    case on
}

private struct SelectionCheckbox: View {
    let state: CheckboxState
    let action: () -> Void

    var body: some View {
        Group {
            switch state {
            case .unavailable:
                Color.clear
            case .off:
                checkboxButton(symbol: "square")
            case .mixed:
                checkboxButton(symbol: "minus.square.fill")
            case .on:
                checkboxButton(symbol: "checkmark.square.fill")
            }
        }
        .frame(width: TreeMetrics.checkboxWidth, height: TreeMetrics.checkboxWidth)
    }

    private func checkboxButton(symbol: String) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(state == .on || state == .mixed ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Item row

private struct ItemRow: View {
    let item: StorageItem
    let isSelected: Bool
    let onToggle: (StorageItem) -> Void
    var leadingIndent: CGFloat = 0

    private var appearance: CategoryStyle.ItemAppearance {
        CategoryStyle.itemAppearance(for: item)
    }

    var body: some View {
        HStack(spacing: TreeMetrics.checkboxSpacing) {
            if leadingIndent > 0 {
                Spacer().frame(width: leadingIndent)
            }

            Spacer().frame(width: TreeMetrics.chevronWidth)

            if item.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(width: TreeMetrics.checkboxWidth, height: TreeMetrics.checkboxWidth)
                    .help("System-owned — cannot delete without admin")
            } else {
                SelectionCheckbox(
                    state: isSelected ? .on : .off,
                    action: { onToggle(item) }
                )
            }

            Image(systemName: appearance.icon)
                .font(.body)
                .foregroundStyle(appearance.color)
                .frame(width: TreeMetrics.iconWidth, height: TreeMetrics.iconWidth)

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
        .frame(minHeight: TreeMetrics.rowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if !item.isLocked {
                onToggle(item)
            }
        }
    }
}
