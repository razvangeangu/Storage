import Foundation

enum ScanConcurrency {
    /// Parallel `du`/enumeration workers — tuned to CPU count without flooding the disk.
    nonisolated static var sizingLimit: Int {
        let cores = ProcessInfo.processInfo.activeProcessorCount
        return max(4, min(12, cores))
    }
}
