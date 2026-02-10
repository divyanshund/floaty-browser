//
//  AppDelegate.swift
//  FloatyBrowser
//
//  Main application delegate for Floaty Browser.q

import Cocoa

// Note: @main removed - see main.swift for app entry point
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let windowManager = WindowManager.shared
    private var onboardingWindowController: OnboardingWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var historyWindowController: HistoryWindowController?
    
    // UserDefaults key
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    
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
        
        // Listen for onboarding completion
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onboardingCompleted),
            name: .onboardingCompleted,
            object: nil
        )
        
        // Small delay to ensure app is fully activated and ready to receive clicks
        // This prevents the "first click doesn't work" issue on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            
            NSLog("📍 FloatyBrowser: App fully activated")
            
            // Check if first launch
            if self.isFirstLaunch() {
                NSLog("🌟 FloatyBrowser: First launch - showing onboarding")
                self.showOnboarding()
            } else {
                NSLog("📍 FloatyBrowser: Returning user - starting normally")
                self.startNormalApp()
            }
        }
    }
    
    // MARK: - Onboarding
    
    private func isFirstLaunch() -> Bool {
        return !UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }
    
    private func showOnboarding() {
        onboardingWindowController = OnboardingWindowController()
        onboardingWindowController?.showWindow(nil)
    }
    
    @objc private func onboardingCompleted() {
        NSLog("🎉 AppDelegate: Onboarding completed, starting app")
        
        // Mark as complete
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        
        // Start normal app
        startNormalApp()
        
        // Clean up
        onboardingWindowController = nil
    }
    
    private func startNormalApp() {
        NSLog("📍 FloatyBrowser: Starting normal app - creating windows")
        
        // Initialize WindowManager and create bubbles
        self.windowManager.initialize()
        
        NSLog("✅ FloatyBrowser: Ready - bubbles are now clickable")
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
        
        NSLog("📋 Menu: Building menu with %d bubble(s)", bubbleCount)
        
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
    
    @objc private func showPreferences() {
        NSLog("⚙️ AppDelegate: Opening Preferences")
        
        // Create preferences window if it doesn't exist
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController()
        }
        
        // Show and bring to front
        preferencesWindowController?.showWindow(nil)
        preferencesWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // MARK: - History
    
    @objc private func showHistory() {
        NSLog("📜 AppDelegate: Opening History")
        
        // Create history window if it doesn't exist
        if historyWindowController == nil {
            historyWindowController = HistoryWindowController()
        }
        
        // Refresh and show
        historyWindowController?.refresh()
        historyWindowController?.showWindow(nil)
        historyWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear History"
        alert.informativeText = "Choose how much history to clear:"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Last Hour")
        alert.addButton(withTitle: "Today")
        alert.addButton(withTitle: "All History")
        
        let response = alert.runModal()
        
        let historyManager = HistoryManager.shared
        
        switch response {
        case .alertSecondButtonReturn: // Last Hour
            let oneHourAgo = Date().addingTimeInterval(-3600)
            historyManager.clearHistory(olderThan: oneHourAgo)
        case .alertThirdButtonReturn: // Today
            let calendar = Calendar.current
            if let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) {
                historyManager.clearHistory(olderThan: startOfDay)
            }
        case NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1): // All History
            historyManager.clearAllHistory()
        default:
            return // Cancel
        }
        
        // Refresh history window if open
        historyWindowController?.refresh()
    }
    
    @objc private func openHistoryItem(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        _ = windowManager.createBubble(url: entry.url)
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
        
        // Settings in app menu (standard macOS location)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showPreferences), keyEquivalent: ",")
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit FloatyBrowser", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        
        // File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.delegate = self
        
        let newBubbleItem = NSMenuItem(title: "New Bubble", action: #selector(createNewBubble), keyEquivalent: "n")
        newBubbleItem.target = self
        fileMenu.addItem(newBubbleItem)
        
        fileMenu.addItem(.separator())
        
        // Open Bubbles submenu - will be dynamically populated
        let openBubblesItem = NSMenuItem(title: "Open Bubbles", action: nil, keyEquivalent: "")
        let openBubblesMenu = NSMenu()
        openBubblesMenu.delegate = self
        openBubblesItem.submenu = openBubblesMenu
        fileMenu.addItem(openBubblesItem)
        
        fileMenuItem.submenu = fileMenu
        
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
        
        // History Menu
        let historyMenuItem = NSMenuItem()
        mainMenu.addItem(historyMenuItem)
        let historyMenu = NSMenu(title: "History")
        historyMenu.delegate = self
        
        let showHistoryItem = NSMenuItem(title: "Show All History", action: #selector(showHistory), keyEquivalent: "y")
        showHistoryItem.target = self
        historyMenu.addItem(showHistoryItem)
        
        historyMenu.addItem(.separator())
        
        let clearHistoryItem = NSMenuItem(title: "Clear History...", action: #selector(clearHistory), keyEquivalent: "")
        clearHistoryItem.target = self
        historyMenu.addItem(clearHistoryItem)
        
        historyMenu.addItem(.separator())
        
        // Recent history items will be added dynamically via delegate
        let recentPlaceholder = NSMenuItem(title: "Recent", action: nil, keyEquivalent: "")
        recentPlaceholder.isEnabled = false
        recentPlaceholder.tag = 1000 // Tag to identify for dynamic update
        historyMenu.addItem(recentPlaceholder)
        
        historyMenuItem.submenu = historyMenu
        
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

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Check if this is the Open Bubbles submenu
        if menu.title == "" && menu.supermenu?.title == "File" {
            // Clear existing items
            menu.removeAllItems()
            
            // Populate with current bubbles
            let bubbleCount = windowManager.getBubbleCount()
            
            if bubbleCount > 0 {
                let bubbleURLs = windowManager.getAllBubbleURLs()
                for (index, urlString) in bubbleURLs.enumerated() {
                    let displayURL = urlString.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
                    let truncated = displayURL.count > 50 ? String(displayURL.prefix(47)) + "..." : displayURL
                    
                    let item = NSMenuItem(title: truncated, action: #selector(focusBubbleAtIndex(_:)), keyEquivalent: "")
                    item.target = self
                    item.tag = index
                    menu.addItem(item)
                }
            } else {
                let item = NSMenuItem(title: "No open bubbles", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }
        
        // Check if this is the History menu
        if menu.title == "History" {
            // Find and remove items after the separator (recent history items)
            // Keep: Show All History, separator, Clear History, separator
            // Remove: Everything after second separator (tag 1000 and beyond)
            
            // Find the placeholder item and remove everything after second separator
            var foundSecondSeparator = false
            var separatorCount = 0
            var itemsToRemove: [NSMenuItem] = []
            
            for item in menu.items {
                if item.isSeparatorItem {
                    separatorCount += 1
                    if separatorCount == 2 {
                        foundSecondSeparator = true
                    }
                } else if foundSecondSeparator {
                    itemsToRemove.append(item)
                }
            }
            
            for item in itemsToRemove {
                menu.removeItem(item)
            }
            
            // Add recent history items
            let recentEntries = HistoryManager.shared.getRecentEntries(limit: 15)
            
            if recentEntries.isEmpty {
                let noHistoryItem = NSMenuItem(title: "No Recent History", action: nil, keyEquivalent: "")
                noHistoryItem.isEnabled = false
                menu.addItem(noHistoryItem)
            } else {
                for entry in recentEntries {
                    let title = entry.title.count > 40 ? String(entry.title.prefix(37)) + "..." : entry.title
                    let item = NSMenuItem(title: title, action: #selector(openHistoryItem(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = entry
                    
                    // Add domain as subtitle/tooltip
                    item.toolTip = entry.url
                    
                    menu.addItem(item)
                }
            }
        }
    }
}

