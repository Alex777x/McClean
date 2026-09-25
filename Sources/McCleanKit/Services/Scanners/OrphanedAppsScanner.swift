import Foundation

/// Result of scanning installed applications and cross-referencing `~/Library` for orphaned leftovers.
public struct OrphanScanResult: Sendable {
    public let orphanedItems: [ScanItem]
    public let installedApps: [InstalledApp]
    public let installedTokens: Set<String>
    
    public init(orphanedItems: [ScanItem], installedApps: [InstalledApp], installedTokens: Set<String>) {
        self.orphanedItems = orphanedItems
        self.installedApps = installedApps
        self.installedTokens = installedTokens
    }
}

/// Cross-references installed `.app` bundles against `~/Library` directories to detect leftover data from uninstalled apps
/// and build complete footprint profiles for the App Uninstaller.
public enum OrphanedAppsScanner {
    
    /// System folders inside `~/Library/Application Support` or `Caches` that belong to macOS itself and are never orphaned apps.
    private static let systemIgnoredNames: Set<String> = [
        "addressbook",
        "animoji",
        "accountsd",
        "apple",
        "assistant",
        "biome",
        "caches",
        "callhistorydb",
        "callhistorytransactions",
        "cloudocs",
        "cloudkit",
        "com.apple",
        "contactsd",
        "controlcenter",
        "coredata",
        "coreparsec",
        "corespotlight",
        "crashreporter",
        "differentialprivacy",
        "diskimages",
        "dock",
        "faceid",
        "fileprovider",
        "geoservices",
        "homed",
        "icdd",
        "icloud",
        "knowledge",
        "lockdownmode",
        "mail",
        "messages",
        "mobile documents",
        "mobilesync",
        "networkserviceproxy",
        "notificationcenter",
        "passkit",
        "proactiveeventtracker",
        "quicklook",
        "routined",
        "safari",
        "siri",
        "spotlight",
        "syncservices",
        "syncedpreferences",
        "trial",
        "ubiquity",
        "videosubscriptionsd",
        "wallpaper"
    ]
    
    /// Generic vendor tokens that shouldn't by themselves link unrelated apps together.
    private static let genericTokens: Set<String> = [
        "com", "org", "net", "io", "app", "mac", "macos", "desktop", "client",
        "helper", "agent", "daemon", "service", "inc", "ltd", "dev", "pro", "studio"
    ]
    
    public static func scan(
        applicationDirectories: [URL]? = nil,
        userLibraryURL: URL? = nil,
        minimumOrphanSizeBytes: Int64 = 64 * 1024 // 64 KB
    ) -> OrphanScanResult {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let appDirs = applicationDirectories ?? [
            URL(fileURLWithPath: "/Applications"),
            home.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Applications")
        ]
        let libraryURL = userLibraryURL ?? home.appendingPathComponent("Library")
        
        // Step 1: Index all installed .app bundles quickly
        var discoveredApps: [InstalledApp] = []
        var installedBundleIDs: Set<String> = []
        var installedTokens: Set<String> = []
        
        for dir in appDirs {
            guard let urls = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            
            for url in urls {
                if Task.isCancelled { break }
                if url.pathExtension.lowercased() == "app" {
                    if let app = inspectAppBundle(at: url, calculateBundleSize: dir.path != "/System/Applications") {
                        discoveredApps.append(app)
                        installedBundleIDs.insert(app.bundleIdentifier.lowercased())
                        for token in extractTokens(appName: app.name, bundleID: app.bundleIdentifier) {
                            installedTokens.insert(token)
                        }
                    }
                }
            }
        }
        
        // Also index CLI packages in /opt/homebrew/Cellar and /opt/homebrew/Caskroom so active brew tools aren't false-flagged
        for brewPath in ["/opt/homebrew/Cellar", "/opt/homebrew/Caskroom", "/usr/local/Cellar"] {
            if let names = try? fm.contentsOfDirectory(atPath: brewPath) {
                for name in names {
                    installedTokens.insert(normalizeToken(name))
                }
            }
        }
        
        // Step 2: Scan ~/Library subdirectories that do not trigger TCC container prompts
        let libraryTargets: [(subpath: String, label: String)] = [
            ("Application Support", "Application Support"),
            ("Saved Application State", "Saved State"),
            ("Caches", "App Cache"),
            ("HTTPStorages", "HTTP Storage"),
            ("WebKit", "WebKit Data")
        ]
        
        var orphanedItems: [ScanItem] = []
        var appRelatedMap: [UUID: [ScanItem]] = [:]
        
        // Precompute normalized name and token sets per app once to avoid repeated string splitting in the library loop
        let indexedApps: [IndexedAppEntry] = discoveredApps.map { app in
            IndexedAppEntry(
                app: app,
                bundleIDLower: app.bundleIdentifier.lowercased(),
                normalizedName: normalizeToken(app.name),
                tokens: extractTokens(appName: app.name, bundleID: app.bundleIdentifier)
            )
        }
        
        for target in libraryTargets {
            if Task.isCancelled { break }
            let targetDir = libraryURL.appendingPathComponent(target.subpath)
            guard let entries = try? fm.contentsOfDirectory(
                at: targetDir,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            
            for entryURL in entries {
                if Task.isCancelled { break }
                guard let values = try? entryURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
                      values.isSymbolicLink != true else {
                    continue
                }
                
                let folderName = entryURL.lastPathComponent
                if shouldSkipSystemFolder(folderName) || TCCGuard.shouldSkipTraversal(of: entryURL) {
                    continue
                }
                
                let matchedApp = findMatchingInstalledApp(
                    forFolderName: folderName,
                    indexedApps: indexedApps,
                    installedTokens: installedTokens
                )
                
                if let app = matchedApp {
                    let metrics = DiskSizeCalculator.calculateMetrics(at: entryURL, maxFiles: 1_500)
                    if metrics.sizeBytes > 0 {
                        let item = ScanItem(
                            url: entryURL,
                            name: "\(target.label): \(folderName)",
                            sizeBytes: metrics.sizeBytes,
                            category: .orphanedLeftovers,
                            safetyLevel: .review,
                            explanation: "\(target.label) data belonging to installed app \(app.name).",
                            associatedAppName: app.name,
                            isOrphaned: false,
                            isDirectory: values.isDirectory == true,
                            lastModified: metrics.lastModified,
                            fileCount: metrics.fileCount,
                            isSelected: true
                        )
                        appRelatedMap[app.id, default: []].append(item)
                    }
                } else {
                    let metrics = DiskSizeCalculator.calculateMetrics(
                        at: entryURL,
                        maxFiles: 3_500,
                        includeChildrenForCategory: (values.isDirectory == true) ? .orphanedLeftovers : nil,
                        parentSafety: .review,
                        maxChildren: 8
                    )
                    guard metrics.sizeBytes >= minimumOrphanSizeBytes else { continue }
                    let inferredAppName = humanizeFolderName(folderName)
                    
                    orphanedItems.append(
                        ScanItem(
                            url: entryURL,
                            name: folderName,
                            sizeBytes: metrics.sizeBytes,
                            category: .orphanedLeftovers,
                            safetyLevel: .review,
                            explanation: "Leftover \(target.label) folder in ~/Library/\(target.subpath). No matching application ('\(inferredAppName)') is currently installed in /Applications.",
                            associatedAppName: inferredAppName,
                            isOrphaned: true,
                            isDirectory: values.isDirectory == true,
                            lastModified: metrics.lastModified,
                            fileCount: metrics.fileCount,
                            isSelected: false,
                            children: metrics.children
                        )
                    )
                }
            }
        }
        
        // Populate related items into discovered non-system apps
        let userApps: [InstalledApp] = discoveredApps
            .filter { !$0.bundleURL.path.hasPrefix("/System/") }
            .map { app in
                var copy = app
                copy.relatedItems = (appRelatedMap[app.id] ?? []).sorted { $0.sizeBytes > $1.sizeBytes }
                return copy
            }
            .sorted { $0.totalFootprintBytes > $1.totalFootprintBytes }
        
        return OrphanScanResult(
            orphanedItems: orphanedItems.sorted { $0.sizeBytes > $1.sizeBytes },
            installedApps: userApps,
            installedTokens: installedTokens
        )
    }
    
    // MARK: - Helpers
    
    private static func inspectAppBundle(at url: URL, calculateBundleSize: Bool) -> InstalledApp? {
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        let plist = NSDictionary(contentsOf: infoPlistURL) as? [String: Any]
        
        let fallbackName = url.deletingPathExtension().lastPathComponent
        let displayName = (plist?["CFBundleDisplayName"] as? String)
            ?? (plist?["CFBundleName"] as? String)
            ?? fallbackName
        let bundleID = (plist?["CFBundleIdentifier"] as? String) ?? "unknown.\(normalizeToken(fallbackName))"
        let version = (plist?["CFBundleShortVersionString"] as? String) ?? "1.0"
        
        let sizeBytes: Int64 = calculateBundleSize
            ? DiskSizeCalculator.calculateMetrics(at: url, maxFiles: 1_200).sizeBytes
            : 0
        
        return InstalledApp(
            bundleURL: url,
            name: displayName,
            bundleIdentifier: bundleID,
            version: version,
            appBundleSizeBytes: sizeBytes
        )
    }
    
    private static func shouldSkipSystemFolder(_ name: String) -> Bool {
        let lower = name.lowercased()
        if lower.hasPrefix("com.apple.") || lower.hasPrefix("apple.") || lower.hasPrefix("group.com.apple.") {
            return true
        }
        if systemIgnoredNames.contains(lower) {
            return true
        }
        return false
    }
    
    private static func extractTokens(appName: String, bundleID: String) -> Set<String> {
        var tokens: Set<String> = []
        let normalizedName = normalizeToken(appName)
        if normalizedName.count >= 3 {
            tokens.insert(normalizedName)
        }
        
        for word in appName.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted) {
            if word.count >= 4 && !genericTokens.contains(word) {
                tokens.insert(word)
            }
        }
        
        let parts = bundleID.lowercased().components(separatedBy: ".")
        for part in parts where part.count >= 3 && !genericTokens.contains(part) {
            tokens.insert(normalizeToken(part))
        }
        return tokens
    }
    
    private struct IndexedAppEntry {
        let app: InstalledApp
        let bundleIDLower: String
        let normalizedName: String
        let tokens: Set<String>
    }
    
    private static func normalizeToken(_ raw: String) -> String {
        raw.lowercased().filter { $0.isLetter || $0.isNumber }
    }
    
    private static func findMatchingInstalledApp(
        forFolderName folderName: String,
        indexedApps: [IndexedAppEntry],
        installedTokens: Set<String>
    ) -> InstalledApp? {
        let lower = folderName.lowercased()
        let cleaned = lower
            .replacingOccurrences(of: ".savedstate", with: "")
            .replacingOccurrences(of: ".binarycookies", with: "")
        
        for entry in indexedApps {
            let bid = entry.bundleIDLower
            if cleaned == bid || cleaned.hasPrefix(bid + ".") || cleaned.hasSuffix("." + bid) {
                return entry.app
            }
        }
        
        let folderNorm = normalizeToken(cleaned)
        let folderParts = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".-_ "))
            .map { normalizeToken($0) }
            .filter { $0.count >= 4 && !genericTokens.contains($0) }
        
        for entry in indexedApps {
            let appNorm = entry.normalizedName
            if appNorm.count >= 3 && (folderNorm == appNorm || folderNorm.contains(appNorm)) {
                return entry.app
            }
            for part in folderParts {
                if entry.tokens.contains(part) {
                    return entry.app
                }
            }
        }
        
        if installedTokens.contains(folderNorm) {
            return InstalledApp(
                bundleURL: URL(fileURLWithPath: "/opt/homebrew"),
                name: folderName,
                bundleIdentifier: folderName,
                appBundleSizeBytes: 0
            )
        }
        for part in folderParts where installedTokens.contains(part) {
            return InstalledApp(
                bundleURL: URL(fileURLWithPath: "/opt/homebrew"),
                name: folderName,
                bundleIdentifier: folderName,
                appBundleSizeBytes: 0
            )
        }
        
        return nil
    }
    
    private static func humanizeFolderName(_ folderName: String) -> String {
        let cleaned = folderName
            .replacingOccurrences(of: ".savedState", with: "")
            .replacingOccurrences(of: "group.", with: "")
        let parts = cleaned.components(separatedBy: ".")
        if parts.count >= 3 {
            let tail = parts.dropFirst(1).joined(separator: " ")
            return tail.capitalized
        }
        return cleaned
    }
}
