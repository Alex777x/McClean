import SwiftUI

/// Application Settings & Preferences view for McClean with dark-glass aesthetic.
public struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var permissionManager: PermissionManager
    
    public init(viewModel: AppViewModel, permissionManager: PermissionManager) {
        self.viewModel = viewModel
        self.permissionManager = permissionManager
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Header
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(McCleanTheme.textPrimary)
                        .frame(width: 32, height: 32)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(McCleanTheme.inkDark)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("McClean Preferences")
                        .font(.system(size: 18, weight: .regular, design: .serif))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("Configure disk access permissions, AI Folder Inspector, and protected paths")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                
                Spacer()
                
                if viewModel.isShowingSettingsSheet {
                    Button {
                        viewModel.isShowingSettingsSheet = false
                    } label: {
                        Text("Done")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(McCleanTheme.inkDark)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(McCleanTheme.textPrimary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
                    generalAndPermissionsCard
                    aiInspectorCard
                    whitelistCard
                    updatesAndOpenSourceCard
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 520)
        .background(McCleanTheme.canvasBackground)
        .preferredColorScheme(.dark)
    }
    
    // MARK: - General & Hybrid Permissions Card
    
    private var generalAndPermissionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("01")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textMuted)
                Text("GENERAL & HYBRID DISK ACCESS")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(McCleanTheme.textMuted)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Deletion Engine Policy")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("Files are permanently removed immediately and visualized in the Space Reclaimed chart")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                Spacer()
                Text("IMMEDIATE PERMANENT DELETE")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.accentEmerald)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(McCleanTheme.accentEmerald.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(McCleanTheme.accentEmerald.opacity(0.32), lineWidth: 1)
                    }
            }
            
            Divider().overlay(McCleanTheme.subtleBorder)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Home Folder Sandbox Bookmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("App Store compliant security-scoped access to your Home directory")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                Spacer()
                Button {
                    permissionManager.requestDiskAccessViaOpenPanel()
                } label: {
                    Text(permissionManager.hasHomeAccess ? "Bookmark Active ✓" : "Grant Folder Access...")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(permissionManager.hasHomeAccess ? McCleanTheme.accentEmerald : McCleanTheme.textPrimary)
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
    
    // MARK: - AI Folder Inspector Card
    
    private var aiInspectorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("02")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textMuted)
                Text("AI FOLDER INSPECTOR ENGINE")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(McCleanTheme.textMuted)
            }
            
            LiquidGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(AIProviderMode.allCases) { mode in
                        let isSelected = viewModel.aiModeRaw == mode.rawValue
                        Button {
                            viewModel.aiModeRaw = mode.rawValue
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isSelected ? McCleanTheme.inkDark : McCleanTheme.textMuted.opacity(0.5))
                                    .frame(width: 5, height: 5)
                                
                                Text(mode.rawValue)
                                    .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                    .foregroundStyle(isSelected ? McCleanTheme.inkDark : McCleanTheme.textPrimary)
                            }
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(McCleanTheme.textPrimary)
                                } else {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(McCleanTheme.elevatedCardBackground)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
                                        }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            if viewModel.aiMode == .localOllama {
                HStack {
                    Text("Ollama Model:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(McCleanTheme.textSecondary)
                    TextField("llama3.2", text: $viewModel.ollamaModel)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(McCleanTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
                        }
                }
                Text("Connects locally to http://127.0.0.1:11434/api/generate and automatically falls back to the offline heuristic engine if Ollama is offline.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(McCleanTheme.textMuted)
            } else if viewModel.aiMode == .customAPI {
                VStack(spacing: 8) {
                    TextField("OpenAI-compatible Endpoint URL", text: $viewModel.customAPIEndpoint)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(McCleanTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
                        }
                    
                    SecureField("API Key", text: $viewModel.customAPIKey)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(McCleanTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
                        }
                }
            } else {
                Text("100% offline & free heuristic engine. Inspects file extensions, directory structure, and installed app bundles locally without any network requests.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(McCleanTheme.textSecondary)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 10)
    }
    
    // MARK: - Protected Whitelist Card
    
    private var whitelistCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("03")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textMuted)
                Text("PROTECTED WHITELIST (NEVER DELETED)")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(McCleanTheme.textMuted)
            }
            
            Text("Built-in Locked Paths: ~/.ssh, ~/.gnupg, ~/.aws, ~/.kube, ~/.zshrc, ~/.gitconfig, ~/Library/Keychains, /System")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(McCleanTheme.textSecondary)
            
            HStack(spacing: 10) {
                TextField("Add custom path to protect (e.g. /Users/you/.myfolder)", text: $viewModel.newWhitelistPath)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(McCleanTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
                    }
                
                Button {
                    let trimmed = viewModel.newWhitelistPath.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        viewModel.addPathToWhitelist(trimmed)
                        viewModel.newWhitelistPath = ""
                    }
                } label: {
                    Text("Protect Path")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(McCleanTheme.inkDark)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(McCleanTheme.textPrimary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            
            if !viewModel.customWhitelist.isEmpty {
                VStack(spacing: 6) {
                    ForEach(viewModel.customWhitelist, id: \.self) { path in
                        HStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(McCleanTheme.accentEmerald)
                            Text(path)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(McCleanTheme.textPrimary)
                            Spacer()
                            Button {
                                viewModel.removePathFromWhitelist(path)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(McCleanTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(McCleanTheme.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 10)
    }
    
    // MARK: - Updates & Open Source Card
    
    private var updatesAndOpenSourceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text("04")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textMuted)
                Text("UPDATES & OPEN SOURCE")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(McCleanTheme.textMuted)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("McClean Version \(UpdateCheckerService.shared.currentVersion)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("MIT LICENSE")
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(McCleanTheme.accentEmerald)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(McCleanTheme.accentEmerald.opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    #if APP_STORE
                    Text("Updates are delivered automatically via the macOS App Store")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                    #else
                    Text("Checks GitHub Releases for new versions or view source code on GitHub")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                    #endif
                }
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        UpdateCheckerService.shared.openRepositoryPage()
                    } label: {
                        Text("GitHub Repo")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .liquidGlassRect(cornerRadius: 7)
                    }
                    .buttonStyle(.plain)
                    
                    #if !APP_STORE
                    Button {
                        UpdateCheckerService.shared.checkForUpdates(showAlertIfUpToDate: true)
                    } label: {
                        Text("Check for Updates")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(McCleanTheme.inkDark)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(McCleanTheme.textPrimary, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    #endif
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 10)
    }
}
