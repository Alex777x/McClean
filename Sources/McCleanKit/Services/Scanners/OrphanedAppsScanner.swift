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
    public static let genericTokens: Set<String> = [
        "com", "org", "net", "io", "app", "mac", "macos", "desktop", "client",
        "helper", "agent", "daemon", "service", "inc", "ltd", "dev", "pro", "studio"
    ]
    
    /// Multi-product vendors whose top-level ~/Library folders must NEVER be attached to a single app for deletion.
    public static let umbrellaVendors: Set<String> = [
        "google", "microsoft", "adobe", "jetbrains", "mozilla",
        "apple", "epic", "valve", "steam", "blizzard", "amazon", "oracle",
        "meta", "facebook", "dropbox", "atlassian", "unity"
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
                        if app.isSelfApp { continue }
                        discoveredApps.append(app)
                        installedBundleIDs.insert(app.bundleIdentifier.lowercased())
                        for token in extractTokens(appName: app.name, bundleID: app.bundleIdentifier) {
                            installedTokens.insert(token)
                        }
                    }
                } else if dir.path != "/System/Applications" && url.lastPathComponent != "Utilities" {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        if let subEntries = try? fm.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                            options: [.skipsHiddenFiles]
                        ) {
                            let subApps = subEntries.filter { $0.pathExtension.lowercased() == "app" }
                            if subApps.count == 1, let singleAppURL = subApps.first {
                                // Dedicated application/game folder (e.g. /Applications/Heroes of the Storm)
                                var extraRelatedItems: [ScanItem] = []
                                for sibling in subEntries where sibling.path != singleAppURL.path {
                                    let sibMetrics = DiskSizeCalculator.calculateMetrics(at: sibling, maxFiles: 50_000)
                                    if sibMetrics.sizeBytes > 0 {
                                        var sibIsDir: ObjCBool = false
                                        fm.fileExists(atPath: sibling.path, isDirectory: &sibIsDir)
                                        extraRelatedItems.append(
                                            ScanItem(
                                                url: sibling,
                                                name: "\(url.lastPathComponent): \(sibling.lastPathComponent)",
                                                sizeBytes: sibMetrics.sizeBytes,
                                                category: .orphanedLeftovers,
                                                safetyLevel: .review,
                                                explanation: "Dedicated data and resources inside application folder '\(url.lastPathComponent)'.",
                                                associatedAppName: url.lastPathComponent,
                                                isOrphaned: false,
                                                isDirectory: sibIsDir.boolValue,
                                                lastModified: sibMetrics.lastModified,
                                                fileCount: sibMetrics.fileCount,
                                                isSelected: true
                                            )
                                        )
                                    }
                                }
                                
                                if let app = inspectAppBundle(at: singleAppURL, calculateBundleSize: true, initialRelatedItems: extraRelatedItems) {
                                    if app.isSelfApp { continue }
                                    discoveredApps.append(app)
                                    installedBundleIDs.insert(app.bundleIdentifier.lowercased())
                                    for token in extractTokens(appName: app.name, bundleID: app.bundleIdentifier) {
                                        installedTokens.insert(token)
                                    }
                                    for token in extractTokens(appName: url.lastPathComponent, bundleID: "") {
                                        installedTokens.insert(token)
                                    }
                                }
                            } else if subApps.count > 1 {
                                // Multi-app suite directory (e.g. /Applications/Epson Software)
                                for subAppURL in subApps {
                                    if let app = inspectAppBundle(at: subAppURL, calculateBundleSize: true) {
                                        if app.isSelfApp { continue }
                                        discoveredApps.append(app)
                                        installedBundleIDs.insert(app.bundleIdentifier.lowercased())
                                        for token in extractTokens(appName: app.name, bundleID: app.bundleIdentifier) {
                                            installedTokens.insert(token)
                                        }
                                    }
                                }
                            }
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
                
                let folderNorm = normalizeToken(folderName)
                
                // If it is an umbrella vendor directory (e.g. ~/Library/Application Support/Google),
                // inspect its subdirectories so Chrome matches Google Chrome, while Google itself is never attached.
                if umbrellaVendors.contains(folderNorm) && values.isDirectory == true {
                    if let subEntries = try? fm.contentsOfDirectory(
                        at: entryURL,
                        includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        for subURL in subEntries {
                            if Task.isCancelled { break }
                            let subName = subURL.lastPathComponent
                            let subNorm = normalizeToken(subName)
                            if shouldSkipSystemFolder(subName) || umbrellaVendors.contains(subNorm) { continue }
                            
                            let matchedSubApp = findStrongMatchApp(forFolderName: subName, indexedApps: indexedApps)
                                ?? findStrongMatchApp(forFolderName: "\(folderName) \(subName)", indexedApps: indexedApps)
                            
                            if let app = matchedSubApp {
                                let subMetrics = DiskSizeCalculator.calculateMetrics(at: subURL, maxFiles: 1_500)
                                if subMetrics.sizeBytes > 0 {
                                    let item = ScanItem(
                                        url: subURL,
                                        name: "\(target.label): \(folderName)/\(subName)",
                                        sizeBytes: subMetrics.sizeBytes,
                                        category: .orphanedLeftovers,
                                        safetyLevel: .review,
                                        explanation: "\(target.label) data belonging to installed app \(app.name).",
                                        associatedAppName: app.name,
                                        isOrphaned: false,
                                        isDirectory: true,
                                        lastModified: subMetrics.lastModified,
                                        fileCount: subMetrics.fileCount,
                                        isSelected: true
                                    )
                                    appRelatedMap[app.id, default: []].append(item)
                                }
                            } else {
                                let isSubAssociated = isFolderAssociatedWithAnyApp(
                                    folderName: subName,
                                    indexedApps: indexedApps,
                                    installedTokens: installedTokens
                                ) || isFolderAssociatedWithAnyApp(
                                    folderName: "\(folderName) \(subName)",
                                    indexedApps: indexedApps,
                                    installedTokens: installedTokens
                                )
                                
                                if !isSubAssociated {
                                    let subMetrics = DiskSizeCalculator.calculateMetrics(
                                        at: subURL,
                                        maxFiles: 3_500,
                                        includeChildrenForCategory: .orphanedLeftovers,
                                        parentSafety: .review,
                                        maxChildren: 8
                                    )
                                    if subMetrics.sizeBytes >= minimumOrphanSizeBytes {
                                        let inferredAppName = "\(folderName) \(humanizeFolderName(subName))"
                                        orphanedItems.append(
                                            ScanItem(
                                                url: subURL,
                                                name: "\(folderName)/\(subName)",
                                                sizeBytes: subMetrics.sizeBytes,
                                                category: .orphanedLeftovers,
                                                safetyLevel: .review,
                                                explanation: "Leftover \(target.label) folder in ~/Library/\(target.subpath)/\(folderName). No matching application ('\(inferredAppName)') is currently installed.",
                                                associatedAppName: inferredAppName,
                                                isOrphaned: true,
                                                isDirectory: true,
                                                lastModified: subMetrics.lastModified,
                                                fileCount: subMetrics.fileCount,
                                                isSelected: false,
                                                children: subMetrics.children
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                    // The umbrella root folder itself is never attached as an app's related items
                    continue
                }
                
                // Normal top-level folder:
                let matchedApp = findStrongMatchApp(
                    forFolderName: folderName,
                    indexedApps: indexedApps
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
                    let isAssociated = isFolderAssociatedWithAnyApp(
                        folderName: folderName,
                        indexedApps: indexedApps,
                        installedTokens: installedTokens
                    )
                    
                    if !isAssociated {
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
        }
        
        // Populate related items into discovered non-system apps
        let finalApps: [InstalledApp] = discoveredApps
            .map { app in
                var copy = app
                if !app.isSystemApp {
                    copy.relatedItems = (copy.relatedItems + (appRelatedMap[app.id] ?? [])).sorted { $0.sizeBytes > $1.sizeBytes }
                } else {
                    copy.relatedItems = []
                }
                return copy
            }
            .sorted { $0.totalFootprintBytes > $1.totalFootprintBytes }
        
        return OrphanScanResult(
            orphanedItems: orphanedItems.sorted { $0.sizeBytes > $1.sizeBytes },
            installedApps: finalApps,
            installedTokens: installedTokens
        )
    }
    
    // MARK: - Helpers
    
    private static func inspectAppBundle(
        at url: URL,
        calculateBundleSize: Bool,
        initialRelatedItems: [ScanItem] = []
    ) -> InstalledApp? {
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        let plist = NSDictionary(contentsOf: infoPlistURL) as? [String: Any]
        
        let fallbackName = url.deletingPathExtension().lastPathComponent
        let displayName = (plist?["CFBundleDisplayName"] as? String)
            ?? (plist?["CFBundleName"] as? String)
            ?? fallbackName
        let bundleID = (plist?["CFBundleIdentifier"] as? String) ?? "unknown.\(normalizeToken(fallbackName))"
        let version = (plist?["CFBundleShortVersionString"] as? String) ?? "1.0"
        
        let sizeBytes: Int64 = calculateBundleSize
            ? DiskSizeCalculator.calculateMetrics(at: url, maxFiles: 50_000).sizeBytes
            : 0
        
        return InstalledApp(
            bundleURL: url,
            name: displayName,
            bundleIdentifier: bundleID,
            version: version,
            appBundleSizeBytes: sizeBytes,
            relatedItems: initialRelatedItems
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
    
    public struct IndexedAppEntry: Sendable {
        public let app: InstalledApp
        public let bundleIDLower: String
        public let normalizedName: String
        public let tokens: Set<String>
        
        public init(app: InstalledApp, bundleIDLower: String, normalizedName: String, tokens: Set<String>) {
            self.app = app
            self.bundleIDLower = bundleIDLower
            self.normalizedName = normalizedName
            self.tokens = tokens
        }
    }
    
    public static func normalizeToken(_ raw: String) -> String {
        raw.lowercased().filter { $0.isLetter || $0.isNumber }
    }
    
    /// Unambiguously finds the single installed app strongly associated with this folder name.
    /// Never attaches umbrella vendor folders, generic names, or ambiguous folders matching multiple apps.
    public static func findStrongMatchApp(
        forFolderName folderName: String,
        indexedApps: [IndexedAppEntry]
    ) -> InstalledApp? {
        let lower = folderName.lowercased()
        let cleaned = lower
            .replacingOccurrences(of: ".savedstate", with: "")
            .replacingOccurrences(of: ".binarycookies", with: "")
            .replacingOccurrences(of: "group.", with: "")
        let folderNorm = normalizeToken(cleaned)
        
        // Never match if folder name is generic or an umbrella vendor root
        if umbrellaVendors.contains(folderNorm) || genericTokens.contains(folderNorm) {
            return nil
        }
        
        var matches: [InstalledApp] = []
        
        // 1. Exact Bundle ID or Bundle ID prefix/suffix match (Strongest)
        for entry in indexedApps {
            let bid = entry.bundleIDLower
            guard !bid.isEmpty, bid != "unknown" else { continue }
            if cleaned == bid || cleaned.hasPrefix(bid + ".") || cleaned.hasSuffix("." + bid) {
                matches.append(entry.app)
            }
        }
        
        if !matches.isEmpty {
            return matches.count == 1 ? matches.first : nil
        }
        
        // 2. Exact App Name match (normalized folder name matches normalized app name exactly)
        if folderNorm.count >= 4 {
            for entry in indexedApps {
                let appNorm = entry.normalizedName
                guard appNorm.count >= 4, !umbrellaVendors.contains(appNorm), !genericTokens.contains(appNorm) else { continue }
                if folderNorm == appNorm {
                    matches.append(entry.app)
                }
            }
        }
        
        // 3. Suffix match for reverse-domain folders (e.g. com.blizzard.heroesofthestorm matching heroesofthestorm)
        if matches.isEmpty && folderNorm.count >= 6 {
            for entry in indexedApps {
                let appNorm = entry.normalizedName
                guard appNorm.count >= 6, !umbrellaVendors.contains(appNorm), !genericTokens.contains(appNorm) else { continue }
                if folderNorm.hasSuffix(appNorm) {
                    matches.append(entry.app)
                }
            }
        }
        
        return matches.count == 1 ? matches.first : nil
    }
    
    /// Checks whether a folder in ~/Library is linked to any active app or package (preventing false orphan alerts).
    public static func isFolderAssociatedWithAnyApp(
        folderName: String,
        indexedApps: [IndexedAppEntry],
        installedTokens: Set<String>
    ) -> Bool {
        let lower = folderName.lowercased()
        let cleaned = lower
            .replacingOccurrences(of: ".savedstate", with: "")
            .replacingOccurrences(of: ".binarycookies", with: "")
            .replacingOccurrences(of: "group.", with: "")
        let folderNorm = normalizeToken(cleaned)
        
        if umbrellaVendors.contains(folderNorm) {
            // Associated if any app from this vendor is currently installed
            return indexedApps.contains { $0.tokens.contains(folderNorm) || $0.bundleIDLower.contains(folderNorm) }
        }
        
        if installedTokens.contains(folderNorm) {
            return true
        }
        
        for entry in indexedApps {
            let bid = entry.bundleIDLower
            if cleaned == bid || cleaned.hasPrefix(bid + ".") || cleaned.hasSuffix("." + bid) {
                return true
            }
            if entry.normalizedName == folderNorm && folderNorm.count >= 4 {
                return true
            }
            if entry.tokens.contains(folderNorm) {
                return true
            }
        }
        
        let folderParts = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".-_ "))
            .map { normalizeToken($0) }
            .filter { $0.count >= 4 && !genericTokens.contains($0) }
        
        for part in folderParts {
            if installedTokens.contains(part) {
                return true
            }
            for entry in indexedApps where entry.tokens.contains(part) {
                return true
            }
        }
        
        return false
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
