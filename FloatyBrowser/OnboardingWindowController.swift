//
//  OnboardingWindowController.swift
//  FloatyBrowser
//
//  Window controller for native macOS onboarding experience.
//

import Cocoa

class OnboardingWindowController: NSWindowController {
    
    private var onboardingVC: OnboardingViewController!
    
    convenience init() {
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Welcome to Floaty Browser"
        window.center()
        window.isReleasedWhenClosed = false
        
        // Initialize with the window
        self.init(window: window)
        
        // Create and set the view controller
        onboardingVC = OnboardingViewController()
        onboardingVC.delegate = self
        window.contentViewController = onboardingVC
        
        NSLog("✅ OnboardingWindowController: Initialized")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        NSLog("🪟 OnboardingWindowController: Window loaded")
    }
}

// MARK: - OnboardingDelegate

extension OnboardingWindowController: OnboardingDelegate {
    func onboardingDidComplete() {
        NSLog("🎉 OnboardingWindowController: Onboarding completed")
        close()
        
        // Notify AppDelegate
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }
    
    func onboardingDidSkip() {
        NSLog("⏭️ OnboardingWindowController: Onboarding skipped")
        close()
        
        // Notify AppDelegate
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}

