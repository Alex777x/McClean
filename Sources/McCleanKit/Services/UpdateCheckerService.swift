import Foundation
import AppKit

/// Lightweight update checker querying GitHub Releases API for non-App-Store (Open Source / Direct) builds.
/// Automatically compiled out when building with `-DAPP_STORE` to comply with Mac App Store Review Guideline 2.4.5(vi).
@MainActor
public final class UpdateCheckerService: ObservableObject {
    public static let shared = UpdateCheckerService()
    
    /// Default GitHub repository slug (`owner/repo`).
    public var repositorySlug: String = "Alex777x/McClean"
    
    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var statusMessage: String?
    
    public var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    public var repositoryURL: URL {
        URL(string: "https://github.com/\(repositorySlug)")!
    }
    
    private init() {}
    
    public func openRepositoryPage() {
        NSWorkspace.shared.open(repositoryURL)
    }
    
    public func checkForUpdates(showAlertIfUpToDate: Bool = true) {
        #if APP_STORE
        // Mac App Store builds receive automatic updates directly via macOS App Store.
        return
        #else
        guard !isChecking else { return }
        isChecking = true
        statusMessage = "Checking GitHub Releases..."
        
        let endpoint = URL(string: "https://api.github.com/repos/\(repositorySlug)/releases/latest")!
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 8
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("McClean/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        
        Task {
            defer { isChecking = false }
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    statusMessage = "Unable to reach GitHub Releases."
                    return
                }
                
                if http.statusCode == 404 {
                    statusMessage = "Up to date (v\(currentVersion))"
                    if showAlertIfUpToDate {
                        presentUpToDateAlert(note: "You are running McClean v\(currentVersion), the latest version.")
                    }
                    return
                }
                
                guard http.statusCode == 200 else {
                    statusMessage = "Update check returned HTTP \(http.statusCode)."
                    return
                }
                
                let release = try JSONDecoder().decode(GitHubReleaseResponse.self, from: data)
                let latestVersion = Self.normalizeVersion(release.tagName)
                let localVersion = Self.normalizeVersion(currentVersion)
                
                if Self.isVersion(latestVersion, newerThan: localVersion) {
                    statusMessage = "Update available: v\(latestVersion)"
                    presentUpdateAvailableAlert(
                        latestVersion: latestVersion,
                        releaseNotes: release.body ?? "Bug fixes and performance improvements.",
                        htmlURL: URL(string: release.htmlURL) ?? repositoryURL
                    )
                } else {
                    statusMessage = "Up to date (v\(currentVersion))"
                    if showAlertIfUpToDate {
                        presentUpToDateAlert(note: "McClean v\(currentVersion) is currently the newest version available.")
                    }
                }
            } catch {
                statusMessage = "Offline — running v\(currentVersion)"
                if showAlertIfUpToDate {
                    presentUpToDateAlert(note: "McClean v\(currentVersion) is installed. Could not reach GitHub Releases (\(error.localizedDescription)).")
                }
            }
        }
        #endif
    }
    
    // MARK: - Version Comparison Helpers
    
    public nonisolated static func normalizeVersion(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }
    
    public nonisolated static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let candidateParts = normalizeVersion(candidate).split(separator: ".").compactMap { Int($0) }
        let currentParts = normalizeVersion(current).split(separator: ".").compactMap { Int($0) }
        let count = max(candidateParts.count, currentParts.count)
        for idx in 0..<count {
            let cVal = idx < candidateParts.count ? candidateParts[idx] : 0
            let curVal = idx < currentParts.count ? currentParts[idx] : 0
            if cVal > curVal { return true }
            if cVal < curVal { return false }
        }
        return false
    }
    
    // MARK: - Native Alerts
    
    private func presentUpToDateAlert(note: String) {
        let alert = NSAlert()
        alert.messageText = "You’re Up to Date"
        alert.informativeText = note
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func presentUpdateAvailableAlert(latestVersion: String, releaseNotes: String, htmlURL: URL) {
        let alert = NSAlert()
        alert.messageText = "McClean v\(latestVersion) is Available"
        let trimmedNotes = releaseNotes.count > 420 ? String(releaseNotes.prefix(420)) + "…" : releaseNotes
        alert.informativeText = "You are currently on v\(currentVersion).\n\n\(trimmedNotes)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download from GitHub")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(htmlURL)
        }
    }
}

private struct GitHubReleaseResponse: Decodable {
    let tagName: String
    let htmlURL: String
    let body: String?
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}
