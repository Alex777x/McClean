import SwiftUI
import Charts

/// Floating bottom action bar using native macOS 26 Liquid Glass (`GlassEffectContainer`)
/// and scoped strictly to the active tab (`viewModel.selectedSection`).
public struct BottomCleanupActionBar: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        LiquidGlassGroup(spacing: 12) {
            HStack(spacing: 14) {
                // Quick Selection Controls for Current Tab
                HStack(spacing: 8) {
                    Button {
                        viewModel.selectOnlySafeItems()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.shield")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(McCleanTheme.accentEmerald)
                            Text("Select Safe Only")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(McCleanTheme.textPrimary)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .liquidGlassCapsule(interactive: true)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        viewModel.deselectAllItems()
                    } label: {
                        Text("Clear Selection")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(McCleanTheme.textSecondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .liquidGlassCapsule(interactive: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedItemsCount == 0)
                }
                
                Spacer()
                
                if let lastReport = viewModel.latestCleanupReport {
                    Button {
                        viewModel.isShowingCleanupReportSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chart.pie")
                            Text("Last Freed: \(lastReport.formattedTotalFreed)")
                        }
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .liquidGlassCapsule(tint: McCleanTheme.accentEmerald.opacity(0.22), interactive: true)
                        .foregroundStyle(McCleanTheme.accentEmerald)
                    }
                    .buttonStyle(.plain)
                }
                
                // Tab-Scoped Selected Summary
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(viewModel.selectedItemsCount) selected in \(viewModel.selectedSection.rawValue)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textMuted)
                    Text(ByteCountFormatterHelper.format(bytes: viewModel.selectedToCleanBytes))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(McCleanTheme.textPrimary)
                }
                
                // High-Contrast Solid Utilitarian CTA Button
                Button {
                    viewModel.isShowingCleanupConfirmation = true
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "trash")
                            .font(.system(size: 11.5, weight: .bold))
                        Text("Clean Immediately (\(ByteCountFormatterHelper.format(bytes: viewModel.selectedToCleanBytes)))")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(viewModel.selectedItemsCount > 0 ? McCleanTheme.inkDark : McCleanTheme.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(viewModel.selectedItemsCount > 0 ? McCleanTheme.textPrimary : Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedItemsCount == 0 || viewModel.isCleaning || viewModel.isScanning)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(McCleanTheme.sidebarBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(McCleanTheme.subtleBorder)
                .frame(height: 1)
        }
    }
}

/// Editorial Minimalist pre-flight confirmation sheet before permanent deletion.
public struct CleanupConfirmationSheet: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    private var selectedItems: [ScanItem] {
        viewModel.selectedItemsForActiveSection
    }
    
    private var reviewItemsCount: Int {
        selectedItems.filter { $0.safetyLevel == .review }.count
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("CONFIRM PERMANENT DELETION • \(viewModel.selectedSection.rawValue.uppercased())")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(McCleanTheme.textMuted)
                
                Text("Permanently Free \(ByteCountFormatterHelper.format(bytes: viewModel.selectedToCleanBytes))?")
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .tracking(-0.4)
                    .foregroundStyle(McCleanTheme.textPrimary)
                
                Text("\(selectedItems.count) selected item(s) in '\(viewModel.selectedSection.rawValue)' will be removed immediately (bypassing Trash) to reclaim disk space right now.")
                    .font(.system(size: 12))
                    .foregroundStyle(McCleanTheme.textSecondary)
            }
            
            if reviewItemsCount > 0 {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(McCleanTheme.accentAmber)
                    Text("Includes \(reviewItemsCount) item(s) marked 'Review' (such as orphaned app data or dotfiles). Verify you no longer need them before deleting.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(McCleanTheme.textPrimary)
                }
                .padding(12)
                .background(McCleanTheme.accentAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(McCleanTheme.accentAmber.opacity(0.28), lineWidth: 1)
                )
            }
            
            // Selected Items Preview List
            ScrollView {
                LazyVStack(spacing: 5) {
                    ForEach(selectedItems.prefix(50)) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.category.iconName)
                                .font(.system(size: 12))
                                .foregroundStyle(McCleanTheme.color(for: item.category))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(McCleanTheme.textPrimary)
                                    .lineLimit(1)
                                Text(item.displayPath)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(McCleanTheme.textMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            SafetyBadgePill(level: item.safetyLevel)
                            Text(item.formattedSize)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(McCleanTheme.textPrimary)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .glassCard(cornerRadius: 6)
                    }
                }
            }
            .frame(maxHeight: 240)
            
            Rectangle()
                .fill(McCleanTheme.subtleBorder)
                .frame(height: 1)
            
            LiquidGlassGroup(spacing: 10) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(McCleanTheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .liquidGlassRect(cornerRadius: 6, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    
                    Spacer()
                    
                    Button {
                        viewModel.executeImmediateCleanup()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Delete Permanently (\(ByteCountFormatterHelper.format(bytes: viewModel.selectedToCleanBytes)))")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundStyle(McCleanTheme.inkDark)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8.5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(McCleanTheme.textPrimary)
                        )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 580)
        .background(McCleanTheme.windowBackground)
    }
}

/// Editorial Minimalist Visual Dashboard & Chart displayed immediately after permanent deletion completes.
public struct CleanupReportChartSheet: View {
    public let report: CleanupReport
    @Environment(\.dismiss) private var dismiss
    
    public init(report: CleanupReport) {
        self.report = report
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top Editorial Header
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("CLEANUP REPORT • IMMEDIATE DELETION")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(McCleanTheme.accentEmerald)
                    
                    Text("Space Reclaimed Immediately.")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .tracking(-0.4)
                        .foregroundStyle(McCleanTheme.textPrimary)
                    
                    Text("Permanently removed \(report.deletedItemCount) item(s) in \(String(format: "%.1f", max(0.1, report.durationSeconds)))s")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TOTAL FREED")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(McCleanTheme.textMuted)
                    Text(report.formattedTotalFreed)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(McCleanTheme.accentEmerald)
                }
            }
            
            Rectangle()
                .fill(McCleanTheme.subtleBorder)
                .frame(height: 1)
            
            // Main Visual Charts Row: Donut Chart + Category Horizontal Bar Chart
            if !report.categoryMetrics.isEmpty {
                HStack(alignment: .center, spacing: 24) {
                    ZStack {
                        Chart(report.categoryMetrics) { metric in
                            SectorMark(
                                angle: .value("Bytes Freed", metric.bytesFreed),
                                innerRadius: .ratio(0.70),
                                angularInset: 1.5
                            )
                            .cornerRadius(2)
                            .foregroundStyle(McCleanTheme.color(for: metric.category))
                        }
                        .frame(width: 168, height: 168)
                        
                        VStack(spacing: 2) {
                            Text(report.formattedTotalFreed)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(McCleanTheme.textPrimary)
                            Text("RECLAIMED")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(McCleanTheme.textMuted)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CATEGORY BREAKDOWN")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(McCleanTheme.textMuted)
                        
                        ForEach(report.categoryMetrics) { metric in
                            let proportion = Double(metric.bytesFreed) / Double(max(1, report.totalBytesFreed))
                            let catColor = McCleanTheme.color(for: metric.category)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Circle()
                                        .fill(catColor)
                                        .frame(width: 7, height: 7)
                                    Text(metric.category.rawValue)
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(McCleanTheme.textPrimary)
                                    Spacer()
                                    Text("\(metric.itemCount) items")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(McCleanTheme.textMuted)
                                    Text(metric.formattedBytes)
                                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                        .monospacedDigit()
                                        .foregroundStyle(McCleanTheme.textPrimary)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .fill(Color.white.opacity(0.06))
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .fill(catColor)
                                            .frame(width: max(6, geo.size.width * proportion))
                                    }
                                }
                                .frame(height: 5)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(18)
                .glassCard(cornerRadius: 8)
            }
            
            // Before vs After Free Disk Space Comparison Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("MACINTOSH HD FREE SPACE IMPACT")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(McCleanTheme.textMuted)
                    Spacer()
                    HStack(spacing: 6) {
                        Text("Before: \(report.formattedFreeBefore)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(McCleanTheme.textSecondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(McCleanTheme.accentEmerald)
                        Text("After: \(report.formattedFreeAfter)")
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(McCleanTheme.accentEmerald)
                    }
                }
                
                GeometryReader { geo in
                    let width = max(1, geo.size.width)
                    let usedAfterFrac = Double(report.diskUsedAfterBytes) / Double(max(1, report.diskTotalBytes))
                    let freedFrac = Double(report.totalBytesFreed) / Double(max(1, report.diskTotalBytes))
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                        
                        HStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(McCleanTheme.textSecondary.opacity(0.55))
                                .frame(width: max(12, width * usedAfterFrac))
                            
                            if freedFrac > 0 {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(McCleanTheme.accentEmerald)
                                    .frame(width: max(10, width * min(0.35, max(0.03, freedFrac))))
                            }
                        }
                    }
                }
                .frame(height: 8)
                
                HStack(spacing: 16) {
                    HStack(spacing: 5) {
                        Circle().fill(McCleanTheme.textSecondary.opacity(0.55)).frame(width: 7, height: 7)
                        Text("Used Space").font(.system(size: 10, design: .monospaced)).foregroundStyle(McCleanTheme.textMuted)
                    }
                    HStack(spacing: 5) {
                        Circle().fill(McCleanTheme.accentEmerald).frame(width: 7, height: 7)
                        Text("Reclaimed (\(report.formattedTotalFreed))").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(McCleanTheme.accentEmerald)
                    }
                    HStack(spacing: 5) {
                        Circle().fill(Color.white.opacity(0.20)).frame(width: 7, height: 7)
                        Text("Free (\(report.formattedFreeAfter))").font(.system(size: 10, design: .monospaced)).foregroundStyle(McCleanTheme.textMuted)
                    }
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 8)
            
            if !report.failedItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(report.failedItems.count) item(s) skipped (protected or in use):")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(McCleanTheme.accentAmber)
                    ForEach(report.failedItems.prefix(3)) { fail in
                        Text("• \(fail.name): \(fail.reason)")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundStyle(McCleanTheme.textSecondary)
                    }
                }
                .padding(10)
                .background(McCleanTheme.accentAmber.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(McCleanTheme.inkDark)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(McCleanTheme.textPrimary)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 620)
        .background(McCleanTheme.windowBackground)
    }
}
