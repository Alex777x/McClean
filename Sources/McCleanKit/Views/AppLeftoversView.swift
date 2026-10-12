import SwiftUI
import AppKit

/// Module for Complete Application Uninstallation and Orphaned Residual Data Cleanup.
public struct AppLeftoversView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var orphanItems: [ScanItem] {
        viewModel.orphanedAppItems
    }
    
    private var totalOrphanBytes: Int64 {
        orphanItems.reduce(0) { $0 + $1.sizeBytes }
    }
    
    private var totalInstalledAppsBytes: Int64 {
        viewModel.installedApps.reduce(0) { $0 + $1.totalFootprintBytes }
    }
    
    public var body: some View {
        let accent = McCleanTheme.color(for: .appLeftovers)
        
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Editorial Header Card
                headerCard(accent: accent)
                
                // Liquid Glass Mode Switcher Tabs
                LiquidGlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        tabPill(
                            title: "Installed Applications (\(viewModel.installedApps.count))",
                            tag: 0
                        )
                        tabPill(
                            title: "Orphaned Leftovers (\(orphanItems.count))",
                            tag: 1
                        )
                        Spacer()
                        
                        // Fast Refresh / Index Button
                        Button {
                            viewModel.refreshInstalledApps()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11, weight: .semibold))
                                    .rotationEffect(.degrees(viewModel.isScanningApps ? 360 : 0))
                                    .animation(
                                        viewModel.isScanningApps
                                            ? .linear(duration: 1).repeatForever(autoreverses: false)
                                            : .default,
                                        value: viewModel.isScanningApps
                                    )
                                Text(viewModel.isScanningApps ? "Scanning..." : "Refresh Apps")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(McCleanTheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5.5)
                            .liquidGlassRect(cornerRadius: 6, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isScanningApps || viewModel.isScanning)
                    }
                }
                
                if viewModel.appLeftoversTab == 0 {
                    uninstallerModuleSection
                } else {
                    orphanedListSection
                }
            }
            .padding(24)
        }
        .onAppear {
            viewModel.scanInstalledAppsIfNeeded()
        }
        .sheet(item: $viewModel.appToConfirmUninstall) { app in
            uninstallConfirmationModal(for: app)
        }
        .sheet(item: $viewModel.batchUninstallWrapper) { wrapper in
            batchUninstallConfirmationModal(for: wrapper.apps)
        }
    }
    
    // MARK: - Header
    
    private func headerCard(accent: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("APPLICATIONS & RESIDUAL STORAGE")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(accent)
                
                Text("Application Uninstaller & Leftovers.")
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(McCleanTheme.textPrimary)
                
                Text("Dragging apps to Trash leaves gigabytes trapped in ~/Library/Application Support, Caches, and Containers. Completely delete active apps or clean abandoned leftover baggage.")
                    .font(.system(size: 12))
                    .foregroundStyle(McCleanTheme.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(viewModel.appLeftoversTab == 0 ? "TOTAL APPS FOOTPRINT" : "ORPHANED BAGGAGE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(McCleanTheme.textMuted)
                Text(ByteCountFormatterHelper.format(bytes: viewModel.appLeftoversTab == 0 ? totalInstalledAppsBytes : totalOrphanBytes))
                    .font(.system(size: 22, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(McCleanTheme.textPrimary)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: 8)
    }
    
    private func tabPill(title: String, tag: Int) -> some View {
        let isSelected = (viewModel.appLeftoversTab == tag)
        return Button {
            viewModel.appLeftoversTab = tag
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? McCleanTheme.textPrimary : McCleanTheme.cardBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? McCleanTheme.textPrimary : McCleanTheme.subtleBorder, lineWidth: 1))
                .foregroundStyle(isSelected ? McCleanTheme.inkDark : McCleanTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 0: Complete App Uninstaller
    
    private var filteredInstalledApps: [InstalledApp] {
        var apps = viewModel.installedApps
        
        // Scope filter
        switch viewModel.appScopeFilter {
        case .all:
            break
        case .userOnly:
            apps = apps.filter { !$0.isSystemApp }
        case .withLibraryOnly:
            apps = apps.filter { !$0.relatedItems.isEmpty }
        }
        
        // Search filter
        let q = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            apps = apps.filter {
                $0.name.lowercased().contains(q) ||
                $0.bundleIdentifier.lowercased().contains(q) ||
                $0.bundleURL.path.lowercased().contains(q)
            }
        }
        
        // Sort
        switch viewModel.appSortOption {
        case .largestTotal:
            apps.sort { $0.totalFootprintBytes > $1.totalFootprintBytes }
        case .nameAZ:
            apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .largestLibrary:
            apps.sort { $0.relatedSupportBytes > $1.relatedSupportBytes }
        case .largestApp:
            apps.sort { $0.appBundleSizeBytes > $1.appBundleSizeBytes }
        }
        
        return apps
    }
    
    private var uninstallerModuleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Filter & Sort Toolbar
            controlsToolbar
            
            // Batch Selection Action Card (if any apps selected)
            if !viewModel.selectedAppsForUninstall.isEmpty {
                batchSelectionBar
            }
            
            // App List or Loading State
            if viewModel.isScanningApps && viewModel.installedApps.isEmpty {
                loadingAppsCard
            } else if filteredInstalledApps.isEmpty {
                emptyCard(
                    icon: "app.dashed",
                    title: viewModel.installedApps.isEmpty ? "No Applications Indexed Yet" : "No Matching Applications",
                    subtitle: viewModel.installedApps.isEmpty
                        ? "Click 'Refresh Apps' or run Smart Scan to index installed applications."
                        : "Try adjusting your search query or scope filter."
                )
            } else {
                ForEach(filteredInstalledApps) { app in
                    installedAppCard(app)
                }
            }
        }
    }
    
    private var controlsToolbar: some View {
        HStack(spacing: 10) {
            // Scope Filter Menu / Pills
            ForEach(AppScopeFilter.allCases) { scope in
                let isSelected = (viewModel.appScopeFilter == scope)
                Button {
                    viewModel.appScopeFilter = scope
                } label: {
                    Text(scope.rawValue)
                        .font(.system(size: 10.5, weight: isSelected ? .semibold : .regular))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .background(isSelected ? McCleanTheme.textPrimary.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(isSelected ? McCleanTheme.textPrimary.opacity(0.20) : McCleanTheme.subtleBorder, lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? McCleanTheme.textPrimary : McCleanTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            // Sort Picker Menu
            Menu {
                ForEach(AppSortOption.allCases) { opt in
                    Button {
                        viewModel.appSortOption = opt
                    } label: {
                        HStack {
                            Text(opt.rawValue)
                            if viewModel.appSortOption == opt {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 10))
                    Text(viewModel.appSortOption.rawValue)
                        .font(.system(size: 10.5, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(McCleanTheme.cardBackground, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1))
                .foregroundStyle(McCleanTheme.textSecondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            // Select All User Apps Toggle
            Button {
                if viewModel.selectedAppsForUninstall.isEmpty {
                    viewModel.selectAllUserAppsForUninstall()
                } else {
                    viewModel.deselectAllAppsForUninstall()
                }
            } label: {
                Text(viewModel.selectedAppsForUninstall.isEmpty ? "Select All" : "Deselect All")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(McCleanTheme.accentAmber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(McCleanTheme.accentAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }
    
    private var batchSelectionBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(McCleanTheme.accentCoral)
            
            VStack(alignment: .leading, spacing: 1) {
                Text("\(viewModel.selectedAppsForUninstall.count) Applications Selected for Complete Removal")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(McCleanTheme.textPrimary)
                Text("Total storage to reclaim: \(ByteCountFormatterHelper.format(bytes: viewModel.selectedAppsTotalBytes)) (.app binaries + associated ~/Library baggage)")
                    .font(.system(size: 10.5))
                    .foregroundStyle(McCleanTheme.textSecondary)
            }
            
            Spacer()
            
            Button {
                viewModel.deselectAllAppsForUninstall()
            } label: {
                Text("Cancel")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(McCleanTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .liquidGlassRect(cornerRadius: 6, interactive: true)
            }
            .buttonStyle(.plain)
            
            Button {
                let targets = viewModel.selectedAppsForUninstall
                guard !targets.isEmpty else { return }
                viewModel.appsToConfirmBatchUninstall = targets
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("Uninstall Selected (\(ByteCountFormatterHelper.format(bytes: viewModel.selectedAppsTotalBytes)))")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .foregroundStyle(McCleanTheme.inkDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 6.5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(McCleanTheme.accentCoral)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(McCleanTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(McCleanTheme.accentCoral.opacity(0.35), lineWidth: 1)
        )
    }
    
    private func installedAppCard(_ app: InstalledApp) -> some View {
        let isExpanded = viewModel.expandedAppPaths.contains(app.bundleURL.path)
        let isChecked = viewModel.selectedAppBundlePaths.contains(app.bundleURL.path)
        
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // Batch Checkbox (Disabled for macOS System apps and Running apps)
                if !app.isSystemApp && !app.isRunning {
                    GlassCheckbox(isChecked: isChecked) {
                        viewModel.toggleAppSelection(for: app)
                    }
                } else if app.isSystemApp {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(McCleanTheme.textMuted)
                        .frame(width: 18, height: 18)
                        .help("macOS System Application — Protected by System Integrity Protection (SIP)")
                } else {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(McCleanTheme.accentAmber)
                        .frame(width: 18, height: 18)
                        .help("Application is currently running. Quit \(app.name) before uninstalling.")
                }
                
                // App Retina Icon
                Image(nsImage: AppIconCache.icon(for: app.bundleURL))
                    .resizable()
                    .frame(width: 38, height: 38)
                
                // Name & Metadata
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("v\(app.version)")
                            .font(.system(size: 9.5, weight: .medium))
                            .monospacedDigit()
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(McCleanTheme.textMuted)
                        
                        Text(app.installLocationLabel)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(McCleanTheme.textMuted)
                        
                        if app.isSystemApp {
                            Text("SYSTEM PROTECTED")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(McCleanTheme.accentCyan.opacity(0.12), in: Capsule())
                                .foregroundStyle(McCleanTheme.accentCyan)
                        } else if app.isRunning {
                            Text("RUNNING")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(McCleanTheme.accentAmber.opacity(0.15), in: Capsule())
                                .foregroundStyle(McCleanTheme.accentAmber)
                        }
                    }
                    
                    Text(app.bundleIdentifier)
                        .font(.system(size: 10))
                        .foregroundStyle(McCleanTheme.textMuted)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("Bundle: \(app.formattedAppSize)")
                            .font(.system(size: 10.5))
                            .monospacedDigit()
                            .foregroundStyle(McCleanTheme.textSecondary)
                        
                        if !app.relatedItems.isEmpty {
                            Text("•")
                                .foregroundStyle(McCleanTheme.textMuted)
                            Text("Library: \(app.formattedSupportSize) (\(app.relatedItems.count) folders)")
                                .font(.system(size: 10.5, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(McCleanTheme.accentAmber)
                        }
                    }
                }
                
                Spacer()
                
                // Total Footprint Size
                VStack(alignment: .trailing, spacing: 2) {
                    Text(app.formattedTotalSize)
                        .font(.system(size: 14.5, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(McCleanTheme.textPrimary)
                    
                    if !app.relatedItems.isEmpty {
                        Button {
                            if isExpanded {
                                viewModel.expandedAppPaths.remove(app.bundleURL.path)
                            } else {
                                viewModel.expandedAppPaths.insert(app.bundleURL.path)
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text(isExpanded ? "Hide Folders" : "Inspect Folders")
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(McCleanTheme.accentAmber)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Reveal in Finder Button
                Button {
                    NSWorkspace.shared.selectFile(app.bundleURL.path, inFileViewerRootedAtPath: "")
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11))
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .frame(width: 26, height: 26)
                        .liquidGlassRect(cornerRadius: 6, interactive: true)
                }
                .buttonStyle(.plain)
                .help("Reveal \(app.name).app in Finder")
                
                // Uninstall Button
                if app.isSystemApp {
                    Text("Protected")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(McCleanTheme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                } else if app.isRunning {
                    Button {
                    } label: {
                        Text("Quit to Uninstall")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(McCleanTheme.accentAmber)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(McCleanTheme.accentAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .help("Quit \(app.name) before uninstalling")
                } else {
                    Button {
                        viewModel.appToConfirmUninstall = app
                    } label: {
                        Text("Uninstall")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(McCleanTheme.accentCoral)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .liquidGlassRect(cornerRadius: 6, tint: McCleanTheme.accentCoral.opacity(0.18), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .help("Completely uninstall \(app.name) and all associated ~/Library folders")
                }
            }
            .padding(14)
            
            // Expanded Associated ~/Library Folders
            if isExpanded && !app.relatedItems.isEmpty {
                Rectangle()
                    .fill(McCleanTheme.subtleBorder)
                    .frame(height: 1)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("ASSOCIATED SUPPORT DIRECTORIES (\(app.relatedItems.count))")
                        .font(.system(size: 8.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(McCleanTheme.textMuted)
                        .padding(.bottom, 2)
                    
                    ForEach(app.relatedItems) { item in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(McCleanTheme.accentAmber)
                            
                            Text(item.displayPath)
                                .font(.system(size: 10.5))
                                .foregroundStyle(McCleanTheme.textSecondary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(item.formattedSize)
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(McCleanTheme.textPrimary)
                            
                            Button {
                                NSWorkspace.shared.selectFile(item.url.path, inFileViewerRootedAtPath: "")
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundStyle(McCleanTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .help("Show folder in Finder")
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(Color.black.opacity(0.02), in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(McCleanTheme.elevatedCardBackground.opacity(0.6))
            }
        }
        .glassCard(cornerRadius: 8)
    }
    
    private var loadingAppsCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Indexing installed applications in /Applications & cross-referencing ~/Library...")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(McCleanTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .glassCard(cornerRadius: 8)
    }
    
    // MARK: - Tab 1: Orphaned Leftovers
    
    private var orphanedListSection: some View {
        Group {
            if orphanItems.isEmpty {
                emptyCard(
                    icon: "archivebox",
                    title: viewModel.hasCompletedScan ? "No Orphaned App Leftovers Found" : "Run Smart Scan First",
                    subtitle: viewModel.hasCompletedScan
                        ? "Your ~/Library has no unmatched folders from uninstalled applications."
                        : "Click 'Smart Scan' in the top bar to cross-reference /Applications against ~/Library."
                )
            } else {
                ForEach(orphanItems) { item in
                    ScanItemRowView(item: item, viewModel: viewModel)
                }
            }
        }
    }
    
    private func emptyCard(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(McCleanTheme.textMuted)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(McCleanTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundStyle(McCleanTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .glassCard(cornerRadius: 8)
    }
    
    // MARK: - Uninstall Confirmation Modal
    
    private func uninstallConfirmationModal(for app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: AppIconCache.icon(for: app.bundleURL))
                    .resizable()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Completely Uninstall \(app.name)?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("Permanently deletes \(app.name).app and all \(app.relatedItems.count) associated ~/Library folders (\(app.formattedTotalSize) total).")
                        .font(.system(size: 12))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Image(systemName: "app").foregroundStyle(McCleanTheme.textPrimary)
                        Text(app.bundleURL.path).font(.system(size: 11)).foregroundStyle(McCleanTheme.textPrimary)
                        Spacer()
                        Text(app.formattedAppSize).font(.system(size: 11, weight: .bold)).monospacedDigit().foregroundStyle(McCleanTheme.textPrimary)
                    }
                    .padding(8)
                    .glassCard(cornerRadius: 6)
                    
                    ForEach(app.relatedItems) { item in
                        HStack {
                            Image(systemName: "folder").foregroundStyle(McCleanTheme.accentAmber)
                            Text(item.displayPath).font(.system(size: 11)).foregroundStyle(McCleanTheme.textSecondary)
                            Spacer()
                            Text(item.formattedSize).font(.system(size: 11, weight: .bold)).monospacedDigit().foregroundStyle(McCleanTheme.textPrimary)
                        }
                        .padding(8)
                        .glassCard(cornerRadius: 6)
                    }
                }
            }
            .frame(maxHeight: 210)
            
            HStack {
                Button {
                    viewModel.appToConfirmUninstall = nil
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlassRect(cornerRadius: 6, interactive: true)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    let target = app
                    viewModel.appToConfirmUninstall = nil
                    viewModel.uninstallAppImmediately(target)
                } label: {
                    Text("Permanently Uninstall (\(app.formattedTotalSize))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(McCleanTheme.inkDark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(McCleanTheme.accentCoral)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 540)
        .background(McCleanTheme.windowBackground)
    }
    
    // MARK: - Batch Uninstall Confirmation Modal
    
    private func batchUninstallConfirmationModal(for apps: [InstalledApp]) -> some View {
        let totalBytes = apps.reduce(0) { $0 + $1.totalFootprintBytes }
        let totalLibraryFolders = apps.reduce(0) { $0 + $1.relatedItems.count }
        
        return VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(McCleanTheme.accentCoral)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Permanently Uninstall \(apps.count) Applications?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("Permanently deletes \(apps.count) application bundles and all \(totalLibraryFolders) associated ~/Library support folders (\(ByteCountFormatterHelper.format(bytes: totalBytes)) total).")
                        .font(.system(size: 12))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(McCleanTheme.accentAmber)
                    Text("Permanent Deletion Warning")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                }
                Text("These applications and their preferences, caches, and application support files will be permanently erased without moving to Trash. This action cannot be undone.")
                    .font(.system(size: 11))
                    .foregroundStyle(McCleanTheme.textSecondary)
            }
            .padding(12)
            .background(McCleanTheme.accentAmber.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(McCleanTheme.accentAmber.opacity(0.25), lineWidth: 1)
            )
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(apps) { app in
                        HStack(spacing: 10) {
                            Image(nsImage: AppIconCache.icon(for: app.bundleURL))
                                .resizable()
                                .frame(width: 24, height: 24)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(app.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(McCleanTheme.textPrimary)
                                Text("\(app.formattedAppSize) • \(app.relatedItems.count) library folders (\(app.formattedSupportSize))")
                                    .font(.system(size: 10))
                                    .monospacedDigit()
                                    .foregroundStyle(McCleanTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Text(app.formattedTotalSize)
                                .font(.system(size: 11.5, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(McCleanTheme.textPrimary)
                        }
                        .padding(8)
                        .glassCard(cornerRadius: 6)
                    }
                }
            }
            .frame(maxHeight: 220)
            
            HStack {
                Button {
                    viewModel.batchUninstallWrapper = nil
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlassRect(cornerRadius: 6, interactive: true)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    let targets = apps
                    viewModel.batchUninstallWrapper = nil
                    viewModel.uninstallBatchAppsImmediately(targets)
                } label: {
                    Text("Permanently Uninstall All (\(ByteCountFormatterHelper.format(bytes: totalBytes)))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(McCleanTheme.inkDark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(McCleanTheme.accentCoral)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 560)
        .background(McCleanTheme.windowBackground)
    }
}
