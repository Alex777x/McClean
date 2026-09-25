import SwiftUI

/// Utilitarian Minimalist row representing a scannable file or directory with native macOS 26 Liquid Glass action buttons.
public struct ScanItemRowView: View {
    public let item: ScanItem
    @ObservedObject var viewModel: AppViewModel
    
    public init(item: ScanItem, viewModel: AppViewModel) {
        self.item = item
        self.viewModel = viewModel
    }
    
    private var isExpanded: Bool {
        viewModel.expandedItemIDs.contains(item.id)
    }
    
    public var body: some View {
        let catColor = McCleanTheme.color(for: item.category)
        
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                // Checkbox or Protected Lock
                if item.safetyLevel == .protected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(McCleanTheme.accentCyan.opacity(0.12))
                            .frame(width: 18, height: 18)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(McCleanTheme.accentCyan)
                    }
                    .help("Protected system/credential directory — locked from deletion")
                    .accessibilityLabel("Protected item, locked from deletion")
                } else {
                    GlassCheckbox(isChecked: item.isSelected, accentColor: catColor) {
                        viewModel.toggleSelection(for: item.id)
                    }
                }
                
                // Minimalist Category Icon
                Image(systemName: item.isDirectory ? item.category.iconName : "doc.text")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(catColor)
                    .frame(width: 28, height: 28)
                    .background(catColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                // Main Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(item.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(McCleanTheme.textPrimary)
                            .lineLimit(1)
                        
                        SafetyBadgePill(level: item.safetyLevel)
                        
                        if item.isOrphaned {
                            Text("ORPHANED LEFTOVER")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .tracking(0.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(McCleanTheme.accentAmber.opacity(0.12), in: Capsule())
                                .foregroundStyle(McCleanTheme.accentAmber)
                        }
                    }
                    
                    Text(item.explanation)
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textSecondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(item.displayPath)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(McCleanTheme.textMuted)
                            .lineLimit(1)
                        
                        if item.fileCount > 1 {
                            Text("• \(item.fileCount) files")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(McCleanTheme.textMuted)
                        }
                    }
                }
                
                Spacer(minLength: 10)
                
                // Grouped Liquid Glass Action Buttons
                LiquidGlassGroup(spacing: 6) {
                    HStack(spacing: 5) {
                        Button {
                            viewModel.inspectItemWithAI(item)
                        } label: {
                            HStack(spacing: 4) {
                                if viewModel.inspectingItemID == item.id {
                                    ProgressView()
                                        .controlSize(.mini)
                                } else {
                                    Image(systemName: "sparkle")
                                        .font(.system(size: 9.5, weight: .semibold))
                                }
                                Text("Inspect")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4.5)
                            .foregroundStyle(McCleanTheme.accentViolet)
                            .liquidGlassCapsule(tint: McCleanTheme.accentViolet.opacity(0.20), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .help("Inspect what created this folder and whether it is safe to remove")
                        
                        Button {
                            viewModel.revealInFinder(item.url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(McCleanTheme.textSecondary)
                                .frame(width: 24, height: 24)
                                .liquidGlassRect(cornerRadius: 5, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                        .accessibilityLabel("Reveal \(item.name) in Finder")
                        
                        if !item.children.isEmpty {
                            Button {
                                withAnimation(.snappy(duration: 0.16)) {
                                    if isExpanded {
                                        viewModel.expandedItemIDs.remove(item.id)
                                    } else {
                                        viewModel.expandedItemIDs.insert(item.id)
                                    }
                                }
                            } label: {
                                Image(systemName: isExpanded ? "minus" : "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(McCleanTheme.textSecondary)
                                    .frame(width: 24, height: 24)
                                    .liquidGlassRect(cornerRadius: 5, interactive: true)
                            }
                            .buttonStyle(.plain)
                            .help("Show largest subfolders inside")
                            .accessibilityLabel(isExpanded ? "Hide subfolders" : "Show subfolders")
                        }
                    }
                }
                
                // Monospace Formatted Size
                Text(item.formattedSize)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(item.isSelected ? McCleanTheme.textPrimary : McCleanTheme.textSecondary)
                    .frame(minWidth: 78, alignment: .trailing)
            }
            
            // AI Analysis Inline Card
            if let aiText = item.aiAnalysis {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("FOLDER INSPECTOR REPORT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(McCleanTheme.accentViolet)
                        Spacer()
                    }
                    Text(aiText)
                        .font(.system(size: 11.5))
                        .lineSpacing(2)
                        .foregroundStyle(McCleanTheme.textPrimary)
                        .textSelection(.enabled)
                }
                .padding(12)
                .background(McCleanTheme.accentViolet.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(McCleanTheme.accentViolet.opacity(0.24), lineWidth: 1)
                )
                .padding(.leading, 30)
            }
            
            // Expandable Child Subfolders
            if isExpanded && !item.children.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(item.children) { child in
                        HStack(spacing: 8) {
                            Image(systemName: child.isDirectory ? "folder" : "doc")
                                .font(.system(size: 10))
                                .foregroundStyle(McCleanTheme.textMuted)
                            Text(child.name)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(McCleanTheme.textSecondary)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                viewModel.revealInFinder(child.url)
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundStyle(McCleanTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Reveal \(child.name) in Finder")
                            
                            Text(child.formattedSize)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(McCleanTheme.textSecondary)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(item.isSelected ? McCleanTheme.elevatedCardBackground : McCleanTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    item.isSelected ? McCleanTheme.highlightBorder : McCleanTheme.subtleBorder,
                    lineWidth: 1
                )
        )
    }
}

public struct SafetyBadgeView: View {
    public let safetyLevel: SafetyLevel
    
    public init(safetyLevel: SafetyLevel) {
        self.safetyLevel = safetyLevel
    }
    
    public var body: some View {
        SafetyBadgePill(level: safetyLevel)
    }
}
