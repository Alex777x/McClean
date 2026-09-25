import Foundation

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
