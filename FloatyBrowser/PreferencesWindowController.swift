//
//  PreferencesWindowController.swift
//  FloatyBrowser
//
//  Window controller for application preferences.
//

import Cocoa

class PreferencesWindowController: NSWindowController {
    
    private var tabViewController: NSTabViewController!
    
    convenience init() {
        // Create the preferences window with translucent background
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        
        // Make window translucent with frosted glass effect
        window.isOpaque = false
        window.backgroundColor = .clear
        
        // Initialize with the window
        self.init(window: window)
        
        // Create tabbed interface
        setupTabbedInterface()
        
        NSLog("✅ PreferencesWindowController: Initialized with tabbed UI")
    }
    
    private func setupTabbedInterface() {
        guard let window = window else { return }
        
        // Create visual effect view as the base content view
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        window.contentView = visualEffectView
        
        // Create tab view controller
        tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar
        
        // Create tab items
        let appearanceTab = NSTabViewItem(viewController: AppearancePreferencesViewController())
        appearanceTab.label = "Appearance"
        appearanceTab.image = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: "Appearance")
        
        let searchTab = NSTabViewItem(viewController: SearchPreferencesViewController())
        searchTab.label = "Search"
        searchTab.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        
        let generalTab = NSTabViewItem(viewController: GeneralPreferencesViewController())
        generalTab.label = "General"
        generalTab.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "General")
        
        // Add tabs
        tabViewController.addTabViewItem(appearanceTab)
        tabViewController.addTabViewItem(searchTab)
        tabViewController.addTabViewItem(generalTab)
        
        // Set as content view controller (will add tab view to visual effect view)
        window.contentViewController = tabViewController
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        NSLog("🪟 PreferencesWindowController: Window loaded with tabs")
    }
}

