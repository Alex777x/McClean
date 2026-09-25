import Foundation
import AppKit

/// Service responsible for permanently deleting selected files/folders with strict whitelist protection
/// and generating detailed category telemetry for the Space Reclaimed visual chart.
public enum CleanupService {
    
    /// Permanently removes the given `ScanItem` list from disk and produces a `CleanupReport` for visual charts.
    public static func cleanImmediately(
        items: [ScanItem],
        customWhitelistedPaths: Set<String> = [],
        allowProtectedOverride: Bool = false,
        progressHandler: (@Sendable (String, Double) -> Void)? = nil
    ) -> CleanupReport {
        let startTime = Date()
        let beforeUsage = DiskVolumeUsage.current()
        let fm = FileManager.default
        
        var totalBytesFreed: Int64 = 0
        var categoryTotals: [JunkCategory: (bytes: Int64, count: Int)] = [:]
        var deletedRecords: [DeletedItemRecord] = []
        var failedItems: [FailedCleanupItem] = []
        
        let totalCount = max(1, items.count)
        
        for (index, item) in items.enumerated() {
            let fraction = Double(index) / Double(totalCount)
            progressHandler?(item.name, fraction)
            
            let standardizedPath = item.url.standardizedFileURL.path
            
            // 1. Check user custom whitelist (handles both ~ and standardized POSIX paths + parent directory protection)
            if KnownPathsDatabase.matchesCustomWhitelist(url: item.url, displayPath: item.displayPath, whitelist: customWhitelistedPaths) {
                failedItems.append(
                    FailedCleanupItem(
                        name: item.name,
                        path: item.displayPath,
                        reason: "Skipped (in your Protected Whitelist)"
                    )
                )
                continue
            }
            
            // 2. Check built-in Protected Whitelist (.ssh, .gnupg, .aws, /System, etc.)
            if !allowProtectedOverride && (item.safetyLevel == .protected || KnownPathsDatabase.isProtectedPath(item.url)) {
                failedItems.append(
                    FailedCleanupItem(
                        name: item.name,
                        path: item.displayPath,
                        reason: "Protected critical directory (blocked for safety)"
                    )
                )
                continue
            }
            
            guard fm.fileExists(atPath: standardizedPath) else {
                continue
            }
            
            // 3. Perform immediate permanent deletion
            let deletionResult = permanentlyDeleteItem(at: item.url, expectedBytes: item.sizeBytes)
            switch deletionResult {
            case .success(let freedBytes):
                totalBytesFreed += freedBytes
                let existing = categoryTotals[item.category] ?? (0, 0)
                categoryTotals[item.category] = (existing.bytes + freedBytes, existing.count + 1)
                deletedRecords.append(
                    DeletedItemRecord(
                        name: item.name,
                        path: item.displayPath,
                        bytesFreed: freedBytes,
                        category: item.category
                    )
                )
            case .failure(let errorMessage):
                failedItems.append(
                    FailedCleanupItem(
                        name: item.name,
                        path: item.displayPath,
                        reason: errorMessage
                    )
                )
            }
        }
        
        progressHandler?("Complete", 1.0)
        
        let rawAfterUsage = DiskVolumeUsage.current()
        // Compute effective after-usage (ensuring immediate visual reflection even if APFS background purge lags by a few ms)
        let effectiveFreeAfter = max(rawAfterUsage.freeBytes, min(beforeUsage.totalBytes, beforeUsage.freeBytes + totalBytesFreed))
        let effectiveUsedAfter = max(0, beforeUsage.totalBytes - effectiveFreeAfter)
        
        let categoryMetrics: [CategoryCleanupMetric] = JunkCategory.allCases.compactMap { cat in
            guard let entry = categoryTotals[cat], entry.bytes > 0 else { return nil }
            return CategoryCleanupMetric(category: cat, bytesFreed: entry.bytes, itemCount: entry.count)
        }.sorted { $0.bytesFreed > $1.bytesFreed }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return CleanupReport(
            totalBytesFreed: totalBytesFreed,
            deletedItemCount: deletedRecords.count,
            diskTotalBytes: beforeUsage.totalBytes,
            diskUsedBeforeBytes: beforeUsage.usedBytes,
            diskUsedAfterBytes: effectiveUsedAfter,
            diskFreeBeforeBytes: beforeUsage.freeBytes,
            diskFreeAfterBytes: effectiveFreeAfter,
            categoryMetrics: categoryMetrics,
            deletedRecords: deletedRecords,
            failedItems: failedItems,
            durationSeconds: duration
        )
    }
    
    private enum DeletionOutcome {
        case success(Int64)
        case failure(String)
    }
    
    private static func permanentlyDeleteItem(at url: URL, expectedBytes: Int64) -> DeletionOutcome {
        let fm = FileManager.default
        
        // Special case: ~/.Trash -> delete contents inside ~/.Trash rather than ~/.Trash directory itself
        if url.lastPathComponent == ".Trash" {
            return deleteContentsInsideDirectory(at: url, expectedBytes: expectedBytes)
        }
        
        do {
            try fm.removeItem(at: url)
            return .success(expectedBytes)
        } catch {
            // Fallback 1: If the parent directory is locked (e.g., idleassetsd/Customer or a container root),
            // try removing all children inside the directory.
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                let innerOutcome = deleteContentsInsideDirectory(at: url, expectedBytes: expectedBytes)
                if case .success = innerOutcome {
                    return innerOutcome
                }
            }
            
            // Fallback 2: For system-owned macOS Aerial Wallpapers (/Library/Application Support/com.apple.idleassetsd/...),
            // attempt privileged deletion via AppleScript administrator prompt if running interactively.
            if url.path.hasPrefix("/Library/Application Support/com.apple.idleassetsd/") {
                if deleteSystemIdleAssetsWithAdminPrompt(at: url) {
                    return .success(expectedBytes)
                }
            }
            
            return .failure(error.localizedDescription)
        }
    }
    
    private static func deleteContentsInsideDirectory(at directoryURL: URL, expectedBytes: Int64) -> DeletionOutcome {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil, options: []) else {
            return .failure("Permission denied reading directory contents.")
        }
        
        if children.isEmpty {
            return .success(0)
        }
        
        var deletedAny = false
        var lastError: String = "Permission denied."
        for child in children {
            do {
                try fm.removeItem(at: child)
                deletedAny = true
            } catch {
                lastError = error.localizedDescription
            }
        }
        
        return deletedAny ? .success(expectedBytes) : .failure(lastError)
    }
    
    /// Explicitly allowlisted system Aerial Wallpaper directories eligible for privileged cleanup.
    /// Using an exact allowlist eliminates any shell/AppleScript string interpolation risk.
    private static let allowedAdminIdleAssetPaths: Set<String> = [
        "/Library/Application Support/com.apple.idleassetsd/Customer",
        "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"
    ]
    
    private static func deleteSystemIdleAssetsWithAdminPrompt(at url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        guard allowedAdminIdleAssetPaths.contains(path) else {
            return false
        }
        #if APP_STORE
        // In the Mac App Store sandbox, reveal the root-owned folder in Finder where macOS handles Touch ID deletion natively.
        DispatchQueue.main.async {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        return false
        #else
        let scriptSource = "do shell script \"rm -rf '\(path)'/*\" with administrator privileges"
        guard let appleScript = NSAppleScript(source: scriptSource) else {
            return false
        }
        var errorDict: NSDictionary?
        appleScript.executeAndReturnError(&errorDict)
        return errorDict == nil
        #endif
    }
}
