import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: StorageViewModel
    @State private var showCachedResults = AppSettings.showCachedResultsOnLaunch

    var body: some View {
        Form {
            scanSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear {
            showCachedResults = AppSettings.showCachedResultsOnLaunch
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
