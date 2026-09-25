import Foundation

/// Deep scanner for Unix-style hidden dot-directories and files (`~/.*`, `~/.config/*`, `~/.local/share/*`).
public enum DotfilesScanner {
    
    /// Scans the specified home directory for hidden dot-directories and large dotfiles.
    public static func scan(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        installedAppNames: Set<String> = [],
        minimumSizeBytes: Int64 = 100 * 1024
    ) -> [ScanItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: homeDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
            options: []
        ) else {
            return []
        }
        
        var items: [ScanItem] = []
        
        for url in contents {
            if Task.isCancelled { break }
            let name = url.lastPathComponent
            guard name.hasPrefix(".") else { continue }
            if name == ".DS_Store" || name == ".CFUserTextEncoding" || name == ".localized" || name == ".Trash" {
                continue
            }
            
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isSymbolicLink != true else {
                continue
            }
            
            let isDirectory = values.isDirectory == true
            let isProtected = KnownPathsDatabase.protectedDotfileNames.contains(name)
            
            let rule = KnownPathsDatabase.dotfileRules[name.lowercased()]
            let safety: SafetyLevel = {
                if isProtected { return .protected }
                if let rule { return rule.safetyLevel }
                return .review
            }()
            
            let category: JunkCategory = {
                if let rule { return rule.category }
                if name.lowercased().contains("wallpaper") || name.lowercased().contains("aerial") {
                    return .wallpapersAndMedia
                }
                return .hiddenDotfiles
            }()
            
            let metrics = DiskSizeCalculator.calculateMetrics(
                at: url,
                maxFiles: 4_500,
                includeChildrenForCategory: (isDirectory && !isProtected) ? category : nil,
                parentSafety: safety,
                maxChildren: 10
            )
            
            if !isProtected && metrics.sizeBytes < minimumSizeBytes {
                continue
            }
            
            if name == ".config" || name == ".local" {
                let subItems = scanSubdirectoryContainer(
                    at: name == ".local" ? url.appendingPathComponent("share") : url,
                    containerDisplayPrefix: name == ".local" ? "~/.local/share" : "~/.config",
                    installedAppNames: installedAppNames,
                    minimumSizeBytes: 1 * 1024 * 1024
                )
                items.append(contentsOf: subItems)
            }
            
            let isOrphaned: Bool = {
                if let rule {
                    return KnownPathsDatabase.isRuleToolOrphaned(rule, installedAppNames: installedAppNames)
                }
                let stripped = String(name.dropFirst()).lowercased()
                return stripped.count >= 3 && !installedAppNames.isEmpty && !installedAppNames.contains(stripped)
            }()
            
            let explanation: String = {
                if let rule {
                    if isOrphaned {
                        return "\(rule.explanation) (Associated app '\(rule.associatedTool)' appears to be uninstalled.)"
                    }
                    return rule.explanation
                }
                if name.lowercased().contains("wallpaper") {
                    return "Hidden wallpaper directory in your Home folder storing high-resolution background assets."
                }
                return "Hidden dot-\(isDirectory ? "directory" : "file") in your Home folder (`~/\(name)`). Review before deleting."
            }()
            
            items.append(
                ScanItem(
                    url: url,
                    name: name,
                    sizeBytes: metrics.sizeBytes,
                    category: category,
                    safetyLevel: safety,
                    explanation: explanation,
                    associatedAppName: rule?.associatedTool,
                    isOrphaned: isOrphaned,
                    isDirectory: isDirectory,
                    lastModified: metrics.lastModified,
                    fileCount: metrics.fileCount,
                    isSelected: safety.defaultSelected,
                    children: metrics.children
                )
            )
        }
        
        return items.sorted { $0.sizeBytes > $1.sizeBytes }
    }
    
    private static func scanSubdirectoryContainer(
        at containerURL: URL,
        containerDisplayPrefix: String,
        installedAppNames: Set<String>,
        minimumSizeBytes: Int64
    ) -> [ScanItem] {
        let fm = FileManager.default
        guard let subdirs = try? fm.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        var results: [ScanItem] = []
        for subURL in subdirs {
            if Task.isCancelled { break }
            guard let values = try? subURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                  values.isDirectory == true,
                  values.isSymbolicLink != true else {
                continue
            }
            
            let metrics = DiskSizeCalculator.calculateMetrics(at: subURL, maxFiles: 2_500)
            guard metrics.sizeBytes >= minimumSizeBytes else { continue }
            
            let folderName = subURL.lastPathComponent
            let normalized = folderName.lowercased()
            let isOrphan = !installedAppNames.isEmpty && !installedAppNames.contains(normalized)
            
            results.append(
                ScanItem(
                    url: subURL,
                    name: "\(containerDisplayPrefix)/\(folderName)",
                    sizeBytes: metrics.sizeBytes,
                    category: .hiddenDotfiles,
                    safetyLevel: .review,
                    explanation: isOrphan
                        ? "Configuration/data folder inside \(containerDisplayPrefix) for '\(folderName)', which may belong to an uninstalled tool."
                        : "Application configuration and local state inside \(containerDisplayPrefix)/\(folderName).",
                    associatedAppName: folderName,
                    isOrphaned: isOrphan,
                    isDirectory: true,
                    lastModified: metrics.lastModified,
                    fileCount: metrics.fileCount,
                    isSelected: false
                )
            )
        }
        return results
    }
}
