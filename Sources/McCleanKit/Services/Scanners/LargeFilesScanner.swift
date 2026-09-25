import Foundation

/// Scans user folders for large files (.dmg, .zip, .pkg, videos, archives) and builds a Space Lens directory breakdown
/// while respecting macOS TCC permissions and gracefully skipping any folder the user chose not to grant.
public enum LargeFilesScanner {
    
    private static let resourceKeys: Set<URLResourceKey> = [
        .isRegularFileKey,
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isPackageKey,
        .totalFileAllocatedSizeKey,
        .fileAllocatedSizeKey,
        .totalFileSizeKey,
        .fileSizeKey,
        .contentModificationDateKey
    ]
    
    /// Scans `~/Downloads`, `~/Desktop`, `~/Documents`, and `~/Movies` for single files above `minimumSizeBytes`.
    /// Gracefully skips any folder where the user declined permission, without blocking the scan.
    public static func scanLargeFiles(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        minimumSizeBytes: Int64 = 50 * 1024 * 1024, // 50 MB default
        maxResults: Int = 150,
        allowUnbookmarkedTCCFolders: Bool = false
    ) -> [ScanItem] {
        let fm = FileManager.default
        let bookmarks = PermissionManager.currentGrantedBookmarkPaths()
        
        let candidateFolders: [(name: String, requiresBookmarkOrTCC: Bool)] = [
            ("Downloads", true),
            ("Desktop", true),
            ("Documents", true),
            ("Movies", false)
        ]
        
        var items: [ScanItem] = []
        
        for candidate in candidateFolders {
            if Task.isCancelled { break }
            let folderURL = homeDirectory.appendingPathComponent(candidate.name)
            
            // If this is a TCC-protected folder (Downloads/Desktop/Documents) and the user hasn't granted
            // a bookmark via McClean's permission dialog, skip it unless allowUnbookmarkedTCCFolders is true.
            if candidate.requiresBookmarkOrTCC && !allowUnbookmarkedTCCFolders {
                if !PermissionManager.canAccessUserFolder(folderURL, bookmarkPaths: bookmarks) {
                    continue
                }
            }
            
            guard let enumerator = fm.enumerator(
                at: folderURL,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }
            
            var visitedCount = 0
            for case let fileURL as URL in enumerator {
                if Task.isCancelled || visitedCount > 8_000 { break }
                visitedCount += 1
                
                if TCCGuard.shouldSkipTraversal(of: fileURL) {
                    enumerator.skipDescendants()
                    continue
                }
                
                guard let values = try? fileURL.resourceValues(forKeys: resourceKeys),
                      values.isSymbolicLink != true else {
                    continue
                }
                
                let name = fileURL.lastPathComponent
                if name == "node_modules" || name == ".git" || name == "Pods" || name == ".build" || name == "DerivedData" {
                    enumerator.skipDescendants()
                    continue
                }
                
                if values.isRegularFile == true {
                    let allocated = Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
                    let logical = Int64(values.totalFileSize ?? values.fileSize ?? 0)
                    let bytes = allocated > 0 ? allocated : logical
                    
                    guard bytes >= minimumSizeBytes else { continue }
                    
                    let ext = fileURL.pathExtension.lowercased()
                    let isInstaller = ["dmg", "pkg", "iso", "ipsw"].contains(ext)
                    let inDownloads = fileURL.path.contains("/Downloads/")
                    
                    let explanation: String = {
                        if isInstaller {
                            return "Disk image or installer package (.\(ext)). Usually safe to delete after installing the app."
                        }
                        if inDownloads {
                            return "Large file in your Downloads folder (\(ByteCountFormatterHelper.format(bytes: bytes)))."
                        }
                        return "Large user file in \(folderURL.lastPathComponent). Review before deleting."
                    }()
                    
                    items.append(
                        ScanItem(
                            url: fileURL,
                            name: name,
                            sizeBytes: bytes,
                            category: .largeFilesAndDownloads,
                            safetyLevel: .review,
                            explanation: explanation,
                            associatedAppName: ext.isEmpty ? "File" : ".\(ext.uppercased()) File",
                            isOrphaned: false,
                            isDirectory: false,
                            lastModified: values.contentModificationDate,
                            fileCount: 1,
                            isSelected: false
                        )
                    )
                }
            }
        }
        
        return items
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .prefix(maxResults)
            .map { $0 }
    }
    
    /// Builds a top-level Space Lens breakdown of the Home directory without touching TCC-protected containers or Photos Library.
    public static func buildSpaceLensNodes(
        at rootURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        maxNodes: Int = 20,
        allowUnbookmarkedTCCFolders: Bool = false
    ) -> [ScanItem] {
        let fm = FileManager.default
        let bookmarks = PermissionManager.currentGrantedBookmarkPaths()
        let tccUserFolders: Set<String> = ["Desktop", "Documents", "Downloads"]
        
        guard let entries = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: []
        ) else {
            return []
        }
        
        var nodes: [ScanItem] = []
        for url in entries {
            if Task.isCancelled { break }
            let name = url.lastPathComponent
            if name == ".DS_Store" || name == ".CFUserTextEncoding" || name == ".Trash" { continue }
            
            // Never directly enumerate raw ~/Library in Space Lens because ~/Library contains
            // TCC-protected Containers, Group Containers, Safari, Mail, Messages, Photos, and Calendars.
            if name == "Library" {
                if let safeLibNode = buildSafeLibrarySpaceLensNode(libraryURL: url) {
                    nodes.append(safeLibNode)
                }
                continue
            }
            
            if TCCGuard.shouldSkipTraversal(of: url) {
                continue
            }
            
            if tccUserFolders.contains(name) && !allowUnbookmarkedTCCFolders {
                if !PermissionManager.canAccessUserFolder(url, bookmarkPaths: bookmarks) {
                    continue
                }
            }
            
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true else {
                continue
            }
            
            let isDir = values.isDirectory == true
            let isProtected = KnownPathsDatabase.isProtectedPath(url)
            let safety: SafetyLevel = isProtected ? .protected : .review
            
            let metrics = DiskSizeCalculator.calculateMetrics(
                at: url,
                maxFiles: 3_000,
                includeChildrenForCategory: isDir ? .largeFilesAndDownloads : nil,
                parentSafety: safety,
                maxChildren: 8,
                minimumChildSizeBytes: 2 * 1024 * 1024
            )
            guard metrics.sizeBytes >= 5 * 1024 * 1024 else { continue }
            
            nodes.append(
                ScanItem(
                    url: url,
                    name: name,
                    sizeBytes: metrics.sizeBytes,
                    category: .largeFilesAndDownloads,
                    safetyLevel: safety,
                    explanation: isDir ? "Directory in \(rootURL.lastPathComponent)" : "File in \(rootURL.lastPathComponent)",
                    isDirectory: isDir,
                    lastModified: metrics.lastModified,
                    fileCount: metrics.fileCount,
                    isSelected: false,
                    children: metrics.children
                )
            )
        }
        
        return nodes
            .sorted { $0.sizeBytes > $1.sizeBytes }
            .prefix(maxNodes)
            .map { $0 }
    }
    
    /// Safely summarizes cleanable/non-TCC subdirectories of `~/Library` (`Developer`, `Caches`, `Logs`, `Application Support`)
    /// without ever touching `Containers`, `Group Containers`, `Safari`, `Mail`, `Messages`, or `Photos`.
    private static func buildSafeLibrarySpaceLensNode(libraryURL: URL) -> ScanItem? {
        let safeSubfolders = ["Developer", "Caches", "Application Support", "Logs"]
        var totalBytes: Int64 = 0
        var totalFiles: Int = 0
        var children: [ScanItem] = []
        
        for sub in safeSubfolders {
            if Task.isCancelled { break }
            let subURL = libraryURL.appendingPathComponent(sub)
            let metrics = DiskSizeCalculator.calculateMetrics(
                at: subURL,
                maxFiles: 2_000,
                includeChildrenForCategory: nil,
                parentSafety: .protected
            )
            if metrics.sizeBytes > 0 {
                totalBytes += metrics.sizeBytes
                totalFiles += metrics.fileCount
                children.append(
                    ScanItem(
                        url: subURL,
                        name: sub,
                        sizeBytes: metrics.sizeBytes,
                        category: .largeFilesAndDownloads,
                        safetyLevel: .protected,
                        explanation: "~/Library/\(sub) (TCC-safe summary)",
                        isDirectory: true,
                        lastModified: metrics.lastModified,
                        fileCount: metrics.fileCount,
                        isSelected: false
                    )
                )
            }
        }
        
        guard totalBytes >= 5 * 1024 * 1024 else { return nil }
        return ScanItem(
            url: libraryURL,
            name: "Library (Accessible Caches & Dev Data)",
            sizeBytes: totalBytes,
            category: .largeFilesAndDownloads,
            safetyLevel: .protected,
            explanation: "User Library caches, logs, and developer data (excludes protected macOS containers).",
            isDirectory: true,
            fileCount: max(1, totalFiles),
            isSelected: false,
            children: children.sorted { $0.sizeBytes > $1.sizeBytes }
        )
    }
}
