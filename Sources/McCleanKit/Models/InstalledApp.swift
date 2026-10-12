import Foundation
import AppKit

/// Represents an installed macOS application (.app) along with its discovered support/cache/container directories.
public struct InstalledApp: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let bundleURL: URL
    public let name: String
    public let bundleIdentifier: String
    public let version: String
    public let appBundleSizeBytes: Int64
    public var relatedItems: [ScanItem]
    public var isSelectedForUninstall: Bool
    
    public init(
        id: UUID = UUID(),
        bundleURL: URL,
        name: String,
        bundleIdentifier: String,
        version: String = "1.0",
        appBundleSizeBytes: Int64,
        relatedItems: [ScanItem] = [],
        isSelectedForUninstall: Bool = false
    ) {
        self.id = id
        self.bundleURL = bundleURL
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.version = version
        self.appBundleSizeBytes = appBundleSizeBytes
        self.relatedItems = relatedItems
        self.isSelectedForUninstall = isSelectedForUninstall
    }
    
    public var relatedSupportBytes: Int64 {
        relatedItems.reduce(0) { $0 + $1.sizeBytes }
    }
    
    public var totalFootprintBytes: Int64 {
        appBundleSizeBytes + relatedSupportBytes
    }
    
    public var isSystemApp: Bool {
        let p = bundleURL.path
        if p.hasPrefix("/System/") || p.hasPrefix("/System/Applications") {
            return true
        }
        if p == "/Applications/Safari.app" || p.hasPrefix("/Applications/Utilities") {
            return true
        }
        return false
    }
    
    public var isSelfApp: Bool {
        if let mainID = Bundle.main.bundleIdentifier, !mainID.isEmpty, bundleIdentifier == mainID {
            return true
        }
        if bundleURL.standardizedFileURL.path == Bundle.main.bundleURL.standardizedFileURL.path {
            return true
        }
        return name.lowercased() == "mcclean" || bundleIdentifier == "com.mcclean.app"
    }
    
    public var isRunning: Bool {
        guard !bundleIdentifier.isEmpty else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }
    
    public var installLocationLabel: String {
        let p = bundleURL.path
        if isSystemApp { return "macOS System" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if p.hasPrefix(home) { return "~/Applications" }
        return "/Applications"
    }
    
    public var formattedTotalSize: String {
        ByteCountFormatterHelper.format(bytes: totalFootprintBytes)
    }
    
    public var formattedAppSize: String {
        ByteCountFormatterHelper.format(bytes: appBundleSizeBytes)
    }
    
    public var formattedSupportSize: String {
        ByteCountFormatterHelper.format(bytes: relatedSupportBytes)
    }
}
