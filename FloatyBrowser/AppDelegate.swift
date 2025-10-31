//
//  AppDelegate.swift
//  FloatyBrowser
//
//  Main application delegate for Floaty Browser.
//

import Cocoa

// Note: @main removed - see main.swift for app entry point
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let windowManager = WindowManager.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSLog("🚀 FloatyBrowser: App launched - starting initialization")
        print("🚀 Floaty Browser launched")
        fflush(stdout)
        
        // Show alert to confirm app is running
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "FloatyBrowser Launching"
            alert.informativeText = "The app is starting up. You should see a bubble appear shortly."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        // Setup menu bar item FIRST
        NSLog("📍 FloatyBrowser: About to setup menu bar")
        setupMenuBar()
        NSLog("📍 FloatyBrowser: Menu bar setup complete")
        
        // Ensure app doesn't terminate when all windows are closed
        // Using .regular instead of .accessory so the app shows in Dock initially
        NSLog("📍 FloatyBrowser: Setting activation policy")
        NSApp.setActivationPolicy(.regular)
        
        // Force app to activate and bring windows to front
        NSLog("📍 FloatyBrowser: Activating app")
        NSApp.activate(ignoringOtherApps: true)
        
        // NOW initialize WindowManager and create windows
        NSLog("📍 FloatyBrowser: About to initialize WindowManager")
        windowManager.initialize()
        NSLog("📍 FloatyBrowser: WindowManager initialized")
        
        // Check accessibility permission (for global shortcuts)
        if !windowManager.checkAccessibilityPermission() {
            showAccessibilityAlert()
        }
        
        NSLog("✅ FloatyBrowser: App ready - bubbles should be visible")
        print("✅ Floaty Browser ready")
        print("ℹ️  You should see:")
        print("   • Menu bar icon (🫧) in top-right")
        print("   • A circular bubble floating on screen")
        print("   • Click the bubble to expand into a browser panel")
        fflush(stdout)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        print("👋 Floaty Browser terminating")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when all windows close - bubbles persist
        return false
    }
    
    // MARK: - Menu Bar
    
    private func setupMenuBar() {
        NSLog("📍 FloatyBrowser: Setting up menu bar")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.title = "🫧"
            button.toolTip = "Floaty Browser"
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            NSLog("📍 FloatyBrowser: Menu bar button created with emoji")
        } else {
            NSLog("❌ FloatyBrowser: Failed to create menu bar button")
        }
        
        // Don't set menu here - we'll show it programmatically on click
    }
    
    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        // Show menu on both left and right click
        showStatusBarMenu()
    }
    
    private func showStatusBarMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // New Bubble
        let newBubbleItem = NSMenuItem(title: "New Bubble", action: #selector(createNewBubble), keyEquivalent: "n")
        newBubbleItem.target = self
        menu.addItem(newBubbleItem)
        
        menu.addItem(.separator())
        
        // Show All Bubbles submenu
        let bubblesSubmenu = NSMenu()
        let bubbleCount = windowManager.getBubbleCount()
        
        if bubbleCount > 0 {
            let bubbleURLs = windowManager.getAllBubbleURLs()
            for (index, urlString) in bubbleURLs.enumerated() {
                let displayURL = urlString.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
                let truncated = displayURL.count > 40 ? String(displayURL.prefix(37)) + "..." : displayURL
                
                let item = NSMenuItem(title: truncated, action: #selector(focusBubbleAtIndex(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                bubblesSubmenu.addItem(item)
            }
        } else {
            let item = NSMenuItem(title: "No bubbles", action: nil, keyEquivalent: "")
            item.isEnabled = false
            bubblesSubmenu.addItem(item)
        }
        
        let showBubblesItem = NSMenuItem(title: "Bubbles (\(bubbleCount))", action: nil, keyEquivalent: "")
        showBubblesItem.submenu = bubblesSubmenu
        menu.addItem(showBubblesItem)
        
        menu.addItem(.separator())
        
        // Toggle All Panels
        let toggleItem = NSMenuItem(title: "Toggle All Panels", action: #selector(toggleAllPanels), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.keyEquivalentModifierMask = [.control, .option]
        menu.addItem(toggleItem)
        
        menu.addItem(.separator())
        
        // Enable Global Shortcuts
        let accessibilityItem = NSMenuItem(title: "Enable Global Shortcuts (⌃⌥Space)...", action: #selector(requestAccessibility), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        
        menu.addItem(.separator())
        
        // About
        let aboutItem = NSMenuItem(title: "About Floaty Browser", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Floaty Browser", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        // Show menu
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        
        // Remove menu after showing (so we can regenerate it next time with fresh data)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }
    
    @objc private func createNewBubble() {
        windowManager.createDefaultBubble()
    }
    
    @objc private func toggleAllPanels() {
        // Toggle all panels via WindowManager
        windowManager.toggleAllPanels()
    }
    
    @objc private func focusBubbleAtIndex(_ sender: NSMenuItem) {
        windowManager.expandBubbleAtIndex(sender.tag)
    }
    
    @objc private func requestAccessibility() {
        windowManager.requestAccessibilityPermission()
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Floaty Browser"
        alert.informativeText = """
        Version 1.0
        
        A floating, bubble-based mini-browser for macOS.
        
        Features:
        • Floating bubbles that stay on top
        • Click to expand into web panels
        • Create new bubbles from links
        • Global shortcut: ⌃⌥Space
        
        Built with Swift and AppKit.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showAccessibilityAlert() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            let alert = NSAlert()
            alert.messageText = "Enable Global Shortcuts"
            alert.informativeText = """
            Floaty Browser can use global keyboard shortcuts (⌃⌥Space) to quickly show/hide panels.
            
            To enable this feature, please grant Accessibility permission in System Settings > Privacy & Security > Accessibility.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Not Now")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                self?.windowManager.requestAccessibilityPermission()
            }
        }
    }
}

