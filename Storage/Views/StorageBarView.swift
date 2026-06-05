import SwiftUI

struct StorageBarView: View {
    let diskInfo: DiskSpaceInfo
    let categories: [StorageCategory]
    var isScanning = false

    @State private var shimmer = false
    @State private var hoveredSegmentID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label(diskInfo.volumeName, systemImage: "internaldrive.fill")
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(ByteFormatting.string(for: diskInfo.usedBytes)) used")
                        .font(.subheadline.weight(.medium))
                    Text("\(ByteFormatting.string(for: diskInfo.availableBytes)) available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 2) {
                        if visibleSegments.isEmpty, isScanning {
                            ForEach(Array(skeletonFractions.enumerated()), id: \.offset) { index, fraction in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color.accentColor.opacity(shimmer && index.isMultiple(of: 2) ? 0.18 : 0.32))
                                    .frame(width: max(8, geometry.size.width * fraction))
                            }
                        } else {
                            ForEach(visibleSegments) { segment in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(segment.color.gradient)
                                    .frame(width: max(3, geometry.size.width * segment.fraction))
                                    .contentShape(Rectangle())
                                    .onHover { hovering in
                                        hoveredSegmentID = hovering ? segment.id : nil
                                    }
                                    .help("\(segment.name): \(ByteFormatting.string(for: segment.bytes))")
                            }
                            if remainingFraction > 0.005 {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                    .frame(width: max(0, geometry.size.width * remainingFraction))
                                    .help("Other used space")
                            }
                        }
                    }
                    .frame(width: geometry.size.width, alignment: .leading)

                    if let hovered = hoveredSegment {
                        Text("\(hovered.name) · \(ByteFormatting.string(for: hovered.bytes))")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08))
                            )
                            .offset(y: -28)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
            }
            .frame(height: 14)
            .animation(.easeOut(duration: 0.12), value: hoveredSegmentID)
            .onAppear {
                guard isScanning else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    shimmer = true
                }
            }
            .onChange(of: isScanning) { _, scanning in
                if scanning {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        shimmer = true
                    }
                } else {
                    shimmer = false
                }
            }

            if !visibleSegments.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 10, alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(visibleSegments) { segment in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 8, height: 8)
                            Text(segment.name)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(ByteFormatting.string(for: segment.bytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    private var skeletonFractions: [Double] {
        [0.22, 0.14, 0.18, 0.1, 0.12, 0.08]
    }

    private var remainingFraction: Double {
        guard diskInfo.totalBytes > 0 else { return 0 }
        let usedFraction = Double(diskInfo.usedBytes) / Double(diskInfo.totalBytes)
        let accounted = visibleSegments.reduce(0.0) { $0 + $1.fraction }
        return max(0, usedFraction - accounted)
    }

    private var hoveredSegment: BarSegment? {
        guard let hoveredSegmentID else { return nil }
        return visibleSegments.first { $0.id == hoveredSegmentID }
    }

    private var visibleSegments: [BarSegment] {
        let total = Double(max(diskInfo.totalBytes, 1))
        return categories
            .sorted { $0.size > $1.size }
            .map { category in
                let style = CategoryStyle.appearance(for: category.id)
                return BarSegment(
                    id: category.id,
                    name: category.name,
                    bytes: category.size,
                    fraction: Double(category.size) / total,
                    color: style.color
                )
            }
            .filter { $0.fraction > 0.001 }
    }
}

private struct BarSegment: Identifiable {
    let id: String
    let name: String
    let bytes: Int64
    let fraction: Double
    let color: Color
}
