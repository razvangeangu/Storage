import SwiftUI

struct StorageBarView: View {
    let diskInfo: DiskSpaceInfo
    let categories: [StorageCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(diskInfo.volumeName, systemImage: "internaldrive.fill")
                    .font(.title2.weight(.semibold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(ByteFormatting.string(for: diskInfo.usedBytes)) used")
                        .font(.subheadline.weight(.medium))
                    Text("\(ByteFormatting.string(for: diskInfo.availableBytes)) available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(visibleSegments) { segment in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(segment.color.gradient)
                            .frame(width: max(3, geometry.size.width * segment.fraction))
                            .help("\(segment.name): \(ByteFormatting.string(for: segment.bytes))")
                    }
                    if remainingFraction > 0.005 {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                            .frame(width: max(0, geometry.size.width * remainingFraction))
                    }
                }
            }
            .frame(height: 14)

            if !visibleSegments.isEmpty {
                FlowLayout(spacing: 10) {
                    ForEach(visibleSegments) { segment in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 8, height: 8)
                            Text(segment.name)
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Text(ByteFormatting.string(for: segment.bytes))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var remainingFraction: Double {
        guard diskInfo.totalBytes > 0 else { return 0 }
        let usedFraction = Double(diskInfo.usedBytes) / Double(diskInfo.totalBytes)
        let accounted = visibleSegments.reduce(0.0) { $0 + $1.fraction }
        return max(0, usedFraction - accounted)
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

/// Simple wrapping layout for the storage legend.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() where index < subviews.count {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
