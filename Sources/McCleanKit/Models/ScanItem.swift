import Foundation
import SwiftUI

/// Classification of how safe a file or directory is to remove.
public enum SafetyLevel: String, Codable, CaseIterable, Equatable, Sendable {
    /// 100% safe to remove; system or app will recreate if needed (e.g., caches, logs, aerial video wallpapers).
    /// Checked by default.
    case safe = "Safe"
    
    /// Requires user confirmation; e.g., orphaned app leftovers, unknown dotfiles, or user downloads.
    /// Unchecked by default so the user explicitly chooses what to remove.
    case review = "Review"
    
    /// Critical user/system configuration (e.g., ~/.ssh, ~/.gnupg, ~/.aws, Keychains).
    /// Locked by default and blocked from accidental deletion.
    case protected = "Protected"
    
    public var badgeTitle: String {
        switch self {
        case .safe: return "Safe"
        case .review: return "Review"
        case .protected: return "Protected"
        }
    }
    
    public var iconName: String {
        switch self {
        case .safe: return "checkmark.shield.fill"
        case .review: return "exclamationmark.triangle.fill"
        case .protected: return "lock.shield.fill"
        }
    }
    
    public var defaultSelected: Bool {
        switch self {
        case .safe: return true
        case .review, .protected: return false
        }
    }
}

/// Primary navigation modules in McClean.
public enum NavigationSection: String, CaseIterable, Identifiable, Equatable, Sendable {
    case smartScan = "Smart Scan"
    case dotfiles = "Dotfiles (~/.*)"
    case appLeftovers = "App Leftovers"
    case systemAndDev = "Wallpapers & Junk"
    case largeFiles = "Large Files & Lens"
    
    public var id: String { rawValue }
    
    public var subtitle: String {
        switch self {
        case .smartScan:
            return "Full deep scan across hidden dotfiles, wallpapers, leftovers & caches"
        case .dotfiles:
            return "Hidden Unix dot-directories in your Home folder (~/.*, ~/.config)"
        case .appLeftovers:
            return "Orphaned remnants of uninstalled apps & complete app uninstaller"
        case .systemAndDev:
            return "4K/8K macOS Aerial wallpapers, app caches, logs & developer tools"
        case .largeFiles:
            return "Forgotten heavy files (.dmg, .pkg, videos) & Space Lens folder map"
        }
    }
    
    public var iconName: String {
        switch self {
        case .smartScan: return "sparkles"
        case .dotfiles: return "eye.trianglebadge.exclamationmark"
        case .appLeftovers: return "puzzlepiece.extension.fill"
        case .systemAndDev: return "sparkles.tv.fill"
        case .largeFiles: return "externaldrive.fill.badge.timemachine"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .smartScan: return Color(red: 0.22, green: 0.58, blue: 1.0)
        case .dotfiles: return Color(red: 0.68, green: 0.38, blue: 0.98)
        case .appLeftovers: return Color(red: 1.0, green: 0.58, blue: 0.18)
        case .systemAndDev: return Color(red: 0.12, green: 0.78, blue: 0.72)
        case .largeFiles: return Color(red: 0.96, green: 0.36, blue: 0.56)
        }
    }
}

/// High-level category grouping used in Smart Scan and Cleanup Charts.
public enum JunkCategory: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case wallpapersAndMedia = "macOS Wallpapers & Media"
    case hiddenDotfiles = "Hidden Dotfiles (~/.*)"
    case orphanedLeftovers = "Orphaned App Leftovers"
    case appAndBrowserCaches = "App & Browser Caches"
    case developerAndAICaches = "Developer & AI Caches"
    case logsAndDiagnostics = "Logs & Crash Reports"
    case largeFilesAndDownloads = "Large & Old Files"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .wallpapersAndMedia: return "sparkles.tv.fill"
        case .hiddenDotfiles: return "folder.fill.badge.gearshape"
        case .orphanedLeftovers: return "trash.slash.fill"
        case .appAndBrowserCaches: return "internaldrive.fill"
        case .developerAndAICaches: return "terminal.fill"
        case .logsAndDiagnostics: return "doc.text.magnifyingglass"
        case .largeFilesAndDownloads: return "arrow.down.doc.fill"
        }
    }
    
    public var description: String {
        switch self {
        case .wallpapersAndMedia:
            return "4K/8K Aerial video wallpapers downloaded by macOS and hidden wallpaper folders"
        case .hiddenDotfiles:
            return "Hidden dot-directories in your Home folder (e.g. .wallpaper, .cache, .npm, .config)"
        case .orphanedLeftovers:
            return "Data folders in ~/Library left behind by applications you already deleted"
        case .appAndBrowserCaches:
            return "Temporary application and browser caches that rebuild automatically"
        case .developerAndAICaches:
            return "Xcode DerivedData, package caches (npm, cargo, pip, brew) & local AI models"
        case .logsAndDiagnostics:
            return "Old application logs, diagnostic traces, and crash reports"
        case .largeFilesAndDownloads:
            return "Heavy archives, disk images (.dmg/.pkg), videos, and large downloads"
        }
    }
    
    public var chartColor: Color {
        switch self {
        case .wallpapersAndMedia: return Color(red: 0.12, green: 0.78, blue: 0.88)
        case .hiddenDotfiles: return Color(red: 0.68, green: 0.38, blue: 0.98)
        case .orphanedLeftovers: return Color(red: 1.0, green: 0.58, blue: 0.18)
        case .appAndBrowserCaches: return Color(red: 0.24, green: 0.56, blue: 1.0)
        case .developerAndAICaches: return Color(red: 0.38, green: 0.42, blue: 0.96)
        case .logsAndDiagnostics: return Color(red: 0.18, green: 0.82, blue: 0.62)
        case .largeFilesAndDownloads: return Color(red: 0.96, green: 0.36, blue: 0.56)
        }
    }
}

/// Represents a single scannable/cleanable file or folder on disk.
/// `formattedSize` and `displayPath` are precomputed at initialization to avoid main-thread formatter allocations during SwiftUI rendering.
public struct ScanItem: Identifiable, Hashable, Equatable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let sizeBytes: Int64
    public let formattedSize: String
    public let displayPath: String
    public let category: JunkCategory
    public let safetyLevel: SafetyLevel
    public let explanation: String
    public let associatedAppName: String?
    public let isOrphaned: Bool
    public let isDirectory: Bool
    public let lastModified: Date?
    public let fileCount: Int
    public var isSelected: Bool
    public var children: [ScanItem]
    public var aiAnalysis: String?
    
    public init(
        id: UUID = UUID(),
        url: URL,
        name: String? = nil,
        sizeBytes: Int64,
        category: JunkCategory,
        safetyLevel: SafetyLevel,
        explanation: String,
        associatedAppName: String? = nil,
        isOrphaned: Bool = false,
        isDirectory: Bool = true,
        lastModified: Date? = nil,
        fileCount: Int = 1,
        isSelected: Bool? = nil,
        children: [ScanItem] = [],
        aiAnalysis: String? = nil
    ) {
        self.id = id
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.sizeBytes = sizeBytes
        self.formattedSize = ByteCountFormatterHelper.format(bytes: sizeBytes)
        let rawPath = url.path
        let home = ByteCountFormatterHelper.homePath
        if rawPath.hasPrefix(home) {
            self.displayPath = "~" + rawPath.dropFirst(home.count)
        } else {
            self.displayPath = rawPath
        }
        self.category = category
        self.safetyLevel = safetyLevel
        self.explanation = explanation
        self.associatedAppName = associatedAppName
        self.isOrphaned = isOrphaned
        self.isDirectory = isDirectory
        self.lastModified = lastModified
        self.fileCount = fileCount
        self.isSelected = isSelected ?? safetyLevel.defaultSelected
        self.children = children
        self.aiAnalysis = aiAnalysis
    }
}

/// Fast, allocation-free byte formatting helper safe for concurrent use.
public enum ByteCountFormatterHelper {
    public static let homePath: String = FileManager.default.homeDirectoryForCurrentUser.path
    
    public static func format(bytes: Int64) -> String {
        let b = max(0, bytes)
        if b < 1024 {
            return "\(b) B"
        }
        let kb = Double(b) / 1000.0
        if kb < 1000.0 {
            return String(format: "%.0f KB", kb)
        }
        let mb = kb / 1000.0
        if mb < 1000.0 {
            return mb >= 100.0 ? String(format: "%.0f MB", mb) : String(format: "%.1f MB", mb)
        }
        let gb = mb / 1000.0
        if gb < 1000.0 {
            return String(format: "%.2f GB", gb)
        }
        let tb = gb / 1000.0
        return String(format: "%.2f TB", tb)
    }
}
