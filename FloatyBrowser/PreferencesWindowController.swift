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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 580),  // Increased from 450 to 580
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
        
        // Create tab view controller
        tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar
        
        // Create tab items with transparent backgrounds
        let appearanceVC = AppearancePreferencesViewController()
        let appearanceTab = NSTabViewItem(viewController: appearanceVC)
        appearanceTab.label = "Appearance"
        appearanceTab.image = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: "Appearance")
        
        let searchVC = SearchPreferencesViewController()
        let searchTab = NSTabViewItem(viewController: searchVC)
        searchTab.label = "Search"
        searchTab.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search")
        
        let generalVC = GeneralPreferencesViewController()
        let generalTab = NSTabViewItem(viewController: generalVC)
        generalTab.label = "General"
        generalTab.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: "General")
        
        // Add tabs
        tabViewController.addTabViewItem(appearanceTab)
        tabViewController.addTabViewItem(searchTab)
        tabViewController.addTabViewItem(generalTab)
        
        // Set as content view controller
        window.contentViewController = tabViewController
        
        // CRITICAL: Make tab views transparent to show visual effect behind
        // Must happen after contentViewController is set
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            
            // Create visual effect view with proper frame
            let visualEffectView = NSVisualEffectView(frame: window.contentView!.bounds)
            visualEffectView.autoresizingMask = [.width, .height]
            visualEffectView.material = .hudWindow  // More frosted than .sidebar
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            
            // Insert behind all content
            window.contentView?.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
            
            // Make tab view controller's view transparent
            if let tabView = self.tabViewController.view.subviews.first(where: { $0 is NSTabView }) as? NSTabView {
                tabView.drawsBackground = false
            }
            self.tabViewController.view.layer?.backgroundColor = .clear
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        NSLog("🪟 PreferencesWindowController: Window loaded with tabs")
    }
}

