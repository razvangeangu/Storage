import SwiftUI

struct ScanningView: View {
    let progress: Double
    let phase: String
    let currentPath: String
    let pathFeed: [ScanPathEntry]
    let itemsChecked: Int

    @State private var pulse = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                hero

                VStack(spacing: 14) {
                    progressCard
                    activityFeed
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)

                statsRow
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(scanBackground)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(pulse ? 0.08 : 0.16))
                    .frame(width: 92, height: 92)
                    .scaleEffect(pulse ? 1.08 : 0.94)

                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color.accentColor.gradient)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(spacing: 6) {
                Text("Analyzing your Mac")
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(phase)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: phase)
            }
        }
        .padding(.top, 8)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: progress)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, geometry.size.width * progress))
                        .animation(.smooth(duration: 0.35), value: progress)
                }
            }
            .frame(height: 8)

            if !currentPath.isEmpty {
                let display = ScanActivityFormatter.entry(for: currentPath)
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("\(display.context)/\(display.name)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Live scan", systemImage: "waveform.path")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                if pathFeed.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Preparing file index…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)
                } else {
                    ForEach(pathFeed) { entry in
                        ScanPathRow(entry: entry)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                        if entry.id != pathFeed.last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .animation(.smooth(duration: 0.22), value: pathFeed.map(\.id))
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var statsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) {
                statPill(title: "Paths checked", value: itemsChecked.formatted())
                statPill(title: "Status", value: "Scanning")
            }
            VStack(spacing: 10) {
                statPill(title: "Paths checked", value: itemsChecked.formatted())
                statPill(title: "Status", value: "Scanning")
            }
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var scanBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.accentColor.opacity(0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct ScanPathRow: View {
    let entry: ScanPathEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(entry.context)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
