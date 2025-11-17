//
//  PanelWindow.swift
//  FloatyBrowser
//
//  A floating panel window that hosts a WKWebView.
//

import Cocoa

class PanelWindow: NSPanel {
    let panelId: UUID
    private(set) var webViewController: WebViewController!
    private var closeButton: NSButton!
    private let minimumSize = NSSize(width: 300, height: 400)
    private let defaultSize = NSSize(width: 420, height: 600)
    
    // Store the user's resized frame so we can restore it when showing again
    private var savedFrame: NSRect?
    
    // Custom control buttons
    private var customControlBar: NSVisualEffectView!
    private var closeWindowButton: NSButton!
    private var fullscreenButton: NSButton!
    private var minimizeToBubbleButton: NSButton!
    
    weak var panelDelegate: PanelWindowDelegate?
    
    init(id: UUID, url: String, nearBubble bubbleFrame: NSRect) {
        self.panelId = id
        
        // Calculate position near the bubble
        let position = PanelWindow.calculatePosition(nearBubble: bubbleFrame, panelSize: defaultSize)
        let rect = NSRect(origin: position, size: defaultSize)
        
        super.init(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupWebView(url: url)
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
    
    private func setupWebView(url: String) {
        webViewController = WebViewController()
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
        let buttonSize: CGFloat = 16
        
        // Create translucent control bar
        customControlBar = NSVisualEffectView(frame: NSRect(
            x: 0,
            y: contentView.bounds.height - controlBarHeight,
            width: contentView.bounds.width,
            height: controlBarHeight
        ))
        customControlBar.autoresizingMask = [.width, .minYMargin]
        customControlBar.material = .hudWindow
        customControlBar.blendingMode = .behindWindow
        customControlBar.state = .active
        customControlBar.wantsLayer = true
        
        var xOffset = margin
        
        // Close button (red circle with X)
        closeWindowButton = NSButton(frame: NSRect(
            x: xOffset,
            y: (controlBarHeight - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        ))
        closeWindowButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeWindowButton.imagePosition = .imageOnly
        closeWindowButton.isBordered = false
        closeWindowButton.contentTintColor = NSColor.systemRed
        closeWindowButton.target = self
        closeWindowButton.action = #selector(customCloseClicked)
        closeWindowButton.toolTip = "Close bubble"
        xOffset += buttonSize + 6
        
        // Fullscreen button (expand arrows)
        fullscreenButton = NSButton(frame: NSRect(
            x: xOffset,
            y: (controlBarHeight - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        ))
        fullscreenButton.image = NSImage(systemSymbolName: "arrow.up.left.and.arrow.down.right", accessibilityDescription: "Fullscreen")
        fullscreenButton.imagePosition = .imageOnly
        fullscreenButton.isBordered = false
        fullscreenButton.contentTintColor = NSColor.systemGreen
        fullscreenButton.target = self
        fullscreenButton.action = #selector(customFullscreenClicked)
        fullscreenButton.toolTip = "Toggle fullscreen"
        xOffset += buttonSize + 6
        
        // Minimize to bubble button (circle)
        minimizeToBubbleButton = NSButton(frame: NSRect(
            x: xOffset,
            y: (controlBarHeight - buttonSize) / 2,
            width: buttonSize,
            height: buttonSize
        ))
        minimizeToBubbleButton.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Minimize to Bubble")
        minimizeToBubbleButton.imagePosition = .imageOnly
        minimizeToBubbleButton.isBordered = false
        minimizeToBubbleButton.contentTintColor = NSColor.systemYellow
        minimizeToBubbleButton.target = self
        minimizeToBubbleButton.action = #selector(customMinimizeClicked)
        minimizeToBubbleButton.toolTip = "Minimize to bubble"
        
        // Add buttons to control bar
        customControlBar.addSubview(closeWindowButton)
        customControlBar.addSubview(fullscreenButton)
        customControlBar.addSubview(minimizeToBubbleButton)
        
        // Add control bar to window
        contentView.addSubview(customControlBar, positioned: .above, relativeTo: nil)
        
        NSLog("✅ Custom window controls added")
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
        NSLog("🟢 Custom fullscreen button clicked")
        toggleFullScreen(nil)
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
}

