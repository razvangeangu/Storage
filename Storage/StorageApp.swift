import SwiftUI

@main
struct StorageApp: App {
    var body: some Scene {
        WindowGroup {
            StorageOverviewView()
        }
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
