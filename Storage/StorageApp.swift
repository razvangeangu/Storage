import SwiftUI

@main
struct StorageApp: App {
    @State private var viewModel = StorageViewModel()

    var body: some Scene {
        WindowGroup {
            StorageOverviewView(viewModel: viewModel)
        }
        .defaultSize(
            width: WindowMetrics.defaultWidth,
            height: WindowMetrics.defaultHeight
        )
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView(viewModel: viewModel)
        }
    }
}
