import SwiftUI

struct CleanupConfirmationSheet: View {
    let items: [StorageItem]
    let totalBytes: Int64
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Move to Trash?")
                .font(.title2.bold())

            Text("\(items.count) items · \(ByteFormatting.string(for: totalBytes)) will be moved to Trash. You can restore them from Trash later.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List(items) { item in
                HStack {
                    Text(item.name)
                    Spacer()
                    Text(ByteFormatting.string(for: item.size))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 120, maxHeight: 240)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Move to Trash", role: .destructive, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
