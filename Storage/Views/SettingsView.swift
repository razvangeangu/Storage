import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: StorageViewModel
    @State private var showCachedResults = AppSettings.showCachedResultsOnLaunch
    @State private var includeAppData = AppSettings.includeAppDataInScan

    var body: some View {
        Form {
            scanSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .onAppear {
            showCachedResults = AppSettings.showCachedResultsOnLaunch
            includeAppData = AppSettings.includeAppDataInScan
        }
    }

    private var scanSection: some View {
        Section {
            Toggle("Scan other apps' data", isOn: $includeAppData)
                .onChange(of: includeAppData) { _, newValue in
                    AppSettings.includeAppDataInScan = newValue
                }

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
            Text("“Scan other apps' data” is off by default. macOS cannot grant this in one step — it shows a separate prompt for each app's folder. Rescan after changing that setting. Clear the cache after upgrading Storage; outdated caches are ignored automatically.")
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
