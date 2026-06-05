import SwiftUI

struct ReadyToScanView: View {
    let onScan: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Color.accentColor.gradient)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 8) {
                    Text("See what's using space")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("Scan your Mac to get a breakdown by category — Applications, Documents, Developer tools, and more.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                Button(action: onScan) {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("r", modifiers: .command)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
}
