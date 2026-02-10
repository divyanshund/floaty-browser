//
//  WebViewController.swift
//  FloatyBrowser
//
//  Manages WKWebView with navigation policy interception for new tabs.
//

import Cocoa
import WebKit
import AuthenticationServices

// Custom cell that vertically centers text in NSTextField
class VerticallyCenteredTextFieldCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        let minimumHeight = cellSize(forBounds: rect).height
        titleRect.origin.y += (titleRect.height - minimumHeight) / 2
        titleRect.size.height = minimumHeight
        return titleRect
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: titleRect(forBounds: cellFrame), in: controlView)
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: titleRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, event: event)
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: titleRect(forBounds: rect), in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

// Custom text field with browser-style select-all behavior
// Selects all text on first click, allows normal cursor positioning while editing
class BrowserStyleTextField: NSTextField {
    private var isCurrentlyEditing = false
    
    // Full URL storage for Safari-style display
    // Shows simplified domain when not editing, full URL when editing
    private var fullURL: String = ""
    
    var hasLockIcon: Bool = false {  // Controls left padding for lock icon
        didSet {
            // Update text indentation when lock icon visibility changes
            updateTextIndentation()
            needsDisplay = true
            invalidateIntrinsicContentSize()
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCell()
        setupFocusGlow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
        setupFocusGlow()
    }
    
    private func setupCell() {
        // Use custom cell for vertical centering
        let centeredCell = VerticallyCenteredTextFieldCell()
        centeredCell.isEditable = true
        centeredCell.isSelectable = true
        centeredCell.isBezeled = true
        centeredCell.bezelStyle = .roundedBezel
        centeredCell.font = self.font
        centeredCell.alignment = self.alignment
        self.cell = centeredCell
    }
    
    /// Set URL with Safari-style display (shows domain when not editing)
    func setURL(_ urlString: String) {
        fullURL = urlString
        if !isCurrentlyEditing {
            // Show simplified domain when not editing
            stringValue = simplifiedURL(from: urlString)
        } else {
            // Show full URL when editing
            stringValue = urlString
        }
    }
    
    /// Get the full URL (for navigation)
    func getFullURL() -> String {
        // If user edited the field, return what they typed
        // Otherwise return the stored full URL
        if isCurrentlyEditing || stringValue != simplifiedURL(from: fullURL) {
            return stringValue
        }
        return fullURL
    }
    
    /// Extract simplified display URL (domain only, no scheme or query params)
    private func simplifiedURL(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        
        // Get host without www prefix
        var host = url.host ?? urlString
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        
        // Add path if it's meaningful (not just "/" or empty)
        let path = url.path
        if !path.isEmpty && path != "/" {
            // Truncate long paths
            let maxPathLength = 20
            if path.count > maxPathLength {
                return host + String(path.prefix(maxPathLength)) + "..."
            }
            return host + path
        }
        
        return host
    }
    
    private func setupFocusGlow() {
        wantsLayer = true
        layer?.borderWidth = 0 // Start with no border
        layer?.borderColor = NSColor.clear.cgColor
    }
    
    // Add left padding when lock icon is visible
    override var intrinsicContentSize: NSSize {
        var size = super.intrinsicContentSize
        if hasLockIcon {
            size.width += 30  // Extra width for lock icon padding
        }
        return size
    }
    
    // Add text indentation when lock icon is visible
    func updateTextIndentation() {
        if hasLockIcon {
            // Create paragraph style with left indent
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 30
            paragraphStyle.headIndent = 30
            
            // Apply to current text if any
            if let currentText = self.attributedStringValue.string as String?, !currentText.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    .paragraphStyle: paragraphStyle,
                    .foregroundColor: self.textColor ?? NSColor.labelColor,
                    .font: self.font ?? NSFont.systemFont(ofSize: 13)
                ]
                self.attributedStringValue = NSAttributedString(string: currentText, attributes: attributes)
            }
        } else {
            // Remove indentation
            if let currentText = self.attributedStringValue.string as String?, !currentText.isEmpty {
                self.stringValue = currentText
            }
        }
    }
    
    private func animateFocusGlow(isFocused: Bool) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            
            if isFocused {
                // Subtle blue glow when focused
                self.layer?.borderWidth = 2.0
                self.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            } else {
                // Remove glow when unfocused
                self.layer?.borderWidth = 0
                self.layer?.borderColor = NSColor.clear.cgColor
            }
        })
    }
    
    override func mouseDown(with event: NSEvent) {
        let wasEditing = isCurrentlyEditing
        
        // Call super to handle the click
        super.mouseDown(with: event)
        
        // Show focus glow immediately on click
        if !wasEditing {
            animateFocusGlow(isFocused: true)
            isCurrentlyEditing = true
        }
        
        // Select all text on first click - needs slight delay for field editor to be ready
        if !wasEditing {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let fieldEditor = self.currentEditor() as? NSTextView {
                    fieldEditor.selectedRange = NSRange(location: 0, length: fieldEditor.string.count)
                    
                    // Apply indentation to field editor
                    if self.hasLockIcon {
                        let paragraphStyle = NSMutableParagraphStyle()
                        paragraphStyle.firstLineHeadIndent = 30
                        paragraphStyle.headIndent = 30
                        
                        var typingAttributes = fieldEditor.typingAttributes
                        typingAttributes[.paragraphStyle] = paragraphStyle
                        fieldEditor.typingAttributes = typingAttributes
                        
                        let range = NSRange(location: 0, length: fieldEditor.textStorage?.length ?? 0)
                        fieldEditor.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
                    }
                }
            }
        }
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        isCurrentlyEditing = true
        animateFocusGlow(isFocused: true)
        
        // Show full URL when editing starts (Safari-style)
        if !fullURL.isEmpty {
            stringValue = fullURL
        }
        
        // Apply indentation and select all on next run loop (after text is set)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Apply text indentation to field editor
            if self.hasLockIcon, let fieldEditor = self.currentEditor() as? NSTextView {
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.firstLineHeadIndent = 30
                paragraphStyle.headIndent = 30
                
                // Set typing attributes for the field editor
                var typingAttributes = fieldEditor.typingAttributes
                typingAttributes[.paragraphStyle] = paragraphStyle
                fieldEditor.typingAttributes = typingAttributes
                
                // Apply to existing text storage
                let range = NSRange(location: 0, length: fieldEditor.textStorage?.length ?? 0)
                fieldEditor.textStorage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
            }
            
            // Select all text
            if let fieldEditor = self.currentEditor() as? NSTextView {
                fieldEditor.selectAll(nil)
            }
        }
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        isCurrentlyEditing = false
        animateFocusGlow(isFocused: false)
        
        // Show simplified URL when editing ends (Safari-style)
        if !fullURL.isEmpty {
            stringValue = simplifiedURL(from: fullURL)
        }
        
        // Ensure indentation is preserved after editing
        updateTextIndentation()
    }
}

// Custom progress bar for address bar
class AddressBarProgressView: NSView {
    private let progressLayer = CALayer()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupProgressLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupProgressLayer()
    }
    
    private func setupProgressLayer() {
        wantsLayer = true
        layer?.masksToBounds = true
        
        // Setup progress layer
        progressLayer.backgroundColor = NSColor.controlAccentColor.cgColor
        progressLayer.frame = CGRect(x: 0, y: 0, width: 0, height: bounds.height)
        layer?.addSublayer(progressLayer)
    }
    
    func setProgress(_ progress: Double, animated: Bool = true) {
        let targetWidth = bounds.width * CGFloat(progress)
        
        if animated {
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            progressLayer.frame = CGRect(x: 0, y: 0, width: targetWidth, height: bounds.height)
            CATransaction.commit()
        } else {
            progressLayer.frame = CGRect(x: 0, y: 0, width: targetWidth, height: bounds.height)
        }
    }
    
    func show() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            self.animator().alphaValue = 1.0
        })
    }
    
    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.animator().alphaValue = 0.0
        })
    }
}

// Custom button with hover state
class HoverButton: NSButton {
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

class WebViewController: NSViewController {
    private var _webView: WKWebView?
    var webView: WKWebView? { return _webView }
    
    private var trafficLightArea: NSView!  // Can be NSVisualEffectView OR NSView
    private var toolbar: NSView!  // Can be NSVisualEffectView OR NSView
    private let backButton = HoverButton()
    private let forwardButton = HoverButton()
    private let reloadButton = HoverButton()
    private let urlField = BrowserStyleTextField()
    private let lockIcon = NSImageView()  // HTTPS lock icon
    private let addressBarProgressView = AddressBarProgressView()
    private let newBubbleButton = HoverButton()
    private var progressIndicator: NSProgressIndicator!
    
    weak var delegate: WebViewControllerDelegate?
    
    // Check if theme colors are enabled (can change dynamically)
    private var useThemeColors: Bool
    
    // Theme color state
    private var currentThemeColor: NSColor?
    private var currentFavicon: NSImage?
    
    // Current page title (for history)
    private var currentPageTitle: String = ""
    
    // External configuration (used for popups)
    private var externalConfiguration: WKWebViewConfiguration?
    
    // Track if this is a popup window (for OAuth auto-close detection)
    private var isPopupWindow: Bool {
        return externalConfiguration != nil
    }
    
    // OAuth authentication session (Apple's official OAuth API)
    private var authSession: ASWebAuthenticationSession?
    
    // Track if we've seen OAuth-related URLs (to avoid closing blank pages prematurely)
    private var hasSeenOAuthURL = false
    
    // Pending URL to load once webView is ready
    private var pendingURL: String?
    
    // Static regex for parsing RGB/RGBA colors (compiled once, reused across all instances)
    private static let rgbColorRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"rgba?\((\d+),\s*(\d+),\s*(\d+)"#)
    }()
    
    // Use shared configuration for session sharing across all bubbles
    private lazy var webConfiguration: WKWebViewConfiguration = {
        // If external config provided (e.g., for popups), we MUST use the exact same object
        // WebKit enforces that the returned WKWebView uses the identical configuration passed
        // to createWebViewWith - creating a copy will cause NSInternalInconsistencyException
        if let external = externalConfiguration {
            // Add viewport script to external config
            // Note: This does modify the passed config, but it's created specifically for this popup
            // and the viewport script is benign (just ensures proper scaling)
            let viewportScript = WKUserScript(
                source: """
                var meta = document.createElement('meta');
                meta.name = 'viewport';
                meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
                document.getElementsByTagName('head')[0].appendChild(meta);
                """,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            external.userContentController.addUserScript(viewportScript)
            
            print("✅ WebViewController: Using external config for popup (required by WebKit)")
            return external
        }
        
        // Get shared configuration with process pool and data store
        let config = SharedWebConfiguration.shared.createConfiguration()
        
        // Add viewport meta tag injection (per-bubble customization)
        let viewportScript = WKUserScript(
            source: """
            var meta = document.createElement('meta');
            meta.name = 'viewport';
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
            document.getElementsByTagName('head')[0].appendChild(meta);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(viewportScript)
        
        NSLog("✅ WebViewController: Using shared WebKit configuration for session sharing")
        
        return config
    }()
    
    var currentURL: String {
        return _webView?.url?.absoluteString ?? ""
    }
    
    init(configuration: WKWebViewConfiguration? = nil) {
        // Decide mode at initialization - NEVER changes after this
        self.useThemeColors = AppearancePreferencesViewController.isThemeColorsEnabled()
        self.externalConfiguration = configuration
        super.init(nibName: nil, bundle: nil)
        NSLog("🎨 WebViewController initialized with theme colors: \(useThemeColors)")
        if configuration != nil {
            NSLog("   ↳ Using external configuration (popup window)")
        }
    }
    
    required init?(coder: NSCoder) {
        // Decide mode at initialization
        self.useThemeColors = AppearancePreferencesViewController.isThemeColorsEnabled()
        self.externalConfiguration = nil
        super.init(coder: coder)
        NSLog("🎨 WebViewController initialized with theme colors: \(useThemeColors)")
    }
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 600))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupToolbar()
        setupWebView()
        
        // Listen for theme color mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeColorModeChanged(_:)),
            name: .themeColorModeChanged,
            object: nil
        )
        
        // Load any pending URL that was requested before the view was ready
        if let pending = pendingURL {
            print("WebView ready, loading pending URL")
            pendingURL = nil
            loadURL(pending)
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure web view can receive keyboard events
        if let webView = _webView {
            view.window?.makeFirstResponder(webView)
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Manually update URL field width to maintain gap with plus button
        // This keeps the address bar expanding with the window while keeping the plus button separate
        let buttonSize: CGFloat = 28
        let rightMargin: CGFloat = 12
        let addressBarRightMargin: CGFloat = 16  // Match spacing from setupToolbar
        let minAddressBarWidth: CGFloat = 200  // Match setupToolbar
        
        // Calculate where plus button should be (it auto-positions via autoresizingMask)
        let plusButtonX = view.bounds.width - buttonSize - rightMargin
        
        // Update URL field width to fill space between its current X and the plus button
        let urlFieldX = urlField.frame.origin.x  // Keep current left position
        let availableWidth = plusButtonX - urlFieldX - addressBarRightMargin
        let newUrlFieldWidth = max(minAddressBarWidth, availableWidth)  // Ensure minimum width
        
        // Only update if width actually changed (avoid unnecessary updates)
        if abs(urlField.frame.width - newUrlFieldWidth) > 0.1 {
            urlField.frame.size.width = newUrlFieldWidth
            
            // Also update progress bar to match
            addressBarProgressView.frame.size.width = newUrlFieldWidth
        }
    }
    
    private func setupToolbar() {
        // Add space for traffic lights (standard macOS titlebar height is ~28px, we'll use 30 for comfort)
        let trafficLightHeight: CGFloat = 30
        let toolbarHeight: CGFloat = 44  // Slightly taller for better spacing
        let totalTopHeight = trafficLightHeight + toolbarHeight
        
        // Create traffic light area
        if useThemeColors {
            // Mode 1: Solid colored view
            let solidView = NSView(frame: NSRect(x: 0, y: view.bounds.height - trafficLightHeight, width: view.bounds.width, height: trafficLightHeight))
            solidView.autoresizingMask = [.width, .minYMargin]
            solidView.wantsLayer = true
            solidView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            trafficLightArea = solidView
            NSLog("✅ Created SOLID traffic light area (theme colors enabled)")
        } else {
            // Mode 2: Frosted glass vibrancy
            let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: view.bounds.height - trafficLightHeight, width: view.bounds.width, height: trafficLightHeight))
            visualEffectView.autoresizingMask = [.width, .minYMargin]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.alphaValue = 0.95
            trafficLightArea = visualEffectView
            NSLog("✅ Created FROSTED GLASS traffic light area (theme colors disabled)")
        }
        view.addSubview(trafficLightArea)
        
        // Create toolbar
        if useThemeColors {
            // Mode 1: Solid colored view
            let solidView = NSView(frame: NSRect(x: 0, y: view.bounds.height - totalTopHeight, width: view.bounds.width, height: toolbarHeight))
            solidView.autoresizingMask = [.width, .minYMargin]
            solidView.wantsLayer = true
            solidView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor  // Start with default, will be colored later
            toolbar = solidView
            NSLog("✅ Created SOLID toolbar (theme colors enabled)")
        } else {
            // Mode 2: Frosted glass vibrancy
            let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: view.bounds.height - totalTopHeight, width: view.bounds.width, height: toolbarHeight))
            visualEffectView.autoresizingMask = [.width, .minYMargin]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.alphaValue = 0.95
            toolbar = visualEffectView
            NSLog("✅ Created FROSTED GLASS toolbar (theme colors disabled)")
        }
        
        let buttonSize: CGFloat = 28  // Modern square buttons
        let buttonY: CGFloat = (toolbarHeight - buttonSize) / 2  // Center vertically
        var xOffset: CGFloat = 12  // More generous left margin
        
        // Back button - modern SF Symbol style
        backButton.frame = NSRect(x: xOffset, y: buttonY, width: buttonSize, height: buttonSize)
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Go Back")
        backButton.imagePosition = .imageOnly
        backButton.isBordered = false
        backButton.bezelStyle = .regularSquare
        backButton.contentTintColor = .secondaryLabelColor
        backButton.target = self
        backButton.action = #selector(goBack)
        backButton.isEnabled = false
        backButton.toolTip = "Go Back"
        styleModernButton(backButton)
        toolbar.addSubview(backButton)
        xOffset += buttonSize + 2
        
        // Forward button
        forwardButton.frame = NSRect(x: xOffset, y: buttonY, width: buttonSize, height: buttonSize)
        forwardButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Go Forward")
        forwardButton.imagePosition = .imageOnly
        forwardButton.isBordered = false
        forwardButton.bezelStyle = .regularSquare
        forwardButton.contentTintColor = .secondaryLabelColor
        forwardButton.target = self
        forwardButton.action = #selector(goForward)
        forwardButton.isEnabled = false
        forwardButton.toolTip = "Go Forward"
        styleModernButton(forwardButton)
        toolbar.addSubview(forwardButton)
        xOffset += buttonSize + 8
        
        // Reload button
        reloadButton.frame = NSRect(x: xOffset, y: buttonY, width: buttonSize, height: buttonSize)
        reloadButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload")
        reloadButton.imagePosition = .imageOnly
        reloadButton.isBordered = false
        reloadButton.bezelStyle = .regularSquare
        reloadButton.contentTintColor = .secondaryLabelColor
        reloadButton.target = self
        reloadButton.action = #selector(reload)
        reloadButton.toolTip = "Reload Page"
        styleModernButton(reloadButton)
        toolbar.addSubview(reloadButton)
        
        // Add generous spacing after reload button before address bar
        let addressBarLeftMargin: CGFloat = 16
        xOffset += buttonSize + addressBarLeftMargin
        
        // Calculate plus button position (need this for address bar width calculation)
        let rightMargin: CGFloat = 12
        let plusButtonX = view.bounds.width - buttonSize - rightMargin
        
        // URL field - positioned BETWEEN reload button and plus button  
        let addressBarRightMargin: CGFloat = 16
        let minAddressBarWidth: CGFloat = 200  // Minimum width for address bar
        
        // Calculate available width
        let availableWidth = plusButtonX - xOffset - addressBarRightMargin
        let urlFieldWidth = max(minAddressBarWidth, availableWidth)  // Ensure minimum width
        let urlFieldHeight: CGFloat = 34  // Slightly taller for better presence
        let urlFieldY = (toolbarHeight - urlFieldHeight) / 2
        
        urlField.frame = NSRect(x: xOffset, y: urlFieldY, width: urlFieldWidth, height: urlFieldHeight)
        // No autoresizing - we'll handle layout manually to keep gap with plus button
        
        NSLog("🎯 Address bar layout - X: \(xOffset), Available width: \(availableWidth), Final width: \(urlFieldWidth), Reload button ends at: \(xOffset - addressBarLeftMargin)")
        
        urlField.placeholderString = "Search or enter website"
        urlField.delegate = self
        urlField.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        urlField.alignment = .left
        
        // Modern URL field styling - very rounded, clean look
        urlField.isBezeled = true
        urlField.bezelStyle = .roundedBezel  // Use native rounded bezel for proper centering
        urlField.focusRingType = .none
        urlField.wantsLayer = true
        urlField.layer?.cornerRadius = 16  // Very rounded
        urlField.layer?.masksToBounds = true
        urlField.clipsToBounds = true  // Ensure nothing draws outside bounds
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
        
        // Add subtle border
        urlField.layer?.borderWidth = 0.5
        urlField.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        toolbar.addSubview(urlField)
        
        // Lock icon - positioned inside address bar on the left
        let lockIconSize: CGFloat = 14
        let lockIconPadding: CGFloat = 10
        lockIcon.frame = NSRect(
            x: urlField.frame.origin.x + lockIconPadding,
            y: urlField.frame.origin.y + (urlFieldHeight - lockIconSize) / 2,
            width: lockIconSize,
            height: lockIconSize
        )
        lockIcon.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Secure")
        lockIcon.contentTintColor = .secondaryLabelColor
        lockIcon.imageScaling = .scaleProportionallyUpOrDown
        lockIcon.isHidden = true  // Hidden by default, shown when HTTPS
        toolbar.addSubview(lockIcon)
        
        // Address bar progress view - positioned at the bottom of the address bar
        let progressBarHeight: CGFloat = 3
        addressBarProgressView.frame = NSRect(
            x: urlField.frame.origin.x,
            y: urlField.frame.origin.y,
            width: urlField.frame.width,
            height: progressBarHeight
        )
        // No autoresizing - we'll update in viewDidLayout
        addressBarProgressView.wantsLayer = true
        addressBarProgressView.layer?.cornerRadius = 1.5  // Slight rounding
        addressBarProgressView.layer?.masksToBounds = true
        addressBarProgressView.alphaValue = 0  // Start hidden
        toolbar.addSubview(addressBarProgressView)
        
        // New bubble button - add AFTER address bar so it's on top (clickable)
        newBubbleButton.frame = NSRect(x: plusButtonX, y: buttonY, width: buttonSize, height: buttonSize)
        newBubbleButton.autoresizingMask = [.minXMargin]  // Stay on right side
        newBubbleButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Bubble")
        newBubbleButton.imagePosition = .imageOnly
        newBubbleButton.isBordered = false
        newBubbleButton.bezelStyle = .regularSquare
        newBubbleButton.contentTintColor = .secondaryLabelColor
        newBubbleButton.target = self
        newBubbleButton.action = #selector(createNewBubble)
        newBubbleButton.toolTip = "Pop out to new bubble"
        styleModernButton(newBubbleButton)
        toolbar.addSubview(newBubbleButton)
        
        view.addSubview(toolbar)
    }
    
    private func styleModernButton(_ button: NSButton) {
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        button.layer?.masksToBounds = true
    }
    
    private func setupWebView() {
        // Total top space = traffic lights (30px) + toolbar (44px) = 74px
        let totalTopSpace: CGFloat = 74
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        _webView = webView
        
        webView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - totalTopSpace)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Allow keyboard events in WKWebView
        webView.allowsBackForwardNavigationGestures = true
        
        // Set custom user agent to identify as Safari on macOS
        // Using Safari UA since WKWebView IS the Safari engine - more authentic than pretending to be Chrome
        // This may help with sites like Google that detect embedded WebViews
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
        
        // Add progress indicator (position it just below the toolbar)
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.frame = NSRect(x: 0, y: view.bounds.height - totalTopSpace - 2, width: view.bounds.width, height: 2)
        progressIndicator.autoresizingMask = [.width, .minYMargin]
        progressIndicator.isHidden = true
        
        view.addSubview(webView)
        view.addSubview(progressIndicator)
        
        // Observe loading progress
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Safety check - ensure webView exists and view is loaded before accessing UI
        guard let webView = _webView, isViewLoaded else { return }
        
        if keyPath == #keyPath(WKWebView.estimatedProgress) {
            let progress = webView.estimatedProgress
            
            // Update old progress indicator
            progressIndicator.doubleValue = progress
            progressIndicator.isHidden = progress >= 1.0
            
            // Update address bar progress view
            if progress > 0 && progress < 1.0 {
                // Show and update progress
                if addressBarProgressView.alphaValue == 0 {
                    addressBarProgressView.show()
                }
                addressBarProgressView.setProgress(progress)
            } else if progress >= 1.0 {
                // Page loaded - hide progress bar after brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.addressBarProgressView.hide()
                    // Reset progress after hiding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.addressBarProgressView.setProgress(0, animated: false)
                    }
                }
            }
        } else if keyPath == #keyPath(WKWebView.canGoBack) {
            backButton.isEnabled = webView.canGoBack
        } else if keyPath == #keyPath(WKWebView.canGoForward) {
            forwardButton.isEnabled = webView.canGoForward
        } else if keyPath == #keyPath(WKWebView.url) {
            if let url = webView.url {
                // Use setURL for Safari-style display (shows domain when not editing)
                urlField.setURL(url.absoluteString)
                // Apply indentation after setting URL (preserves lock icon spacing)
                urlField.updateTextIndentation()
                delegate?.webViewController(self, didUpdateURL: url.absoluteString)
                // Update lock icon when URL changes
                updateLockIcon()
                // Don't fetch favicon here - wait for page to load
            }
        } else if keyPath == #keyPath(WKWebView.title) {
            // Store title for history recording
            currentPageTitle = webView.title ?? ""
        }
    }
    
    func loadURL(_ urlString: String) {
        // Create a local copy of the string to ensure it's retained
        let trimmedInput = String(urlString.trimmingCharacters(in: .whitespacesAndNewlines))
        
        guard !trimmedInput.isEmpty else { return }
        
        // Safety: For popup windows, don't manually load URLs
        // WebKit automatically navigates popups - manual loading causes race conditions
        if isPopupWindow {
            if let existingURL = _webView?.url, existingURL.absoluteString != "about:blank" {
                NSLog("⚠️ Skipping manual loadURL for popup - WebKit already navigated to: \(existingURL)")
                return
            }
            // Allow loading "about:blank" popups in case they need navigation
            if trimmedInput == "about:blank" {
                NSLog("⚠️ Skipping loadURL for about:blank popup - WebKit handles this")
                return
            }
        }
        
        // Check if webView is ready - if not, store URL for later
        guard let webView = _webView else {
            print("WebView not ready, storing URL for later")
            pendingURL = trimmedInput
            return
        }
        
        // Additional safety: ensure webView is in view hierarchy
        // If not, defer loading to next run loop
        if webView.superview == nil || webView.window == nil {
            print("WebView not in view hierarchy yet, deferring load")
            let urlCopy = String(trimmedInput)  // Ensure string is retained
            DispatchQueue.main.async { [weak self] in
                self?.loadURL(urlCopy)
            }
            return
        }
        
        // Determine if input is a URL or search query
        if isURL(trimmedInput) {
            // It's a URL - load it directly
            var urlToLoad = String(trimmedInput)  // Create explicit copy
            
            // Add scheme if missing
            if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
                urlToLoad = "https://" + urlToLoad
            }
            
            guard let url = URL(string: urlToLoad) else { return }
            print("Loading URL: \(url.absoluteString)")
            webView.load(URLRequest(url: url))
        } else {
            // It's a search query - use search engine
            performSearch(query: trimmedInput)
        }
    }
    
    /// Detects if input is a URL or search query
    private func isURL(_ input: String) -> Bool {
        // Already has scheme
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            return true
        }
        
        // Contains spaces - definitely a search query, not a URL
        if input.contains(" ") {
            return false
        }
        
        // Has domain extension and no spaces - likely URL
        let domainPattern = #"^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}(/.*)?$"#
        if let regex = try? NSRegularExpression(pattern: domainPattern),
           regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
            return true
        }
        
        // localhost or IP address pattern
        if input.hasPrefix("localhost") {
            return true
        }
        
        // Check for IP address pattern (simplified)
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"#
        if let ipRegex = try? NSRegularExpression(pattern: ipPattern),
           ipRegex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil {
            return true
        }
        
        // Default to search for single words or unclear input
        return false
    }
    
    /// Performs a search using the saved search engine
    private func performSearch(query: String) {
        // Create local copy of query to ensure retention
        let queryCopy = String(query)
        
        // Ensure webView is ready
        guard let webView = _webView else {
            print("WebView not ready for search, storing query for later")
            pendingURL = queryCopy
            return
        }
        
        // Additional safety: ensure webView is in view hierarchy
        if webView.superview == nil || webView.window == nil {
            print("WebView not in view hierarchy for search, deferring")
            DispatchQueue.main.async { [weak self] in
                self?.performSearch(query: queryCopy)
            }
            return
        }
        
        // Get the current search engine from preferences
        let searchEngine = SearchPreferencesViewController.getCurrentSearchEngine()
        
        // Encode the query for URL
        guard let encodedQuery = queryCopy.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        
        // Construct search URL
        let searchURLString = searchEngine.searchURL + encodedQuery
        
        guard let url = URL(string: searchURLString) else { return }
        print("Searching: \(url.absoluteString)")
        webView.load(URLRequest(url: url))
    }
    
    @objc private func goBack() {
        _webView?.goBack()
    }
    
    @objc private func goForward() {
        _webView?.goForward()
    }
    
    @objc private func reload() {
        _webView?.reload()
    }
    
    @objc private func createNewBubble() {
        if let url = _webView?.url {
            delegate?.webViewController(self, didRequestNewBubble: url.absoluteString)
        }
    }
    
    // Note: suspendWebView/resumeWebView were removed - document.hidden is read-only
    // and these methods were never called. WebView lifecycle is handled naturally
    // by window visibility (orderOut/orderFront).
    
    private func fetchFavicon() {
        NSLog("🎨 FloatyBrowser: Attempting to fetch favicon")
        
        guard let webView = _webView else {
            NSLog("⚠️ WebView not available for favicon fetch")
            return
        }
        
        // JavaScript to extract the BEST favicon from the page
        // Priority: apple-touch-icon (180px) > large icons > any icon > /favicon.ico
        let script = """
        (function() {
            var links = document.getElementsByTagName('link');
            var bestIcon = null;
            var bestSize = 0;
            
            for (var i = 0; i < links.length; i++) {
                var link = links[i];
                var rel = (link.getAttribute('rel') || '').toLowerCase();
                
                // Priority 1: Apple touch icon (usually 180x180)
                if (rel.includes('apple-touch-icon')) {
                    return link.href;
                }
                
                // Check for icon links
                if (rel.includes('icon')) {
                    var sizes = link.getAttribute('sizes') || '';
                    var size = 0;
                    
                    // Parse size (e.g., "192x192" -> 192)
                    var match = sizes.match(/(\\d+)x(\\d+)/);
                    if (match) {
                        size = parseInt(match[1], 10);
                    }
                    
                    // Keep track of largest icon
                    if (size > bestSize || (!bestIcon && size === 0)) {
                        bestSize = size;
                        bestIcon = link.href;
                    }
                }
            }
            
            // Return best found icon, or fallback to /favicon.ico
            return bestIcon || (window.location.origin + '/favicon.ico');
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                NSLog("❌ FloatyBrowser: Favicon JS error: \(error.localizedDescription)")
                return
            }
            
            guard let self = self,
                  let urlString = result as? String,
                  let url = URL(string: urlString) else {
                NSLog("❌ FloatyBrowser: Invalid favicon URL")
                return
            }
            
            NSLog("🎨 FloatyBrowser: Found favicon URL: \(url.absoluteString)")
            
            // Download favicon
            self.downloadFavicon(from: url)
        }
    }
    
    private func downloadFavicon(from url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("❌ FloatyBrowser: Favicon download error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, !data.isEmpty else {
                NSLog("❌ FloatyBrowser: Favicon data is empty")
                return
            }
            
            guard let image = NSImage(data: data) else {
                NSLog("❌ FloatyBrowser: Failed to create NSImage from favicon data")
                return
            }
            
            NSLog("✅ FloatyBrowser: Successfully loaded favicon")
            
            // Store favicon for color extraction
            self.currentFavicon = image
            
            // Update on main thread
            DispatchQueue.main.async {
                self.delegate?.webViewController(self, didUpdateFavicon: image)
            }
        }.resume()
    }
    
    deinit {
        // Only remove observers if webView was initialized
        if let webView = _webView {
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
            webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Dynamic Mode Switching
    
    @objc private func themeColorModeChanged(_ notification: Notification) {
        guard let enabled = notification.userInfo?["enabled"] as? Bool else { return }
        
        NSLog("📢 WebViewController received theme color mode change: \(enabled)")
        
        // Update our mode
        useThemeColors = enabled
        
        // Swap the views
        swapToolbarViews(toColoredMode: enabled)
        swapTrafficLightAreaViews(toColoredMode: enabled)
        
        // Re-apply colors if we switched to colored mode, or reset to default
        if enabled {
            applyThemeColorForCurrentURL()
        } else {
            // Reset to default icon colors (gray icons for frosted glass)
            resetToDefaultIconColors()
        }
        
        // Notify PanelWindow if we're in one
        if let panelWindow = view.window as? PanelWindow {
            panelWindow.handleThemeColorModeChanged(enabled)
        }
        
        NSLog("✅ Successfully switched to \(enabled ? "COLORED" : "FROSTED GLASS") mode")
    }
    
    private func swapToolbarViews(toColoredMode: Bool) {
        NSLog("🔄 Swapping toolbar to \(toColoredMode ? "colored" : "frosted glass") mode")
        
        let trafficLightHeight: CGFloat = 30
        let toolbarHeight: CGFloat = 44
        let totalTopHeight = trafficLightHeight + toolbarHeight
        let frame = NSRect(x: 0, y: view.bounds.height - totalTopHeight, width: view.bounds.width, height: toolbarHeight)
        
        // Store all subviews
        let subviews = toolbar.subviews
        
        // Remove old toolbar
        toolbar.removeFromSuperview()
        
        // Create new toolbar
        if toColoredMode {
            // Solid view
            let solidView = NSView(frame: frame)
            solidView.autoresizingMask = [.width, .minYMargin]
            solidView.wantsLayer = true
            solidView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            toolbar = solidView
        } else {
            // Frosted glass
            let visualEffectView = NSVisualEffectView(frame: frame)
            visualEffectView.autoresizingMask = [.width, .minYMargin]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.alphaValue = 0.95
            toolbar = visualEffectView
        }
        
        // Re-add all subviews
        for subview in subviews {
            toolbar.addSubview(subview)
        }
        
        // Add toolbar back
        view.addSubview(toolbar)
        
        NSLog("✅ Toolbar swapped")
    }
    
    private func swapTrafficLightAreaViews(toColoredMode: Bool) {
        NSLog("🔄 Swapping traffic light area to \(toColoredMode ? "colored" : "frosted glass") mode")
        
        let trafficLightHeight: CGFloat = 30
        let frame = NSRect(x: 0, y: view.bounds.height - trafficLightHeight, width: view.bounds.width, height: trafficLightHeight)
        
        // Store all subviews
        let subviews = trafficLightArea.subviews
        
        // Remove old traffic light area
        trafficLightArea.removeFromSuperview()
        
        // Create new traffic light area
        if toColoredMode {
            // Solid view
            let solidView = NSView(frame: frame)
            solidView.autoresizingMask = [.width, .minYMargin]
            solidView.wantsLayer = true
            solidView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            trafficLightArea = solidView
        } else {
            // Frosted glass
            let visualEffectView = NSVisualEffectView(frame: frame)
            visualEffectView.autoresizingMask = [.width, .minYMargin]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.alphaValue = 0.95
            trafficLightArea = visualEffectView
        }
        
        // Re-add all subviews
        for subview in subviews {
            trafficLightArea.addSubview(subview)
        }
        
        // Add traffic light area back
        view.addSubview(trafficLightArea)
        
        NSLog("✅ Traffic light area swapped")
    }
    
    // MARK: - Network Error Detection
    
    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                 NSURLErrorDNSLookupFailed, NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost, NSURLErrorTimedOut:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    private func loadSnakeGame() {
        guard let gameURL = Bundle.main.url(forResource: "snake_game", withExtension: "html") else {
            print("❌ Could not find snake_game.html")
            return
        }
        _webView?.loadFileURL(gameURL, allowingReadAccessTo: gameURL.deletingLastPathComponent())
        print("🎮 FloatyBrowser: Loading Snake Game - no internet detected")
    }
}

// MARK: - NSTextFieldDelegate

extension WebViewController: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // User pressed Enter - use getFullURL() to get what user typed or the stored URL
            loadURL(urlField.getFullURL())
            view.window?.makeFirstResponder(nil) // Dismiss keyboard focus
            return true
        }
        return false
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Allow all navigation
        // Note: Google sign-in is blocked by Google's security policy for embedded WebViews.
        // This is a known limitation - Google requires sign-in via Safari or Chrome.
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Safety check: ensure view is loaded before accessing UI elements
        guard isViewLoaded else { return }
        
        progressIndicator.isHidden = false
        progressIndicator.doubleValue = 0
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // Safety check: ensure this is our webView and we haven't been deallocated
        guard webView === _webView else {
            NSLog("⚠️ didCommit called with wrong webView, ignoring")
            return
        }
        
        NSLog("📍 Page committed (started loading): \(webView.url?.absoluteString ?? "unknown")")
        
        // Reset to default colors immediately when navigating to a new page
        // This ensures text is always visible during the transition
        // Only do this if the view is loaded and toolbar exists
        if useThemeColors && isViewLoaded {
            resetToDefaultIconColors()
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Safety check: ensure this is our webView
        guard webView === _webView else {
            NSLog("⚠️ didFinish called with wrong webView, ignoring")
            return
        }
        
        // Safety check: ensure view is loaded before accessing UI elements
        guard isViewLoaded else {
            NSLog("⚠️ didFinish called before view loaded, ignoring")
            return
        }
        
        progressIndicator.isHidden = true
        
        // Update lock icon based on URL scheme
        updateLockIcon()
        
        // Record history (skip for popup windows to avoid duplicates)
        if !isPopupWindow, let url = webView.url {
            let title = webView.title ?? currentPageTitle
            HistoryManager.shared.recordVisit(url: url.absoluteString, title: title)
        }
        
        // Fetch favicon after page fully loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchFavicon()
        }
        
        // Extract and apply theme colors if enabled
        if useThemeColors {
            // Reset to default colors immediately to ensure text is visible
            // The async extraction will update colors once complete
            resetToDefaultIconColors()
            extractAndApplyThemeColor()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        // Safety check: ensure view is loaded before accessing UI elements
        guard isViewLoaded else { return }
        
        progressIndicator.isHidden = true
        print("❌ Navigation failed: \(error.localizedDescription)")
        if isNetworkError(error) {
            loadSnakeGame()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Safety check: ensure view is loaded before accessing UI elements
        guard isViewLoaded else { return }
        
        progressIndicator.isHidden = true
        print("❌ Provisional navigation failed: \(error.localizedDescription)")
        if isNetworkError(error) {
            loadSnakeGame()
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {
    /// Handle popup window requests (window.open(), target="_blank", etc.)
    /// OAuth popups use ASWebAuthenticationSession, other popups open in new panels
    ///
    /// IMPORTANT: Facebook and other sites often open blank popups first (nil URL or about:blank),
    /// then navigate them via JavaScript. We must ALWAYS create a WKWebView for popup requests,
    /// never return nil, or WebKit will crash when the JS tries to use the popup reference.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // URL may be nil for blank popups - that's OK, we still create the webView
        let url = navigationAction.request.url
        
        // Only check OAuth if we have a URL - blank popups are never OAuth
        if let url = url, isOAuthURL(url) {
            NSLog("🔐 OAuth detected - using ASWebAuthenticationSession")
            startOAuthWithAuthenticationSession(url: url, parentWebView: webView)
            return nil  // Don't create popup - ASWebAuthenticationSession handles it
        }
        
        // For all other popups (including blank ones), create a new panel
        // WebKit will navigate the popup automatically via the page's JavaScript
        NSLog("🪟 Creating popup panel for: \(url?.absoluteString ?? "blank/nil URL")")
        if let popupWebView = delegate?.webViewController(self, createPopupPanelFor: url, configuration: configuration) {
            return popupWebView
        }
        return nil
    }
    
    /// Start OAuth flow using Apple's ASWebAuthenticationSession
    /// This is the official, proper way to handle OAuth in native macOS apps
    private func startOAuthWithAuthenticationSession(url: URL, parentWebView: WKWebView) {
        // Check if we already have an active session
        if authSession != nil {
            NSLog("⚠️ OAuth session already in progress (normal for multi-step OAuth)")
            return
        }
        
        NSLog("🚀 Starting OAuth with ASWebAuthenticationSession")
        
        // Extract the callback URL scheme from the OAuth URL
        let callbackScheme = extractCallbackScheme(from: url)
        
        // Use weak reference to parent WebView to prevent crash if panel is closed during auth
        weak var weakParentWebView = parentWebView
        
        // Create authentication session
        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackScheme
        ) { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.handleAuthenticationSessionCallback(
                    callbackURL: callbackURL,
                    error: error,
                    parentWebView: weakParentWebView
                )
            }
        }
        
        // Set presentation context provider
        if let session = authSession {
            // For ASWebAuthenticationSession to work, it needs a presentation context
            if #available(macOS 10.15, *) {
                session.presentationContextProvider = self
            }
            
            // Prefer ephemeral session (doesn't persist cookies)
            // Set to false so cookies ARE shared with our WebView
            session.prefersEphemeralWebBrowserSession = false
            
            // IMPORTANT: For Google Sign-In to work, we need to allow it to use
            // the system's authentication cookies. This is already enabled above.
            
            // Start the session
            let started = session.start()
            
            if started {
                NSLog("✅ ASWebAuthenticationSession started successfully")
                NSLog("   ↳ System authentication sheet will appear")
                NSLog("   ↳ User will authenticate in secure system view")
            } else {
                NSLog("❌ Failed to start ASWebAuthenticationSession")
            }
        } else {
            NSLog("❌ Failed to create ASWebAuthenticationSession")
        }
    }
    
    /// Extract callback URL scheme from OAuth URL
    /// This parses the redirect_uri parameter to determine what scheme to intercept
    private func extractCallbackScheme(from url: URL) -> String {
        // Try to find redirect_uri in the OAuth URL
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for item in queryItems where item.name == "redirect_uri" {
                if let redirectURI = item.value,
                   let redirectURL = URL(string: redirectURI),
                   let scheme = redirectURL.scheme {
                    return scheme
                }
            }
        }
        
        // Default to https if we can't find redirect_uri
        return "https"
    }
    
    /// Handle callback from ASWebAuthenticationSession
    /// Note: parentWebView is weak to prevent crashes if the panel was closed during auth
    private func handleAuthenticationSessionCallback(callbackURL: URL?, error: Error?, parentWebView: WKWebView?) {
        // Clear session reference
        authSession = nil
        
        if let error = error {
            let nsError = error as NSError
            
            // Check if user cancelled
            if nsError.domain == ASWebAuthenticationSessionErrorDomain &&
               nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                NSLog("⚠️ OAuth cancelled or completed")
                
                // Try reloading parent page in case OAuth set cookies
                // Use weak reference to avoid crash if panel was closed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak parentWebView] in
                    parentWebView?.reload()
                }
                return
            }
            
            NSLog("❌ OAuth error: \(error.localizedDescription)")
            return
        }
        
        guard let callbackURL = callbackURL else {
            NSLog("❌ No callback URL received from OAuth")
            return
        }
        
        NSLog("✅ OAuth callback received - completing login")
        
        // Navigate parent WebView to the callback URL (if still available)
        // The website will process this and complete the login
        if let webView = parentWebView {
            webView.load(URLRequest(url: callbackURL))
        } else {
            NSLog("⚠️ Parent WebView no longer available, cannot complete OAuth callback")
        }
        
        // Bring app to foreground
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// Detects if a URL is an OAuth/authentication URL
    /// OAuth URLs are handled by ASWebAuthenticationSession
    ///
    /// IMPORTANT: ASWebAuthenticationSession only works for FIRST-PARTY OAuth
    /// (where our app is the OAuth client). It does NOT work for third-party login
    /// scenarios like "Login with Facebook" on Instagram/Spotify, because the callback
    /// goes back to the third-party site, not a custom URL scheme we control.
    ///
    /// For this reason, we EXCLUDE providers commonly used as third-party login
    /// (Facebook, Google) and let them work as normal popups with shared cookies.
    private func isOAuthURL(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        let host = url.host?.lowercased() ?? ""
        
        // EXCLUDED: Providers commonly used for third-party login
        // These work better as popups with shared cookies
        // - Facebook: Used by Instagram, Spotify, many others
        // - Google: Blocks ASWebAuthenticationSession anyway
        let excludedProviders = [
            "facebook.com",
            "accounts.google.com",
            "google.com/accounts",
        ]
        
        for provider in excludedProviders {
            if host.contains(provider) || urlString.contains(provider) {
                print("🌐 Third-party login provider detected (\(provider)) - using popup instead of OAuth session")
                return false
            }
        }
        
        // Only use ASWebAuthenticationSession for providers where:
        // 1. Our app is the OAuth client (rare for a browser)
        // 2. We control the callback URL scheme
        // Since this is a browser, these cases are rare - mostly for internal app features
        
        let path = url.path.lowercased()
        let query = url.query?.lowercased() ?? ""
        
        // Well-known OAuth provider domains that might work with ASWebAuthenticationSession
        // These are less commonly used as third-party login providers
        let oauthProviderDomains = [
            "login.microsoftonline.com",     // Microsoft OAuth
            "appleid.apple.com",             // Apple Sign In
            "api.twitter.com/oauth",         // Twitter OAuth API
            "twitter.com/i/oauth2",          // Twitter OAuth2
            "x.com/i/oauth2",                // X (Twitter) OAuth2
            "github.com/login/oauth",        // GitHub OAuth (specific path)
            "linkedin.com/oauth",            // LinkedIn OAuth
            "discord.com/oauth2",            // Discord OAuth
            "discord.com/api/oauth2",        // Discord OAuth API
            "slack.com/oauth",               // Slack OAuth
            "accounts.spotify.com",          // Spotify OAuth (when Spotify is the client)
            "www.dropbox.com/oauth2",        // Dropbox OAuth
        ]
        
        for domain in oauthProviderDomains {
            if urlString.contains(domain) {
                print("🔐 OAuth detected: known provider domain - \(domain)")
                return true
            }
        }
        
        // For unknown domains, require STRONG OAuth indicators
        let hasOAuthPath = path.contains("/oauth") || path.contains("/oauth2")
        let hasClientId = query.contains("client_id=")
        let hasRedirectUri = query.contains("redirect_uri=")
        let hasResponseType = query.contains("response_type=")
        
        // Require OAuth path + at least client_id + redirect_uri (standard OAuth spec)
        if hasOAuthPath && hasClientId && hasRedirectUri {
            print("🔐 OAuth detected: OAuth path with required query params")
            return true
        }
        
        // Also detect if we have response_type (code/token) with client_id
        if hasResponseType && hasClientId {
            print("🔐 OAuth detected: response_type with client_id")
            return true
        }
        
        // NOT detected as OAuth - will open as normal popup
        return false
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Web Page Alert"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        completionHandler()
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Confirm"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        delegate?.webViewControllerDidRequestClose(self)
    }
    
}

// MARK: - ASWebAuthenticationPresentationContextProviding

@available(macOS 10.15, *)
extension WebViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the window that should present the authentication sheet
        return view.window ?? NSApplication.shared.windows.first ?? NSWindow()
    }
}

// MARK: - Theme Color Management

extension WebViewController {
    /// Main orchestrator - tries extraction methods in priority order
    func extractAndApplyThemeColor() {
        guard useThemeColors else {
            return
        }
        
        guard let url = _webView?.url, let host = url.host else {
            applyDefaultThemeColor()
            return
        }
        
        NSLog("🎨 Extracting theme color for: \(host)")
        
        // Priority 1: Header/Nav color (visual accuracy)
        extractColorFromHeader { [weak self] color in
            guard let self = self else { return }
            
            if let color = color {
                NSLog("✅ Theme color (header): \(color)")
                self.currentThemeColor = color
                self.applyThemeColor(color)
                return
            }
            
            // Priority 2: Meta tag
            self.extractColorFromMetaTag { [weak self] color in
                guard let self = self else { return }
                
                if let color = color {
                    NSLog("✅ Theme color (meta tag): \(color)")
                    self.currentThemeColor = color
                    self.applyThemeColor(color)
                    return
                }
                
                // Priority 3: Web manifest
                self.extractColorFromManifest { [weak self] color in
                    guard let self = self else { return }
                    
                    if let color = color {
                        NSLog("✅ Theme color (manifest): \(color)")
                        self.currentThemeColor = color
                        self.applyThemeColor(color)
                        return
                    }
                    
                    // Priority 4: Favicon dominant color
                    self.extractColorFromFavicon { [weak self] color in
                        guard let self = self else { return }
                        
                        if let color = color {
                            NSLog("✅ Theme color (favicon): \(color)")
                            self.currentThemeColor = color
                            self.applyThemeColor(color)
                            return
                        }
                        
                        NSLog("⚠️ No valid theme color found, using default")
                        self.applyDefaultThemeColor()
                    }
                }
            }
        }
    }
    
    /// Extract color from header/nav bar background (Priority 1 - visual accuracy)
    private func extractColorFromHeader(completion: @escaping (NSColor?) -> Void) {
        let script = """
        (function() {
            // Helper: Check if element is at/near top of viewport
            function isTopElement(el) {
                var rect = el.getBoundingClientRect();
                return rect.top >= -50 && rect.top <= 200;
            }
            
            // Helper: Check if color is valid
            function isValidColor(color) {
                if (!color || color === 'transparent' || 
                    color === 'rgba(0, 0, 0, 0)' ||
                    color.includes('rgba(255, 255, 255, 0)')) {
                    return false;
                }
                return true;
            }
            
            // Find the TOPMOST visible header/nav with solid background
            var selectors = [
                'header', 'nav', '[role="banner"]', '.header', '.navbar',
                '.top-bar', '.site-header', '#header', '#navbar', '.main-header',
                '.navigation', '[class*="header"]', '[class*="navbar"]', '[class*="navigation"]'
            ];
            
            var candidates = [];
            
            for (var i = 0; i < selectors.length; i++) {
                var elements = document.querySelectorAll(selectors[i]);
                for (var j = 0; j < elements.length; j++) {
                    var el = elements[j];
                    if (isTopElement(el)) {
                        var style = window.getComputedStyle(el);
                        var bgColor = style.backgroundColor;
                        
                        if (isValidColor(bgColor)) {
                            var rect = el.getBoundingClientRect();
                            candidates.push({
                                color: bgColor,
                                top: rect.top,
                                width: rect.width
                            });
                        }
                    }
                }
            }
            
            // Sort by: 1) closest to top, 2) widest
            candidates.sort(function(a, b) {
                if (Math.abs(a.top - b.top) < 10) {
                    return b.width - a.width;
                }
                return a.top - b.top;
            });
            
            if (candidates.length > 0) {
                return candidates[0].color;
            }
            
            // Fallback: try body background
            var bodyStyle = window.getComputedStyle(document.body);
            var bodyBg = bodyStyle.backgroundColor;
            if (isValidColor(bodyBg)) {
                return bodyBg;
            }
            
            return null;
        })();
        """
        
        guard let webView = _webView else {
            completion(nil)
            return
        }
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                NSLog("⚠️ Header extraction error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let colorString = result as? String,
                  let color = self?.parseColor(from: colorString) else {
                completion(nil)
                return
            }
            
            // Flatten color for modern look and validate quality
            let flattenedColor = self?.flattenColor(color) ?? color
            if let validColor = self?.validateColorQuality(flattenedColor) {
                completion(validColor)
            } else {
                completion(nil)
            }
        }
    }
    
    /// Extract color from <meta name="theme-color">
    private func extractColorFromMetaTag(completion: @escaping (NSColor?) -> Void) {
        let script = """
        (function() {
            var meta = document.querySelector('meta[name="theme-color"]');
            return meta ? meta.getAttribute('content') : null;
        })();
        """
        
        guard let webView = _webView else {
            completion(nil)
            return
        }
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard error == nil,
                  let colorString = result as? String,
                  let color = self?.parseColor(from: colorString) else {
                completion(nil)
                return
            }
            
            // Flatten color for modern look and validate quality
            let flattenedColor = self?.flattenColor(color) ?? color
            if let validColor = self?.validateColorQuality(flattenedColor) {
                completion(validColor)
            } else {
                completion(nil)
            }
        }
    }
    
    /// Extract color from web app manifest.json
    private func extractColorFromManifest(completion: @escaping (NSColor?) -> Void) {
        let script = """
        (function() {
            var link = document.querySelector('link[rel="manifest"]');
            return link ? link.href : null;
        })();
        """
        
        guard let webView = _webView else {
            completion(nil)
            return
        }
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                NSLog("❌ Error finding manifest: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let manifestURL = result as? String else {
                completion(nil)
                return
            }
            
            self?.fetchManifestColor(from: manifestURL, completion: completion)
        }
    }
    
    private func fetchManifestColor(from urlString: String, completion: @escaping (NSColor?) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                NSLog("❌ Error fetching manifest: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let themeColor = json["theme_color"] as? String {
                    NSLog("🎨 Manifest color string: '\(themeColor)'")
                    let color = self?.parseColor(from: themeColor)
                    
                    if let color = color {
                        // Flatten color for modern look
                        let flattenedColor = self?.flattenColor(color) ?? color
                        
                        // Validate color quality
                        if let validColor = self?.validateColorQuality(flattenedColor) {
                            NSLog("✅ Manifest color passed quality check")
                            completion(validColor)
                            return
                        } else {
                            NSLog("⚠️ Manifest color failed quality check, skipping")
                        }
                    }
                }
            } catch {
                NSLog("❌ Error parsing manifest JSON: \(error.localizedDescription)")
            }
            
            completion(nil)
        }.resume()
    }
    
    /// Extract dominant color from favicon
    private func extractColorFromFavicon(completion: @escaping (NSColor?) -> Void) {
        guard let favicon = currentFavicon else {
            NSLog("⚠️ No favicon available for color extraction")
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let color = self?.getDominantColor(from: favicon)
            DispatchQueue.main.async {
                completion(color)
            }
        }
    }
    
    /// Extract dominant color from image using pixel sampling and color quantization
    private func getDominantColor(from image: NSImage) -> NSColor? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        var colorCounts: [String: Int] = [:]
        let pixelCount = bitmap.pixelsWide * bitmap.pixelsHigh
        let sampleRate = max(1, pixelCount / 1000) // Sample ~1000 pixels
        
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: sampleRate) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: sampleRate) {
                guard let pixelColor = bitmap.colorAt(x: x, y: y) else { continue }
                
                // Convert to RGB color space
                guard let rgbColor = pixelColor.usingColorSpace(.deviceRGB) else { continue }
                
                let red = rgbColor.redComponent
                let green = rgbColor.greenComponent
                let blue = rgbColor.blueComponent
                let alpha = rgbColor.alphaComponent
                
                // Skip transparent pixels
                if alpha < 0.5 { continue }
                
                // Skip near-white pixels (luminance > 0.95)
                let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
                if luminance > 0.95 { continue }
                
                // Skip near-black pixels (luminance < 0.05)
                if luminance < 0.05 { continue }
                
                // Quantize to reduce color space (bucket by 0.05)
                let quantizedR = (red * 20).rounded() / 20
                let quantizedG = (green * 20).rounded() / 20
                let quantizedB = (blue * 20).rounded() / 20
                
                let key = "\(quantizedR),\(quantizedG),\(quantizedB)"
                colorCounts[key, default: 0] += 1
            }
        }
        
        // Find most common color
        guard let mostCommon = colorCounts.max(by: { $0.value < $1.value }) else {
            return nil
        }
        
        let components = mostCommon.key.split(separator: ",").compactMap { Double($0) }
        guard components.count == 3 else { return nil }
        
        var dominantColor = NSColor(
            red: CGFloat(components[0]),
            green: CGFloat(components[1]),
            blue: CGFloat(components[2]),
            alpha: 1.0
        )
        
        // Flatten color for modern, subtle appearance
        dominantColor = flattenColor(dominantColor)
        
        NSLog("🎨 Extracted dominant color: R:\(components[0]) G:\(components[1]) B:\(components[2])")
        
        // Validate the extracted color (already filtered during extraction, but double-check)
        return validateColorQuality(dominantColor)
    }
    
    /// Flatten color for modern, subtle appearance
    /// Makes colors less saturated and more pleasant to look at
    private func flattenColor(_ color: NSColor) -> NSColor {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else { return color }
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        NSColor(red: rgbColor.redComponent,
                green: rgbColor.greenComponent,
                blue: rgbColor.blueComponent,
                alpha: rgbColor.alphaComponent).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Reduce saturation to max 50% for a flatter, modern look
        let flattenedSaturation = min(saturation, 0.5)
        
        // Slightly brighten very dark colors for better visibility
        var adjustedBrightness = brightness
        if brightness < 0.3 {
            adjustedBrightness = min(1.0, brightness + 0.15)
        }
        
        NSLog("🎨 Flattening color - Original S:\(saturation) B:\(brightness) → New S:\(flattenedSaturation) B:\(adjustedBrightness)")
        
        return NSColor(hue: hue, saturation: flattenedSaturation, brightness: adjustedBrightness, alpha: alpha)
    }
    
    /// Validate color quality - only reject pure black
    /// White colors are now allowed!
    private func validateColorQuality(_ color: NSColor) -> NSColor? {
        guard let rgbColor = color.usingColorSpace(.deviceRGB) else {
            NSLog("⚠️ Could not convert color to RGB for quality check")
            return nil
        }
        
        let red = rgbColor.redComponent
        let green = rgbColor.greenComponent
        let blue = rgbColor.blueComponent
        
        // Calculate relative luminance (WCAG formula)
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        NSLog("🔍 Color luminance: \(luminance)")
        
        // Only reject pure black (luminance < 0.03)
        if luminance < 0.03 {
            NSLog("❌ Rejected: too dark (luminance \(luminance) < 0.03)")
            return nil
        }
        
        NSLog("✅ Color quality OK: \(luminance)")
        return color
    }
    
    /// Parse color string from various formats (#RGB, #RRGGBB, rgb(), rgba())
    private func parseColor(from string: String) -> NSColor? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("🔍 Parsing color: '\(trimmed)'")
        
        // Handle hex colors (#RGB or #RRGGBB)
        if trimmed.hasPrefix("#") {
            let hex = String(trimmed.dropFirst())
            NSLog("🔍 Detected hex color: '\(hex)'")
            
            if hex.count == 3 {
                // #RGB -> #RRGGBB
                let r = String(repeating: hex[hex.startIndex], count: 2)
                let g = String(repeating: hex[hex.index(hex.startIndex, offsetBy: 1)], count: 2)
                let b = String(repeating: hex[hex.index(hex.startIndex, offsetBy: 2)], count: 2)
                let expanded = r + g + b
                NSLog("🔍 Expanded #RGB to #RRGGBB: \(expanded)")
                return parseHexColor(expanded)
            } else if hex.count == 6 {
                NSLog("🔍 Parsing 6-digit hex: \(hex)")
                return parseHexColor(hex)
            } else {
                NSLog("❌ Invalid hex length: \(hex.count)")
            }
        }
        
        // Handle rgb() or rgba()
        if trimmed.hasPrefix("rgb") {
            NSLog("🔍 Detected rgb/rgba format")
            // Use pre-compiled static regex for better performance
            if let regex = Self.rgbColorRegex,
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                
                let r = (trimmed as NSString).substring(with: match.range(at: 1))
                let g = (trimmed as NSString).substring(with: match.range(at: 2))
                let b = (trimmed as NSString).substring(with: match.range(at: 3))
                
                NSLog("🔍 RGB values: R=\(r) G=\(g) B=\(b)")
                
                if let red = Int(r), let green = Int(g), let blue = Int(b) {
                    return NSColor(
                        red: CGFloat(red) / 255.0,
                        green: CGFloat(green) / 255.0,
                        blue: CGFloat(blue) / 255.0,
                        alpha: 1.0
                    )
                }
            }
        }
        
        NSLog("❌ Could not parse color: '\(trimmed)'")
        return nil
    }
    
    private func parseHexColor(_ hex: String) -> NSColor? {
        guard hex.count == 6 else {
            NSLog("❌ parseHexColor: Invalid length \(hex.count), expected 6")
            return nil
        }
        
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            let r = CGFloat((hexNumber & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((hexNumber & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(hexNumber & 0x0000FF) / 255.0
            
            NSLog("✅ parseHexColor: \(hex) -> R:\(r) G:\(g) B:\(b)")
            
            return NSColor(red: r, green: g, blue: b, alpha: 1.0)
        }
        
        NSLog("❌ parseHexColor: Failed to scan hex: \(hex)")
        return nil
    }
    
    /// Apply extracted theme color to all UI elements
    private func applyThemeColor(_ color: NSColor) {
        guard useThemeColors else {
            NSLog("⚠️ Theme colors disabled, not applying")
            return
        }
        
        NSLog("🎨 Applying theme color: \(color)")
        
        // Apply to toolbar (85% opacity)
        toolbar.layer?.backgroundColor = color.withAlphaComponent(0.85).cgColor
        
        // Apply to traffic light area (90% opacity)
        trafficLightArea.layer?.backgroundColor = color.withAlphaComponent(0.90).cgColor
        
        // Apply to PanelWindow's custom control bar if we're in a panel
        if let panelWindow = view.window as? PanelWindow {
            panelWindow.applyThemeColorToControlBar(color)
        }
        
        // Adapt icon and text colors for accessibility
        adaptUIElementColors(forBackgroundColor: color)
        
        NSLog("✅ Theme color applied successfully")
    }
    
    /// Reset to default gray theme
    private func applyDefaultThemeColor() {
        guard useThemeColors else { return }
        
        NSLog("🎨 Applying default theme color (gray)")
        
        let defaultColor = NSColor(white: 0.95, alpha: 1.0)
        
        // Apply default with opacity
        toolbar.layer?.backgroundColor = defaultColor.withAlphaComponent(0.85).cgColor
        trafficLightArea.layer?.backgroundColor = defaultColor.withAlphaComponent(0.90).cgColor
        
        if let panelWindow = view.window as? PanelWindow {
            panelWindow.applyThemeColorToControlBar(defaultColor)
        }
        
        // Adapt icon and text colors for accessibility
        adaptUIElementColors(forBackgroundColor: defaultColor)
        
        currentThemeColor = nil
    }
    
    /// Adapt icon and text colors based on background color luminance
    /// Ensures proper contrast and accessibility
    private func adaptUIElementColors(forBackgroundColor backgroundColor: NSColor) {
        guard let rgbColor = backgroundColor.usingColorSpace(.deviceRGB) else {
            NSLog("⚠️ Could not convert background color to RGB")
            return
        }
        
        // Calculate relative luminance (WCAG formula)
        let red = rgbColor.redComponent
        let green = rgbColor.greenComponent
        let blue = rgbColor.blueComponent
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        // Determine if toolbar background is light or dark
        // Use a slightly lower threshold (0.45) to bias toward light icons on mid-tones
        let isDarkToolbar = luminance < 0.45
        
        // Choose icon color based on toolbar background
        let iconColor: NSColor
        if isDarkToolbar {
            iconColor = NSColor.white.withAlphaComponent(0.9)
            NSLog("🎨 Dark toolbar (luminance: \(luminance)) → Light icons")
        } else {
            iconColor = NSColor.black.withAlphaComponent(0.7)
            NSLog("🎨 Light toolbar (luminance: \(luminance)) → Dark icons")
        }
        
        // Apply to navigation buttons
        backButton.contentTintColor = iconColor
        forwardButton.contentTintColor = iconColor
        reloadButton.contentTintColor = iconColor
        newBubbleButton.contentTintColor = iconColor
        lockIcon.contentTintColor = iconColor
        
        // URL field styling: Create contrasting background for readability
        // The URL field needs its own background that works regardless of toolbar color
        let urlFieldBackgroundColor: NSColor
        let urlFieldTextColor: NSColor
        let urlFieldBorderColor: NSColor
        
        if isDarkToolbar {
            // Dark toolbar → Slightly lighter URL field for subtle contrast
            urlFieldBackgroundColor = NSColor.white.withAlphaComponent(0.1)
            urlFieldTextColor = NSColor.white.withAlphaComponent(0.9)
            urlFieldBorderColor = NSColor.white.withAlphaComponent(0.2)
        } else {
            // Light toolbar → Darker URL field for contrast
            urlFieldBackgroundColor = NSColor.black.withAlphaComponent(0.08)
            urlFieldTextColor = NSColor.black.withAlphaComponent(0.85)
            urlFieldBorderColor = NSColor.black.withAlphaComponent(0.15)
        }
        
        // Apply URL field styling
        urlField.backgroundColor = urlFieldBackgroundColor
        urlField.textColor = urlFieldTextColor
        urlField.layer?.borderColor = urlFieldBorderColor.cgColor
        
        // Create placeholder with proper indentation if lock icon is visible
        let paragraphStyle = NSMutableParagraphStyle()
        if urlField.hasLockIcon {
            paragraphStyle.firstLineHeadIndent = 30
            paragraphStyle.headIndent = 30
        }
        
        urlField.placeholderAttributedString = NSAttributedString(
            string: "Search or enter website",
            attributes: [
                .foregroundColor: urlFieldTextColor.withAlphaComponent(0.5),
                .font: NSFont.systemFont(ofSize: 13),
                .paragraphStyle: paragraphStyle
            ]
        )
        
        NSLog("✅ UI elements adapted for accessibility")
    }
    
    /// Update lock icon visibility and color based on URL scheme
    private func updateLockIcon() {
        guard let url = _webView?.url else {
            lockIcon.isHidden = true
            urlField.hasLockIcon = false
            return
        }
        
        if url.scheme == "https" {
            // HTTPS - show lock icon
            lockIcon.isHidden = false
            urlField.hasLockIcon = true
            lockIcon.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Secure")
            NSLog("🔒 HTTPS detected - showing lock icon")
        } else {
            // HTTP or other - hide lock icon
            lockIcon.isHidden = true
            urlField.hasLockIcon = false
            NSLog("🔓 Non-HTTPS URL - hiding lock icon")
        }
        
        // Update lock icon color to match current icon color
        lockIcon.contentTintColor = backButton.contentTintColor
    }
    
    /// Reset icon and text colors to default (for frosted glass mode)
    private func resetToDefaultIconColors() {
        NSLog("🎨 Resetting to default icon colors (frosted glass mode)")
        
        // Default system colors (gray icons)
        let defaultIconColor = NSColor.secondaryLabelColor
        
        // Reset navigation buttons
        backButton.contentTintColor = defaultIconColor
        forwardButton.contentTintColor = defaultIconColor
        reloadButton.contentTintColor = defaultIconColor
        newBubbleButton.contentTintColor = defaultIconColor
        lockIcon.contentTintColor = defaultIconColor
        
        // Reset URL field styling to default
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
        urlField.textColor = NSColor.labelColor
        urlField.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        // Create placeholder with proper indentation if lock icon is visible
        let paragraphStyle = NSMutableParagraphStyle()
        if urlField.hasLockIcon {
            paragraphStyle.firstLineHeadIndent = 30
            paragraphStyle.headIndent = 30
        }
        
        urlField.placeholderAttributedString = NSAttributedString(
            string: "Search or enter website",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 13),
                .paragraphStyle: paragraphStyle
            ]
        )
        
        NSLog("✅ Default icon colors restored")
    }
    
    /// Called when theme color mode is toggled in preferences
    func applyThemeColorForCurrentURL() {
        if useThemeColors {
            // Re-extract for current page
            extractAndApplyThemeColor()
        } else {
            // Clear colors when disabled
            currentThemeColor = nil
        }
    }
}

// MARK: - Delegate Protocol

protocol WebViewControllerDelegate: AnyObject {
    func webViewController(_ controller: WebViewController, didRequestNewBubble url: String)
    func webViewController(_ controller: WebViewController, didUpdateURL url: String)
    func webViewController(_ controller: WebViewController, didUpdateFavicon image: NSImage)
    func webViewController(_ controller: WebViewController, createPopupPanelFor url: URL?, configuration: WKWebViewConfiguration) -> WKWebView?
    func webViewControllerDidRequestClose(_ controller: WebViewController)
}

