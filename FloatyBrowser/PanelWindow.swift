//
//  PanelWindow.swift
//  FloatyBrowser
//
//  A floating panel window that hosts a WKWebView.
//

import Cocoa
import WebKit

// Custom button for window controls with hover effect
class WindowControlButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove old tracking area if it exists
        if let existingTrackingArea = trackingArea {
            removeTrackingArea(existingTrackingArea)
        }
        
        // Create new tracking area
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        applyHoverState()
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        applyHoverState()
    }
    
    private func applyHoverState() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.allowsImplicitAnimation = true
            
            if isHovering {
                self.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
            } else {
                self.layer?.backgroundColor = NSColor.clear.cgColor
            }
        })
    }
}

class PanelWindow: NSPanel {
    let panelId: UUID
    private(set) var webViewController: WebViewController!
    private var closeButton: NSButton!
    private let minimumSize = NSSize(width: 380, height: 400)  // Increased to fit all toolbar elements
    private let defaultSize = NSSize(width: 420, height: 600)
    
    // Store the user's resized frame so we can restore it when showing again
    private var savedFrame: NSRect?
    
    // Store the window's frame before maximizing so we can restore it
    private var savedNormalFrame: NSRect?
    
    // Custom control buttons
    private var customControlBar: NSView!  // Can be NSVisualEffectView OR NSView
    private var closeWindowButton: NSButton!
    private var fullscreenButton: NSButton!
    private var minimizeToBubbleButton: NSButton!
    private var useThemeColors: Bool  // Can change dynamically
    
    weak var panelDelegate: PanelWindowDelegate?
    
    init(id: UUID, url: String, nearBubble bubbleFrame: NSRect, configuration: WKWebViewConfiguration? = nil) {
        self.panelId = id
        
        // Decide mode at creation - same as WebViewController
        self.useThemeColors = AppearancePreferencesViewController.isThemeColorsEnabled()
        
        // Calculate position near the bubble
        let position = PanelWindow.calculatePosition(nearBubble: bubbleFrame, panelSize: defaultSize)
        let rect = NSRect(origin: position, size: defaultSize)
        
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        NSLog("🎨 PanelWindow initialized with theme colors: \(useThemeColors)")
        if configuration != nil {
            NSLog("   ↳ Using external configuration (popup window)")
        }
        
        setupWindow()
        setupWebView(url: url, configuration: configuration)
        setupCloseButton()
        setupCustomControls()
    }
    
    private func setupWindow() {
        level = .floating
        backgroundColor = NSColor.windowBackgroundColor
        isOpaque = true
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Rounded corners
        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 10
        contentView?.layer?.masksToBounds = true
        
        // Hide title bar and make it transparent
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // Hide standard traffic lights
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        
        // Set minimum size
        minSize = minimumSize
        
        // Make resizable with a subtle grip (system handles this with .resizable mask)
        isMovableByWindowBackground = true
        
        // CRITICAL: Disable state restoration to prevent macOS from caching/restoring closed windows
        isRestorable = false
        restorationClass = nil
        
        // Set self as delegate to intercept close button
        delegate = self
        
        // Make sure the window becomes key to receive keyboard events
        makeKeyAndOrderFront(nil)
    }
    
    // MARK: - Window Responder
    
    // Allow the panel to become key window (for keyboard input)
    override var canBecomeKey: Bool {
        return true
    }
    
    // Allow the panel to become main window
    override var canBecomeMain: Bool {
        return true
    }
    
    // Accept first responder to handle keyboard events
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    // Make key when clicked
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        makeKeyAndOrderFront(nil)
    }
    
    private func setupWebView(url: String, configuration: WKWebViewConfiguration? = nil) {
        webViewController = WebViewController(configuration: configuration)
        webViewController.delegate = self
        
        // Set up the content view
        let containerView = NSView(frame: frame)
        containerView.autoresizingMask = [.width, .height]
        
        webViewController.view.frame = containerView.bounds
        webViewController.view.autoresizingMask = [.width, .height]
        containerView.addSubview(webViewController.view)
        
        contentView = containerView
        
        // Load URL
        webViewController.loadURL(url)
    }
    
    private func setupCustomControls() {
        guard let contentView = contentView else { return }
        
        let controlBarHeight: CGFloat = 28
        let margin: CGFloat = 8
        let buttonSize: CGFloat = 20  // Slightly larger for better click target
        
        // Create control bar - solid or frosted glass based on setting
        if useThemeColors {
            // Mode 1: Solid colored view
            let solidView = NSView(frame: NSRect(
                x: 0,
                y: contentView.bounds.height - controlBarHeight,
                width: contentView.bounds.width,
                height: controlBarHeight
            ))
            solidView.autoresizingMask = [.width, .minYMargin]
            solidView.wantsLayer = true
            solidView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor  // Start with default
            customControlBar = solidView
            NSLog("✅ Created SOLID control bar (theme colors enabled)")
        } else {
            // Mode 2: Frosted glass vibrancy
            let visualEffectView = NSVisualEffectView(frame: NSRect(
                x: 0,
                y: contentView.bounds.height - controlBarHeight,
                width: contentView.bounds.width,
                height: controlBarHeight
            ))
            visualEffectView.autoresizingMask = [.width, .minYMargin]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            customControlBar = visualEffectView
            NSLog("✅ Created FROSTED GLASS control bar (theme colors disabled)")
        }
        
        var xOffset = margin
        
        // Close button - styled like other browser buttons
        closeWindowButton = WindowControlButton(frame: NSRect(
            x: xOffset,
            y: (controlBarHeight - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        ))
        closeWindowButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close")
        closeWindowButton.imagePosition = .imageOnly
        closeWindowButton.isBordered = false
        closeWindowButton.bezelStyle = .regularSquare
        closeWindowButton.contentTintColor = .secondaryLabelColor
        closeWindowButton.target = self
        closeWindowButton.action = #selector(customCloseClicked)
        closeWindowButton.toolTip = "Close bubble"
        styleWindowButton(closeWindowButton)
        xOffset += buttonSize + 2
        
        // Fullscreen button - styled like other browser buttons
        fullscreenButton = WindowControlButton(frame: NSRect(
            x: xOffset,
            y: (controlBarHeight - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        ))
        fullscreenButton.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Fullscreen")
        fullscreenButton.imagePosition = .imageOnly
        fullscreenButton.isBordered = false
        fullscreenButton.bezelStyle = .regularSquare
        fullscreenButton.contentTintColor = .secondaryLabelColor
        fullscreenButton.target = self
        fullscreenButton.action = #selector(customFullscreenClicked)
        fullscreenButton.toolTip = "Maximize window"
        styleWindowButton(fullscreenButton)
        xOffset += buttonSize + 2
        
        // Minimize to bubble button - styled like other browser buttons
        minimizeToBubbleButton = WindowControlButton(frame: NSRect(
            x: xOffset,
            y: (controlBarHeight - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        ))
        minimizeToBubbleButton.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Minimize to Bubble")
        minimizeToBubbleButton.imagePosition = .imageOnly
        minimizeToBubbleButton.isBordered = false
        minimizeToBubbleButton.bezelStyle = .regularSquare
        minimizeToBubbleButton.contentTintColor = .secondaryLabelColor
        minimizeToBubbleButton.target = self
        minimizeToBubbleButton.action = #selector(customMinimizeClicked)
        minimizeToBubbleButton.toolTip = "Minimize to bubble"
        styleWindowButton(minimizeToBubbleButton)
        
        // Add buttons to control bar
        customControlBar.addSubview(closeWindowButton)
        customControlBar.addSubview(fullscreenButton)
        customControlBar.addSubview(minimizeToBubbleButton)
        
        // Add control bar to window
        contentView.addSubview(customControlBar, positioned: .above, relativeTo: nil)
        
        NSLog("✅ Custom window controls added")
    }
    
    private func styleWindowButton(_ button: NSButton) {
        button.wantsLayer = true
        button.layer?.cornerRadius = 10  // Circular background
        button.layer?.masksToBounds = true
    }
    
    private func setupCloseButton() {
        // No longer needed - close button is now in the toolbar
        // Keeping this method for compatibility but it does nothing
    }
    
    // MARK: - Custom Control Actions
    
    @objc private func customCloseClicked() {
        NSLog("🔴 Custom close button clicked - deleting bubble")
        panelDelegate?.panelWindowDidRequestClose(self)
    }
    
    @objc private func customFullscreenClicked() {
        NSLog("🟢 Custom expand/restore button clicked")
        
        guard let screen = self.screen else {
            NSLog("❌ No screen found")
            return
        }
        
        let visibleFrame = screen.visibleFrame
        let tolerance: CGFloat = 10  // Small tolerance for comparison
        
        // Check if currently maximized (within tolerance)
        let isMaximized = (abs(frame.size.width - visibleFrame.size.width) < tolerance &&
                          abs(frame.size.height - visibleFrame.size.height) < tolerance)
        
        if isMaximized {
            // Restore to previous size
            if let savedFrame = savedNormalFrame {
                NSLog("🟢 Restoring to previous size: \(NSStringFromRect(savedFrame))")
                setFrame(savedFrame, display: true, animate: true)
                savedNormalFrame = nil
            } else {
                NSLog("⚠️ No saved frame, restoring to default size")
                let restoredFrame = NSRect(origin: frame.origin, size: defaultSize)
                setFrame(restoredFrame, display: true, animate: true)
            }
        } else {
            // Save current frame and maximize
            savedNormalFrame = frame
            NSLog("🟢 Maximizing window. Saved frame: \(NSStringFromRect(frame))")
            setFrame(visibleFrame, display: true, animate: true)
        }
    }
    
    @objc private func customMinimizeClicked() {
        NSLog("🟡 Custom minimize to bubble button clicked")
        panelDelegate?.panelWindowDidRequestCollapse(self)
    }
    
    @objc private func closeButtonClicked() {
        // Deprecated - collapse is now handled via toolbar button
        panelDelegate?.panelWindowDidRequestCollapse(self)
    }
    
    override func performClose(_ sender: Any?) {
        // Red close button = completely delete bubble and panel
        NSLog("🔴 PanelWindow.performClose() called - sender: %@", String(describing: sender))
        NSLog("🔴 This should ONLY be called by red traffic light button")
        panelDelegate?.panelWindowDidRequestClose(self)
    }
    
    // MARK: - Theme Color
    
    func applyThemeColorToControlBar(_ color: NSColor) {
        guard useThemeColors else {
            NSLog("⚠️ Theme colors disabled, not applying to control bar")
            return
        }
        
        // 90% opacity for top control bar (same as traffic light area)
        customControlBar.layer?.backgroundColor = color.withAlphaComponent(0.90).cgColor
        
        // Adapt button icon colors for accessibility
        adaptControlButtonColors(forBackgroundColor: color)
        
        NSLog("✅ Applied theme color to PanelWindow control bar: \(color) with 90% opacity")
    }
    
    /// Adapt control button colors based on background color luminance
    private func adaptControlButtonColors(forBackgroundColor backgroundColor: NSColor) {
        guard let rgbColor = backgroundColor.usingColorSpace(.deviceRGB) else {
            NSLog("⚠️ Could not convert background color to RGB for control buttons")
            return
        }
        
        // Calculate relative luminance (WCAG formula)
        let red = rgbColor.redComponent
        let green = rgbColor.greenComponent
        let blue = rgbColor.blueComponent
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        // Determine if background is light or dark
        let isDarkBackground = luminance < 0.5
        
        // Choose appropriate icon color
        let iconColor: NSColor
        
        if isDarkBackground {
            // Light icons for dark backgrounds
            iconColor = NSColor.white.withAlphaComponent(0.9)
            NSLog("🎨 Control bar: Dark background → Using LIGHT icons")
        } else {
            // Dark icons for light backgrounds
            iconColor = NSColor.black.withAlphaComponent(0.7)
            NSLog("🎨 Control bar: Light background → Using DARK icons")
        }
        
        // Apply to all control buttons
        closeWindowButton.contentTintColor = iconColor
        fullscreenButton.contentTintColor = iconColor
        minimizeToBubbleButton.contentTintColor = iconColor
        
        NSLog("✅ Control button colors adapted")
    }
    
    /// Reset control button colors to default (for frosted glass mode)
    private func resetControlButtonColors() {
        NSLog("🎨 Resetting control button colors to default")
        
        let defaultIconColor = NSColor.secondaryLabelColor
        
        closeWindowButton.contentTintColor = defaultIconColor
        fullscreenButton.contentTintColor = defaultIconColor
        minimizeToBubbleButton.contentTintColor = defaultIconColor
        
        NSLog("✅ Control button colors reset")
    }
    
    func handleThemeColorModeChanged(_ enabled: Bool) {
        NSLog("📢 PanelWindow received theme color mode change: \(enabled)")
        
        // Update our mode
        useThemeColors = enabled
        
        // Swap the control bar
        swapCustomControlBar(toColoredMode: enabled)
        
        // Re-apply color if we switched to colored mode, or reset if disabled
        if enabled {
            // Ask WebViewController to apply the color
            webViewController.applyThemeColorForCurrentURL()
        } else {
            // Reset control button colors to default (gray)
            resetControlButtonColors()
        }
        
        NSLog("✅ PanelWindow switched to \(enabled ? "COLORED" : "FROSTED GLASS") mode")
    }
    
    private func swapCustomControlBar(toColoredMode: Bool) {
        guard let contentView = contentView else { return }
        
        NSLog("🔄 Swapping custom control bar to \(toColoredMode ? "colored" : "frosted glass") mode")
        
        let controlBarHeight: CGFloat = 28
        let frame = NSRect(x: 0, y: contentView.bounds.height - controlBarHeight, width: contentView.bounds.width, height: controlBarHeight)
        
        // Store all subviews (buttons)
        let subviews = customControlBar.subviews
        
        // Remove old control bar
        customControlBar.removeFromSuperview()
        
        // Create new control bar
        if toColoredMode {
            // Solid view
            let solidView = NSView(frame: frame)
            solidView.autoresizingMask = [.width, .minYMargin]
            solidView.wantsLayer = true
            solidView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            customControlBar = solidView
        } else {
            // Frosted glass
            let visualEffectView = NSVisualEffectView(frame: frame)
            visualEffectView.autoresizingMask = [.width, .minYMargin]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.wantsLayer = true
            customControlBar = visualEffectView
        }
        
        // Re-add all subviews (buttons)
        for subview in subviews {
            customControlBar.addSubview(subview)
        }
        
        // Add control bar back to window
        contentView.addSubview(customControlBar, positioned: .above, relativeTo: nil)
        
        NSLog("✅ Custom control bar swapped")
    }
    
    // Calculate position to show panel near bubble but fully visible on screen
    private static func calculatePosition(nearBubble bubbleFrame: NSRect, panelSize: NSSize) -> CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 100, y: 100)
        }
        
        let visibleFrame = screen.visibleFrame
        
        // Try to position panel to the right of bubble
        var position = CGPoint(
            x: bubbleFrame.maxX + 10,
            y: bubbleFrame.midY - panelSize.height / 2
        )
        
        // Ensure panel is within screen bounds
        if position.x + panelSize.width > visibleFrame.maxX {
            // Position to the left instead
            position.x = bubbleFrame.minX - panelSize.width - 10
        }
        
        if position.x < visibleFrame.minX {
            position.x = visibleFrame.minX + 10
        }
        
        // Adjust Y position if needed
        if position.y + panelSize.height > visibleFrame.maxY {
            position.y = visibleFrame.maxY - panelSize.height - 10
        }
        
        if position.y < visibleFrame.minY {
            position.y = visibleFrame.minY + 10
        }
        
        return position
    }
    
    func updateURL(_ url: String) {
        webViewController.loadURL(url)
    }
    
    func getCurrentURL() -> String {
        return webViewController.currentURL
    }
    
    // Save current frame before hiding (so we can restore it later)
    func saveFrameBeforeHiding() {
        savedFrame = frame
        NSLog("💾 Saving panel frame: %@", NSStringFromRect(frame))
    }
    
    // Restore saved frame and show panel (for reused panels)
    func restoreAndShow() {
        if let saved = savedFrame {
            NSLog("📐 Restoring saved frame: %@", NSStringFromRect(saved))
            setFrame(saved, display: true)
        }
        alphaValue = 1.0
        makeKeyAndOrderFront(nil)
        makeFirstResponder(webViewController.view)
    }
    
    // Animate appearance (for new panels only)
    func animateIn() {
        alphaValue = 0
        let scale: CGFloat = 0.3
        
        let originalFrame = frame
        let scaledFrame = NSRect(
            x: originalFrame.midX - (originalFrame.width * scale) / 2,
            y: originalFrame.midY - (originalFrame.height * scale) / 2,
            width: originalFrame.width * scale,
            height: originalFrame.height * scale
        )
        
        setFrame(scaledFrame, display: true)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            animator().alphaValue = 1.0
            animator().setFrame(originalFrame, display: true)
        }, completionHandler: { [weak self] in
            // Animation complete - make sure we're key window
            self?.makeKeyAndOrderFront(nil)
            self?.makeFirstResponder(self?.webViewController.view)
        })
    }
    
    // Animate disappearance
    func animateOut(completion: @escaping () -> Void) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            
            animator().alphaValue = 0
            
            let currentFrame = frame
            let scaledFrame = NSRect(
                x: currentFrame.midX - (currentFrame.width * 0.3) / 2,
                y: currentFrame.midY - (currentFrame.height * 0.3) / 2,
                width: currentFrame.width * 0.3,
                height: currentFrame.height * 0.3
            )
            animator().setFrame(scaledFrame, display: true)
        }, completionHandler: {
            completion()
        })
    }
}

// MARK: - WebViewControllerDelegate

extension PanelWindow: WebViewControllerDelegate {
    func webViewController(_ controller: WebViewController, didRequestNewBubble url: String) {
        panelDelegate?.panelWindow(self, didRequestNewBubble: url)
    }
    
    func webViewController(_ controller: WebViewController, didUpdateURL url: String) {
        panelDelegate?.panelWindow(self, didUpdateURL: url)
    }
    
    func webViewController(_ controller: WebViewController, didUpdateFavicon image: NSImage) {
        panelDelegate?.panelWindow(self, didUpdateFavicon: image)
    }
    
    func webViewController(_ controller: WebViewController, createPopupPanelFor url: URL, configuration: WKWebViewConfiguration) -> WKWebView? {
        // Forward popup creation request to WindowManager
        return panelDelegate?.panelWindow(self, createPopupPanelFor: url, configuration: configuration)
    }
    
    func webViewControllerDidRequestClose(_ controller: WebViewController) {
        NSLog("📍 PanelWindow: WebViewController requested close (OAuth popup callback)")
        
        // Notify all parent windows to reload and detect new authentication
        // This is necessary because window.opener is broken on macOS WebKit,
        // so the popup can't send postMessage to parent. Instead, parent reloads
        // and detects the new authentication cookies.
        NSLog("🔄 OAuth popup closing - notifying parent windows to check for new authentication")
        NotificationCenter.default.post(name: .oauthPopupClosed, object: nil)
        
        // This panel is a popup that wants to close itself after OAuth
        panelDelegate?.panelWindowDidRequestClose(self)
    }
}

// MARK: - NSWindowDelegate

extension PanelWindow: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // CRITICAL: This is called when user clicks RED close button (traffic light)
        NSLog("🔴🔴🔴 windowShouldClose called - RED BUTTON CLICKED")
        NSLog("🔴 Calling panelWindowDidRequestClose to DELETE bubble")
        
        // Call our custom close logic
        panelDelegate?.panelWindowDidRequestClose(self)
        
        // Return false to prevent default close behavior (we handle it ourselves)
        return false
    }
}

// MARK: - Delegate Protocol

protocol PanelWindowDelegate: AnyObject {
    func panelWindowDidRequestCollapse(_ panel: PanelWindow)
    func panelWindowDidRequestClose(_ panel: PanelWindow)
    func panelWindow(_ panel: PanelWindow, didRequestNewBubble url: String)
    func panelWindow(_ panel: PanelWindow, didUpdateURL url: String)
    func panelWindow(_ panel: PanelWindow, didUpdateFavicon image: NSImage)
    func panelWindow(_ panel: PanelWindow, createPopupPanelFor url: URL, configuration: WKWebViewConfiguration) -> WKWebView?
}

// MARK: - Notification Names

extension Notification.Name {
    static let oauthPopupClosed = Notification.Name("oauthPopupClosed")
}

