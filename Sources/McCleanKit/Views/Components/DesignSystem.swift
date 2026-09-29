import SwiftUI

/// Premium Light Theme Design System — Warm Cream Surfaces, SF Pro Typography, Muted Accents.
/// Applies insights from: redesign-existing-projects, high-end-visual-design, swiftui-expert-skill.
/// Single warm gray family, one accent palette, semantic tokens, Double-Bezel card architecture.
public enum McCleanTheme {
    // MARK: - Warm Cream Light Surfaces
    public static let windowBackground = Color(red: 0.976, green: 0.973, blue: 0.965)       // #F9F8F6 Warm Cream Canvas
    public static let canvasBackground = windowBackground
    public static let sidebarBackground = Color(red: 0.949, green: 0.945, blue: 0.929)      // #F2F1ED Warm Sidebar
    public static let cardBackground = Color.white                                            // #FFFFFF Clean Card
    public static let elevatedCardBackground = Color(red: 0.961, green: 0.957, blue: 0.941) // #F5F4F0 Active/Hover Card
    
    // MARK: - Crisp 1px Structural Hairlines (Dark Ink on Light)
    public static let subtleBorder = Color.black.opacity(0.06)
    public static let borderSubtle = subtleBorder
    public static let highlightBorder = Color.black.opacity(0.10)
    
    // MARK: - Typography Colors (High-Contrast on Light)
    public static let textPrimary = Color(red: 0.102, green: 0.102, blue: 0.094)            // #1A1A18 Dark Graphite
    public static let textSecondary = Color(red: 0.420, green: 0.416, blue: 0.400)          // #6B6A66 Warm Medium Gray
    public static let textMuted = Color(red: 0.620, green: 0.616, blue: 0.596)              // #9E9D98 Soft Stone
    public static let inkDark = Color.white                                                   // White text on dark buttons
    
    // MARK: - Saturated Semantic Accents (WCAG AA on Light Backgrounds)
    public static let accentCyan = Color(red: 0.20, green: 0.55, blue: 0.75)                // Deep Slate Blue
    public static let accentEmerald = Color(red: 0.22, green: 0.62, blue: 0.38)             // Deep Emerald
    public static let accentViolet = Color(red: 0.48, green: 0.38, blue: 0.72)              // Rich Violet
    public static let accentAmber = Color(red: 0.72, green: 0.56, blue: 0.18)               // Deep Ochre
    public static let accentCoral = Color(red: 0.78, green: 0.32, blue: 0.30)               // Rich Terracotta
    
    // MARK: - Dark Action Fills (Premium Dark Buttons on Light Canvas)
    public static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.102, green: 0.102, blue: 0.094),  // #1A1A18
            Color(red: 0.165, green: 0.165, blue: 0.149)   // #2A2A26
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    public static let brandGradient = primaryGradient
    
    public static let cleanActionGradient = LinearGradient(
        colors: [
            Color(red: 0.106, green: 0.420, blue: 0.227),  // #1B6B3A Deep Emerald
            Color(red: 0.082, green: 0.376, blue: 0.188)   // #156030
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let dangerGradient = LinearGradient(
        colors: [
            Color(red: 0.753, green: 0.188, blue: 0.188),  // #C03030 Vivid Red
            Color(red: 0.659, green: 0.157, blue: 0.157)   // #A82828
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
            return Color(red: 0.18, green: 0.52, blue: 0.62)   // Deeper teal for light bg
        case .developerAndAICaches:
            return accentEmerald
        case .logsAndDiagnostics:
            return Color(red: 0.68, green: 0.36, blue: 0.48)   // Deeper mauve for light bg
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
                    (tint ?? Color.black).opacity(0.06),
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
                    .fill(isChecked ? McCleanTheme.textPrimary : Color.black.opacity(0.03))
                    .frame(width: 18, height: 18)
                
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(
                        isChecked ? McCleanTheme.textPrimary : Color.black.opacity(0.15),
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
                .font(.system(size: 9, weight: .semibold))
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
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(McCleanTheme.textMuted)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.04))
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
                .stroke(Color.black.opacity(0.06), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
            
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: size * 0.22, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(McCleanTheme.textPrimary)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disk usage")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent used")
    }
}
