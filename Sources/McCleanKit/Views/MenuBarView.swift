import SwiftUI
import AppKit

/// Compact macOS Menu Bar widget showing live disk capacity and quick scan/cleanup triggers.
public struct MenuBarView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(McCleanTheme.brandGradient)
                        .frame(width: 28, height: 28)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                Text("McClean")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(McCleanTheme.textPrimary)
                
                Spacer()
                
                Text("\(viewModel.diskUsage.formattedFree) Free")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(McCleanTheme.accentEmerald.opacity(0.15), in: Capsule())
                    .foregroundStyle(McCleanTheme.accentEmerald)
            }
            
            // Circular Disk Gauge + Metrics
            HStack(spacing: 12) {
                CircularDiskGauge(
                    usedFraction: viewModel.diskUsage.usedFraction,
                    freeText: viewModel.diskUsage.formattedFree,
                    size: 46,
                    lineWidth: 6
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Macintosh HD")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                    Text("\(viewModel.diskUsage.formattedUsed) of \(viewModel.diskUsage.formattedTotal) used")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(McCleanTheme.textSecondary)
                }
                Spacer()
            }
            .padding(10)
            .glassCard(cornerRadius: 10)
            
            if viewModel.hasCompletedScan {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DISCOVERED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(McCleanTheme.textMuted)
                        Text(ByteCountFormatterHelper.format(bytes: viewModel.totalDiscoverableBytes))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(McCleanTheme.accentCyan)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("READY TO CLEAN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(McCleanTheme.textMuted)
                        Text(ByteCountFormatterHelper.format(bytes: viewModel.selectedToCleanBytes))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(McCleanTheme.accentEmerald)
                    }
                }
                .padding(.horizontal, 4)
            }
            
            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    viewModel.requestOrStartSmartScan()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: viewModel.isScanning ? "hourglass" : "bolt.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(viewModel.isScanning ? "Scanning..." : "Quick Scan")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(McCleanTheme.brandGradient, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isScanning)
                
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                } label: {
                    Text("Dashboard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(McCleanTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            
            Divider().overlay(McCleanTheme.borderSubtle)
            
            HStack {
                Text("Lifetime Freed: \(ByteCountFormatterHelper.format(bytes: Int64(viewModel.lifetimeBytesFreed)))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(McCleanTheme.textSecondary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(McCleanTheme.textMuted)
            }
        }
        .padding(14)
        .frame(width: 290)
        .background(McCleanTheme.canvasBackground)
        .preferredColorScheme(.dark)
    }
}
