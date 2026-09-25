import SwiftUI

/// Module for Orphaned Application Leftovers and Complete App Uninstaller with Utilitarian Editorial Minimalism.
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
    
    public var body: some View {
        let accent = McCleanTheme.color(for: .appLeftovers)
        
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Editorial Header Card
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("APPLICATION CONTAINERS • ~/LIBRARY")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(accent)
                        
                        Text("Orphaned App Leftovers & Uninstaller.")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .tracking(-0.4)
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("Dragging an app to Trash leaves gigabytes behind in ~/Library/Application Support, Caches, and Saved State. Clean orphaned remnants or completely uninstall active apps.")
                            .font(.system(size: 12))
                            .foregroundStyle(McCleanTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ORPHANED BAGGAGE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(McCleanTheme.textMuted)
                        Text(ByteCountFormatterHelper.format(bytes: totalOrphanBytes))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(McCleanTheme.textPrimary)
                    }
                }
                .padding(20)
                .glassCard(cornerRadius: 8)
                
                // Liquid Glass Mode Switcher Strip
                LiquidGlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        tabPill(
                            title: "Orphaned Leftovers (\(orphanItems.count))",
                            tag: 0
                        )
                        tabPill(
                            title: "Complete App Uninstaller (\(viewModel.installedApps.count))",
                            tag: 1
                        )
                        Spacer()
                    }
                }
                
                if viewModel.appLeftoversTab == 0 {
                    orphanedListSection
                } else {
                    uninstallerListSection
                }
            }
            .padding(24)
        }
        .sheet(item: $viewModel.appToConfirmUninstall) { app in
            uninstallConfirmationModal(for: app)
                .preferredColorScheme(.dark)
        }
    }
    
    private func tabPill(title: String, tag: Int) -> some View {
        let isSelected = (viewModel.appLeftoversTab == tag)
        return Button {
            viewModel.appLeftoversTab = tag
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? McCleanTheme.textPrimary : McCleanTheme.cardBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? McCleanTheme.textPrimary : McCleanTheme.subtleBorder, lineWidth: 1))
                .foregroundStyle(isSelected ? McCleanTheme.inkDark : McCleanTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 0: Orphaned Leftovers
    
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
    
    // MARK: - Tab 1: Full App Uninstaller
    
    private var filteredInstalledApps: [InstalledApp] {
        let q = viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return viewModel.installedApps }
        return viewModel.installedApps.filter {
            $0.name.lowercased().contains(q) || $0.bundleIdentifier.lowercased().contains(q)
        }
    }
    
    private var uninstallerListSection: some View {
        Group {
            if filteredInstalledApps.isEmpty {
                emptyCard(
                    icon: "app.dashed",
                    title: viewModel.hasCompletedScan ? "No Matching Applications" : "Run Smart Scan First",
                    subtitle: "Run Smart Scan to index all installed applications and their associated ~/Library data."
                )
            } else {
                ForEach(filteredInstalledApps) { app in
                    installedAppRow(app)
                }
            }
        }
    }
    
    private func installedAppRow(_ app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(nsImage: AppIconCache.icon(for: app.bundleURL))
                    .resizable()
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                        Text("v\(app.version)")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(McCleanTheme.textMuted)
                    }
                    
                    Text(app.bundleIdentifier)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textMuted)
                    
                    HStack(spacing: 10) {
                        Text("Bundle: \(app.formattedAppSize)")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(McCleanTheme.textSecondary)
                        Text("•")
                            .foregroundStyle(McCleanTheme.textMuted)
                        Text("Library: \(app.formattedSupportSize) (\(app.relatedItems.count) folders)")
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(McCleanTheme.accentAmber)
                    }
                }
                
                Spacer()
                
                Text(app.formattedTotalSize)
                    .font(.system(size: 14.5, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(McCleanTheme.textPrimary)
                
                Button {
                    viewModel.appToConfirmUninstall = app
                } label: {
                    Text("Uninstall")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(McCleanTheme.accentCoral)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlassRect(cornerRadius: 6, tint: McCleanTheme.accentCoral.opacity(0.20), interactive: true)
                }
                .buttonStyle(.plain)
            }
            
            if !app.relatedItems.isEmpty {
                HStack(spacing: 6) {
                    ForEach(app.relatedItems.prefix(4)) { rel in
                        Text("\(rel.name) (\(rel.formattedSize))")
                            .font(.system(size: 9.5, design: .monospaced))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(McCleanTheme.textMuted)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 50)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 8)
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
    
    private func uninstallConfirmationModal(for app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: AppIconCache.icon(for: app.bundleURL))
                    .resizable()
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Completely Uninstall \(app.name)?")
                        .font(.system(size: 20, weight: .regular, design: .serif))
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
                        Text(app.bundleURL.path).font(.system(size: 11, design: .monospaced)).foregroundStyle(McCleanTheme.textPrimary)
                        Spacer()
                        Text(app.formattedAppSize).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(McCleanTheme.textPrimary)
                    }
                    .padding(8)
                    .glassCard(cornerRadius: 6)
                    
                    ForEach(app.relatedItems) { item in
                        HStack {
                            Image(systemName: "folder").foregroundStyle(McCleanTheme.accentAmber)
                            Text(item.displayPath).font(.system(size: 11, design: .monospaced)).foregroundStyle(McCleanTheme.textSecondary)
                            Spacer()
                            Text(item.formattedSize).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(McCleanTheme.textPrimary)
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
                                .fill(McCleanTheme.textPrimary)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 540)
        .background(McCleanTheme.windowBackground)
    }
}
