import Foundation
import Testing
@testable import McCleanKit

@Suite("McClean Core Scanners & Cleanup Tests")
struct McCleanTests {
    
    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("McCleanTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    
    private func writeDummyFile(at url: URL, sizeBytes: Int) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = Data(repeating: 0xAB, count: sizeBytes)
        try data.write(to: url)
    }
    
    @Test("DotfilesScanner classifies .wallpaper, protected .ssh, .npm, and unknown dotfiles")
    func testDotfilesScannerClassifiesWallpapersProtectedAndUnknownDotfiles() throws {
        let tempRoot = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let mockHome = tempRoot.appendingPathComponent("Home", isDirectory: true)
        
        // 1. ~/.wallpaper (high-res wallpapers hidden folder)
        try writeDummyFile(
            at: mockHome.appendingPathComponent(".wallpaper/aerial_4k.mov"),
            sizeBytes: 512 * 1024
        )
        // 2. ~/.ssh (critical protected folder)
        try writeDummyFile(
            at: mockHome.appendingPathComponent(".ssh/id_ed25519"),
            sizeBytes: 1024
        )
        // 3. ~/.npm (safe developer cache)
        try writeDummyFile(
            at: mockHome.appendingPathComponent(".npm/_cacache/index.db"),
            sizeBytes: 300 * 1024
        )
        // 4. ~/.forgotten_tool (unknown dot-directory -> Review Needed, unchecked by default)
        try writeDummyFile(
            at: mockHome.appendingPathComponent(".forgotten_tool/data.bin"),
            sizeBytes: 400 * 1024
        )
        
        let items = DotfilesScanner.scan(
            homeDirectory: mockHome,
            installedAppNames: ["node"],
            minimumSizeBytes: 100 * 1024
        )
        
        let byName = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0) })
        
        // Verify .wallpaper
        let wallpaperItem = try #require(byName[".wallpaper"])
        #expect(wallpaperItem.category == .wallpapersAndMedia)
        #expect(wallpaperItem.safetyLevel == .safe)
        #expect(wallpaperItem.isSelected == true)
        
        // Verify .ssh is protected and unchecked
        let sshItem = try #require(byName[".ssh"])
        #expect(sshItem.safetyLevel == .protected)
        #expect(sshItem.isSelected == false)
        
        // Verify .npm is safe and checked
        let npmItem = try #require(byName[".npm"])
        #expect(npmItem.category == .developerAndAICaches)
        #expect(npmItem.safetyLevel == .safe)
        #expect(npmItem.isSelected == true)
        
        // Verify .forgotten_tool is Review Needed and unchecked by default
        let unknownItem = try #require(byName[".forgotten_tool"])
        #expect(unknownItem.safetyLevel == .review)
        #expect(unknownItem.isSelected == false)
        #expect(unknownItem.isOrphaned == true)
    }
    
    @Test("OrphanedAppsScanner separates installed apps from uninstalled leftovers")
    func testOrphanedAppsScannerSeparatesInstalledFromUninstalledLeftovers() throws {
        let tempRoot = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let mockAppsDir = tempRoot.appendingPathComponent("Applications", isDirectory: true)
        let mockLibraryDir = tempRoot.appendingPathComponent("Library", isDirectory: true)
        
        // Create an installed app: AcmeEditor.app (bundle ID: com.acme.editor)
        let acmePlistURL = mockAppsDir.appendingPathComponent("AcmeEditor.app/Contents/Info.plist")
        try FileManager.default.createDirectory(at: acmePlistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let plistDict: NSDictionary = [
            "CFBundleName": "AcmeEditor",
            "CFBundleIdentifier": "com.acme.editor",
            "CFBundleShortVersionString": "2.4.0"
        ]
        plistDict.write(to: acmePlistURL, atomically: true)
        try writeDummyFile(
            at: mockAppsDir.appendingPathComponent("AcmeEditor.app/Contents/MacOS/AcmeEditor"),
            sizeBytes: 256 * 1024
        )
        
        // Create Application Support for installed app (com.acme.editor)
        try writeDummyFile(
            at: mockLibraryDir.appendingPathComponent("Application Support/com.acme.editor/cache.db"),
            sizeBytes: 200 * 1024
        )
        
        // Create Application Support for an UNINSTALLED app (com.deletedvendor.ghostapp)
        try writeDummyFile(
            at: mockLibraryDir.appendingPathComponent("Application Support/com.deletedvendor.ghostapp/heavy_leftover.dat"),
            sizeBytes: 500 * 1024
        )
        
        let scanResult = OrphanedAppsScanner.scan(
            applicationDirectories: [mockAppsDir],
            userLibraryURL: mockLibraryDir,
            minimumOrphanSizeBytes: 64 * 1024
        )
        
        // 1. Orphaned items should contain com.deletedvendor.ghostapp, NOT com.acme.editor
        #expect(scanResult.orphanedItems.count == 1)
        let orphan = try #require(scanResult.orphanedItems.first)
        #expect(orphan.name == "com.deletedvendor.ghostapp")
        #expect(orphan.isOrphaned == true)
        #expect(orphan.isSelected == false)
        
        // 2. Installed apps should include AcmeEditor with its Application Support linked
        let installedAcme = try #require(scanResult.installedApps.first)
        #expect(installedAcme.name == "AcmeEditor")
        #expect(installedAcme.relatedItems.count == 1)
    }
    
    @Test("CleanupService permanently deletes selected items and blocks protected paths")
    func testCleanupServicePermanentlyDeletesAndBlocksProtectedPaths() throws {
        let tempRoot = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempRoot) }
        
        let removableURL = tempRoot.appendingPathComponent("removable_wallpaper_cache", isDirectory: true)
        try writeDummyFile(at: removableURL.appendingPathComponent("video.mov"), sizeBytes: 600 * 1024)
        
        let protectedSSHURL = tempRoot.appendingPathComponent(".ssh", isDirectory: true)
        try writeDummyFile(at: protectedSSHURL.appendingPathComponent("id_rsa"), sizeBytes: 4096)
        
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
            )
        ]
        
        let report = CleanupService.cleanImmediately(items: items)
        
        // Removable folder should be permanently deleted from disk
        #expect(!FileManager.default.fileExists(atPath: removableURL.path))
        // Protected .ssh folder must still exist!
        #expect(FileManager.default.fileExists(atPath: protectedSSHURL.path))
        
        #expect(report.deletedItemCount == 1)
        #expect(report.totalBytesFreed == 600 * 1024)
        #expect(report.categoryMetrics.first?.category == .wallpapersAndMedia)
        #expect(report.failedItems.count == 1)
    }
    
    @Test("FolderInspectorAI generates detailed offline heuristic analysis")
    func testFolderInspectorAIOfflineHeuristics() async throws {
        let tempRoot = try makeTempDirectory()
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
        #expect(analysis.contains(".ollama"))
        #expect(analysis.contains("gguf"))
    }
}
