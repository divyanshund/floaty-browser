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
        
        // Setup menu bar item immediately
        setupMenuBar()
        
        // Setup main menu for keyboard shortcuts
        setupMainMenu()
        
        // Configure app activation policy (shows in Dock)
        NSApp.setActivationPolicy(.regular)
        
        // Activate app and wait for full activation before creating windows
        // This prevents the first click being consumed by app activation
        NSApp.activate(ignoringOtherApps: true)
        
        // Small delay to ensure app is fully activated and ready to receive clicks
        // This prevents the "first click doesn't work" issue on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            
            NSLog("📍 FloatyBrowser: App fully activated - creating windows")
            
            // NOW initialize WindowManager and create bubbles
            self.windowManager.initialize()
            
            NSLog("✅ FloatyBrowser: Ready - bubbles are now clickable")
        }
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
        • Offline Snake game
        
        Built with Swift and AppKit.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Main Menu Setup
    
    private func setupMainMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About FloatyBrowser", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit FloatyBrowser", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        
        // Edit Menu (CRITICAL for keyboard shortcuts)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        
        // Window Menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu
        
        // Set the main menu
        NSApp.mainMenu = mainMenu
        
        NSLog("✅ FloatyBrowser: Main menu setup complete - keyboard shortcuts enabled")
    }
}

