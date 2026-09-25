import SwiftUI

/// Utilitarian Minimalist top header bar with native macOS 26 Liquid Glass interactive controls.
public struct StorageHeaderBar: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var permissionManager: PermissionManager
    
    public init(viewModel: AppViewModel, permissionManager: PermissionManager) {
        self.viewModel = viewModel
        self.permissionManager = permissionManager
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                // Active Module Title & Subtitle
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(viewModel.selectedSection.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .tracking(-0.2)
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        if viewModel.isScanning {
                            Text("SCANNING")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .tracking(0.6)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(McCleanTheme.accentCyan.opacity(0.14), in: Capsule())
                                .foregroundStyle(McCleanTheme.accentCyan)
                        }
                    }
                    
                    Text(viewModel.isScanning ? viewModel.scanStatusMessage : viewModel.selectedSection.subtitle)
                        .font(.system(size: 11, design: viewModel.isScanning ? .monospaced : .default))
                        .foregroundStyle(viewModel.isScanning ? McCleanTheme.accentCyan : McCleanTheme.textSecondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)
                
                Spacer(minLength: 16)
                
                // Minimalist Search Input
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(McCleanTheme.textMuted)
                    
                    TextField("Filter by name or path...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    
                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                        } label: {
                            Text("ESC")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(McCleanTheme.textSecondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 210)
                .glassCard(cornerRadius: 6)
                
                // Grouped Liquid Glass Action Strip
                LiquidGlassGroup(spacing: 8) {
                    HStack(spacing: 8) {
                        // Folder Permissions Status Button
                        Button {
                            viewModel.isShowingPermissionSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: permissionManager.hasHomeBookmark ? "checkmark.shield" : "shield")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(permissionManager.hasHomeBookmark ? "Access Ready" : "Permissions")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .foregroundStyle(permissionManager.hasHomeBookmark ? McCleanTheme.accentEmerald : McCleanTheme.textSecondary)
                            .liquidGlassRect(cornerRadius: 6, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .help("Configure folder permissions or skip optional scopes like Photos")
                        
                        // High-Contrast Minimalist Primary CTA Button
                        Button {
                            viewModel.requestOrStartSmartScan()
                        } label: {
                            HStack(spacing: 6) {
                                if viewModel.isScanning {
                                    ProgressView()
                                        .controlSize(.mini)
                                    Text("Scanning...")
                                        .font(.system(size: 11.5, weight: .semibold))
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10.5, weight: .bold))
                                    Text(viewModel.hasCompletedScan ? "Rescan" : "Smart Scan")
                                        .font(.system(size: 11.5, weight: .semibold))
                                }
                            }
                            .foregroundStyle(McCleanTheme.inkDark)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(McCleanTheme.textPrimary)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isScanning || viewModel.isCleaning)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            // Minimalist 2px Scan Progress Hairline
            if viewModel.isScanning {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(McCleanTheme.subtleBorder)
                        Rectangle()
                            .fill(McCleanTheme.textPrimary)
                            .frame(width: max(20, geo.size.width * viewModel.scanProgress))
                            .animation(.easeOut(duration: 0.25), value: viewModel.scanProgress)
                    }
                }
                .frame(height: 2)
            } else {
                Rectangle()
                    .fill(McCleanTheme.subtleBorder)
                    .frame(height: 1)
            }
        }
        .background(McCleanTheme.sidebarBackground)
    }
}
