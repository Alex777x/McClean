import SwiftUI

/// Premium Utilitarian Minimalism + Native macOS 26 Liquid Glass Design System.
/// Enforces warm monochrome surfaces, editorial typography, muted pastel semantic tokens,
/// crisp 1px Bento borders, zero neon gradients/glows, and native `glassEffect` / `GlassEffectContainer`.
public enum McCleanTheme {
    // MARK: - Warm Monochrome Surfaces
    public static let windowBackground = Color(red: 0.067, green: 0.067, blue: 0.063)       // #111110 Warm Obsidian
    public static let canvasBackground = windowBackground
    public static let sidebarBackground = Color(red: 0.082, green: 0.082, blue: 0.075)      // #151513 Warm Graphite
    public static let cardBackground = Color(red: 0.102, green: 0.102, blue: 0.094)         // #1A1A18 Flat Bento Card
    public static let elevatedCardBackground = Color(red: 0.137, green: 0.137, blue: 0.125) // #232320 Selected Bento Card
    
    // MARK: - Crisp 1px Structural Hairlines
    public static let subtleBorder = Color.white.opacity(0.07)
    public static let borderSubtle = subtleBorder
    public static let highlightBorder = Color.white.opacity(0.16)
    
    // MARK: - Editorial Typography Colors
    public static let textPrimary = Color(red: 0.957, green: 0.953, blue: 0.937)            // #F4F3EF Warm Bone White
    public static let textSecondary = Color(red: 0.620, green: 0.616, blue: 0.596)          // #9E9D98 Muted Stone
    public static let textMuted = Color(red: 0.431, green: 0.427, blue: 0.408)              // #6E6D68 Subtle Charcoal Gray
    public static let inkDark = Color(red: 0.067, green: 0.067, blue: 0.063)                // #111110 High-contrast Ink
    
    // MARK: - Muted Pastel Semantic Accents (No Neon)
    public static let accentCyan = Color(red: 0.58, green: 0.74, blue: 0.86)                // Muted Slate Blue
    public static let accentEmerald = Color(red: 0.52, green: 0.76, blue: 0.60)             // Muted Sage Green
    public static let accentViolet = Color(red: 0.70, green: 0.64, blue: 0.84)              // Muted Lavender
    public static let accentAmber = Color(red: 0.86, green: 0.72, blue: 0.46)               // Muted Ochre Sand
    public static let accentCoral = Color(red: 0.86, green: 0.54, blue: 0.52)               // Muted Terracotta Rose
    
    // MARK: - Flat Utilitarian Fills (Replacing Neon Gradients)
    public static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.94, green: 0.93, blue: 0.90),
            Color(red: 0.88, green: 0.87, blue: 0.84)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    public static let brandGradient = primaryGradient
    
    public static let cleanActionGradient = LinearGradient(
        colors: [
            Color(red: 0.24, green: 0.42, blue: 0.30),
            Color(red: 0.20, green: 0.36, blue: 0.26)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let dangerGradient = LinearGradient(
        colors: [
            Color(red: 0.52, green: 0.22, blue: 0.22),
            Color(red: 0.44, green: 0.18, blue: 0.18)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Desaturated Category & Safety Palettes
    public static func color(for category: JunkCategory) -> Color {
        switch category {
        case .wallpapersAndMedia:
            return accentViolet
        case .hiddenDotfiles:
            return accentCyan
        case .orphanedLeftovers:
            return accentAmber
        case .appAndBrowserCaches:
            return Color(red: 0.64, green: 0.76, blue: 0.82)
        case .developerAndAICaches:
            return accentEmerald
        case .logsAndDiagnostics:
            return Color(red: 0.80, green: 0.62, blue: 0.68)
        case .largeFilesAndDownloads:
            return accentCoral
        }
    }
    
    public static func color(for safety: SafetyLevel) -> Color {
        switch safety {
        case .safe:
            return accentEmerald
        case .review:
            return accentAmber
        case .protected:
            return accentCyan
        }
    }
    
    public static func color(for section: NavigationSection) -> Color {
        switch section {
        case .smartScan:
            return textPrimary
        case .dotfiles:
            return accentCyan
        case .appLeftovers:
            return accentAmber
        case .systemAndDev:
            return accentEmerald
        case .largeFiles:
            return accentCoral
        }
    }
}

// MARK: - Native macOS 26+ Liquid Glass Containers & Modifiers

/// Wraps grouped glass elements in `GlassEffectContainer` on macOS 26+ for optical blending and morphing performance.
public struct LiquidGlassGroup<Content: View>: View {
    public let spacing: CGFloat
    @ViewBuilder public let content: () -> Content
    
    public init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

public extension View {
    /// Applies a flat Utilitarian Bento card with crisp 8–10px radius and 1px border (no heavy drop shadows).
    func glassCard(cornerRadius: CGFloat = 10) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(McCleanTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
            )
    }
    
    /// Applies native macOS 26 Liquid Glass in a rounded rectangle shape, with a subtle material fallback on earlier macOS.
    @ViewBuilder
    func liquidGlassRect(
        cornerRadius: CGFloat = 10,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(interactive), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular.interactive(interactive), in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
                )
        }
    }
    
    /// Applies native macOS 26 Liquid Glass in a capsule shape for interactive filter pills and floating action bars.
    @ViewBuilder
    func liquidGlassCapsule(
        tint: Color? = nil,
        interactive: Bool = true
    ) -> some View {
        if #available(macOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint).interactive(interactive), in: .capsule)
            } else {
                self.glassEffect(.regular.interactive(interactive), in: .capsule)
            }
        } else {
            self
                .background(
                    (tint ?? Color.white).opacity(0.10),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
                )
        }
    }
}

// MARK: - Reusable Minimalist & Liquid Glass Components

/// Tactile minimalist checkbox with crisp 5px corner radius and full accessibility traits.
public struct GlassCheckbox: View {
    public let isChecked: Bool
    public let accentColor: Color
    public let action: () -> Void
    
    public init(
        isChecked: Bool,
        accentColor: Color = McCleanTheme.textPrimary,
        action: @escaping () -> Void
    ) {
        self.isChecked = isChecked
        self.accentColor = accentColor
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isChecked ? McCleanTheme.textPrimary : Color.white.opacity(0.03))
                    .frame(width: 18, height: 18)
                
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        isChecked ? McCleanTheme.textPrimary : Color.white.opacity(0.22),
                        lineWidth: 1
                    )
                    .frame(width: 18, height: 18)
                
                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(McCleanTheme.inkDark)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isChecked ? "Selected" : "Not selected")
        .accessibilityAddTraits(.isButton)
    }
}

/// Editorial status pill badge using desaturated pastel foreground and subtle washed background.
public struct SafetyBadgePill: View {
    public let level: SafetyLevel
    
    public init(level: SafetyLevel) {
        self.level = level
    }
    
    public var body: some View {
        let color = McCleanTheme.color(for: level)
        HStack(spacing: 4) {
            Image(systemName: level.iconName)
                .font(.system(size: 8.5, weight: .semibold))
            Text(level.badgeTitle.uppercased())
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(color.opacity(0.11), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.26), lineWidth: 1)
        )
        .foregroundStyle(color)
    }
}

/// Monospace physical keystroke badge (`<kbd>` aesthetic from minimalist-ui).
public struct KeycapBadge: View {
    public let label: String
    
    public init(_ label: String) {
        self.label = label
    }
    
    public var body: some View {
        Text(label)
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundStyle(McCleanTheme.textMuted)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(McCleanTheme.subtleBorder, lineWidth: 1)
            )
    }
}

/// Minimalist monochrome circular storage ring gauge (no rainbow angular gradients).
public struct CircularDiskGauge: View {
    public let fraction: Double
    public let size: CGFloat
    public let lineWidth: CGFloat
    
    public init(fraction: Double, size: CGFloat = 44, lineWidth: CGFloat = 4) {
        self.fraction = min(max(fraction, 0), 1)
        self.size = size
        self.lineWidth = lineWidth
    }
    
    public init(usedFraction: Double, freeText: String = "", size: CGFloat = 44, lineWidth: CGFloat = 4) {
        self.fraction = min(max(usedFraction, 0), 1)
        self.size = size
        self.lineWidth = lineWidth
    }
    
    private var ringColor: Color {
        if fraction > 0.88 {
            return McCleanTheme.accentCoral
        } else if fraction > 0.75 {
            return McCleanTheme.accentAmber
        }
        return McCleanTheme.textPrimary
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
            
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: size * 0.22, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(McCleanTheme.textPrimary)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disk usage")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent used")
    }
}
