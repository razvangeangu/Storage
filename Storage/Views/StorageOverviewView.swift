import SwiftUI

struct StorageOverviewView: View {
    @State private var viewModel = StorageViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !viewModel.hasFullDiskAccess {
                fdaBanner
                Divider()
            }
            if viewModel.isScanning {
                scanProgress
                Divider()
            }
            content
            Divider()
            footer
        }
        .frame(minWidth: 900, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { viewModel.onAppear() }
        .sheet(isPresented: $viewModel.showCleanupConfirmation) {
            CleanupConfirmationSheet(
                items: viewModel.selectedItems,
                totalBytes: viewModel.selectedBytes,
                onConfirm: { viewModel.performCleanup() },
                onCancel: { viewModel.showCleanupConfirmation = false }
            )
        }
        .alert("Cleanup errors", isPresented: Binding(
            get: { viewModel.cleanupError != nil },
            set: { if !$0 { viewModel.cleanupError = nil } }
        )) {
            Button("OK") { viewModel.cleanupError = nil }
        } message: {
            Text(viewModel.cleanupError ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    viewModel.refreshPermissions()
                    viewModel.rescan()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.isScanning)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let result = viewModel.scanResult {
            CategoryTreeView(
                categories: result.categories,
                totalBytes: result.totalBytes,
                selectedItemIDs: viewModel.selectedItemIDs,
                onToggle: { viewModel.toggleSelection(for: $0) },
                onToggleCategorySelection: { viewModel.toggleCategorySelection(for: $0) }
            )
        } else if !viewModel.isScanning {
            ContentUnavailableView {
                Label("No scan data", systemImage: "internaldrive")
            } description: {
                Text("Click Rescan to analyze what's using space on this Mac.")
            } actions: {
                Button("Rescan") { viewModel.rescan() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var scanProgress: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: viewModel.scanProgress)
                .progressViewStyle(.linear)
            Text(viewModel.scanStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var header: some View {
        Group {
            if let disk = viewModel.diskInfo {
                StorageBarView(
                    diskInfo: disk,
                    categories: viewModel.scanResult?.categories ?? []
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var fdaBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.orange.gradient)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Full Disk Access for System Data")
                    .font(.subheadline.weight(.semibold))
                Text("Opens Privacy & Security and adds Storage to the list. Toggle it on, then Refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") {
                viewModel.openFullDiskAccessSettings()
            }
            .controlSize(.small)
            Button("Refresh") {
                viewModel.refreshPermissions()
                viewModel.rescan()
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.07))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if viewModel.selectedItems.isEmpty {
                Label(viewModel.scanStatusText, systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label(
                    "\(viewModel.selectedItems.count) selected · \(ByteFormatting.string(for: viewModel.selectedBytes))",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            }
            Spacer()
            if !viewModel.selectedItems.isEmpty {
                Button("Clear Selection") { viewModel.clearSelection() }
                Button {
                    viewModel.requestCleanup()
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }
}

#Preview {
    StorageOverviewView()
}
