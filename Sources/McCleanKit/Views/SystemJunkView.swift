import SwiftUI

/// Dedicated module for macOS 4K/8K Aerial Video Wallpapers, Application Caches, Developer Caches, and Logs.
public struct SystemJunkView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private let relevantCategories: [JunkCategory] = [
        .wallpapersAndMedia,
        .appAndBrowserCaches,
        .developerAndAICaches,
        .logsAndDiagnostics
    ]
    
    private var displayedItems: [ScanItem] {
        let base = viewModel.systemAndDevItems
        guard let cat = viewModel.systemJunkFilter else { return base }
        return base.filter { $0.category == cat }
    }
    
    private var totalBytes: Int64 {
        displayedItems.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var body: some View {
        let accent = McCleanTheme.color(for: .systemAndDev)
        
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Editorial Header Card
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SYSTEM & DEVELOPER STORAGE • IDLEASSETSD & CACHES")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(accent)
                        
                        Text("4K Aerial Wallpapers, Caches & Build Bloat.")
                            .font(.system(size: 24, weight: .regular, design: .serif))
                            .tracking(-0.4)
                            .foregroundStyle(McCleanTheme.textPrimary)
                        
                        Text("Includes 4K 240FPS Aerial video wallpapers (idleassetsd & .wallpaper), application caches, Xcode DerivedData, and package manager stores.")
                            .font(.system(size: 12))
                            .foregroundStyle(McCleanTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("RECLAIMABLE BLOAT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(McCleanTheme.textMuted)
                        Text(ByteCountFormatterHelper.format(bytes: totalBytes))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(McCleanTheme.textPrimary)
                    }
                }
                .padding(20)
                .glassCard(cornerRadius: 8)
                
                // Subcategory Quick Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    LiquidGlassGroup(spacing: 6) {
                        HStack(spacing: 6) {
                            filterPill(title: "All Categories", category: nil)
                            ForEach(relevantCategories) { cat in
                                let catBytes = viewModel.bytesForCategory(cat)
                                filterPill(
                                    title: "\(cat.rawValue) (\(ByteCountFormatterHelper.format(bytes: catBytes)))",
                                    category: cat
                                )
                            }
                        }
                    }
                }
                
                if displayedItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "film.stack")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(McCleanTheme.textMuted)
                        Text(viewModel.hasCompletedScan ? "No Items in This Category" : "Run Smart Scan First")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                        Text(viewModel.hasCompletedScan
                             ? "Select another category pill above or run Rescan."
                             : "Click 'Smart Scan' in the top bar to scan macOS video wallpapers and caches.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(McCleanTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 52)
                    .glassCard(cornerRadius: 8)
                } else {
                    ForEach(displayedItems) { item in
                        ScanItemRowView(item: item, viewModel: viewModel)
                    }
                }
            }
            .padding(24)
        }
    }
    
    private func filterPill(title: String, category: JunkCategory?) -> some View {
        let isSelected = (viewModel.systemJunkFilter == category)
        return Button {
            viewModel.systemJunkFilter = category
        } label: {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 5.5)
                .background(isSelected ? McCleanTheme.textPrimary : McCleanTheme.cardBackground, in: Capsule())
                .overlay(
                    Capsule().strokeBorder(isSelected ? McCleanTheme.textPrimary : McCleanTheme.subtleBorder, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? McCleanTheme.inkDark : McCleanTheme.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
