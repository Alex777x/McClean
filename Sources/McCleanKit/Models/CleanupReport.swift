import Foundation
import SwiftUI

/// Breakdown of freed bytes for a specific category, used in the post-cleanup visual chart.
public struct CategoryCleanupMetric: Identifiable, Hashable, Sendable {
    public let id: String
    public let category: JunkCategory
    public let bytesFreed: Int64
    public let itemCount: Int
    
    public init(category: JunkCategory, bytesFreed: Int64, itemCount: Int) {
        self.id = category.rawValue
        self.category = category
        self.bytesFreed = bytesFreed
        self.itemCount = itemCount
    }
    
    public var formattedBytes: String {
        ByteCountFormatterHelper.format(bytes: bytesFreed)
    }
}

/// Record of an individual deleted file or folder.
public struct DeletedItemRecord: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public let bytesFreed: Int64
    public let category: JunkCategory
    
    public init(id: UUID = UUID(), name: String, path: String, bytesFreed: Int64, category: JunkCategory) {
        self.id = id
        self.name = name
        self.path = path
        self.bytesFreed = bytesFreed
        self.category = category
    }
}

/// Record of an item that could not be deleted (e.g., permission denied or in use).
public struct FailedCleanupItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let path: String
    public let reason: String
    
    public init(id: UUID = UUID(), name: String, path: String, reason: String) {
        self.id = id
        self.name = name
        self.path = path
        self.reason = reason
    }
}

/// Complete report generated immediately after permanent deletion completes.
public struct CleanupReport: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let totalBytesFreed: Int64
    public let deletedItemCount: Int
    public let diskTotalBytes: Int64
    public let diskUsedBeforeBytes: Int64
    public let diskUsedAfterBytes: Int64
    public let diskFreeBeforeBytes: Int64
    public let diskFreeAfterBytes: Int64
    public let categoryMetrics: [CategoryCleanupMetric]
    public let deletedRecords: [DeletedItemRecord]
    public let failedItems: [FailedCleanupItem]
    public let durationSeconds: TimeInterval
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        totalBytesFreed: Int64,
        deletedItemCount: Int,
        diskTotalBytes: Int64,
        diskUsedBeforeBytes: Int64,
        diskUsedAfterBytes: Int64,
        diskFreeBeforeBytes: Int64,
        diskFreeAfterBytes: Int64,
        categoryMetrics: [CategoryCleanupMetric],
        deletedRecords: [DeletedItemRecord],
        failedItems: [FailedCleanupItem],
        durationSeconds: TimeInterval
    ) {
        self.id = id
        self.timestamp = timestamp
        self.totalBytesFreed = totalBytesFreed
        self.deletedItemCount = deletedItemCount
        self.diskTotalBytes = diskTotalBytes
        self.diskUsedBeforeBytes = diskUsedBeforeBytes
        self.diskUsedAfterBytes = diskUsedAfterBytes
        self.diskFreeBeforeBytes = diskFreeBeforeBytes
        self.diskFreeAfterBytes = diskFreeAfterBytes
        self.categoryMetrics = categoryMetrics
        self.deletedRecords = deletedRecords
        self.failedItems = failedItems
        self.durationSeconds = durationSeconds
    }
    
    public var formattedTotalFreed: String {
        ByteCountFormatterHelper.format(bytes: totalBytesFreed)
    }
    
    public var formattedFreeBefore: String {
        ByteCountFormatterHelper.format(bytes: diskFreeBeforeBytes)
    }
    
    public var formattedFreeAfter: String {
        ByteCountFormatterHelper.format(bytes: diskFreeAfterBytes)
    }
}

/// Snapshot of overall volume capacity and usage.
public struct DiskVolumeUsage: Sendable, Equatable {
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let usedBytes: Int64
    
    public init(totalBytes: Int64, freeBytes: Int64) {
        self.totalBytes = max(1, totalBytes)
        self.freeBytes = max(0, freeBytes)
        self.usedBytes = max(0, totalBytes - freeBytes)
    }
    
    public var usedFraction: Double {
        min(1.0, max(0.0, Double(usedBytes) / Double(totalBytes)))
    }
    
    public var formattedTotal: String {
        ByteCountFormatterHelper.format(bytes: totalBytes)
    }
    
    public var formattedFree: String {
        ByteCountFormatterHelper.format(bytes: freeBytes)
    }
    
    public var formattedUsed: String {
        ByteCountFormatterHelper.format(bytes: usedBytes)
    }
    
    public static func current() -> DiskVolumeUsage {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        if let values = try? homeURL.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ]) {
            let total = Int64(values.volumeTotalCapacity ?? 500_000_000_000)
            let availableImportant = values.volumeAvailableCapacityForImportantUsage ?? Int64(values.volumeAvailableCapacity ?? 100_000_000_000)
            return DiskVolumeUsage(totalBytes: total, freeBytes: availableImportant)
        }
        return DiskVolumeUsage(totalBytes: 500_000_000_000, freeBytes: 100_000_000_000)
    }
}
