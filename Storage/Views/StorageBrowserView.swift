import SwiftUI

struct StorageBrowserView: View {
    @Bindable var viewModel: StorageViewModel
    let categories: [StorageCategory]
    let totalBytes: Int64

    var body: some View {
        NavigationSplitView {
            categorySidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            browserDetail
        }
    }

    // MARK: - Sidebar

    private var categorySidebar: some View {
        List(selection: $viewModel.selectedCategoryID) {
            Section("Categories") {
                ForEach(categories) { category in
                    CategorySidebarRow(category: category, totalBytes: totalBytes)
                        .tag(category.id as String?)
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: viewModel.selectedCategoryID) { _, _ in
            viewModel.onCategorySelectionChanged()
        }
    }

    // MARK: - Detail

    private var browserDetail: some View {
        VStack(spacing: 0) {
            browserToolbar
            Divider()
            if viewModel.isLoadingFolder {
                loadingState
            } else if viewModel.browserRows.isEmpty {
                emptyState
            } else {
                browserList
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    private var browserToolbar: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.navigateBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.canNavigateBack)
            .help("Back")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(viewModel.breadcrumbSegments) { segment in
                        if segment.index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        Button(segment.title) {
                            viewModel.navigateToBreadcrumb(index: segment.index)
                        }
                        .buttonStyle(.plain)
                        .font(segment.index == viewModel.breadcrumbSegments.count - 1 ? .subheadline.weight(.semibold) : .subheadline)
                        .foregroundStyle(segment.index == viewModel.breadcrumbSegments.count - 1 ? .primary : .secondary)
                        .lineLimit(1)
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            if viewModel.isLoadingFolder {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private var browserList: some View {
        List {
            ForEach(viewModel.browserRows) { row in
                BrowserRowView(
                    row: row,
                    isSelected: row.storageItem.map { viewModel.selectedItemIDs.contains($0.id) } ?? false,
                    riskAssessment: row.storageItem.map { viewModel.deletionRisk(for: $0) },
                    onOpen: { viewModel.openBrowserRow($0) },
                    onToggleSelection: { item in viewModel.toggleSelection(for: item) }
                )
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Reading folder contents…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Nothing here",
            systemImage: "folder",
            description: Text("This folder is empty or could not be read.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sidebar row

private struct CategorySidebarRow: View {
    let category: StorageCategory
    let totalBytes: Int64

    private var style: CategoryStyle.Appearance {
        CategoryStyle.appearance(for: category.id)
    }

    private var share: Int {
        guard totalBytes > 0 else { return 0 }
        return Int((Double(category.size) / Double(totalBytes)) * 100)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(style.color)
                .frame(width: 28, height: 28)
                .background(style.color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(ByteFormatting.string(for: category.size)) · \(share)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Browser row

private struct BrowserRowView: View {
    let row: BrowserRow
    let isSelected: Bool
    let riskAssessment: DeletionRiskAssessment?
    let onOpen: (BrowserRow) -> Void
    let onToggleSelection: (StorageItem) -> Void

    private var appearance: CategoryStyle.ItemAppearance {
        if case .item(let item) = row {
            return CategoryStyle.itemAppearance(for: item)
        }
        if case .group(let category) = row {
            let style = CategoryStyle.appearance(for: category.id)
            return CategoryStyle.ItemAppearance(icon: style.icon, color: style.color)
        }
        return CategoryStyle.ItemAppearance(icon: "folder.fill", color: .accentColor)
    }

    private var isNavigable: Bool {
        switch row {
        case .group:
            return true
        case .item:
            return row.isDirectory
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            selectionControl
                .frame(width: BrowserMetrics.selectionWidth)

            Button {
                if isNavigable {
                    onOpen(row)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isNavigable ? "folder.fill" : appearance.icon)
                        .font(.title3)
                        .foregroundStyle(appearance.color)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(row.name)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let riskAssessment, riskAssessment.risk > .safe {
                                DeletionRiskBadge(assessment: riskAssessment, compact: true)
                            }
                        }
                        if let path = row.path {
                            Text(path)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else if case .group(let category) = row {
                            Text("\(category.children.count) items")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                    Text(ByteFormatting.string(for: row.size))
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    if isNavigable {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .frame(width: BrowserMetrics.chevronWidth, height: BrowserMetrics.chevronWidth)
                    }
                }
                .frame(minHeight: BrowserMetrics.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isNavigable && row.storageItem == nil)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 12))
    }

    @ViewBuilder
    private var selectionControl: some View {
        if let item = row.storageItem, !item.isLocked, item.isDeletable {
            Button {
                onToggleSelection(item)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .help(selectionHelp)
        } else if row.storageItem?.isLocked == true {
            Image(systemName: "lock.fill")
                .font(.body)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .help("Protected — cannot delete")
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectionHelp: String {
        guard let item = row.storageItem else { return "" }
        let assessment = riskAssessment ?? DeletionRiskService.assess(path: item.path)
        if isSelected {
            return assessment.reason
        }
        if assessment.risk > .safe {
            return "Select for cleanup — \(assessment.reason)"
        }
        return "Select for cleanup"
    }
}

private enum BrowserMetrics {
    static let rowHeight: CGFloat = 52
    static let selectionWidth: CGFloat = 44
    static let chevronWidth: CGFloat = 20
}
