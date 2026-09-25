import SwiftUI

/// Primary macOS split-view window for McClean combining Utilitarian Editorial Minimalism
/// with native macOS 26+ Liquid Glass interactive surfaces.
public struct MainWindowView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var permissionManager: PermissionManager
    @Namespace private var sidebarGlassNamespace
    
    public init(viewModel: AppViewModel, permissionManager: PermissionManager) {
        self.viewModel = viewModel
        self.permissionManager = permissionManager
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            sidebarColumn
                .frame(width: 256)
                .background(McCleanTheme.sidebarBackground)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(McCleanTheme.subtleBorder)
                        .frame(width: 1)
                }
            
            VStack(spacing: 0) {
                StorageHeaderBar(viewModel: viewModel, permissionManager: permissionManager)
                
                ZStack {
                    McCleanTheme.windowBackground
                        .ignoresSafeArea()
                    
                    activeDetailView
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.snappy(duration: 0.18), value: viewModel.selectedSection)
                
                if viewModel.hasCompletedScan || !viewModel.allScanItems.isEmpty {
                    BottomCleanupActionBar(viewModel: viewModel)
                }
            }
            .background(McCleanTheme.windowBackground)
        }
        .frame(minWidth: 1180, minHeight: 680)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $viewModel.isShowingCleanupConfirmation) {
            CleanupConfirmationSheet(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $viewModel.isShowingCleanupReportSheet) {
            if let report = viewModel.latestCleanupReport {
                CleanupReportChartSheet(report: report)
                    .preferredColorScheme(.dark)
            }
        }
        .sheet(isPresented: $viewModel.isShowingSettingsSheet) {
            SettingsView(viewModel: viewModel, permissionManager: permissionManager)
                .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $viewModel.isShowingPermissionSheet) {
            PermissionOnboardingSheet(viewModel: viewModel, permissionManager: permissionManager)
                .preferredColorScheme(.dark)
        }
    }
    
    @ViewBuilder
    private var activeDetailView: some View {
        switch viewModel.selectedSection {
        case .smartScan:
            SmartScanView(viewModel: viewModel)
        case .dotfiles:
            DotfilesView(viewModel: viewModel)
        case .appLeftovers:
            AppLeftoversView(viewModel: viewModel)
        case .systemAndDev:
            SystemJunkView(viewModel: viewModel)
        case .largeFiles:
            LargeFilesView(viewModel: viewModel)
        }
    }
    
    // MARK: - Editorial Sidebar Column
    
    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Minimalist Brand Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(McCleanTheme.textPrimary)
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "internaldrive")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(McCleanTheme.inkDark)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("McClean")
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(-0.3)
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("OSS")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .tracking(0.6)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(McCleanTheme.accentEmerald.opacity(0.14), in: Capsule())
                            .foregroundStyle(McCleanTheme.accentEmerald)
                            .help("Open-Source Software — Free & Open Source macOS Utility")
                    }
                    
                    Text("macOS Storage Utility")
                        .font(.system(size: 10.5, weight: .regular))
                        .foregroundStyle(McCleanTheme.textMuted)
                }
                
                Spacer()
                
                Button {
                    viewModel.isShowingSettingsSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .liquidGlassRect(cornerRadius: 6, interactive: true)
                }
                .buttonStyle(.plain)
                .help("Preferences, AI Inspector & Protected Whitelist (⌘,)")
                .accessibilityLabel("Open Preferences")
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            Rectangle()
                .fill(McCleanTheme.subtleBorder)
                .frame(height: 1)
                .padding(.bottom, 14)
            
            // Section Header
            Text("MODULES")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(McCleanTheme.textMuted)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            
            // Navigation List inside LiquidGlassGroup for macOS 26 optical blending
            LiquidGlassGroup(spacing: 6) {
                VStack(spacing: 3) {
                    ForEach(NavigationSection.allCases) { section in
                        sidebarRowButton(for: section)
                    }
                }
            }
            .padding(.horizontal, 10)
            
            Spacer()
            
            // Flat Bento Disk Status Card
            sidebarStorageCard
                .padding(12)
        }
    }
    
    @ViewBuilder
    private func sidebarRowButton(for section: NavigationSection) -> some View {
        let isSelected = (viewModel.selectedSection == section)
        let accent = McCleanTheme.color(for: section)
        let bytes = viewModel.badgeBytes(for: section)
        
        Button {
            viewModel.selectSection(section)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.iconName)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? McCleanTheme.textPrimary : accent)
                    .frame(width: 22, height: 22)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.rawValue)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? McCleanTheme.textPrimary : McCleanTheme.textSecondary)
                        .lineLimit(1)
                    
                    Text(shortDescription(for: section))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textMuted)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 4)
                
                if bytes > 0 {
                    Text(ByteCountFormatterHelper.format(bytes: bytes))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Color.white.opacity(isSelected ? 0.10 : 0.04),
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                        .foregroundStyle(isSelected ? McCleanTheme.textPrimary : McCleanTheme.textSecondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(
                SidebarRowGlassModifier(
                    isSelected: isSelected,
                    namespace: sidebarGlassNamespace
                )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func shortDescription(for section: NavigationSection) -> String {
        switch section {
        case .smartScan: return "All categories"
        case .dotfiles: return "~/.* & .config"
        case .appLeftovers: return "Orphans & apps"
        case .systemAndDev: return "Aerials & caches"
        case .largeFiles: return "50MB+ & lens"
        }
    }
    
    private var sidebarStorageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CircularDiskGauge(fraction: viewModel.diskUsage.usedFraction, size: 42, lineWidth: 3.5)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Macintosh HD")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("\(viewModel.diskUsage.formattedFree) available")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(McCleanTheme.accentEmerald)
                    Text("of \(viewModel.diskUsage.formattedTotal)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textMuted)
                }
                Spacer()
            }
            
            Rectangle()
                .fill(McCleanTheme.subtleBorder)
                .frame(height: 1)
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RECLAIMED TOTAL")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(McCleanTheme.textMuted)
                    Text(ByteCountFormatterHelper.format(bytes: viewModel.lifetimeBytesFreed))
                        .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(McCleanTheme.textPrimary)
                }
                
                Spacer()
                
                if viewModel.latestCleanupReport != nil {
                    Button {
                        viewModel.isShowingCleanupReportSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.pie")
                                .font(.system(size: 9.5, weight: .semibold))
                            Text("Report")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .liquidGlassCapsule(tint: McCleanTheme.accentEmerald.opacity(0.25), interactive: true)
                        .foregroundStyle(McCleanTheme.accentEmerald)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 8)
    }
}

/// Applies macOS 26 Liquid Glass morphing highlight to the active sidebar row.
private struct SidebarRowGlassModifier: ViewModifier {
    let isSelected: Bool
    let namespace: Namespace.ID
    
    func body(content: Content) -> some View {
        if isSelected {
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
                    .glassEffectID("activeSidebarRow", in: namespace)
            } else {
                content
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(McCleanTheme.elevatedCardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(McCleanTheme.highlightBorder, lineWidth: 1)
                    )
            }
        } else {
            content
        }
    }
}
