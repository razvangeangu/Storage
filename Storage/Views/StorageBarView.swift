import SwiftUI

struct StorageBarView: View {
    let diskInfo: DiskSpaceInfo
    let categories: [StorageCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(diskInfo.volumeName)
                    .font(.headline)
                Spacer()
                Text("\(ByteFormatting.string(for: diskInfo.usedBytes)) used · \(ByteFormatting.string(for: diskInfo.availableBytes)) free")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                HStack(spacing: 1) {
                    ForEach(visibleSegments) { segment in
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(2, geometry.size.width * segment.fraction))
                    }
                    if remainingFraction > 0.01 {
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor))
                            .frame(width: max(0, geometry.size.width * remainingFraction))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 12)

            if !categories.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 4) {
                    ForEach(visibleSegments) { segment in
                        HStack(spacing: 6) {
                            Circle().fill(segment.color).frame(width: 8, height: 8)
                            Text(segment.name)
                                .font(.caption)
                                .lineLimit(1)
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
        let palette: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo, .mint, .cyan, .yellow]
        return categories.prefix(palette.count).enumerated().map { index, category in
            BarSegment(
                id: category.id,
                name: category.name,
                fraction: Double(category.size) / total,
                color: palette[index % palette.count]
            )
        }.filter { $0.fraction > 0.001 }
    }
}

private struct BarSegment: Identifiable {
    let id: String
    let name: String
    let fraction: Double
    let color: Color
}
