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
                ProgressView(value: viewModel.scanProgress) {
                    Text(viewModel.scanStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            if let result = viewModel.scanResult {
                CategoryTreeView(
                    categories: result.categories,
                    selectedItemIDs: viewModel.selectedItemIDs,
                    onToggle: { viewModel.toggleSelection(for: $0) },
                    onSelectAllDeletable: { viewModel.selectAllDeletable(in: $0) }
                )
            } else if !viewModel.isScanning {
                ContentUnavailableView(
                    "No scan data",
                    systemImage: "internaldrive",
                    description: Text("Click Rescan to analyze storage.")
                )
            }
            Divider()
            footer
        }
        .frame(minWidth: 900, minHeight: 600)
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
    private var header: some View {
        Group {
            if let disk = viewModel.diskInfo {
                StorageBarView(
                    diskInfo: disk,
                    categories: viewModel.scanResult?.categories ?? []
                )
            }
        }
        .padding()
    }

    private var fdaBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Full Disk Access to see System Data")
                    .font(.subheadline.weight(.medium))
                Text("This is a privacy toggle, not admin access. No password required on a personal Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") {
                viewModel.openFullDiskAccessSettings()
            }
            Button("I've enabled it") {
                viewModel.refreshPermissions()
                viewModel.rescan()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
    }

    private var footer: some View {
        HStack {
            if viewModel.selectedItems.isEmpty {
                Text(viewModel.scanStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(viewModel.selectedItems.count) selected · \(ByteFormatting.string(for: viewModel.selectedBytes))")
                    .font(.subheadline)
            }
            Spacer()
            if !viewModel.selectedItems.isEmpty {
                Button("Clear") { viewModel.clearSelection() }
                Button("Move to Trash") { viewModel.requestCleanup() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
        }
        .padding()
    }
}

#Preview {
    StorageOverviewView()
}
