import SwiftUI

struct StorageOverviewView: View {
    @Bindable var viewModel: StorageViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !viewModel.hasFullDiskAccess {
                fdaBanner
                Divider()
            }
            content
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .layoutPriority(1)
            Divider()
            footer
        }
        .frame(
            minWidth: WindowMetrics.minWidth,
            idealWidth: WindowMetrics.defaultWidth,
            minHeight: WindowMetrics.minHeight,
            idealHeight: WindowMetrics.defaultHeight,
            maxHeight: .infinity
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .clipped()
        .onAppear { viewModel.onAppear() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.handleAppDidBecomeActive()
        }
        .sheet(isPresented: $viewModel.showCleanupConfirmation) {
            CleanupConfirmationSheet(
                items: viewModel.selectedItems,
                totalBytes: viewModel.selectedBytes,
                riskSummary: viewModel.selectionRiskSummary,
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
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.isScanning)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isScanning, viewModel.scanResult == nil {
            ScanningView(
                progress: viewModel.scanProgress,
                phase: viewModel.scanPhase,
                currentPath: viewModel.scanCurrentPath,
                pathFeed: viewModel.scanPathFeed,
                itemsChecked: viewModel.scanItemsChecked
            )
        } else if let result = viewModel.scanResult {
            ZStack(alignment: .top) {
                StorageBrowserView(
                    viewModel: viewModel,
                    categories: result.categories,
                    totalBytes: result.totalBytes
                )

                if viewModel.isScanning {
                    ScanProgressOverlay(
                        progress: viewModel.scanProgress,
                        phase: viewModel.scanPhase,
                        currentName: URL(fileURLWithPath: viewModel.scanCurrentPath).lastPathComponent
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .animation(.smooth(duration: 0.3), value: viewModel.isScanning)
        } else if !viewModel.isScanning {
            ReadyToScanView(onScan: { viewModel.rescan() })
        }
    }

    @ViewBuilder
    private var header: some View {
        Group {
            if let disk = viewModel.diskInfo {
                StorageBarView(
                    diskInfo: disk,
                    categories: viewModel.scanResult?.categories ?? [],
                    isScanning: viewModel.isScanning
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    private var fdaBanner: some View {
        ViewThatFits(in: .horizontal) {
            fdaBannerWide
            fdaBannerCompact
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.07))
    }

    private var fdaBannerWide: some View {
        HStack(alignment: .top, spacing: 14) {
            fdaBannerIcon
            fdaBannerText
            Spacer(minLength: 8)
            fdaBannerButtons
        }
    }

    private var fdaBannerCompact: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                fdaBannerIcon
                fdaBannerText
            }
            fdaBannerButtons
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fdaBannerIcon: some View {
        Image(systemName: "lock.shield.fill")
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(Color.orange.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var fdaBannerText: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Enable Full Disk Access for System Data")
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text("Install Storage in /Applications first. Open Settings, enable Storage, then run Scan for full System Data visibility.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var fdaBannerButtons: some View {
        HStack(spacing: 8) {
            Button("Open Settings") {
                viewModel.openFullDiskAccessSettings()
            }
            .controlSize(.small)
            Button("Check Access") {
                viewModel.refreshPermissions()
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if viewModel.selectionRiskSummary.hasWarnings {
                DeletionRiskBanner(summary: viewModel.selectionRiskSummary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
            footerActions
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
    }

    private var footerActions: some View {
        HStack(spacing: 12) {
            Group {
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
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            if !viewModel.selectedItems.isEmpty {
                HStack(spacing: 8) {
                    Button("Clear") { viewModel.clearSelection() }
                    Button {
                        viewModel.requestCleanup()
                    } label: {
                        Label("Move to Trash", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    StorageOverviewView(viewModel: StorageViewModel())
}
