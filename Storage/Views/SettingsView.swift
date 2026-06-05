import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: StorageViewModel
    @State private var showCachedResults = AppSettings.showCachedResultsOnLaunch

    var body: some View {
        Form {
            permissionsSection
            scanSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear {
            viewModel.refreshPermissions()
            showCachedResults = AppSettings.showCachedResultsOnLaunch
        }
    }

    private var permissionsSection: some View {
        Section {
            LabeledContent("Full Disk Access") {
                Label(
                    viewModel.hasFullDiskAccess ? "Enabled" : "Not enabled",
                    systemImage: viewModel.hasFullDiskAccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(viewModel.hasFullDiskAccess ? .green : .orange)
            }

            Button("Open Full Disk Access Settings…") {
                viewModel.openFullDiskAccessSettings()
            }

            Text("Keep Storage in /Applications so macOS recognizes the same app when you toggle access. Run Scan after enabling for full visibility.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Permissions")
        }
    }

    private var scanSection: some View {
        Section {
            if let scannedAt = viewModel.scanResult?.scannedAt {
                LabeledContent("Last scan") {
                    Text(scannedAt.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("Show last scan while rescanning", isOn: $showCachedResults)
                .onChange(of: showCachedResults) { _, newValue in
                    AppSettings.showCachedResultsOnLaunch = newValue
                }

            Button("Clear Scan Cache") {
                viewModel.clearCache()
            }

            Button("Reveal Cache in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([ScanCacheStore.cacheFileURL.deletingLastPathComponent()])
            }
        } header: {
            Text("Scan")
        } footer: {
            Text("Clear the cache after upgrading Storage or changing Full Disk Access, then run Scan. Outdated caches are ignored automatically.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(AppVersion.displayString)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
