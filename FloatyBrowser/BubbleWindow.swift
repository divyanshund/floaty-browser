//
//  BubbleWindow.swift
//  FloatyBrowser
//
//  A circular, floating, draggable bubble window.
//

import Cocoa

// MARK: - Bubble Appearance

enum BubbleAppearance: String, CaseIterable {
    case frostedGlass = "Frosted Glass"
    case oceanBlue = "Ocean Blue"
    case sunset = "Sunset"
    case forest = "Forest"
    case purpleDream = "Purple Dream"
    case roseGold = "Rose Gold"
    case midnight = "Midnight"
    
    var userDefaultsKey: String {
        return "bubbleAppearance"
    }
    
    static func getCurrentAppearance() -> BubbleAppearance {
        if let savedAppearance = UserDefaults.standard.string(forKey: "bubbleAppearance"),
           let appearance = BubbleAppearance(rawValue: savedAppearance) {
            return appearance
        }
        return .frostedGlass // Default
    }
    
    func saveAsCurrent() {
        UserDefaults.standard.set(self.rawValue, forKey: "bubbleAppearance")
        UserDefaults.standard.synchronize()
        
        // Post notification to update all bubbles
        NotificationCenter.default.post(name: NSNotification.Name("BubbleAppearanceChanged"), object: nil)
    }
    
    // Define gradient colors for each theme
    var gradientColors: (NSColor, NSColor)? {
        switch self {
        case .frostedGlass:
            return nil // Will use NSVisualEffectView
        case .oceanBlue:
            return (
                NSColor(calibratedRed: 0.3, green: 0.6, blue: 1.0, alpha: 0.95),
                NSColor(calibratedRed: 0.2, green: 0.4, blue: 0.8, alpha: 0.95)
            )
        case .sunset:
            return (
                NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.4, alpha: 0.95),
                NSColor(calibratedRed: 0.95, green: 0.35, blue: 0.55, alpha: 0.95)
            )
        case .forest:
            return (
                NSColor(calibratedRed: 0.2, green: 0.7, blue: 0.5, alpha: 0.95),
                NSColor(calibratedRed: 0.15, green: 0.5, blue: 0.35, alpha: 0.95)
            )
        case .purpleDream:
            return (
                NSColor(calibratedRed: 0.7, green: 0.4, blue: 0.95, alpha: 0.95),
                NSColor(calibratedRed: 0.5, green: 0.3, blue: 0.75, alpha: 0.95)
            )
        case .roseGold:
            return (
                NSColor(calibratedRed: 0.95, green: 0.7, blue: 0.75, alpha: 0.95),
                NSColor(calibratedRed: 0.85, green: 0.5, blue: 0.55, alpha: 0.95)
            )
        case .midnight:
            return (
                NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.25, alpha: 0.95),
                NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.15, alpha: 0.95)
            )
        }
    }
}

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
        
        // Make window larger to accommodate close button outside the circular bubble
        // Bubble circle: 60x60, Window: 75x75 (extra 15px for button to sit on top)
        let windowSize = CGSize(width: 75, height: 75)
        let rect = NSRect(origin: position, size: windowSize)
        
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
        
        // CRITICAL: Disable state restoration to prevent macOS from caching/restoring closed windows
        isRestorable = false
        restorationClass = nil
    }
    
    // Allow the panel to receive clicks even when not key
    override var canBecomeKey: Bool {
        return false // Non-activating but still receives clicks
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    private func setupBubbleView() {
        // Create a container view for the window (75x75)
        let containerView = NSView(frame: contentView!.bounds)
        containerView.wantsLayer = true
        
        // Position the circular bubble (60x60) offset to bottom-right within the 75x75 window
        // This leaves space at top-left for the close button to sit outside the circle
        let bubbleSize: CGFloat = 60
        let offset: CGFloat = 15  // Space for close button
        let bubbleFrame = NSRect(x: offset, y: 0, width: bubbleSize, height: bubbleSize)
        
        bubbleView = BubbleView(frame: bubbleFrame, owner: self)
        bubbleView.updateFavicon(for: currentURL)
        
        containerView.addSubview(bubbleView)
        
        // Add close button to container (not to bubbleView) so it sits outside the circle
        let closeButton = bubbleView.createCloseButton()
        containerView.addSubview(closeButton)
        
        contentView = containerView
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
    private var closeButton: NSButton?
    private var gradientLayer: CAGradientLayer?
    private var frostedGlassView: NSVisualEffectView?
    
    init(frame frameRect: NSRect, owner: BubbleWindow) {
        self.bubbleWindow = owner
        super.init(frame: frameRect)
        setupView()
        setupTrackingArea()
        setupInnerGlowLayer()
        applyCurrentAppearance()
        
        // Listen for appearance changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appearanceDidChange),
            name: NSNotification.Name("BubbleAppearanceChanged"),
            object: nil
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // CRITICAL: Allow first click to trigger action, not just activate window
    // Without this, first click on app launch just activates, requiring a second click
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
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
        
        // Allow outer glow and subviews to extend beyond bounds
        clipsToBounds = false
        
        // Circular mask for the layer - but don't mask to bounds for outer shadow
        layer?.cornerRadius = bounds.width / 2
        layer?.masksToBounds = false  // Allow outer glow to render
        
        // Add subtle outer shadow (glow) - hidden by default
        layer?.shadowColor = NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 1.0).cgColor
        layer?.shadowOpacity = 0  // Hidden by default
        layer?.shadowOffset = CGSize.zero
        layer?.shadowRadius = 8  // Subtle blur
        
        // Background will be set by applyCurrentAppearance()
        // Just create the gradient layer placeholder
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.cornerRadius = bounds.width / 2
        gradient.masksToBounds = true
        layer?.insertSublayer(gradient, at: 0)
        self.gradientLayer = gradient
        
        // Icon label (emoji fallback) - centered properly
        // NSTextField doesn't center text vertically by default, so we offset it manually
        let iconSize: CGFloat = 28
        let verticalOffset: CGFloat = -8  // Push down to visually center (negative moves content down)
        iconLabel.font = NSFont.systemFont(ofSize: iconSize)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 0, y: verticalOffset, width: bounds.width, height: bounds.height)
        iconLabel.autoresizingMask = [.width, .height]
        iconLabel.textColor = .white
        iconLabel.drawsBackground = false
        iconLabel.isBezeled = false
        iconLabel.isBordered = false
        iconLabel.isEditable = false
        iconLabel.isSelectable = false
        // Center vertically and horizontally
        iconLabel.usesSingleLineMode = true
        iconLabel.lineBreakMode = .byClipping
        iconLabel.cell?.wraps = false
        iconLabel.cell?.isScrollable = false
        iconLabel.cell?.usesSingleLineMode = true
        iconLabel.baseWritingDirection = .natural
        addSubview(iconLabel)
        
        // Icon image view (for real favicons)
        iconImageView.frame = bounds.insetBy(dx: 12, dy: 12)
        iconImageView.autoresizingMask = [.width, .height]
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.imageAlignment = .alignCenter
        iconImageView.wantsLayer = true
        iconImageView.layer?.magnificationFilter = .linear  // High-quality scaling
        iconImageView.isHidden = true
        addSubview(iconImageView)
    }
    
    @objc private func appearanceDidChange() {
        applyCurrentAppearance()
    }
    
    private func applyCurrentAppearance() {
        let appearance = BubbleAppearance.getCurrentAppearance()
        
        if appearance == .frostedGlass {
            // Use frosted glass effect
            gradientLayer?.isHidden = true
            
            if frostedGlassView == nil {
                let glassView = NSVisualEffectView(frame: bounds)
                glassView.material = .hudWindow
                glassView.blendingMode = .behindWindow
                glassView.state = .active
                glassView.wantsLayer = true
                glassView.layer?.cornerRadius = bounds.width / 2
                glassView.layer?.masksToBounds = true
                glassView.autoresizingMask = [.width, .height]
                
                // Add tinted overlay for better visibility
                // Darker in light mode, lighter in dark mode
                let isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
                if isDarkMode {
                    // In dark mode: lighter tint for visibility against dark backgrounds
                    glassView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.22).cgColor
                } else {
                    // In light mode: darker tint for visibility against light backgrounds
                    glassView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.32).cgColor
                }
                
                // Add visible frosted glass stroke for clear definition
                glassView.layer?.borderWidth = 1.0
                glassView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.5).cgColor
                
                // Insert at the bottom
                addSubview(glassView, positioned: .below, relativeTo: iconLabel)
                frostedGlassView = glassView
            }
            frostedGlassView?.isHidden = false
            
            // Update colors when appearance changes
            let isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
            if isDarkMode {
                frostedGlassView?.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.22).cgColor
            } else {
                frostedGlassView?.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.32).cgColor
            }
            frostedGlassView?.layer?.borderColor = NSColor(white: 1.0, alpha: 0.5).cgColor
            
            iconLabel.textColor = .labelColor
        } else {
            // Use gradient
            frostedGlassView?.isHidden = true
            gradientLayer?.isHidden = false
            
            if let colors = appearance.gradientColors {
                gradientLayer?.colors = [colors.0.cgColor, colors.1.cgColor]
                gradientLayer?.startPoint = CGPoint(x: 0, y: 0)
                gradientLayer?.endPoint = CGPoint(x: 1, y: 1)
            }
            iconLabel.textColor = .white
        }
    }
    
    private func setupInnerGlowLayer() {
        // Create subtle, blurry inner glow layer
        let glowLayer = CALayer()
        glowLayer.frame = bounds.insetBy(dx: 8, dy: 8)
        glowLayer.cornerRadius = glowLayer.bounds.width / 2
        glowLayer.borderWidth = 8  // Thinner for subtlety
        glowLayer.borderColor = NSColor(calibratedRed: 0.6, green: 0.85, blue: 1.0, alpha: 0.0).cgColor
        glowLayer.shadowColor = NSColor(calibratedRed: 0.6, green: 0.85, blue: 1.0, alpha: 1.0).cgColor
        glowLayer.shadowOpacity = 0
        glowLayer.shadowOffset = CGSize.zero
        glowLayer.shadowRadius = 12  // Very blurry and diffused
        glowLayer.masksToBounds = false
        
        layer?.insertSublayer(glowLayer, at: 1)  // Above gradient, below content
        self.innerGlowLayer = glowLayer
    }
    
    func createCloseButton() -> NSButton {
        // Create close button (X) that appears on hover - 20% larger
        let buttonSize: CGFloat = 22  // Increased from 18 (20% larger)
        
        // Position button to sit on top-left of the circular bubble
        // BubbleView is at (15, 0) with size 60x60 within container (75x75)
        // Position so button overlaps the bubble's edge nicely
        let xPos: CGFloat = 12  // Overlaps left edge of bubble
        let yPos: CGFloat = 43  // Overlaps top edge of bubble
        
        let button = NSButton(frame: NSRect(x: xPos, y: yPos, width: buttonSize, height: buttonSize))
        button.title = "×"
        button.font = NSFont.systemFont(ofSize: 20, weight: .semibold)  // Larger, bolder font
        button.bezelStyle = .circular
        button.isBordered = false  // Remove border for cleaner look
        button.wantsLayer = true
        
        // Style the button - dark background with white X
        button.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.95).cgColor  // Darker, more opaque
        button.layer?.cornerRadius = buttonSize / 2  // Perfect circle
        button.contentTintColor = .white
        
        // Add shadow for visibility and depth
        button.layer?.shadowColor = NSColor.black.cgColor
        button.layer?.shadowOpacity = 0.6
        button.layer?.shadowOffset = CGSize(width: 0, height: -1)
        button.layer?.shadowRadius = 3
        
        button.target = self
        button.action = #selector(closeButtonClicked)
        button.alphaValue = 0  // Hidden by default
        
        // Store reference so we can show/hide on hover
        self.closeButton = button
        
        return button
    }
    
    @objc private func closeButtonClicked() {
        bubbleWindow?.bubbleDelegate?.bubbleWindowDidRequestClose(bubbleWindow!)
    }
    
    func setHovered(_ hovered: Bool) {
        isHovered = hovered
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            if hovered {
                // Show subtle outer glow
                animator().alphaValue = 1.0
                layer?.shadowOpacity = 0.4  // Subtle outer glow
                
                // Show subtle, blurry inner glow
                innerGlowLayer?.shadowOpacity = 0.6  // More subtle than before
                innerGlowLayer?.borderColor = NSColor(calibratedRed: 0.6, green: 0.85, blue: 1.0, alpha: 0.3).cgColor
                
                // Show close button
                closeButton?.animator().alphaValue = 1.0
            } else {
                // Hide glows
                animator().alphaValue = 0.95
                layer?.shadowOpacity = 0  // Hide outer glow
                
                innerGlowLayer?.shadowOpacity = 0
                innerGlowLayer?.borderColor = NSColor(calibratedRed: 0.6, green: 0.85, blue: 1.0, alpha: 0.0).cgColor
                
                // Hide close button
                closeButton?.animator().alphaValue = 0
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
        // Show real favicon image with proper Retina scaling
        usingImage = true
        
        // Create a copy of the image to avoid modifying the original
        // This ensures consistent quality across multiple uses
        let displayImage = NSImage(size: image.size)
        displayImage.addRepresentations(image.representations)
        
        // Set explicit size for crisp Retina rendering
        // The image from Google is 128x128, but we display it at 36x36
        // By setting the size to 36x36, NSImage will use the 128x128 data
        // at 2x scale, resulting in perfect Retina quality
        let displaySize = iconImageView.bounds.size
        displayImage.size = displaySize
        
        iconImageView.image = displayImage
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

