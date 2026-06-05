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
            LabeledContent("Extended visibility") {
                Label(
                    viewModel.hasFullDiskAccess ? "On" : "Off",
                    systemImage: viewModel.hasFullDiskAccess ? "checkmark.circle.fill" : "minus.circle.fill"
                )
                .foregroundStyle(viewModel.hasFullDiskAccess ? .green : .secondary)
            }

            if !viewModel.hasFullDiskAccess {
                Text("Storage scans your home folder, apps, caches, and developer tools without this. Extended visibility only adds macOS-protected areas such as Mail and Messages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Open Full Disk Access Settings…") {
                viewModel.openFullDiskAccessSettings()
            }

            Text("Optional — does not require an administrator password on a personal Mac. Some work or school Macs block this setting; the app still works without it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Optional visibility")
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
            Text("Clear the cache after upgrading Storage, then run Scan. Outdated caches are ignored automatically.")
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
