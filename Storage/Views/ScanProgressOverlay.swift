import SwiftUI

struct ScanProgressOverlay: View {
    let progress: Double
    let phase: String
    let currentName: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rescanning · \(phase)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if !currentName.isEmpty {
                    Text(currentName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Text("\(Int(progress * 100))%")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.25), value: progress)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.accentColor.gradient)
                    .frame(width: geometry.size.width * progress, height: 2)
                    .animation(.smooth(duration: 0.35), value: progress)
            }
            .frame(height: 2)
        }
    }
}
