import SwiftUI

struct CleanupConfirmationSheet: View {
    let items: [StorageItem]
    let totalBytes: Int64
    let riskSummary: DeletionRiskSummary
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var acknowledgedHighRisk = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Move to Trash?")
                .font(.title2.bold())

            Text("\(items.count) items · \(ByteFormatting.string(for: totalBytes)) will be moved to Trash. You can restore them from Trash later.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if riskSummary.hasWarnings {
                DeletionRiskBanner(summary: riskSummary)
            }

            List {
                ForEach(items) { item in
                    let assessment = riskSummary.assessments[item.path]
                        ?? DeletionRiskService.assess(path: item.path)
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(item.name)
                                    .lineLimit(1)
                                if assessment.risk > .safe {
                                    DeletionRiskBadge(assessment: assessment, compact: true)
                                }
                            }
                            if assessment.risk > .safe {
                                Text(assessment.reason)
                                    .font(.caption2)
                                    .foregroundStyle(assessment.risk == .critical ? .red : .orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 8)
                        Text(ByteFormatting.string(for: item.size))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .frame(minHeight: 120, maxHeight: 260)

            if riskSummary.requiresAcknowledgment {
                Toggle(isOn: $acknowledgedHighRisk) {
                    Text("I understand these items may break apps or cause data loss.")
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .toggleStyle(.checkbox)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Move to Trash", role: .destructive, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(riskSummary.requiresAcknowledgment && !acknowledgedHighRisk)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear { acknowledgedHighRisk = false }
    }
}
