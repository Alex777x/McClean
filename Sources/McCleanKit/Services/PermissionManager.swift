import Foundation
import AppKit
import Photos

/// Status of an optional permission scope in McClean.
public enum PermissionScopeStatus: String, Sendable {
    case granted = "Granted"
    case notGranted = "Optional (Skipped)"
    case denied = "Declined (Skipped Safely)"
}

/// Centralized guard that prevents scanners from touching macOS TCC traps (`Containers`, `Group Containers`,
/// `com.apple.*` private app data, `Photos Library.photoslibrary`, Mail, Messages, Safari, etc.)
/// that would otherwise trigger macOS "blocked from accessing data from other apps" notifications.
public enum TCCGuard {
    
    /// Package extensions that trigger macOS Photos / Media Library TCC prompts and should never be traversed inside.
    public static let protectedPackageExtensions: Set<String> = [
        "photoslibrary",
        "photolibrary",
        "aplibrary",
        "migratedphotolibrary",
        "musiclibrary",
        "tvlibrary",
        "theater"
    ]
    
    /// Subdirectories inside `~/Library` that are protected by macOS TCC / App Data Management.
    /// Touching these without explicit Full Disk Access causes macOS Sequoia/27 to display "blocked" notifications.
    public static let protectedLibraryFolderNames: Set<String> = [
        "accounts",
        "addressbook",
        "apple",
        "assistant",
        "autosave information",
        "biome",
        "calendars",
        "callhistorydb",
        "callhistorytransactions",
        "clouddocs",
        "com.apple.icloud.searchpartyd",
        "container",
        "containers",
        "cookies",
        "corefollowup",
        "coredata",
        "daemon containers",
        "dataaccess",
        "differentialprivacy",
        "diagnosticreports",
        "donotdisturb",
        "facetime",
        "familycircle",
        "fileprovider",
        "finance",
        "followup",
        "group containers",
        "homekit",
        "identityservices",
        "intents",
        "intelligenceplatform",
        "keychains",
        "knowledge",
        "mail",
        "maps",
        "messages",
        "metadata",
        "mobile documents",
        "mobilesync",
        "notes",
        "passkit",
        "passes",
        "personalizationportrait",
        "personas",
        "photos",
        "reminders",
        "routined",
        "safari",
        "safarishared",
        "sharing",
        "shortcuts",
        "siri",
        "stagedextensions",
        "statuskit",
        "suggestions",
        "syncservices",
        "systemmigration",
        "trial",
        "ubiquity",
        "voicetrigger",
        "weather"
    ]
    
    /// Safe Apple-owned cache/support folders that do NOT trigger TCC blocks and are legitimate developer/wallpaper caches.
    public static let allowedAppleFolderNames: Set<String> = [
        "com.apple.dt.xcode",
        "com.apple.dt.instruments",
        "com.apple.wallpaper"
    ]
    
    /// Returns `true` if a URL must be completely skipped during scanning to avoid macOS TCC blocks or notifications.
    public static func shouldSkipTraversal(of url: URL, allowPhotosLibrary: Bool = false) -> Bool {
        let ext = url.pathExtension.lowercased()
        if protectedPackageExtensions.contains(ext) {
            return !allowPhotosLibrary
        }
        
        let nameLower = url.lastPathComponent.lowercased()
        if nameLower == ".trash" || nameLower == ".spotlight-v100" || nameLower == ".fseventsd" {
            return true
        }
        
        let pathLower = url.standardizedFileURL.path.lowercased()
            .replacingOccurrences(of: "/library/containers/com.mcclean.app/data", with: "")
        
        // Never walk raw ~/Library in Space Lens or general file scanners
        if pathLower.contains("/library/") {
            if protectedLibraryFolderNames.contains(nameLower) {
                return true
            }
            
            // Block any path inside ~/Library/Containers, Group Containers, Daemon Containers, etc.
            for blocked in [
                "/library/containers",
                "/library/group containers",
                "/library/daemon containers",
                "/library/application support/addressbook",
                "/library/application support/clouddocs",
                "/library/application support/fileprovider",
                "/library/application support/knowledge",
                "/library/application support/mobilesync",
                "/library/application support/syncservices",
                "/library/application support/ubiquity",
                "/library/application support/com.apple.tcc",
                "/library/application support/differentialprivacy",
                "/library/caches/cloudkit",
                "/library/caches/familycircle",
                "/library/logs/diagnosticreports",
                "/library/diagnosticreports",
                "/library/safari",
                "/library/mail",
                "/library/messages",
                "/library/calendars",
                "/library/reminders",
                "/library/photos",
                "/library/homekit"
            ] {
                if pathLower.contains(blocked) {
                    return true
                }
            }
            
            // On macOS Sequoia / macOS 27, com.apple.* folders inside Caches/Application Support/HTTPStorages/SavedState
            // are protected by App Data Management TCC and trigger top-right "blocked" banners.
            if (nameLower.hasPrefix("com.apple.") || nameLower.hasPrefix("apple.") || nameLower.hasPrefix("group.com.apple.") || nameLower.hasPrefix("systemgroup.com.apple.")) {
                if !allowedAppleFolderNames.contains(nameLower) {
                    return true
                }
            }
        }
        
        return false
    }
}

/// Manages user-driven permission requests, Security-Scoped Bookmarks, and graceful fallback when optional permissions
/// (such as Photos, Desktop, Documents, or Downloads) are not granted.
@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    private let bookmarkStorageKey = "com.mcclean.securityScopedBookmarks"
    private let onboardingCompleteKey = "com.mcclean.permissionOnboardingComplete"
    private let includePhotosKey = "com.mcclean.includePhotosLibrary"
    
    private var activeSecurityScopedURLs: [URL] = []
    
    @Published public var hasCompletedPermissionOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedPermissionOnboarding, forKey: onboardingCompleteKey) }
    }
    @Published public var includePhotosLibrary: Bool {
        didSet { UserDefaults.standard.set(includePhotosLibrary, forKey: includePhotosKey) }
    }
    
    @Published public private(set) var hasHomeBookmark: Bool = false
    public var hasHomeAccess: Bool { hasHomeBookmark }
    @Published public private(set) var hasFullDiskAccess: Bool = false
    @Published public private(set) var grantedPaths: [String] = []
    
    // Granular optional scope statuses
    @Published public private(set) var downloadsStatus: PermissionScopeStatus = .notGranted
    @Published public private(set) var desktopStatus: PermissionScopeStatus = .notGranted
    @Published public private(set) var documentsStatus: PermissionScopeStatus = .notGranted
    @Published public private(set) var photosStatus: PermissionScopeStatus = .notGranted
    
    public init() {
        let defaults = UserDefaults.standard
        self.hasCompletedPermissionOnboarding = defaults.bool(forKey: onboardingCompleteKey)
        self.includePhotosLibrary = defaults.bool(forKey: includePhotosKey)
        restoreSavedBookmarks()
        updateScopeStatusesWithoutPrompting()
    }
    
    /// Checks current permission statuses WITHOUT touching any TCC-prompting directories.
    public func updateScopeStatusesWithoutPrompting() {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let hasHomeGrant = grantedPaths.contains { path in
            let std = URL(fileURLWithPath: path).standardizedFileURL.path
            return std == homePath || std == "/"
        }
        self.hasHomeBookmark = hasHomeGrant
        
        // Check if specific folders were granted via NSOpenPanel bookmark
        self.downloadsStatus = isFolderGrantedByBookmark(named: "Downloads") ? .granted : .notGranted
        self.desktopStatus = isFolderGrantedByBookmark(named: "Desktop") ? .granted : .notGranted
        self.documentsStatus = isFolderGrantedByBookmark(named: "Documents") ? .granted : .notGranted
        
        // Check Photos authorization status purely via PHPhotoLibrary.authorizationStatus (never triggers a prompt!)
        let auth = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch auth {
        case .authorized, .limited:
            self.photosStatus = .granted
        case .denied, .restricted:
            self.photosStatus = .denied
        case .notDetermined:
            self.photosStatus = .notGranted
        @unknown default:
            self.photosStatus = .notGranted
        }
        
        // Check non-TCC-prompting system wallpaper folder readability in background
        Task.detached(priority: .utility) {
            let idleAssetsReadable = FileManager.default.isReadableFile(
                atPath: "/Library/Application Support/com.apple.idleassetsd/Customer"
            )
            await MainActor.run {
                PermissionManager.shared.hasFullDiskAccess = idleAssetsReadable
            }
        }
    }
    
    public func refreshPermissionStatus() {
        updateScopeStatusesWithoutPrompting()
    }
    
    /// Returns true if the user granted access to `~`, `/`, or the specific folder via `NSOpenPanel` bookmark.
    public func isFolderGrantedByBookmark(named folderName: String) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        let target = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(folderName)
            .standardizedFileURL.path
        
        return grantedPaths.contains { granted in
            let std = URL(fileURLWithPath: granted).standardizedFileURL.path
            return std == "/" || std == home || std == target || target.hasPrefix(std + "/")
        }
    }
    
    /// Non-Snapshots snapshot of granted paths for background scanners.
    nonisolated public static func currentGrantedBookmarkPaths() -> Set<String> {
        let stored = UserDefaults.standard.dictionary(forKey: "com.mcclean.securityScopedBookmarks") as? [String: Data] ?? [:]
        return Set(stored.keys.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
    }
    
    /// Checks whether a background scanner has bookmark permission for a protected user folder (`Downloads`, `Desktop`, `Documents`).
    /// Avoiding unbookmarked enumeration of these folders prevents unexpected macOS TCC blocks/dialogs.
    nonisolated public static func canAccessUserFolder(_ folderURL: URL, bookmarkPaths: Set<String>) -> Bool {
        let target = folderURL.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        if bookmarkPaths.contains("/") || bookmarkPaths.contains(home) || bookmarkPaths.contains(target) {
            return true
        }
        for granted in bookmarkPaths {
            if target.hasPrefix(granted + "/") {
                return true
            }
        }
        return false
    }
    
    /// Opens a standard macOS `NSOpenPanel` so the user can officially grant access to their Home folder (`~`) or a specific folder.
    /// Because `NSOpenPanel` is user-driven through macOS Powerbox, it grants access cleanly without "blocked" notifications.
    @discardableResult
    public func requestDiskAccessViaOpenPanel(defaultDirectory: URL? = nil) -> Bool {
        let panel = NSOpenPanel()
        panel.title = "Grant McClean Folder Access"
        panel.message = "Click 'Grant Access' to allow McClean to scan your Home folder (including Downloads, Desktop, Documents, and ~/.* dotfiles). You can also select a single folder or click Cancel — McClean works smoothly even with partial permissions."
        panel.prompt = "Grant Access"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.showsHiddenFiles = false
        panel.directoryURL = defaultDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        
        let response = panel.runModal()
        guard response == .OK else {
            return false
        }
        
        for url in panel.urls {
            saveSecurityScopedBookmark(for: url)
        }
        hasCompletedPermissionOnboarding = true
        updateScopeStatusesWithoutPrompting()
        return true
    }
    
    /// Requests access to a specific user folder (`Downloads`, `Desktop`, `Documents`) via `NSOpenPanel`.
    @discardableResult
    public func requestAccessToUserFolder(named folderName: String) -> Bool {
        let folderURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(folderName)
        return requestDiskAccessViaOpenPanel(defaultDirectory: folderURL)
    }
    
    /// Explicitly requests macOS Photos Library permission only if the user clicks the button in McClean.
    /// If the user declines, McClean records `.denied` and continues working without Photos access.
    public func requestOptionalPhotosPermission() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            Task { @MainActor in
                switch status {
                case .authorized, .limited:
                    self.photosStatus = .granted
                    self.includePhotosLibrary = true
                default:
                    self.photosStatus = .denied
                    self.includePhotosLibrary = false
                }
            }
        }
    }
    
    /// Marks permission onboarding as complete so the user can scan immediately without granting extra permissions.
    public func continueWithLimitedPermissions() {
        hasCompletedPermissionOnboarding = true
        updateScopeStatusesWithoutPrompting()
    }
    
    /// Opens macOS System Settings -> Privacy & Security -> Files and Folders (or Full Disk Access).
    public func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func saveSecurityScopedBookmark(for url: URL) {
        let stdPath = url.standardizedFileURL.path
        do {
            let bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var stored = UserDefaults.standard.dictionary(forKey: bookmarkStorageKey) as? [String: Data] ?? [:]
            stored[stdPath] = bookmarkData
            UserDefaults.standard.set(stored, forKey: bookmarkStorageKey)
            
            if url.startAccessingSecurityScopedResource() {
                activeSecurityScopedURLs.append(url)
            }
            grantedPaths = Array(stored.keys).sorted()
        } catch {
            var stored = UserDefaults.standard.dictionary(forKey: bookmarkStorageKey) as? [String: Data] ?? [:]
            if let regularBookmark = try? url.bookmarkData() {
                stored[stdPath] = regularBookmark
                UserDefaults.standard.set(stored, forKey: bookmarkStorageKey)
            } else {
                stored[stdPath] = Data()
                UserDefaults.standard.set(stored, forKey: bookmarkStorageKey)
            }
            grantedPaths = Array(stored.keys).sorted()
        }
    }
    
    private func restoreSavedBookmarks() {
        guard let stored = UserDefaults.standard.dictionary(forKey: bookmarkStorageKey) as? [String: Data] else {
            return
        }
        var activePaths: [String] = []
        for (path, data) in stored {
            var isStale = false
            if !data.isEmpty,
               let resolvedURL = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
               ) {
                if resolvedURL.startAccessingSecurityScopedResource() {
                    activeSecurityScopedURLs.append(resolvedURL)
                }
                activePaths.append(resolvedURL.standardizedFileURL.path)
            } else {
                activePaths.append(URL(fileURLWithPath: path).standardizedFileURL.path)
            }
        }
        self.grantedPaths = Array(Set(activePaths)).sorted()
    }
}
