import Foundation

/// Shared helpers for the on-device stores.
enum StorageUtility {
    /// Audio is re-downloadable from Drive, so it must not bloat iCloud/iTunes
    /// backups. Applied to the Downloads and cache directories (and so to
    /// everything created inside them).
    static func excludeFromBackup(_ url: URL) {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = url
        try? url.setResourceValues(values)
    }

    static func fileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    /// Bytes the system is willing to let the app consume for optional data,
    /// as reported by iOS (accounts for purgeable space).
    static var availableForOpportunisticUse: Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        return (try? home.resourceValues(forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey]).volumeAvailableCapacityForOpportunisticUsage) ?? 0
    }

    static func format(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
}
