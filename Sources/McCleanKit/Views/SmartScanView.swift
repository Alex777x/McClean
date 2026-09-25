import SwiftUI
import Charts

/// Primary 1-click Smart Scan view featuring Editorial Serif typography, flat 1px Bento grids,
/// sharp `+` / `−` accordion toggles, and native macOS 26 Liquid Glass filter strips.
public struct SmartScanView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        if !viewModel.hasCompletedScan && !viewModel.isScanning && viewModel.allScanItems.isEmpty {
            emptyHeroState
        } else if viewModel.isScanning && viewModel.allScanItems.isEmpty {
            scanningProgressState
        } else {
            resultsDashboard
        }
    }
    
    // MARK: - Editorial Minimalist Hero State
    
    private var emptyHeroState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Editorial Header Block
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("SYSTEM DIAGNOSTICS & STORAGE AUDIT")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(McCleanTheme.textMuted)
                        
                        KeycapBadge("⌘R")
                    }
                    
                    Text("Deep Storage Inspection for macOS.")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .tracking(-0.6)
                        .foregroundStyle(McCleanTheme.textPrimary)
                    
                    Text("Inspects hidden Unix dot-directories (~/.*, .wallpaper, ~/.config), 4K 240FPS macOS Aerial video stores, orphaned application containers, and local AI/developer build caches in a single pass.")
                        .font(.system(size: 13.5, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .frame(maxWidth: 640, alignment: .leading)
                }
                
                // Flat 2x2 Bento Feature Grid (1px solid border, 8px radius, zero shadow)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    bentoFeatureCard(
                        index: "01",
                        icon: "film.stack",
                        accent: McCleanTheme.color(for: .wallpapersAndMedia),
                        title: "macOS 4K Aerial Videos",
                        pathHint: "/Library/Application Support/com.apple.idleassetsd",
                        detail: "High-bitrate 240FPS video wallpapers and ~/.wallpaper stores that silently consume 5–50 GB."
                    )
                    
                    bentoFeatureCard(
                        index: "02",
                        icon: "eye.slash",
                        accent: McCleanTheme.color(for: .hiddenDotfiles),
                        title: "Hidden Unix Dotfiles",
                        pathHint: "~/.* • ~/.config • ~/.local/share",
                        detail: "Hidden dot-directories ignored by standard Mac cleaners, with built-in locks for .ssh and .gnupg."
                    )
                    
                    bentoFeatureCard(
                        index: "03",
                        icon: "archivebox",
                        accent: McCleanTheme.color(for: .orphanedLeftovers),
                        title: "Orphaned App Leftovers",
                        pathHint: "~/Library/Application Support & Caches",
                        detail: "Cross-references installed .app bundles against ~/Library to isolate remnants of deleted apps."
                    )
                    
                    bentoFeatureCard(
                        index: "04",
                        icon: "terminal",
                        accent: McCleanTheme.color(for: .developerAndAICaches),
                        title: "Developer & AI Model Caches",
                        pathHint: "DerivedData • npm • cargo • Ollama",
                        detail: "Reclaims gigabytes of intermediate build artifacts, package caches, and orphaned LLM weights."
                    )
                }
                
                // Primary Action Strip
                LiquidGlassGroup(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.requestOrStartSmartScan()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Run Deep Smart Scan")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(McCleanTheme.inkDark)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(McCleanTheme.textPrimary)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            viewModel.isShowingPermissionSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "shield")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Configure Folder Permissions")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(McCleanTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .liquidGlassRect(cornerRadius: 6, interactive: true)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
            }
            .padding(32)
            .frame(maxWidth: 880, alignment: .leading)
        }
    }
    
    private func bentoFeatureCard(
        index: String,
        icon: String,
        accent: Color,
        title: String,
        pathHint: String,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(index)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textMuted)
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(6)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(McCleanTheme.textPrimary)
                
                Text(pathHint)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
            
            Text(detail)
                .font(.system(size: 11.5))
                .lineSpacing(2)
                .foregroundStyle(McCleanTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 8)
    }
    
    // MARK: - Active Scanning State
    
    private var scanningProgressState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .controlSize(.regular)
            Text(viewModel.scanStatusMessage)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(McCleanTheme.textPrimary)
            Text("Calculating physical APFS allocated blocks without following symlinks")
                .font(.system(size: 11.5))
                .foregroundStyle(McCleanTheme.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results Dashboard
    
    private var resultsDashboard: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                overviewSummaryCard
                safetyFilterBar
                
                ForEach(JunkCategory.allCases) { category in
                    let categoryItems = viewModel.items(for: category)
                    if !categoryItems.isEmpty {
                        categoryCard(for: category, items: categoryItems)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private var overviewSummaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 24) {
                let activeCategories = JunkCategory.allCases.compactMap { cat -> (JunkCategory, Int64)? in
                    let bytes = viewModel.bytesForCategory(cat)
                    return bytes > 0 ? (cat, bytes) : nil
                }
                
                if !activeCategories.isEmpty {
                    ZStack {
                        Chart(activeCategories, id: \.0.id) { pair in
                            SectorMark(
                                angle: .value("Size", pair.1),
                                innerRadius: .ratio(0.72),
                                angularInset: 1.5
                            )
                            .cornerRadius(2)
                            .foregroundStyle(McCleanTheme.color(for: pair.0))
                        }
                        .frame(width: 116, height: 116)
                        
                        VStack(spacing: 1) {
                            Text(ByteCountFormatterHelper.format(bytes: viewModel.totalDiscoverableBytes))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(McCleanTheme.textPrimary)
                            Text("TOTAL")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(McCleanTheme.textMuted)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Storage Audit Summary")
                            .font(.system(size: 18, weight: .regular, design: .serif))
                            .tracking(-0.3)
                            .foregroundStyle(McCleanTheme.textPrimary)
                        Text("Nothing is selected automatically without your consent. Check specific items or click 'Select Only Safe' for this tab.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(McCleanTheme.textSecondary)
                    }
                    
                    HStack(spacing: 10) {
                        summaryMetricTile(
                            title: "SAFE CACHE",
                            bytes: viewModel.safeDiscoverableBytes,
                            color: McCleanTheme.color(for: SafetyLevel.safe)
                        )
                        
                        summaryMetricTile(
                            title: "REVIEW NEEDED",
                            bytes: viewModel.reviewDiscoverableBytes,
                            color: McCleanTheme.color(for: SafetyLevel.review)
                        )
                        
                        summaryMetricTile(
                            title: "SELECTED IN TAB",
                            bytes: viewModel.selectedToCleanBytes,
                            color: McCleanTheme.textPrimary
                        )
                    }
                }
            }
            
            // Minimalist Proportional Bar
            let totalBytes = max(1, viewModel.totalDiscoverableBytes)
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(JunkCategory.allCases) { cat in
                        let catBytes = viewModel.bytesForCategory(cat)
                        if catBytes > 0 {
                            let ratio = Double(catBytes) / Double(totalBytes)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(McCleanTheme.color(for: cat))
                                .frame(width: max(6, geo.size.width * ratio))
                        }
                    }
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .glassCard(cornerRadius: 8)
    }
    
    private func summaryMetricTile(title: String, bytes: Int64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(McCleanTheme.textMuted)
            }
            Text(ByteCountFormatterHelper.format(bytes: bytes))
                .font(.system(size: 14.5, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(McCleanTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
        )
    }
    
    private var safetyFilterBar: some View {
        LiquidGlassGroup(spacing: 8) {
            HStack(spacing: 6) {
                safetyFilterPill(title: "All (\(viewModel.allScanItems.count))", level: nil)
                safetyFilterPill(title: "Safe", level: .safe)
                safetyFilterPill(title: "Review", level: .review)
                safetyFilterPill(title: "Protected (\(viewModel.protectedItemsCount))", level: .protected)
                
                Spacer()
                
                Button {
                    viewModel.selectOnlySafeItems()
                } label: {
                    Text("Select Only Safe")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(McCleanTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .liquidGlassCapsule(interactive: true)
                }
                .buttonStyle(.plain)
                
                Button {
                    viewModel.deselectAllItems()
                } label: {
                    Text("Clear Selection")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .liquidGlassCapsule(interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func safetyFilterPill(title: String, level: SafetyLevel?) -> some View {
        let isSelected = (viewModel.selectedSafetyFilter == level)
        return Button {
            viewModel.selectedSafetyFilter = level
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(
                    isSelected ? McCleanTheme.textPrimary : McCleanTheme.cardBackground,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? McCleanTheme.textPrimary : McCleanTheme.subtleBorder, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? McCleanTheme.inkDark : McCleanTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
    
    private func categoryCard(for category: JunkCategory, items: [ScanItem]) -> some View {
        let isExpanded = viewModel.expandedCategories.contains(category)
        let catColor = McCleanTheme.color(for: category)
        let totalCategoryBytes = items.reduce(0) { $0 + $1.sizeBytes }
        let selectedCategoryBytes = items.filter(\.isSelected).reduce(0) { $0 + $1.sizeBytes }
        let selectableItems = items.filter { $0.safetyLevel != .protected }
        let allSelected = !selectableItems.isEmpty && selectableItems.allSatisfy(\.isSelected)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                GlassCheckbox(isChecked: allSelected, accentColor: catColor) {
                    viewModel.setCategorySelection(category, isSelected: !allSelected)
                }
                
                Image(systemName: category.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(catColor)
                    .frame(width: 28, height: 28)
                    .background(catColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(category.rawValue)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("\(items.count)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(McCleanTheme.textMuted)
                    }
                    Text(category.description)
                        .font(.system(size: 11))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteCountFormatterHelper.format(bytes: totalCategoryBytes))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(McCleanTheme.textPrimary)
                    if selectedCategoryBytes > 0 {
                        Text("\(ByteCountFormatterHelper.format(bytes: selectedCategoryBytes)) selected")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(McCleanTheme.accentEmerald)
                    }
                }
                
                // Sharp + / − accordion toggle icon per minimalist-ui specification
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        if isExpanded {
                            viewModel.expandedCategories.remove(category)
                        } else {
                            viewModel.expandedCategories.insert(category)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "minus" : "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .frame(width: 26, height: 26)
                        .liquidGlassRect(cornerRadius: 6, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "Collapse \(category.rawValue)" : "Expand \(category.rawValue)")
            }
            
            if isExpanded {
                Rectangle()
                    .fill(McCleanTheme.subtleBorder)
                    .frame(height: 1)
                
                LazyVStack(spacing: 6) {
                    ForEach(items) { item in
                        ScanItemRowView(item: item, viewModel: viewModel)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 8)
    }
}
