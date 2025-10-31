//
//  BubbleWindow.swift
//  FloatyBrowser
//
//  A circular, floating, draggable bubble window.
//

import Cocoa

class BubbleWindow: NSPanel {
    let bubbleId: UUID
    var currentURL: String
    private var isDragging = false
    private var dragOffset: CGPoint = .zero
    private var bubbleView: BubbleView!
    private var idleAnimationTimer: Timer?
    private var faviconImage: NSImage?
    
    weak var bubbleDelegate: BubbleWindowDelegate?
    
    init(id: UUID, url: String, position: CGPoint) {
        self.bubbleId = id
        self.currentURL = url
        
        let size = CGSize(width: 60, height: 60)
        let rect = NSRect(origin: position, size: size)
        
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupBubbleView()
        startIdleAnimation()
    }
    
    private func setupWindow() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        // Allow the window to accept mouse events
        isMovableByWindowBackground = false
        acceptsMouseMovedEvents = true
    }
    
    // Allow the panel to receive clicks even when not key
    override var canBecomeKey: Bool {
        return false // Non-activating but still receives clicks
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    private func setupBubbleView() {
        bubbleView = BubbleView(frame: contentView!.bounds, owner: self)
        bubbleView.updateFavicon(for: currentURL)
        contentView = bubbleView
    }
    
    override func mouseEntered(with event: NSEvent) {
        stopIdleAnimation()
        bubbleView.setHovered(true)
    }
    
    override func mouseExited(with event: NSEvent) {
        if !isDragging {
            startIdleAnimation()
        }
        bubbleView.setHovered(false)
    }
    
    override func mouseDown(with event: NSEvent) {
        NSLog("🖱️ FloatyBrowser: Mouse down in bubble")
        
        // Ensure we're processing the event
        let location = event.locationInWindow
        dragOffset = location
        isDragging = false // Start as false, set to true only if actually dragged
        stopIdleAnimation()
        
        // Accept first responder to ensure we receive mouse events
        if !self.isKeyWindow {
            self.makeFirstResponder(self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        isDragging = true // Mark as dragging when mouse actually moves
        NSLog("🖱️ FloatyBrowser: Dragging bubble")
        
        let screenLocation = NSEvent.mouseLocation
        let newOrigin = CGPoint(
            x: screenLocation.x - dragOffset.x,
            y: screenLocation.y - dragOffset.y
        )
        
        setFrameOrigin(snapToEdgesIfNeeded(newOrigin))
    }
    
    override func mouseUp(with event: NSEvent) {
        NSLog("🖱️ FloatyBrowser: Bubble clicked - isDragging: \(isDragging)")
        
        if !isDragging {
            // Single click without drag = expand
            NSLog("🖱️ FloatyBrowser: Expanding bubble")
            bubbleDelegate?.bubbleWindowDidRequestExpand(self)
        } else {
            // Save position after drag
            NSLog("🖱️ FloatyBrowser: Saving bubble position after drag")
            bubbleDelegate?.bubbleWindowDidMove(self)
        }
        
        isDragging = false
        
        // Resume animation if mouse is outside
        let mouseLocation = NSEvent.mouseLocation
        let windowFrame = frame
        if !windowFrame.contains(mouseLocation) {
            startIdleAnimation()
        }
    }
    
    override func rightMouseDown(with event: NSEvent) {
        showContextMenu(at: event.locationInWindow)
    }
    
    private func showContextMenu(at point: CGPoint) {
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: "Open", action: #selector(expandBubble), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(.separator())
        
        let copyURLItem = NSMenuItem(title: "Copy URL", action: #selector(copyURL), keyEquivalent: "")
        copyURLItem.target = self
        menu.addItem(copyURLItem)
        
        menu.addItem(.separator())
        
        let closeItem = NSMenuItem(title: "Close Bubble", action: #selector(closeBubble), keyEquivalent: "")
        closeItem.target = self
        menu.addItem(closeItem)
        
        menu.popUp(positioning: nil, at: point, in: contentView)
    }
    
    @objc private func expandBubble() {
        bubbleDelegate?.bubbleWindowDidRequestExpand(self)
    }
    
    @objc private func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(currentURL, forType: .string)
    }
    
    @objc private func closeBubble() {
        bubbleDelegate?.bubbleWindowDidRequestClose(self)
    }
    
    private func snapToEdgesIfNeeded(_ origin: CGPoint) -> CGPoint {
        guard let screen = screen ?? NSScreen.main else { return origin }
        
        let snapThreshold: CGFloat = 20
        let visibleFrame = screen.visibleFrame
        var snappedOrigin = origin
        
        // Snap to left edge
        if abs(origin.x - visibleFrame.minX) < snapThreshold {
            snappedOrigin.x = visibleFrame.minX + 5
        }
        
        // Snap to right edge
        if abs(origin.x + frame.width - visibleFrame.maxX) < snapThreshold {
            snappedOrigin.x = visibleFrame.maxX - frame.width - 5
        }
        
        // Snap to top edge
        if abs(origin.y + frame.height - visibleFrame.maxY) < snapThreshold {
            snappedOrigin.y = visibleFrame.maxY - frame.height - 5
        }
        
        // Snap to bottom edge
        if abs(origin.y - visibleFrame.minY) < snapThreshold {
            snappedOrigin.y = visibleFrame.minY + 5
        }
        
        return snappedOrigin
    }
    
    // MARK: - Idle Animation
    
    private func startIdleAnimation() {
        stopIdleAnimation()
        
        idleAnimationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.performIdleAnimation()
        }
    }
    
    private func stopIdleAnimation() {
        idleAnimationTimer?.invalidate()
        idleAnimationTimer = nil
    }
    
    private func performIdleAnimation() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 2.0
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            let randomOffset = CGPoint(
                x: CGFloat.random(in: -5...5),
                y: CGFloat.random(in: -5...5)
            )
            
            let currentOrigin = frame.origin
            let newOrigin = CGPoint(
                x: currentOrigin.x + randomOffset.x,
                y: currentOrigin.y + randomOffset.y
            )
            
            animator().setFrameOrigin(newOrigin)
        }
    }
    
    func updateURL(_ url: String) {
        currentURL = url
        if faviconImage == nil {
            bubbleView.updateFavicon(for: url)
        }
    }
    
    func updateFavicon(_ image: NSImage?) {
        faviconImage = image
        if let image = image {
            bubbleView.setFaviconImage(image)
        } else {
            bubbleView.updateFavicon(for: currentURL)
        }
    }
    
    deinit {
        stopIdleAnimation()
    }
}

// MARK: - Bubble View

class BubbleView: NSView {
    private var isHovered = false
    private let iconLabel = NSTextField(labelWithString: "🌐")
    private let iconImageView = NSImageView()
    private var usingImage = false
    private weak var bubbleWindow: BubbleWindow?
    private var innerGlowLayer: CALayer?
    
    init(frame frameRect: NSRect, owner: BubbleWindow) {
        self.bubbleWindow = owner
        super.init(frame: frameRect)
        setupView()
        setupTrackingArea()
        setupInnerGlowLayer()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTrackingArea() {
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        bubbleWindow?.mouseEntered(with: event)
    }
    
    override func mouseExited(with event: NSEvent) {
        bubbleWindow?.mouseExited(with: event)
    }
    
    private func setupView() {
        wantsLayer = true
        
        // Circular mask
        layer?.cornerRadius = bounds.width / 2
        layer?.masksToBounds = true  // Clip to bounds for inner glow
        
        // Background gradient
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = bounds.width / 2
        gradientLayer.masksToBounds = true
        gradientLayer.colors = [
            NSColor(calibratedRed: 0.3, green: 0.6, blue: 1.0, alpha: 0.95).cgColor,
            NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.8, alpha: 0.95).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer?.insertSublayer(gradientLayer, at: 0)
        
        // Icon label (emoji fallback)
        iconLabel.font = NSFont.systemFont(ofSize: 24)
        iconLabel.alignment = .center
        iconLabel.frame = bounds
        iconLabel.autoresizingMask = [.width, .height]
        addSubview(iconLabel)
        
        // Icon image view (for real favicons)
        iconImageView.frame = bounds.insetBy(dx: 12, dy: 12)
        iconImageView.autoresizingMask = [.width, .height]
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.isHidden = true
        addSubview(iconImageView)
    }
    
    private func setupInnerGlowLayer() {
        // Create soft, diffused inner glow layer
        let glowLayer = CALayer()
        glowLayer.frame = bounds.insetBy(dx: 5, dy: 5)
        glowLayer.cornerRadius = glowLayer.bounds.width / 2
        glowLayer.borderWidth = 15  // Wider for more spread
        glowLayer.borderColor = NSColor(calibratedRed: 0.5, green: 0.8, blue: 1.0, alpha: 0.0).cgColor
        glowLayer.shadowColor = NSColor(calibratedRed: 0.5, green: 0.8, blue: 1.0, alpha: 1.0).cgColor
        glowLayer.shadowOpacity = 0
        glowLayer.shadowOffset = CGSize.zero
        glowLayer.shadowRadius = 20  // Larger radius for more blur
        glowLayer.masksToBounds = false
        
        layer?.insertSublayer(glowLayer, at: 1)  // Above gradient, below content
        self.innerGlowLayer = glowLayer
    }
    
    func setHovered(_ hovered: Bool) {
        isHovered = hovered
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            if hovered {
                // Show soft, diffused inner glow
                animator().alphaValue = 1.0
                innerGlowLayer?.shadowOpacity = 1.0
                innerGlowLayer?.borderColor = NSColor(calibratedRed: 0.5, green: 0.8, blue: 1.0, alpha: 0.5).cgColor
            } else {
                // Hide glow
                animator().alphaValue = 0.95
                innerGlowLayer?.shadowOpacity = 0
                innerGlowLayer?.borderColor = NSColor(calibratedRed: 0.5, green: 0.8, blue: 1.0, alpha: 0.0).cgColor
            }
        }
    }
    
    func updateFavicon(for url: String) {
        // Show emoji as fallback
        usingImage = false
        iconImageView.isHidden = true
        iconLabel.isHidden = false
        
        // Simple domain-based icon
        if url.contains("github") {
            iconLabel.stringValue = "📦"
        } else if url.contains("apple") {
            iconLabel.stringValue = "🍎"
        } else if url.contains("google") {
            iconLabel.stringValue = "🔍"
        } else if url.contains("youtube") {
            iconLabel.stringValue = "▶️"
        } else if url.contains("twitter") || url.contains("x.com") {
            iconLabel.stringValue = "🐦"
        } else {
            iconLabel.stringValue = "🌐"
        }
    }
    
    func setFaviconImage(_ image: NSImage) {
        // Show real favicon image
        usingImage = true
        iconImageView.image = image
        iconImageView.isHidden = false
        iconLabel.isHidden = true
    }
}

// MARK: - Delegate Protocol

protocol BubbleWindowDelegate: AnyObject {
    func bubbleWindowDidRequestExpand(_ bubble: BubbleWindow)
    func bubbleWindowDidRequestClose(_ bubble: BubbleWindow)
    func bubbleWindowDidMove(_ bubble: BubbleWindow)
}

