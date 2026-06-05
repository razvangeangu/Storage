import SwiftUI

struct DeletionRiskBadge: View {
    let assessment: DeletionRiskAssessment
    var compact: Bool = false

    var body: some View {
        if assessment.risk == .safe {
            EmptyView()
        } else {
            Label(assessment.risk.title, systemImage: assessment.risk.icon)
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(assessment.risk == .critical ? .red : .orange)
                .padding(.horizontal, compact ? 6 : 8)
                .padding(.vertical, compact ? 2 : 4)
                .background((assessment.risk == .critical ? Color.red : Color.orange).opacity(0.12))
                .clipShape(Capsule())
                .help(assessment.reason)
        }
    }
}

struct DeletionRiskBanner: View {
    let summary: DeletionRiskSummary

    var body: some View {
        if summary.hasWarnings {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: summary.highest.icon)
                    .font(.title3)
                    .foregroundStyle(summary.highest == .critical ? .red : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bannerTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(bannerDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background((summary.highest == .critical ? Color.red : Color.orange).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var bannerTitle: String {
        if summary.criticalCount > 0 {
            return "High-risk items selected"
        }
        return "Review before deleting"
    }

    private var bannerDetail: String {
        var parts: [String] = []
        if summary.criticalCount > 0 {
            parts.append("\(summary.criticalCount) high-risk")
        }
        if summary.cautionCount > 0 {
            parts.append("\(summary.cautionCount) caution")
        }
        let counts = parts.joined(separator: ", ")
        return "\(counts) item(s) may break apps or require reinstalling. Trash is recoverable, but some data cannot be rebuilt."
    }
}
