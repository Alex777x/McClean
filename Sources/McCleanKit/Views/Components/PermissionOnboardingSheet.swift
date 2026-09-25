import SwiftUI

/// Folder & Disk Permissions view styled identically to `SettingsView`
/// (Editorial Minimalist top bar with `Done` button + numbered 01–03 Bento cards inside a ScrollView).
public struct PermissionOnboardingSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var permissionManager: PermissionManager
    @Environment(\.dismiss) private var dismiss
    
    public init(viewModel: AppViewModel, permissionManager: PermissionManager) {
        self.viewModel = viewModel
        self.permissionManager = permissionManager
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Header (Identical layout & styling to SettingsView)
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(McCleanTheme.textPrimary)
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(McCleanTheme.inkDark)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disk & Folder Permissions")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("Choose which folders McClean can scan and skip anything you prefer to keep private")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if !viewModel.hasCompletedScan && !viewModel.isScanning {
                        Button {
                            permissionManager.continueWithLimitedPermissions()
                            viewModel.isShowingPermissionSheet = false
                            dismiss()
                            viewModel.startSmartScan()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9.5, weight: .bold))
                                Text("Start Scan")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundStyle(McCleanTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .liquidGlassRect(cornerRadius: 7)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        permissionManager.continueWithLimitedPermissions()
                        viewModel.isShowingPermissionSheet = false
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(McCleanTheme.inkDark)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(McCleanTheme.textPrimary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(McCleanTheme.sidebarBackground)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(McCleanTheme.subtleBorder)
                    .frame(height: 1)
            }
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    primaryAccessCard
                    optionalFoldersCard
                    privacyProtectionCard
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 520)
        .background(McCleanTheme.canvasBackground)
        .preferredColorScheme(.dark)
        .onAppear {
            permissionManager.updateScopeStatusesWithoutPrompting()
        }
    }
    
    // MARK: - 01. Primary Recommended Access Card
    
    private var primaryAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("01")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textMuted)
                Text("RECOMMENDED HOME & SYSTEM ACCESS")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(McCleanTheme.textMuted)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Home Folder Access (~/.* & ~/Library Caches)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("RECOMMENDED")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(McCleanTheme.accentEmerald)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(McCleanTheme.accentEmerald.opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    Text("Enables 1-click scanning of hidden dot-directories (.wallpaper, .npm, .ollama) and app caches")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                Spacer()
                Button {
                    permissionManager.requestDiskAccessViaOpenPanel()
                } label: {
                    Text(permissionManager.hasHomeBookmark ? "Bookmark Active ✓" : "Grant Home Access...")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(permissionManager.hasHomeBookmark ? McCleanTheme.accentEmerald : McCleanTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlassRect(cornerRadius: 7)
                }
                .buttonStyle(.plain)
            }
            
            Divider().overlay(McCleanTheme.subtleBorder)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Full Disk Access (System Wallpapers & Caches)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("Optional access for /Library/Application Support/com.apple.idleassetsd 4K/8K videos")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                Spacer()
                Button {
                    permissionManager.openFullDiskAccessSettings()
                } label: {
                    Text("System Settings")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlassRect(cornerRadius: 7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 10)
    }
    
    // MARK: - 02. Optional User Folders Card
    
    private var optionalFoldersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("02")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textMuted)
                Text("OPTIONAL USER FOLDERS (SKIP ANYTIME)")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(McCleanTheme.textMuted)
            }
            
            folderScopeRow(
                title: "Downloads Folder (~/Downloads)",
                subtitle: "Scan for forgotten .dmg, .pkg, .iso installers and heavy archives",
                status: permissionManager.downloadsStatus,
                buttonTitle: "Grant Downloads..."
            ) {
                permissionManager.requestAccessToUserFolder(named: "Downloads")
            }
            
            Divider().overlay(McCleanTheme.subtleBorder)
            
            folderScopeRow(
                title: "Desktop Folder (~/Desktop)",
                subtitle: "Optional scan for 50MB+ files and archives on your Desktop",
                status: permissionManager.desktopStatus,
                buttonTitle: "Grant Desktop..."
            ) {
                permissionManager.requestAccessToUserFolder(named: "Desktop")
            }
            
            Divider().overlay(McCleanTheme.subtleBorder)
            
            folderScopeRow(
                title: "Documents Folder (~/Documents)",
                subtitle: "Optional scan for 50MB+ files and installers in Documents",
                status: permissionManager.documentsStatus,
                buttonTitle: "Grant Documents..."
            ) {
                permissionManager.requestAccessToUserFolder(named: "Documents")
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 10)
    }
    
    // MARK: - 03. Privacy & TCC Protection Card
    
    private var privacyProtectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("03")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textMuted)
                Text("PRIVACY & TCC PROTECTION")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(McCleanTheme.textMuted)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Photos Library (Skipped by Default)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text(permissionManager.includePhotosLibrary && permissionManager.photosStatus == .granted ? "INCLUDED" : "SAFELY SKIPPED")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(McCleanTheme.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    Text("Skipped by default so macOS never blocks or prompts for your personal Photos library")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                Spacer()
                Button {
                    if permissionManager.includePhotosLibrary {
                        permissionManager.includePhotosLibrary = false
                    } else {
                        permissionManager.requestOptionalPhotosPermission()
                    }
                } label: {
                    Text(permissionManager.includePhotosLibrary ? "Skip Photos" : "Request Photos...")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlassRect(cornerRadius: 7)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 10)
    }
    
    private func folderScopeRow(
        title: String,
        subtitle: String,
        status: PermissionScopeStatus,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    
                    Text(status == .granted ? "GRANTED ✓" : "OPTIONAL")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(status == .granted ? McCleanTheme.accentEmerald : McCleanTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (status == .granted ? McCleanTheme.accentEmerald : Color.white).opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
                        )
                }
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(McCleanTheme.textSecondary)
            }
            Spacer()
            Button(action: action) {
                Text(status == .granted ? "Access Granted ✓" : buttonTitle)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(status == .granted ? McCleanTheme.accentEmerald : McCleanTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .liquidGlassRect(cornerRadius: 7)
            }
            .buttonStyle(.plain)
        }
    }
}
