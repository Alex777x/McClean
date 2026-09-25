import SwiftUI

/// Module for locating heavy files (.dmg, .pkg, archives, videos) and visually exploring Home directory sizes (Space Lens).
public struct LargeFilesView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var largeItems: [ScanItem] {
        viewModel.largeFileItems
    }
    
    private var totalLargeBytes: Int64 {
        largeItems.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var body: some View {
        let accent = McCleanTheme.color(for: .largeFiles)
        
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Editorial Header Card
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("DISK ARCHIVES & SPACE LENS • 50MB+ FILES")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(accent)
                        
                        Text("Large Files & Space Lens Explorer.")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .tracking(-0.4)
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("Locate forgotten disk images (.dmg, .pkg, .iso), heavy downloads, and visually inspect the largest directories in your Home folder.")
                            .font(.system(size: 12))
                            .foregroundStyle(McCleanTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("LARGE FILES FOUND")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(McCleanTheme.textMuted)
                        Text(ByteCountFormatterHelper.format(bytes: totalLargeBytes))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(McCleanTheme.textPrimary)
                    }
                }
                .padding(20)
                .glassCard(cornerRadius: 8)
                
                // Controls Bar
                LiquidGlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        modePill(title: "Large Files (\(largeItems.count))", tag: 0)
                        modePill(title: "Space Lens Map (\(viewModel.spaceLensNodes.count))", tag: 1)
                        
                        Spacer()
                        
                        if viewModel.largeFilesTab == 0 {
                            HStack(spacing: 5) {
                                ForEach([50, 250, 500, 1024], id: \.self) { sizeMB in
                                    sizeThresholdPill(sizeMB: sizeMB)
                                }
                            }
                        }
                    }
                }
                
                if !PermissionManager.shared.hasHomeBookmark && PermissionManager.shared.downloadsStatus != .granted {
                    HStack(spacing: 12) {
                        Image(systemName: "shield")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(McCleanTheme.accentCyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Optional User Folders Skipped (Downloads, Desktop, Documents)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(McCleanTheme.textPrimary)
                            Text("McClean works without extra permissions. Grant access anytime if you also want to scan Downloads, Desktop, and Documents.")
                                .font(.system(size: 11))
                                .foregroundStyle(McCleanTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            viewModel.isShowingPermissionSheet = true
                        } label: {
                            Text("Grant Access...")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(McCleanTheme.inkDark)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(McCleanTheme.textPrimary)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 8)
                }
                
                if viewModel.largeFilesTab == 0 {
                    largeFilesSection
                } else {
                    spaceLensSection
                }
            }
            .padding(24)
        }
    }
    
    private func modePill(title: String, tag: Int) -> some View {
        let isSelected = (viewModel.largeFilesTab == tag)
        return Button {
            viewModel.largeFilesTab = tag
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
    
    private func sizeThresholdPill(sizeMB: Int) -> some View {
        let isSelected = (viewModel.minimumLargeFileSizeMB == sizeMB)
        let label = sizeMB >= 1024 ? "1 GB+" : "\(sizeMB) MB+"
        return Button {
            viewModel.minimumLargeFileSizeMB = sizeMB
        } label: {
            Text(label)
                .font(.system(size: 10.5, weight: isSelected ? .bold : .regular, design: .monospaced))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isSelected ? McCleanTheme.textPrimary : McCleanTheme.cardBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? McCleanTheme.textPrimary : McCleanTheme.subtleBorder, lineWidth: 1))
                .foregroundStyle(isSelected ? McCleanTheme.inkDark : McCleanTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
    
    private var largeFilesSection: some View {
        Group {
            if largeItems.isEmpty {
                emptyCard(
                    icon: "doc.zipper",
                    title: viewModel.hasCompletedScan ? "No Large Files Above \(viewModel.minimumLargeFileSizeMB) MB" : "Run Smart Scan First",
                    subtitle: viewModel.hasCompletedScan
                        ? "Try lowering the size threshold (e.g. 50 MB+) or run Rescan."
                        : "Click 'Smart Scan' in the top bar to search Downloads, Desktop, Movies, and Documents."
                )
            } else {
                ForEach(largeItems) { item in
                    ScanItemRowView(item: item, viewModel: viewModel)
                }
            }
        }
    }
    
    private var spaceLensSection: some View {
        let maxBytes = max(1, viewModel.spaceLensNodes.first?.sizeBytes ?? 1)
        return Group {
            if viewModel.spaceLensNodes.isEmpty {
                emptyCard(
                    icon: "chart.bar.doc.horizontal",
                    title: "Space Lens Ready",
                    subtitle: "Run Smart Scan to build a visual size map of your Home folder."
                )
            } else {
                ForEach(viewModel.spaceLensNodes) { node in
                    spaceLensRow(node: node, maxBytes: maxBytes)
                }
            }
        }
    }
    
    private func spaceLensRow(node: ScanItem, maxBytes: Int64) -> some View {
        let ratio = min(1.0, max(0.03, Double(node.sizeBytes) / Double(maxBytes)))
        let isHidden = node.name.hasPrefix(".")
        let barColor: Color = isHidden ? McCleanTheme.color(for: .hiddenDotfiles) : McCleanTheme.textSecondary
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: isHidden ? "eye.slash" : (node.isDirectory ? "folder" : "doc"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(barColor)
                    .frame(width: 28, height: 28)
                    .background(barColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(node.name)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(McCleanTheme.textPrimary)
                        if isHidden {
                            Text("DOT-FOLDER")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(McCleanTheme.accentCyan.opacity(0.12), in: Capsule())
                                .foregroundStyle(McCleanTheme.accentCyan)
                        }
                        SafetyBadgePill(level: node.safetyLevel)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(barColor)
                                .frame(width: geo.size.width * ratio)
                        }
                    }
                    .frame(height: 5)
                }
                
                Spacer()
                
                Button {
                    viewModel.revealInFinder(node.url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .frame(width: 24, height: 24)
                        .liquidGlassRect(cornerRadius: 5, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Reveal \(node.name) in Finder")
                
                Text(node.formattedSize)
                    .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(McCleanTheme.textPrimary)
                    .frame(width: 88, alignment: .trailing)
            }
            
            if !node.children.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(node.children.prefix(6)) { sub in
                            Button {
                                viewModel.revealInFinder(sub.url)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: sub.isDirectory ? "folder" : "doc")
                                        .font(.system(size: 9))
                                        .foregroundStyle(McCleanTheme.textMuted)
                                    Text("\(sub.name) (\(sub.formattedSize))")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(McCleanTheme.textSecondary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 40)
                }
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
}
