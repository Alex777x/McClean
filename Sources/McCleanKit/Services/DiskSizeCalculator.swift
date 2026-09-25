import Foundation

/// Result of scanning a single file or directory on disk.
public struct DirectorySizeMetrics: Sendable {
    public let sizeBytes: Int64
    public let fileCount: Int
    public let lastModified: Date?
    public let children: [ScanItem]
    
    public init(sizeBytes: Int64, fileCount: Int, lastModified: Date?, children: [ScanItem] = []) {
        self.sizeBytes = sizeBytes
        self.fileCount = fileCount
        self.lastModified = lastModified
        self.children = children
    }
}

/// Fast APFS-aware single-pass disk size calculator that avoids symlink loops, TCC traps, and double enumeration.
public enum DiskSizeCalculator {
    
    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isPackageKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .totalFileSizeKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .ubiquitousItemDownloadingStatusKey
    ]
    
    private struct ChildAccumulator {
        var url: URL
        var sizeBytes: Int64 = 0
        var fileCount: Int = 0
        var isDirectory: Bool = false
        var lastModified: Date?
    }
    
    /// Calculates physical allocated size, file count, last modification date, and optional top child breakdown in a single pass.
    public static func calculateMetrics(
        at url: URL,
        maxFiles: Int = 4_500,
        includeChildrenForCategory: JunkCategory? = nil,
        parentSafety: SafetyLevel = .review,
        maxChildren: Int = 10,
        minimumChildSizeBytes: Int64 = 512 * 1024
    ) -> DirectorySizeMetrics {
        if TCCGuard.shouldSkipTraversal(of: url) {
            return DirectorySizeMetrics(sizeBytes: 0, fileCount: 0, lastModified: nil)
        }
        
        guard let rootValues = try? url.resourceValues(forKeys: resourceKeys) else {
            return DirectorySizeMetrics(sizeBytes: 0, fileCount: 0, lastModified: nil)
        }
        
        // Never follow symbolic links
        if rootValues.isSymbolicLink == true {
            return DirectorySizeMetrics(sizeBytes: 0, fileCount: 0, lastModified: rootValues.contentModificationDate)
        }
        
        // Single regular file
        if rootValues.isRegularFile == true {
            let bytes = extractBytes(from: rootValues)
            return DirectorySizeMetrics(sizeBytes: bytes, fileCount: 1, lastModified: rootValues.contentModificationDate)
        }
        
        return calculateSinglePassDirectoryMetrics(
            at: url,
            initialModified: rootValues.contentModificationDate,
            maxFiles: maxFiles,
            includeChildrenForCategory: includeChildrenForCategory,
            parentSafety: parentSafety,
            maxChildren: maxChildren,
            minimumChildSizeBytes: minimumChildSizeBytes
        )
    }
    
    private static func calculateSinglePassDirectoryMetrics(
        at url: URL,
        initialModified: Date?,
        maxFiles: Int,
        includeChildrenForCategory: JunkCategory?,
        parentSafety: SafetyLevel,
        maxChildren: Int,
        minimumChildSizeBytes: Int64
    ) -> DirectorySizeMetrics {
        let fm = FileManager.default
        var totalBytes: Int64 = 0
        var count: Int = 0
        var latestModified = initialModified
        
        let rootStdPath = url.standardizedFileURL.path
        let rootPrefix = rootStdPath.hasSuffix("/") ? rootStdPath : (rootStdPath + "/")
        let collectChildren = includeChildrenForCategory != nil
        var childBuckets: [String: ChildAccumulator] = [:]
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return DirectorySizeMetrics(sizeBytes: 0, fileCount: 0, lastModified: latestModified)
        }
        
        for case let fileURL as URL in enumerator {
            if Task.isCancelled || count >= maxFiles {
                break
            }
            if TCCGuard.shouldSkipTraversal(of: fileURL) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                continue
            }
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                continue
            }
            
            let modDate = values.contentModificationDate
            if let mod = modDate {
                if latestModified == nil || mod > latestModified! {
                    latestModified = mod
                }
            }
            
            let isReg = values.isRegularFile == true
            let isDir = values.isDirectory == true
            let fileBytes: Int64 = isReg ? extractBytes(from: values) : 0
            
            if isReg {
                totalBytes += fileBytes
                count += 1
            }
            
            if collectChildren {
                let stdPath = fileURL.standardizedFileURL.path
                if stdPath.hasPrefix(rootPrefix) {
                    let relative = String(stdPath.dropFirst(rootPrefix.count))
                    if let slashIndex = relative.firstIndex(of: "/") {
                        let firstComponent = String(relative[..<slashIndex])
                        if !firstComponent.isEmpty && firstComponent != ".DS_Store" {
                            var acc = childBuckets[firstComponent] ?? ChildAccumulator(
                                url: url.appendingPathComponent(firstComponent),
                                isDirectory: true,
                                lastModified: modDate
                            )
                            acc.isDirectory = true
                            acc.sizeBytes += fileBytes
                            if isReg { acc.fileCount += 1 }
                            if let mod = modDate, (acc.lastModified == nil || mod > acc.lastModified!) {
                                acc.lastModified = mod
                            }
                            childBuckets[firstComponent] = acc
                        }
                    } else if !relative.isEmpty && relative != ".DS_Store" {
                        var acc = childBuckets[relative] ?? ChildAccumulator(
                            url: fileURL,
                            isDirectory: isDir,
                            lastModified: modDate
                        )
                        acc.isDirectory = acc.isDirectory || isDir
                        acc.sizeBytes += fileBytes
                        if isReg { acc.fileCount += 1 }
                        if let mod = modDate, (acc.lastModified == nil || mod > acc.lastModified!) {
                            acc.lastModified = mod
                        }
                        childBuckets[relative] = acc
                    }
                }
            }
        }
        
        var childItems: [ScanItem] = []
        if let category = includeChildrenForCategory, !childBuckets.isEmpty {
            let parentName = url.lastPathComponent
            childItems = childBuckets.values
                .filter { $0.sizeBytes >= minimumChildSizeBytes }
                .sorted { $0.sizeBytes > $1.sizeBytes }
                .prefix(maxChildren)
                .map { acc in
                    ScanItem(
                        url: acc.url,
                        name: acc.url.lastPathComponent,
                        sizeBytes: acc.sizeBytes,
                        category: category,
                        safetyLevel: parentSafety,
                        explanation: acc.isDirectory
                            ? "Subdirectory inside \(parentName)"
                            : "File inside \(parentName)",
                        isDirectory: acc.isDirectory,
                        lastModified: acc.lastModified,
                        fileCount: max(1, acc.fileCount),
                        isSelected: parentSafety.defaultSelected
                    )
                }
        }
        
        return DirectorySizeMetrics(
            sizeBytes: totalBytes,
            fileCount: max(1, count),
            lastModified: latestModified,
            children: childItems
        )
    }
    
    /// Legacy helper preserved for compatibility; now uses single-pass calculation.
    public static func buildImmediateChildren(
        of directoryURL: URL,
        category: JunkCategory,
        parentSafety: SafetyLevel,
        maxChildren: Int = 10,
        minimumChildSizeBytes: Int64 = 512 * 1024
    ) -> [ScanItem] {
        calculateMetrics(
            at: directoryURL,
            maxFiles: 4_000,
            includeChildrenForCategory: category,
            parentSafety: parentSafety,
            maxChildren: maxChildren,
            minimumChildSizeBytes: minimumChildSizeBytes
        ).children
    }
    
    /// Extracts physical allocated bytes when available, falling back to logical file size when on tmpfs/tests.
    private static func extractBytes(from values: URLResourceValues) -> Int64 {
        if let status = values.ubiquitousItemDownloadingStatus,
           status == .notDownloaded {
            return 0
        }
        let allocated = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        let logical = Int64(values.totalFileSize ?? values.fileSize ?? 0)
        return allocated > 0 ? allocated : logical
    }
}
