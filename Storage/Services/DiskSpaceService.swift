import Foundation

struct DiskSpaceInfo: Sendable {
    let volumeName: String
    let totalBytes: Int64
    let availableBytes: Int64

    var usedBytes: Int64 { max(0, totalBytes - availableBytes) }
}

enum DiskSpaceService {
    nonisolated static func bootVolumeInfo() -> DiskSpaceInfo? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
        ]),
              let total = values.volumeTotalCapacity,
              let available = values.volumeAvailableCapacity else {
            return nil
        }

        return DiskSpaceInfo(
            volumeName: values.volumeName ?? "Macintosh HD",
            totalBytes: Int64(total),
            availableBytes: Int64(available)
        )
    }
}
