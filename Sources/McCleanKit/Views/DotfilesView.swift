import SwiftUI

/// Dedicated module for exploring hidden Unix dot-directories (`~/.*`, `~/.config/*`, `~/.local/share/*`).
public struct DotfilesView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var items: [ScanItem] {
        viewModel.dotfileItems
    }
    
    private var totalDotfilesBytes: Int64 {
        items.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var body: some View {
        let accent = McCleanTheme.color(for: .hiddenDotfiles)
        
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Editorial Bento Header Card
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("UNIX DOTFILES • ~/.* & ~/.CONFIG")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(accent)
                        
                        Text("Hidden Dotfiles & Directories.")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .tracking(-0.4)
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("Standard Mac cleaners ignore hidden Unix dot-directories like ~/.wallpaper, ~/.cache, ~/.ollama, and ~/.npm. Click 'Inspect' on any folder to verify what created it.")
                            .font(.system(size: 12))
                            .foregroundStyle(McCleanTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("DISCOVERED SIZE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(McCleanTheme.textMuted)
                        Text(ByteCountFormatterHelper.format(bytes: totalDotfilesBytes))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(McCleanTheme.textPrimary)
                    }
                }
                .padding(20)
                .glassCard(cornerRadius: 8)
                
                // Safety Filter Strip
                LiquidGlassGroup(spacing: 6) {
                    HStack(spacing: 6) {
                        filterPill(title: "All (\(items.count))", level: nil)
                        filterPill(title: "Safe Cache", level: .safe)
                        filterPill(title: "Review Needed", level: .review)
                        filterPill(title: "Protected (.ssh/.gnupg)", level: .protected)
                        Spacer()
                    }
                }
                
                if items.isEmpty {
                    emptyStateCard
                } else {
                    ForEach(items) { item in
                        ScanItemRowView(item: item, viewModel: viewModel)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func filterPill(title: String, level: SafetyLevel?) -> some View {
        let isSelected = (viewModel.selectedSafetyFilter == level)
        return Button {
            viewModel.selectedSafetyFilter = level
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(isSelected ? McCleanTheme.textPrimary : McCleanTheme.cardBackground, in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? McCleanTheme.textPrimary : McCleanTheme.subtleBorder, lineWidth: 1))
                .foregroundStyle(isSelected ? McCleanTheme.inkDark : McCleanTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
    
    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(McCleanTheme.textMuted)
            Text(viewModel.hasCompletedScan ? "No Matching Dotfiles Found" : "Run Smart Scan to Inspect ~/.*")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(McCleanTheme.textPrimary)
            Text(viewModel.hasCompletedScan
                 ? "Try clearing your search or safety filter above."
                 : "Click 'Smart Scan' in the top bar to discover hidden dot-directories in your Home folder.")
                .font(.system(size: 11.5))
                .foregroundStyle(McCleanTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 52)
        .glassCard(cornerRadius: 8)
    }
}
