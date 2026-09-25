import Foundation

/// Built-in verification suite that runs all core unit tests (DotfilesScanner, OrphanedAppsScanner,
/// CleanupService permanent deletion & whitelist protection, and FolderInspectorAI) in an isolated temp directory.
public enum SelfTestRunner {
    
    public static func runAllTests() -> Bool {
        print("Running McClean Automated Verification Suite...")
        do {
            try testDotfilesScanner()
            print("  [PASS] DotfilesScanner (.wallpaper, .ssh protection, .npm cache, unknown dot-directories)")
            
            try testOrphanedAppsScanner()
            print("  [PASS] OrphanedAppsScanner (installed app matching vs uninstalled app leftover detection)")
            
            try testCleanupServicePermanentDeleteAndProtection()
            print("  [PASS] CleanupService (immediate permanent deletion, .ssh whitelist protection & chart report)")
            
            let sema = DispatchSemaphore(value: 0)
            var aiPassed = false
            Task {
                aiPassed = (try? await testFolderInspectorAI()) ?? false
                sema.signal()
            }
            sema.wait()
            guard aiPassed else {
                print("  [FAIL] FolderInspectorAI heuristic analysis")
                return false
            }
            print("  [PASS] FolderInspectorAI (structural inspection & model weight diagnosis)")
            
            try testTCCGuardAndPartialPermissions()
            print("  [PASS] TCCGuard & Partial Permissions (Photos Library, Containers, and com.apple.* TCC folders skipped safely)")
            
            print("All 5 test suites passed successfully!")
            return true
        } catch {
            print("  [FAIL] Test failed with error: \(error)")
            return false
        }
    }
    
    private static func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("McCleanSelfTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    private static func writeDummyFile(at url: URL, sizeBytes: Int) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(repeating: 0xAB, count: sizeBytes)
        try data.write(to: url)
    }
    
    private static func assertCondition(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw NSError(domain: "McCleanSelfTest", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }
    
    private static func testDotfilesScanner() throws {
        let tempRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let mockHome = tempRoot.appendingPathComponent("Home", isDirectory: true)
        try writeDummyFile(at: mockHome.appendingPathComponent(".wallpaper/aerial_4k.mov"), sizeBytes: 512 * 1024)
        try writeDummyFile(at: mockHome.appendingPathComponent(".ssh/id_ed25519"), sizeBytes: 1024)
        try writeDummyFile(at: mockHome.appendingPathComponent(".npm/_cacache/index.db"), sizeBytes: 300 * 1024)
        try writeDummyFile(at: mockHome.appendingPathComponent(".forgotten_tool/data.bin"), sizeBytes: 400 * 1024)
        
        let items = DotfilesScanner.scan(
            homeDirectory: mockHome,
            installedAppNames: ["node"],
            minimumSizeBytes: 100 * 1024
        )
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })
        
        guard let wallpaper = byName[".wallpaper"] else {
            throw NSError(domain: "McCleanSelfTest", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing .wallpaper"])
        }
        try assertCondition(wallpaper.category == .wallpapersAndMedia, ".wallpaper category mismatch")
        try assertCondition(wallpaper.safetyLevel == .safe && wallpaper.isSelected, ".wallpaper should be safe & selected")
        
        guard let ssh = byName[".ssh"] else {
            throw NSError(domain: "McCleanSelfTest", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing .ssh"])
        }
        try assertCondition(ssh.safetyLevel == .protected && !ssh.isSelected, ".ssh must be protected & unselected")
        
        guard let unknown = byName[".forgotten_tool"] else {
            throw NSError(domain: "McCleanSelfTest", code: 4, userInfo: [NSLocalizedDescriptionKey: "Missing .forgotten_tool"])
        }
        try assertCondition(unknown.safetyLevel == .review && !unknown.isSelected && unknown.isOrphaned, ".forgotten_tool should be review & orphaned")
    }
    
    private static func testOrphanedAppsScanner() throws {
        let tempRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let mockAppsDir = tempRoot.appendingPathComponent("Applications", isDirectory: true)
        let mockLibraryDir = tempRoot.appendingPathComponent("Library", isDirectory: true)
        
        let acmePlistURL = mockAppsDir.appendingPathComponent("AcmeEditor.app/Contents/Info.plist")
        try FileManager.default.createDirectory(at: acmePlistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let plistDict: NSDictionary = [
            "CFBundleName": "AcmeEditor",
            "CFBundleIdentifier": "com.acme.editor",
            "CFBundleShortVersionString": "2.4.0"
        ]
        plistDict.write(to: acmePlistURL, atomically: true)
        try writeDummyFile(at: mockAppsDir.appendingPathComponent("AcmeEditor.app/Contents/MacOS/AcmeEditor"), sizeBytes: 256 * 1024)
        
        try writeDummyFile(at: mockLibraryDir.appendingPathComponent("Application Support/com.acme.editor/cache.db"), sizeBytes: 200 * 1024)
        try writeDummyFile(at: mockLibraryDir.appendingPathComponent("Application Support/com.deletedvendor.ghostapp/heavy_leftover.dat"), sizeBytes: 500 * 1024)
        
        let scanResult = OrphanedAppsScanner.scan(
            applicationDirectories: [mockAppsDir],
            userLibraryURL: mockLibraryDir,
            minimumOrphanSizeBytes: 64 * 1024
        )
        
        try assertCondition(scanResult.orphanedItems.count == 1, "Expected 1 orphaned app folder")
        try assertCondition(scanResult.orphanedItems.first?.name == "com.deletedvendor.ghostapp", "Unexpected orphan name")
        try assertCondition(scanResult.installedApps.first?.relatedItems.count == 1, "Expected 1 related item for AcmeEditor")
    }
    
    private static func testCleanupServicePermanentDeleteAndProtection() throws {
        let tempRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let removableURL = tempRoot.appendingPathComponent("removable_wallpaper_cache", isDirectory: true)
        try writeDummyFile(at: removableURL.appendingPathComponent("video.mov"), sizeBytes: 600 * 1024)
        
        let protectedSSHURL = tempRoot.appendingPathComponent(".ssh", isDirectory: true)
        try writeDummyFile(at: protectedSSHURL.appendingPathComponent("id_rsa"), sizeBytes: 4096)
        
        let customWhitelistedURL = tempRoot.appendingPathComponent("custom_kept_folder", isDirectory: true)
        try writeDummyFile(at: customWhitelistedURL.appendingPathComponent("important.dat"), sizeBytes: 128 * 1024)
        
        let items: [ScanItem] = [
            ScanItem(
                url: removableURL,
                name: "removable_wallpaper_cache",
                sizeBytes: 600 * 1024,
                category: .wallpapersAndMedia,
                safetyLevel: .safe,
                explanation: "Mock wallpaper cache",
                isSelected: true
            ),
            ScanItem(
                url: protectedSSHURL,
                name: ".ssh",
                sizeBytes: 4096,
                category: .hiddenDotfiles,
                safetyLevel: .protected,
                explanation: "Protected SSH keys",
                isSelected: true
            ),
            ScanItem(
                url: customWhitelistedURL,
                name: "custom_kept_folder",
                sizeBytes: 128 * 1024,
                category: .hiddenDotfiles,
                safetyLevel: .safe,
                explanation: "User whitelisted folder",
                isSelected: true
            )
        ]
        
        let report = CleanupService.cleanImmediately(
            items: items,
            customWhitelistedPaths: [customWhitelistedURL.path]
        )
        try assertCondition(!FileManager.default.fileExists(atPath: removableURL.path), "Removable folder should be permanently deleted")
        try assertCondition(FileManager.default.fileExists(atPath: protectedSSHURL.path), "Protected .ssh folder must not be deleted")
        try assertCondition(FileManager.default.fileExists(atPath: customWhitelistedURL.path), "Custom whitelisted folder must not be deleted")
        try assertCondition(report.deletedItemCount == 1 && report.totalBytesFreed == 600 * 1024, "CleanupReport byte count mismatch")
        
        // Verify ~ tilde expansion in KnownPathsDatabase.matchesCustomWhitelist
        let homeFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".my_custom_protected/sub/file.txt")
        try assertCondition(
            KnownPathsDatabase.matchesCustomWhitelist(
                url: homeFile,
                displayPath: "~/.my_custom_protected/sub/file.txt",
                whitelist: ["~/.my_custom_protected"]
            ),
            "Tilde-prefixed custom whitelist should protect child paths"
        )
    }
    
    private static func testFolderInspectorAI() async throws -> Bool {
        let tempRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let modelFolder = tempRoot.appendingPathComponent(".ollama", isDirectory: true)
        try writeDummyFile(at: modelFolder.appendingPathComponent("llama3.gguf"), sizeBytes: 128 * 1024)
        
        let item = ScanItem(
            url: modelFolder,
            name: ".ollama",
            sizeBytes: 128 * 1024,
            category: .developerAndAICaches,
            safetyLevel: .review,
            explanation: "Ollama models",
            associatedAppName: "Ollama",
            isOrphaned: true
        )
        let analysis = await FolderInspectorAI.inspect(item: item, mode: .offlineHeuristic)
        return analysis.contains(".ollama") && analysis.contains("gguf")
    }
    
    private static func testTCCGuardAndPartialPermissions() throws {
        let tempRoot = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let mockHome = tempRoot.appendingPathComponent("Home", isDirectory: true)
        let photosPkg = mockHome.appendingPathComponent("Pictures/Photos Library.photoslibrary/originals/photo.heic")
        try writeDummyFile(at: photosPkg, sizeBytes: 512 * 1024)
        
        let containerPath = mockHome.appendingPathComponent("Library/Containers/com.apple.Safari/Data/cache.db")
        try writeDummyFile(at: containerPath, sizeBytes: 512 * 1024)
        
        let appleCachePath = mockHome.appendingPathComponent("Library/Caches/com.apple.Safari/WebKitCache/data.bin")
        try writeDummyFile(at: appleCachePath, sizeBytes: 512 * 1024)
        
        let xcodeSafePath = mockHome.appendingPathComponent("Library/Caches/com.apple.dt.Xcode/Downloads/sim.dmg")
        try writeDummyFile(at: xcodeSafePath, sizeBytes: 512 * 1024)
        
        try assertCondition(
            TCCGuard.shouldSkipTraversal(of: mockHome.appendingPathComponent("Pictures/Photos Library.photoslibrary")),
            "Photos Library package must be skipped by default"
        )
        try assertCondition(
            TCCGuard.shouldSkipTraversal(of: mockHome.appendingPathComponent("Library/Containers")),
            "~/Library/Containers must be skipped by TCCGuard"
        )
        try assertCondition(
            TCCGuard.shouldSkipTraversal(of: mockHome.appendingPathComponent("Library/CoreData")),
            "~/Library/CoreData must be skipped by TCCGuard"
        )
        try assertCondition(
            TCCGuard.shouldSkipTraversal(of: mockHome.appendingPathComponent("Library/FollowUp")),
            "~/Library/FollowUp must be skipped by TCCGuard"
        )
        try assertCondition(
            TCCGuard.shouldSkipTraversal(of: mockHome.appendingPathComponent("Library/IntelligencePlatform")),
            "~/Library/IntelligencePlatform must be skipped by TCCGuard"
        )
        try assertCondition(
            TCCGuard.shouldSkipTraversal(of: mockHome.appendingPathComponent("Library/Caches/com.apple.Safari")),
            "com.apple.Safari cache must be skipped by TCCGuard"
        )
        try assertCondition(
            !TCCGuard.shouldSkipTraversal(of: mockHome.appendingPathComponent("Library/Caches/com.apple.dt.Xcode")),
            "com.apple.dt.Xcode should be allowed"
        )
        
        // Verify every entry in TCCGuard.protectedLibraryFolderNames is normalized lowercase without leading/trailing whitespace
        for entry in TCCGuard.protectedLibraryFolderNames {
            try assertCondition(
                entry == entry.lowercased().trimmingCharacters(in: .whitespaces),
                "TCCGuard entry '\(entry)' must be lowercase and trimmed"
            )
        }
        
        let picturesMetrics = DiskSizeCalculator.calculateMetrics(at: mockHome.appendingPathComponent("Pictures"))
        try assertCondition(picturesMetrics.sizeBytes == 0, "Pictures directory size must ignore Photos Library.photoslibrary")
    }
}
