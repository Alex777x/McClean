import Foundation
import SwiftUI
import AppKit

/// Fast thread-safe in-memory cache for application bundle icons to avoid synchronous disk/LaunchServices hits during SwiftUI layout.
@MainActor
public enum AppIconCache {
    private static var cache: [String: NSImage] = [:]
    
    public static func icon(for bundleURL: URL) -> NSImage {
        let key = bundleURL.path
        if let existing = cache[key] {
            return existing
        }
        let img = NSWorkspace.shared.icon(forFile: key)
        img.size = NSSize(width: 36, height: 36)
        cache[key] = img
        return img
    }
}

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var selectedSection: NavigationSection = .smartScan
    @Published public var isScanning: Bool = false
    @Published public var scanProgress: Double = 0.0
    @Published public var scanStatusMessage: String = "Ready to scan your Mac"
    @Published public var hasCompletedScan: Bool = false
    
    @Published public var allScanItems: [ScanItem] = []
    @Published public var installedApps: [InstalledApp] = []
    @Published public var spaceLensNodes: [ScanItem] = []
    @Published public var diskUsage: DiskVolumeUsage = .current()
    
    @Published public var searchQuery: String = ""
    @Published public var selectedSafetyFilter: SafetyLevel? = nil
    @Published public var minimumLargeFileSizeMB: Int = 50
    
    // Cleanup & Visual Chart State
    @Published public var isShowingCleanupConfirmation: Bool = false
    @Published public var isCleaning: Bool = false
    @Published public var cleaningProgress: Double = 0.0
    @Published public var cleaningItemName: String = ""
    @Published public var latestCleanupReport: CleanupReport? = nil
    @Published public var isShowingCleanupReportSheet: Bool = false
    @Published public var isShowingSettingsSheet: Bool = false
    @Published public var isShowingPermissionSheet: Bool = false
    
    // AI Inspection State
    @Published public var inspectingItemID: UUID? = nil
    @Published public var activeAIInspectionItem: ScanItem? = nil
    
    // Persistent View UI State (No @State macros needed)
    @Published public var expandedCategories: Set<JunkCategory> = [
        .wallpapersAndMedia,
        .hiddenDotfiles,
        .orphanedLeftovers,
        .developerAndAICaches
    ]
    @Published public var expandedItemIDs: Set<UUID> = []
    @Published public var appLeftoversTab: Int = 0 {
        didSet { syncActiveSectionSelections() }
    }
    @Published public var appToConfirmUninstall: InstalledApp? = nil
    @Published public var systemJunkFilter: JunkCategory? = nil {
        didSet { syncActiveSectionSelections() }
    }
    @Published public var largeFilesTab: Int = 0 {
        didSet { syncActiveSectionSelections() }
    }
    @Published public var newWhitelistPath: String = ""
    
    /// Independent selection state per navigation tab so selecting items in one tab never leaks into another tab.
    private var selectedIDsBySection: [NavigationSection: Set<UUID>] = [:]
    
    // User Settings (stored via UserDefaults + @Published to avoid @AppStorage DynamicProperty conflicts in ObservableObject)
    @Published public var aiModeRaw: String {
        didSet { UserDefaults.standard.set(aiModeRaw, forKey: "com.mcclean.aiMode") }
    }
    @Published public var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: "com.mcclean.ollamaModel") }
    }
    @Published public var customAPIEndpoint: String {
        didSet { UserDefaults.standard.set(customAPIEndpoint, forKey: "com.mcclean.customEndpoint") }
    }
    @Published public var customAPIKey: String {
        didSet { UserDefaults.standard.set(customAPIKey, forKey: "com.mcclean.customAPIKey") }
    }
    @Published public var showMenuBarExtra: Bool {
        didSet { UserDefaults.standard.set(showMenuBarExtra, forKey: "com.mcclean.showMenuBarExtra") }
    }
    @Published public var lifetimeBytesFreed: Int64 {
        didSet { UserDefaults.standard.set(lifetimeBytesFreed, forKey: "com.mcclean.totalBytesFreedLifetime") }
    }
    @Published public var customWhitelist: [String] = []
    
    private let whitelistStorageKey = "com.mcclean.customWhitelist"
    private var scanTask: Task<Void, Never>?
    
    public init() {
        let defaults = UserDefaults.standard
        self.aiModeRaw = defaults.string(forKey: "com.mcclean.aiMode") ?? AIProviderMode.offlineHeuristic.rawValue
        self.ollamaModel = defaults.string(forKey: "com.mcclean.ollamaModel") ?? "llama3.2"
        self.customAPIEndpoint = defaults.string(forKey: "com.mcclean.customEndpoint") ?? "https://api.openai.com/v1/chat/completions"
        self.customAPIKey = defaults.string(forKey: "com.mcclean.customAPIKey") ?? ""
        if defaults.object(forKey: "com.mcclean.showMenuBarExtra") != nil {
            self.showMenuBarExtra = defaults.bool(forKey: "com.mcclean.showMenuBarExtra")
        } else {
            self.showMenuBarExtra = true
        }
        self.lifetimeBytesFreed = (defaults.object(forKey: "com.mcclean.totalBytesFreedLifetime") as? NSNumber)?.int64Value ?? 0
        self.customWhitelist = defaults.stringArray(forKey: whitelistStorageKey) ?? []
        self.diskUsage = DiskVolumeUsage.current()
    }
    
    public func selectSection(_ section: NavigationSection) {
        guard selectedSection != section else { return }
        selectedSection = section
        syncActiveSectionSelections()
    }
    
    public var aiMode: AIProviderMode {
        get { AIProviderMode(rawValue: aiModeRaw) ?? .offlineHeuristic }
        set { aiModeRaw = newValue.rawValue }
    }
    
    // MARK: - Computed Metrics & Active Tab Scoping
    
    /// Returns only the items belonging to the currently active navigation tab (and active sub-filter).
    public var activeSectionItems: [ScanItem] {
        switch selectedSection {
        case .smartScan:
            return filterItems(allScanItems)
        case .dotfiles:
            return dotfileItems
        case .appLeftovers:
            return appLeftoversTab == 0 ? orphanedAppItems : []
        case .systemAndDev:
            let base = systemAndDevItems
            if let cat = systemJunkFilter {
                return base.filter { $0.category == cat }
            }
            return base
        case .largeFiles:
            return largeFilesTab == 0 ? largeFileItems : []
        }
    }
    
    /// Returns only the selected items inside the currently active tab.
    public var selectedItemsForActiveSection: [ScanItem] {
        activeSectionItems.filter(\.isSelected)
    }
    
    public var totalDiscoverableBytes: Int64 {
        allScanItems.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedToCleanBytes: Int64 {
        selectedItemsForActiveSection.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var selectedItemsCount: Int {
        selectedItemsForActiveSection.count
    }
    
    public var safeDiscoverableBytes: Int64 {
        allScanItems.filter { $0.safetyLevel == .safe }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var reviewDiscoverableBytes: Int64 {
        allScanItems.filter { $0.safetyLevel == .review }.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var protectedItemsCount: Int {
        allScanItems.filter { $0.safetyLevel == .protected }.count
    }
    
    public func items(for category: JunkCategory) -> [ScanItem] {
        filterItems(allScanItems.filter { $0.category == category })
    }
    
    public func bytesForCategory(_ category: JunkCategory, onlySelected: Bool = false) -> Int64 {
        allScanItems
            .filter { $0.category == category && (!onlySelected || $0.isSelected) }
            .reduce(0) { $0 + $1.sizeBytes }
    }
    
    public func badgeCount(for section: NavigationSection) -> Int {
        switch section {
        case .smartScan:
            return allScanItems.count
        case .dotfiles:
            return dotfileItems.count
        case .appLeftovers:
            return orphanedAppItems.count
        case .systemAndDev:
            return systemAndDevItems.count
        case .largeFiles:
            return largeFileItems.count
        }
    }
    
    public func badgeBytes(for section: NavigationSection) -> Int64 {
        switch section {
        case .smartScan:
            return totalDiscoverableBytes
        case .dotfiles:
            return dotfileItems.reduce(0) { $0 + $1.sizeBytes }
        case .appLeftovers:
            return orphanedAppItems.reduce(0) { $0 + $1.sizeBytes }
        case .systemAndDev:
            return systemAndDevItems.reduce(0) { $0 + $1.sizeBytes }
        case .largeFiles:
            return largeFileItems.reduce(0) { $0 + $1.sizeBytes }
        }
    }
    
    public var dotfileItems: [ScanItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return filterItems(
            allScanItems.filter {
                $0.category == .hiddenDotfiles ||
                $0.url.lastPathComponent.hasPrefix(".") ||
                $0.url.path.hasPrefix(home + "/.")
            }
        )
    }
    
    public var orphanedAppItems: [ScanItem] {
        filterItems(allScanItems.filter { $0.category == .orphanedLeftovers || $0.isOrphaned })
    }
    
    public var systemAndDevItems: [ScanItem] {
        filterItems(
            allScanItems.filter {
                $0.category == .wallpapersAndMedia ||
                $0.category == .appAndBrowserCaches ||
                $0.category == .developerAndAICaches ||
                $0.category == .logsAndDiagnostics
            }
        )
    }
    
    public var largeFileItems: [ScanItem] {
        let minBytes = Int64(minimumLargeFileSizeMB) * 1024 * 1024
        return filterItems(
            allScanItems.filter {
                $0.category == .largeFilesAndDownloads && $0.sizeBytes >= minBytes
            }
        )
    }
    
    private func filterItems(_ source: [ScanItem]) -> [ScanItem] {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasQuery = !trimmedQuery.isEmpty
        let safetyFilter = selectedSafetyFilter
        
        guard hasQuery || safetyFilter != nil else {
            return source
        }
        
        return source.filter { item in
            if let safety = safetyFilter, item.safetyLevel != safety {
                return false
            }
            if hasQuery {
                let matchName = item.name.lowercased().contains(trimmedQuery)
                let matchPath = item.displayPath.lowercased().contains(trimmedQuery)
                let matchApp = item.associatedAppName?.lowercased().contains(trimmedQuery) ?? false
                let matchExp = item.explanation.lowercased().contains(trimmedQuery)
                return matchName || matchPath || matchApp || matchExp
            }
            return true
        }
    }
    
    // MARK: - Scanning Orchestration
    
    /// Checks if the user has completed initial permission setup; if not, presents the interactive Permission Onboarding Sheet
    /// so the user can grant folder access (or skip optional permissions like Photos/Desktop/Documents) without triggering OS blocks.
    public func requestOrStartSmartScan() {
        let pm = PermissionManager.shared
        if !pm.hasCompletedPermissionOnboarding && !pm.hasHomeBookmark {
            isShowingPermissionSheet = true
            return
        }
        startSmartScan()
    }
    
    public func startSmartScan() {
        scanTask?.cancel()
        isScanning = true
        scanProgress = 0.08
        scanStatusMessage = "Indexing installed applications & ~/Library..."
        diskUsage = DiskVolumeUsage.current()
        selectedIDsBySection.removeAll()
        
        let whitelistSet = Set(self.customWhitelist)
        
        scanTask = Task {
            // Step 1: Index installed applications & scan ~/Library for orphaned app leftovers
            let orphanResult = await Task.detached(priority: .userInitiated) {
                OrphanedAppsScanner.scan()
            }.value
            if Task.isCancelled { return }
            
            self.installedApps = orphanResult.installedApps
            self.allScanItems = Self.deduplicateAndSort(orphanResult.orphanedItems, whitelistSet: whitelistSet)
            self.syncActiveSectionSelections()
            self.scanProgress = 0.32
            self.scanStatusMessage = "Scanning hidden dotfiles (~/.*, ~/.config, .wallpaper)..."
            
            // Step 2: Scan hidden dotfiles in Home directory
            let dotfiles = await Task.detached(priority: .userInitiated) {
                DotfilesScanner.scan(installedAppNames: orphanResult.installedTokens)
            }.value
            if Task.isCancelled { return }
            
            self.allScanItems = Self.deduplicateAndSort(
                dotfiles + orphanResult.orphanedItems,
                whitelistSet: whitelistSet
            )
            self.syncActiveSectionSelections()
            self.scanProgress = 0.58
            self.scanStatusMessage = "Scanning macOS 4K Aerial wallpapers, caches & developer bloat..."
            
            // Step 3: Scan macOS Wallpapers, Caches, Logs & Developer junk
            let systemAndDev = await Task.detached(priority: .userInitiated) {
                SystemAndDevJunkScanner.scan()
            }.value
            if Task.isCancelled { return }
            
            self.allScanItems = Self.deduplicateAndSort(
                systemAndDev + dotfiles + orphanResult.orphanedItems,
                whitelistSet: whitelistSet
            )
            self.syncActiveSectionSelections()
            self.scanProgress = 0.82
            self.scanStatusMessage = "Scanning large files & building Space Lens tree..."
            
            // Step 4: Scan Large Files & Space Lens
            let (largeFiles, lensNodes) = await Task.detached(priority: .userInitiated) {
                let large = LargeFilesScanner.scanLargeFiles(minimumSizeBytes: 50 * 1024 * 1024)
                let nodes = LargeFilesScanner.buildSpaceLensNodes()
                return (large, nodes)
            }.value
            if Task.isCancelled { return }
            
            let merged = Self.deduplicateAndSort(
                systemAndDev + dotfiles + orphanResult.orphanedItems + largeFiles,
                whitelistSet: whitelistSet
            )
            
            self.allScanItems = merged
            self.syncActiveSectionSelections()
            self.spaceLensNodes = lensNodes
            self.diskUsage = DiskVolumeUsage.current()
            self.scanProgress = 1.0
            self.isScanning = false
            self.hasCompletedScan = true
            self.scanStatusMessage = "Found \(ByteCountFormatterHelper.format(bytes: self.totalDiscoverableBytes)) across \(merged.count) items"
        }
    }
    
    private static func deduplicateAndSort(_ items: [ScanItem], whitelistSet: Set<String>) -> [ScanItem] {
        var seenPaths: Set<String> = []
        var merged: [ScanItem] = []
        merged.reserveCapacity(items.count)
        
        for candidate in items {
            let path = candidate.displayPath
            guard !seenPaths.contains(path) else { continue }
            seenPaths.insert(path)
            
            var adjusted = candidate
            // Never auto-select items across tabs without explicit user choice
            adjusted.isSelected = false
            if KnownPathsDatabase.matchesCustomWhitelist(url: candidate.url, displayPath: path, whitelist: whitelistSet) {
                adjusted.isSelected = false
            }
            merged.append(adjusted)
        }
        merged.sort { $0.sizeBytes > $1.sizeBytes }
        return merged
    }
    
    // MARK: - Tab-Scoped Selection Controls
    
    /// Synchronizes `allScanItems[i].isSelected` to reflect ONLY the selections made in the currently active tab (`selectedSection`).
    private func syncActiveSectionSelections() {
        let activeIDs = selectedIDsBySection[selectedSection] ?? []
        let whitelistSet = Set(customWhitelist)
        for idx in allScanItems.indices {
            let item = allScanItems[idx]
            if item.safetyLevel == .protected || KnownPathsDatabase.matchesCustomWhitelist(url: item.url, displayPath: item.displayPath, whitelist: whitelistSet) {
                if allScanItems[idx].isSelected {
                    allScanItems[idx].isSelected = false
                }
            } else {
                let shouldBeSelected = activeIDs.contains(item.id)
                if allScanItems[idx].isSelected != shouldBeSelected {
                    allScanItems[idx].isSelected = shouldBeSelected
                }
            }
        }
    }
    
    public func toggleSelection(for itemID: UUID) {
        guard let idx = allScanItems.firstIndex(where: { $0.id == itemID }) else { return }
        guard allScanItems[idx].safetyLevel != .protected else { return }
        var activeSet = selectedIDsBySection[selectedSection] ?? []
        if activeSet.contains(itemID) {
            activeSet.remove(itemID)
        } else {
            activeSet.insert(itemID)
        }
        selectedIDsBySection[selectedSection] = activeSet
        syncActiveSectionSelections()
    }
    
    public func setCategorySelection(_ category: JunkCategory, isSelected: Bool) {
        let visibleIDs = Set(activeSectionItems.filter { $0.category == category && $0.safetyLevel != .protected }.map(\.id))
        var activeSet = selectedIDsBySection[selectedSection] ?? []
        if isSelected {
            activeSet.formUnion(visibleIDs)
        } else {
            activeSet.subtract(visibleIDs)
        }
        selectedIDsBySection[selectedSection] = activeSet
        syncActiveSectionSelections()
    }
    
    public func selectOnlySafeItems() {
        let safeIDsInCurrentTab = Set(activeSectionItems.filter { $0.safetyLevel == .safe }.map(\.id))
        selectedIDsBySection[selectedSection] = safeIDsInCurrentTab
        syncActiveSectionSelections()
    }
    
    public func deselectAllItems() {
        selectedIDsBySection[selectedSection] = []
        syncActiveSectionSelections()
    }
    
    // MARK: - Immediate Permanent Deletion & Visual Report
    
    public func executeImmediateCleanup() {
        let itemsToClean = selectedItemsForActiveSection
        guard !itemsToClean.isEmpty else { return }
        
        isShowingCleanupConfirmation = false
        isCleaning = true
        cleaningProgress = 0.0
        cleaningItemName = itemsToClean.first?.name ?? "Cleaning..."
        
        let whitelistSet = Set(customWhitelist)
        let vm = self
        
        Task {
            let report = await Task.detached(priority: .userInitiated) {
                CleanupService.cleanImmediately(
                    items: itemsToClean,
                    customWhitelistedPaths: whitelistSet,
                    progressHandler: { name, fraction in
                        Task { @MainActor in
                            vm.cleaningItemName = name
                            vm.cleaningProgress = fraction
                        }
                    }
                )
            }.value
            
            let deletedPaths = Set(report.deletedRecords.map(\.path))
            let removedIDs = Set(
                self.allScanItems
                    .filter { deletedPaths.contains($0.displayPath) || !FileManager.default.fileExists(atPath: $0.url.path) }
                    .map(\.id)
            )
            self.allScanItems.removeAll { removedIDs.contains($0.id) }
            for section in NavigationSection.allCases {
                self.selectedIDsBySection[section]?.subtract(removedIDs)
            }
            self.syncActiveSectionSelections()
            
            self.diskUsage = DiskVolumeUsage.current()
            self.lifetimeBytesFreed += report.totalBytesFreed
            self.latestCleanupReport = report
            self.isCleaning = false
            self.isShowingCleanupReportSheet = true
        }
    }
    
    // MARK: - Full Application Uninstaller
    
    public func toggleAppForUninstall(_ appID: UUID) {
        guard let idx = installedApps.firstIndex(where: { $0.id == appID }) else { return }
        installedApps[idx].isSelectedForUninstall.toggle()
    }
    
    public func uninstallAppImmediately(_ app: InstalledApp) {
        var targets: [ScanItem] = [
            ScanItem(
                url: app.bundleURL,
                name: "\(app.name).app",
                sizeBytes: app.appBundleSizeBytes,
                category: .orphanedLeftovers,
                safetyLevel: .review,
                explanation: "Application bundle for \(app.name)",
                associatedAppName: app.name,
                isOrphaned: false,
                isDirectory: true,
                isSelected: true
            )
        ]
        targets.append(contentsOf: app.relatedItems)
        
        isCleaning = true
        Task {
            let report = await Task.detached(priority: .userInitiated) {
                CleanupService.cleanImmediately(
                    items: targets,
                    allowProtectedOverride: true
                )
            }.value
            
            if !FileManager.default.fileExists(atPath: app.bundleURL.path) {
                self.installedApps.removeAll { $0.id == app.id }
            }
            self.diskUsage = DiskVolumeUsage.current()
            self.lifetimeBytesFreed += report.totalBytesFreed
            self.latestCleanupReport = report
            self.isCleaning = false
            self.isShowingCleanupReportSheet = true
        }
    }
    
    // MARK: - AI Folder Inspection & Finder Helpers
    
    public func inspectItemWithAI(_ item: ScanItem) {
        inspectingItemID = item.id
        let currentMode = aiMode
        let model = ollamaModel
        let endpoint = customAPIEndpoint
        let key = customAPIKey
        
        Task {
            let report = await FolderInspectorAI.inspect(
                item: item,
                mode: currentMode,
                ollamaModel: model,
                customEndpoint: endpoint,
                apiKey: key
            )
            if let idx = self.allScanItems.firstIndex(where: { $0.id == item.id }) {
                self.allScanItems[idx].aiAnalysis = report
                self.activeAIInspectionItem = self.allScanItems[idx]
            } else {
                var copy = item
                copy.aiAnalysis = report
                self.activeAIInspectionItem = copy
            }
            self.inspectingItemID = nil
        }
    }
    
    public func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    // MARK: - Whitelist Management
    
    public func addPathToWhitelist(_ path: String) {
        let normalized = KnownPathsDatabase.normalizeWhitelistPath(path)
        guard !normalized.isEmpty, !customWhitelist.contains(normalized) else { return }
        customWhitelist.append(normalized)
        UserDefaults.standard.set(customWhitelist, forKey: whitelistStorageKey)
        let whitelistSet = Set(customWhitelist)
        for idx in allScanItems.indices {
            if KnownPathsDatabase.matchesCustomWhitelist(
                url: allScanItems[idx].url,
                displayPath: allScanItems[idx].displayPath,
                whitelist: whitelistSet
            ) {
                allScanItems[idx].isSelected = false
            }
        }
    }
    
    public func removePathFromWhitelist(_ path: String) {
        customWhitelist.removeAll { $0 == path }
        UserDefaults.standard.set(customWhitelist, forKey: whitelistStorageKey)
    }
}
