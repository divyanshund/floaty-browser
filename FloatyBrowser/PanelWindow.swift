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
        
        // Hide title bar but keep controls
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        
        // Set minimum size
        minSize = minimumSize
        
        // Make resizable with a subtle grip (system handles this with .resizable mask)
        isMovableByWindowBackground = true
        
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
    
    private func setupCloseButton() {
        // No longer needed - close button is now in the toolbar
        // Keeping this method for compatibility but it does nothing
    }
    
    @objc private func closeButtonClicked() {
        // Deprecated - collapse is now handled via toolbar button
        panelDelegate?.panelWindowDidRequestCollapse(self)
    }
    
    override func performClose(_ sender: Any?) {
        // Intercept standard close to collapse instead
        panelDelegate?.panelWindowDidRequestCollapse(self)
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
    
    // Animate appearance
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

// MARK: - Delegate Protocol

protocol PanelWindowDelegate: AnyObject {
    func panelWindowDidRequestCollapse(_ panel: PanelWindow)
    func panelWindow(_ panel: PanelWindow, didRequestNewBubble url: String)
    func panelWindow(_ panel: PanelWindow, didUpdateURL url: String)
    func panelWindow(_ panel: PanelWindow, didUpdateFavicon image: NSImage)
}

