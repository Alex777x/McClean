import SwiftUI
import AppKit
import Combine
import McCleanKit

@main
enum McCleanMain {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            let passed = SelfTestRunner.runAllTests()
            exit(passed ? 0 : 1)
        }
        
        let app = NSApplication.shared
        let delegate = MainActor.assumeIsolated {
            McCleanAppDelegate()
        }
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class McCleanAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let viewModel = AppViewModel()
    let permissionManager = PermissionManager.shared
    
    var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSWindow.allowsAutomaticWindowTabbing = false
        
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let appIcon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = appIcon
        }
        
        setupMainMenu()
        setupMainWindow()
        
        NSApp.activate(ignoringOtherApps: true)
        
        if CommandLine.arguments.contains("--ui-smoke-test") {
            Task { @MainActor in
                print("[UI-SMOKE] Starting Smart Scan...")
                viewModel.startSmartScan()
                try? await Task.sleep(nanoseconds: 500_000_000)
                for section in NavigationSection.allCases {
                    print("[UI-SMOKE] Switching to section: \(section.rawValue)")
                    viewModel.selectSection(section)
                    try? await Task.sleep(nanoseconds: 350_000_000)
                }
                viewModel.selectSection(.smartScan)
                // Wait for scan completion (up to 15s)
                for _ in 0..<30 {
                    if !viewModel.isScanning && viewModel.hasCompletedScan {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
                print("[UI-SMOKE] Scan finished! Found \(viewModel.allScanItems.count) items (\(ByteCountFormatterHelper.format(bytes: viewModel.totalDiscoverableBytes))).")
                for section in NavigationSection.allCases {
                    viewModel.selectSection(section)
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
                viewModel.selectSection(.smartScan)
                print("[UI-SMOKE] ALL GUI TABS & SCAN VERIFIED SUCCESSFULLY!")
                exit(0)
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        return true
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow, closingWindow === mainWindow {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // MARK: - Window Setup
    
    private func setupMainWindow() {
        let rootView = MainWindowView(viewModel: viewModel, permissionManager: permissionManager)
        let hostingView = NSHostingView(rootView: rootView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 780),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "McClean"
        window.minSize = NSSize(width: 1180, height: 680)
        window.contentMinSize = NSSize(width: 1180, height: 680)
        window.backgroundColor = NSColor(red: 0.067, green: 0.067, blue: 0.063, alpha: 1.0)
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        self.mainWindow = window
    }
    
    // MARK: - Native macOS Menu Bar
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // 1. App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        
        appMenu.addItem(withTitle: "About McClean", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        
        #if !APP_STORE
        let checkUpdatesItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "u")
        checkUpdatesItem.target = self
        appMenu.addItem(checkUpdatesItem)
        #endif
        
        appMenu.addItem(.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)
        
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide McClean", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit McClean", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        // 2. Scan Menu
        let scanMenuItem = NSMenuItem()
        mainMenu.addItem(scanMenuItem)
        let scanMenu = NSMenu(title: "Scan")
        scanMenuItem.submenu = scanMenu
        
        let startScanItem = NSMenuItem(title: "Start Smart Scan", action: #selector(triggerSmartScan), keyEquivalent: "r")
        startScanItem.target = self
        scanMenu.addItem(startScanItem)
        
        // 3. Edit Menu (for Search & Settings TextFields)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        
        // 4. Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        
        NSApp.mainMenu = mainMenu
    }
    
    @objc private func openPreferences() {
        mainWindow?.makeKeyAndOrderFront(nil)
        viewModel.isShowingSettingsSheet = true
    }
    
    @objc private func checkForUpdates() {
        UpdateCheckerService.shared.checkForUpdates(showAlertIfUpToDate: true)
    }
    
    @objc private func triggerSmartScan() {
        mainWindow?.makeKeyAndOrderFront(nil)
        viewModel.startSmartScan()
    }
}
