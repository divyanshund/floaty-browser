//
//  PreferencesWindowController.swift
//  FloatyBrowser
//
//  Window controller for application preferences.
//

import Cocoa

class PreferencesWindowController: NSWindowController {
    
    private var preferencesVC: PreferencesViewController!
    
    convenience init() {
        // Create the preferences window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        
        // Initialize with the window
        self.init(window: window)
        
        // Create and set the view controller
        preferencesVC = PreferencesViewController()
        window.contentViewController = preferencesVC
        
        NSLog("✅ PreferencesWindowController: Initialized")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        NSLog("🪟 PreferencesWindowController: Window loaded")
    }
}

