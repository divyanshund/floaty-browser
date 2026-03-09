//
//  WebViewController.swift
//  FloatyBrowser
//
//  Manages WKWebView with navigation policy interception for new tabs.
//

import Cocoa
import WebKit
import AuthenticationServices

// MARK: - AddressBarTextView

protocol AddressBarTextViewDelegate: AnyObject {
    func addressBarDidSubmit(_ addressBar: AddressBarTextView, text: String)
    func addressBar(_ addressBar: AddressBarTextView, completionForPrefix prefix: String) -> String?
}

/// Browser-style address bar built on NSTextView.
/// Owns its own text storage — no shared field editor, no cell layer.
class AddressBarTextView: NSView, NSTextViewDelegate {

    weak var addressBarDelegate: AddressBarTextViewDelegate?

    private let textView = NSTextView()
    private let scrollView = NSScrollView()
    private var placeholderLabel = NSTextField(labelWithString: "Search or enter website")

    private(set) var isEditing = false
    private var didJustEnterEditing = false
    private var fullURL: String = ""

    // Inline autocomplete state
    private var userTypedText: String = ""
    private var isAutocompleting = false
    private var suppressAutocomplete = false

    var hasLockIcon: Bool = false {
        didSet {
            textView.textContainerInset = NSSize(width: hasLockIcon ? 32 : 8, height: verticalInset)
            layoutPlaceholder()
            needsDisplay = true
        }
    }

    // Exposed so WebViewController can theme the bar
    var textColor: NSColor = .labelColor {
        didSet {
            textView.textColor = textColor
            textView.insertionPointColor = textColor
        }
    }

    var backgroundColor: NSColor? {
        get { return scrollView.backgroundColor }
        set { scrollView.backgroundColor = newValue ?? .clear; scrollView.drawsBackground = newValue != nil }
    }

    private var verticalInset: CGFloat {
        let lineHeight = (textView.font ?? NSFont.systemFont(ofSize: 13)).ascender
            + abs((textView.font ?? NSFont.systemFont(ofSize: 13)).descender)
            + (textView.font ?? NSFont.systemFont(ofSize: 13)).leading
        return max(0, (bounds.height - lineHeight) / 2 - 1)
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true

        // Scroll view (provides clipping, no visible scrollers)
        scrollView.frame = bounds
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        addSubview(scrollView)

        // Text view — must have a real frame; NSTextView() defaults to zero.
        let contentSize = scrollView.contentSize
        let font = NSFont.systemFont(ofSize: 13, weight: .regular)
        textView.frame = NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: contentSize.height)
        textView.font = font
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.isRichText = false
        textView.isFieldEditor = true
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: contentSize.height)
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 8, height: verticalInset)
        scrollView.documentView = textView

        // Placeholder label — positioned to match the text view's vertical centering
        placeholderLabel.font = font
        placeholderLabel.textColor = NSColor.placeholderTextColor
        placeholderLabel.isBezeled = false
        placeholderLabel.drawsBackground = false
        placeholderLabel.isEditable = false
        placeholderLabel.isSelectable = false
        placeholderLabel.sizeToFit()
        placeholderLabel.autoresizingMask = [.width]
        addSubview(placeholderLabel)
        layoutPlaceholder()
    }

    override func layout() {
        super.layout()
        let h = scrollView.contentSize.height
        textView.minSize = NSSize(width: 0, height: h)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: h)
        textView.frame.size.height = h
        textView.textContainer?.containerSize.height = h
        textView.textContainerInset = NSSize(
            width: hasLockIcon ? 32 : 8,
            height: verticalInset
        )
        layoutPlaceholder()
    }

    private func layoutPlaceholder() {
        let pad: CGFloat = hasLockIcon ? 36 : 12
        let labelH = placeholderLabel.intrinsicContentSize.height
        let y = round((bounds.height - labelH) / 2)
        placeholderLabel.frame = NSRect(x: pad, y: y, width: bounds.width - pad - 8, height: labelH)
    }

    // MARK: - Public API

    func setURL(_ urlString: String) {
        fullURL = urlString
        if !isEditing {
            textView.string = simplifiedURL(from: urlString)
            updatePlaceholderVisibility()
        }
    }

    func getFullURL() -> String {
        if isEditing || textView.string != simplifiedURL(from: fullURL) {
            return textView.string
        }
        return fullURL
    }

    var stringValue: String {
        get { textView.string }
        set { textView.string = newValue; updatePlaceholderVisibility() }
    }

    var placeholderAttributedString: NSAttributedString? {
        get { placeholderLabel.attributedStringValue }
        set {
            if let v = newValue { placeholderLabel.attributedStringValue = v }
        }
    }

    // MARK: - Focus & Selection

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // When not editing, intercept clicks so they come to us (not the inner textView).
    // When editing, let clicks through to the textView for cursor positioning.
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        if !isEditing { return self }
        return hit
    }

    override func becomeFirstResponder() -> Bool {
        enterEditing()
        return true
    }

    override func mouseDown(with event: NSEvent) {
        if isEditing {
            if didJustEnterEditing {
                // This click triggered enterEditing via becomeFirstResponder.
                // Don't forward it — it would place the cursor and undo select-all.
                didJustEnterEditing = false
                return
            }
            textView.mouseDown(with: event)
            return
        }
        enterEditing()
        didJustEnterEditing = false
    }

    private func enterEditing() {
        isEditing = true
        didJustEnterEditing = true
        userTypedText = ""
        suppressAutocomplete = true
        animateFocusGlow(isFocused: true)

        if !fullURL.isEmpty {
            textView.string = fullURL
        }
        updatePlaceholderVisibility()

        window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: 0, length: textView.string.count))
    }

    private func exitEditing() {
        isEditing = false
        animateFocusGlow(isFocused: false)

        if !fullURL.isEmpty {
            textView.string = simplifiedURL(from: fullURL)
        }
        updatePlaceholderVisibility()
    }

    // MARK: - NSTextViewDelegate

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            addressBarDelegate?.addressBarDidSubmit(self, text: textView.string)
            window?.makeFirstResponder(nil)
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            if !fullURL.isEmpty {
                textView.string = simplifiedURL(from: fullURL)
            }
            window?.makeFirstResponder(nil)
            return true
        }
        if commandSelector == #selector(NSResponder.deleteBackward(_:)) ||
           commandSelector == #selector(NSResponder.deleteForward(_:)) {
            // Suppress autocomplete for the next text change after a delete.
            // If there's an active suggestion, just clear it and remove the
            // selected ghost text — don't delete the user's own characters.
            if hasActiveSuggestion {
                let typed = userTypedText
                isAutocompleting = true
                textView.string = typed
                textView.setSelectedRange(NSRange(location: typed.count, length: 0))
                isAutocompleting = false
                userTypedText = typed
                suppressAutocomplete = true
                updatePlaceholderVisibility()
                return true
            }
            suppressAutocomplete = true
            return false
        }
        if commandSelector == #selector(NSResponder.moveRight(_:)) ||
           commandSelector == #selector(NSResponder.moveToEndOfLine(_:)) ||
           commandSelector == #selector(NSResponder.insertTab(_:)) {
            // Accept suggestion: place cursor at the end
            if hasActiveSuggestion {
                textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
                userTypedText = textView.string
                return true
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                return true
            }
            return false
        }
        return false
    }

    func textDidChange(_ notification: Notification) {
        updatePlaceholderVisibility()

        // Don't recurse when we're programmatically modifying the text.
        guard !isAutocompleting else { return }

        let currentText = textView.string

        if suppressAutocomplete {
            suppressAutocomplete = false
            userTypedText = currentText
            return
        }

        userTypedText = currentText

        guard !currentText.isEmpty,
              let completion = addressBarDelegate?.addressBar(self, completionForPrefix: currentText) else {
            return
        }

        // `completion` is the full URL/string. We only want the suffix beyond what the user typed.
        let suffix = String(completion.dropFirst(currentText.count))
        guard !suffix.isEmpty else { return }

        // Append the ghost text and select it so the next keystroke replaces it.
        isAutocompleting = true
        textView.string = currentText + suffix
        textView.setSelectedRange(NSRange(location: currentText.count, length: suffix.count))
        isAutocompleting = false
    }

    func textDidEndEditing(_ notification: Notification) {
        userTypedText = ""
        suppressAutocomplete = false
        exitEditing()
    }

    private var hasActiveSuggestion: Bool {
        let sel = textView.selectedRange()
        return sel.length > 0 && sel.location == userTypedText.count && textView.string.count > userTypedText.count
    }

    // MARK: - Helpers

    private func simplifiedURL(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        var host = url.host ?? urlString
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        let path = url.path
        if !path.isEmpty && path != "/" {
            let maxPathLength = 20
            if path.count > maxPathLength {
                return host + String(path.prefix(maxPathLength)) + "..."
            }
            return host + path
        }
        return host
    }

    private func updatePlaceholderVisibility() {
        placeholderLabel.isHidden = !textView.string.isEmpty
    }

    private func animateFocusGlow(isFocused: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true
            if isFocused {
                self.layer?.borderWidth = 2.0
                self.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.5).cgColor
            } else {
                self.layer?.borderWidth = 0
                self.layer?.borderColor = NSColor.clear.cgColor
            }
        }
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
    
    func setColor(_ color: NSColor) {
        progressLayer.backgroundColor = color.cgColor
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

/// Weak wrapper to avoid retain cycles with WKUserContentController.
private class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var delegate: WKScriptMessageHandler?
    init(delegate: WKScriptMessageHandler) { self.delegate = delegate }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate?.userContentController(controller, didReceive: message)
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
    private let urlField = AddressBarTextView()
    private let lockIcon = NSImageView()  // HTTPS lock icon
    private let addressBarProgressView = AddressBarProgressView()
    private let newBubbleButton = HoverButton()
    private var progressIndicator: NSProgressIndicator!
    
    weak var delegate: WebViewControllerDelegate?
    
    // Check if theme colors are enabled (can change dynamically)
    private var useThemeColors: Bool
    
    // Theme color state
    private var currentThemeColor: NSColor?
    private var currentThemeColorSource: ThemeColorSource?
    private var currentFavicon: NSImage?
    private var extractionId: UUID?
    private var pendingExtractions = 0
    private var spaDebounceWorkItem: DispatchWorkItem?
    
    // Per-domain color cache (shared across all instances)
    private static var domainColorCache: [String: NSColor] = [:]
    
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
    }
    
    required init?(coder: NSCoder) {
        // Decide mode at initialization
        self.useThemeColors = AppearancePreferencesViewController.isThemeColorsEnabled()
        self.externalConfiguration = nil
        super.init(coder: coder)
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
        } else {
            // Mode 2: Frosted glass vibrancy
            let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: view.bounds.height - trafficLightHeight, width: view.bounds.width, height: trafficLightHeight))
            visualEffectView.autoresizingMask = [.width, .minYMargin]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.alphaValue = 0.95
            trafficLightArea = visualEffectView
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
        } else {
            // Mode 2: Frosted glass vibrancy
            let visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: view.bounds.height - totalTopHeight, width: view.bounds.width, height: toolbarHeight))
            visualEffectView.autoresizingMask = [.width, .minYMargin]
            visualEffectView.material = .hudWindow
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.state = .active
            visualEffectView.alphaValue = 0.95
            toolbar = visualEffectView
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
        
        urlField.addressBarDelegate = self
        urlField.wantsLayer = true
        urlField.layer?.cornerRadius = 16
        urlField.layer?.masksToBounds = true
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
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
        
        // Address bar progress view - child of urlField so it clips to rounded corners
        let progressBarHeight: CGFloat = 3
        addressBarProgressView.frame = NSRect(
            x: 0,
            y: 0,
            width: urlField.bounds.width,
            height: progressBarHeight
        )
        addressBarProgressView.autoresizingMask = [.width]
        addressBarProgressView.wantsLayer = true
        addressBarProgressView.alphaValue = 0
        urlField.addSubview(addressBarProgressView)
        
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
        let totalTopSpace: CGFloat = 74
        
        let config = webConfiguration
        
        // Inject SPA navigation observer (pushState/replaceState + meta theme-color mutations)
        let spaScript = WKUserScript(source: Self.spaObserverScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(spaScript)
        config.userContentController.add(WeakScriptMessageHandler(delegate: self), name: "themeColorObserver")
        
        let webView = WKWebView(frame: .zero, configuration: config)
        _webView = webView
        
        webView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - totalTopSpace)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
        
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.frame = NSRect(x: 0, y: view.bounds.height - totalTopSpace - 2, width: view.bounds.width, height: 2)
        progressIndicator.autoresizingMask = [.width, .minYMargin]
        progressIndicator.isHidden = true
        
        view.addSubview(webView)
        view.addSubview(progressIndicator)
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
    }
    
    /// JavaScript injected at document-end to detect SPA route changes and
    /// live meta theme-color updates, then post messages back to native code.
    private static let spaObserverScript: String = """
    (function() {
        function notify(type, color) {
            try { webkit.messageHandlers.themeColorObserver.postMessage({type: type, color: color || null}); } catch(e) {}
        }
        // Observe <meta name="theme-color"> additions and content changes
        if (document.head) {
            new MutationObserver(function() {
                var meta = document.querySelector('meta[name="theme-color"]');
                if (meta) notify('metaColorChanged', meta.getAttribute('content'));
            }).observe(document.head, {childList: true, subtree: true, attributes: true, attributeFilter: ['content']});
        }
        // Hook pushState / replaceState
        var origPush = history.pushState, origReplace = history.replaceState;
        history.pushState = function() { origPush.apply(this, arguments); notify('navigation'); };
        history.replaceState = function() { origReplace.apply(this, arguments); notify('navigation'); };
        window.addEventListener('popstate', function() { notify('navigation'); });
    })();
    """
    
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
                urlField.setURL(url.absoluteString)
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
        guard let webView = _webView else { return }
        
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
            guard error == nil,
                  let self = self,
                  let urlString = result as? String,
                  let url = URL(string: urlString) else { return }
            
            self.downloadFavicon(from: url)
        }
    }
    
    private func downloadFavicon(from url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            guard error == nil,
                  let data = data, !data.isEmpty,
                  let image = NSImage(data: data) else { return }
            
            self.currentFavicon = image
            
            DispatchQueue.main.async {
                self.delegate?.webViewController(self, didUpdateFavicon: image)
                
                // If theme colors are on and no higher-priority source provided a color,
                // try extracting from the freshly-loaded favicon.
                if self.useThemeColors && self.currentThemeColorSource == nil {
                    self.extractColorFromFavicon { [weak self] color in
                        if let color = color {
                            self?.proposeThemeColor(color, from: .favicon)
                        }
                    }
                }
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
        
        useThemeColors = enabled
        
        swapToolbarViews(toColoredMode: enabled)
        swapTrafficLightAreaViews(toColoredMode: enabled)
        
        if enabled {
            startThemeColorExtraction()
        } else {
            currentThemeColor = nil
            currentThemeColorSource = nil
            resetToFrostedGlassDefaults()
        }
        
        if let panelWindow = view.window as? PanelWindow {
            panelWindow.handleThemeColorModeChanged(enabled)
        }
    }
    
    private func swapToolbarViews(toColoredMode: Bool) {
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
    }
    
    private func swapTrafficLightAreaViews(toColoredMode: Bool) {
        
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

// MARK: - AddressBarTextViewDelegate

extension WebViewController: AddressBarTextViewDelegate {
    func addressBarDidSubmit(_ addressBar: AddressBarTextView, text: String) {
        loadURL(urlField.getFullURL())
    }

    func addressBar(_ addressBar: AddressBarTextView, completionForPrefix prefix: String) -> String? {
        let query = prefix.lowercased()
        guard query.count >= 2 else { return nil }

        // Search history for a URL whose domain (or full URL without scheme) starts with the typed prefix.
        let entries = HistoryManager.shared.getAllEntries()

        // Build candidate strings to match against, preferring most-recently-visited.
        for entry in entries {
            guard let url = URL(string: entry.url), let host = url.host else { continue }

            // Strip www. for matching
            let bareHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            // Full URL without scheme, e.g. "google.com/search?q=test"
            let withoutScheme = bareHost + (url.path == "/" ? "" : url.path)

            if withoutScheme.lowercased().hasPrefix(query) {
                return withoutScheme
            }
            // Also try matching with scheme, e.g. user typed "https://g"
            if entry.url.lowercased().hasPrefix(query) {
                return entry.url
            }
        }
        return nil
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Check if this is a Facebook login/OAuth navigation
        if let url = navigationAction.request.url {
            let host = url.host?.lowercased() ?? ""
            let urlString = url.absoluteString.lowercased()
            
            // Block Facebook OAuth/login URLs - they cause crashes and hangs
            if (host.contains("facebook.com") || host.contains("fb.com")) &&
               (urlString.contains("/dialog") || urlString.contains("/oauth") || 
                urlString.contains("/login") || urlString.contains("/oidc") ||
                urlString.contains("connect/login")) {
                NSLog("🚫 Blocking Facebook login navigation: \(url.absoluteString)")
                decisionHandler(.cancel)
                showFacebookLoginUnsupportedAlert()
                return
            }
        }
        
        // Allow all other navigation
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
        guard webView === _webView else { return }
        // Keep current theme color during transition — no flash to defaults.
        // The new color will be applied by startThemeColorExtraction in didFinish.
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === _webView, isViewLoaded else { return }
        
        progressIndicator.isHidden = true
        updateLockIcon()
        
        if !isPopupWindow, let url = webView.url {
            let title = webView.title ?? currentPageTitle
            HistoryManager.shared.recordVisit(url: url.absoluteString, title: title)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchFavicon()
        }
        
        if useThemeColors {
            startThemeColorExtraction()
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
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let url = navigationAction.request.url
        
        // Backup check for Facebook login popups (primary blocking is in decidePolicyFor)
        if isFacebookLoginURL(url) {
            showFacebookLoginUnsupportedAlert()
            return nil
        }
        
        // Check for OAuth URLs that should use ASWebAuthenticationSession
        if let url = url, isOAuthURL(url) {
            startOAuthWithAuthenticationSession(url: url, parentWebView: webView)
            return nil
        }
        
        // For all other popups, create a new panel
        if let popupWebView = delegate?.webViewController(self, createPopupPanelFor: url, configuration: configuration) {
            return popupWebView
        }
        return nil
    }
    
    /// Check if URL is a Facebook login/OAuth URL
    private func isFacebookLoginURL(_ url: URL?) -> Bool {
        guard let url = url else { return false }
        let host = url.host?.lowercased() ?? ""
        let urlString = url.absoluteString.lowercased()
        
        let isFacebookDomain = host.contains("facebook.com") || host.contains("fb.com")
        let isLoginPath = urlString.contains("/login") ||
                          urlString.contains("/dialog") ||
                          urlString.contains("/oauth") ||
                          urlString.contains("/oidc")
        
        return isFacebookDomain && isLoginPath
    }
    
    /// Show alert explaining Facebook login isn't supported
    private func showFacebookLoginUnsupportedAlert() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.view.window else { return }
            
            let alert = NSAlert()
            alert.messageText = "Facebook Sign-In Not Supported"
            alert.informativeText = "This browser doesn't support signing in with Facebook yet due to technical limitations.\n\nPlease use email, phone number, or another sign-in method instead."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            
            alert.beginSheetModal(for: window) { _ in
                // Alert dismissed
            }
        }
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
    
    // MARK: Extraction Orchestration
    
    /// Kick off parallel extraction from header, meta tag, and manifest.
    /// Favicon is handled separately when it loads (see downloadFavicon).
    func startThemeColorExtraction() {
        guard useThemeColors else { return }
        guard let url = _webView?.url, let host = url.host else {
            applyDefaultThemeColor()
            return
        }
        
        // Apply cached color immediately for instant feedback, then re-extract
        if let cached = Self.domainColorCache[host] {
            currentThemeColor = cached
            applyThemeColor(cached)
        }
        
        let thisExtraction = UUID()
        extractionId = thisExtraction
        currentThemeColorSource = nil
        pendingExtractions = 3
        
        extractColorFromHeader { [weak self] color in
            guard self?.extractionId == thisExtraction else { return }
            self?.handleExtractionResult(color, from: .header)
        }
        extractColorFromMetaTag { [weak self] color in
            guard self?.extractionId == thisExtraction else { return }
            self?.handleExtractionResult(color, from: .metaTag)
        }
        extractColorFromManifest { [weak self] color in
            guard self?.extractionId == thisExtraction else { return }
            self?.handleExtractionResult(color, from: .manifest)
        }
    }
    
    private func handleExtractionResult(_ color: NSColor?, from source: ThemeColorSource) {
        if let color = color {
            proposeThemeColor(color, from: source)
        }
        pendingExtractions -= 1
        if pendingExtractions <= 0 && currentThemeColorSource == nil {
            extractBodyBackground()
        }
    }
    
    /// Last-resort fallback: read the computed body/html background color.
    /// Only applied for distinctly non-white, non-transparent pages (e.g. dark mode).
    private func extractBodyBackground() {
        let script = """
        (function() {
            var bodyBg = window.getComputedStyle(document.body).backgroundColor;
            var htmlBg = window.getComputedStyle(document.documentElement).backgroundColor;
            function isUsable(c) {
                return c && c !== 'transparent' && c !== 'rgba(0, 0, 0, 0)';
            }
            return isUsable(bodyBg) ? bodyBg : (isUsable(htmlBg) ? htmlBg : null);
        })();
        """
        _webView?.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self = self, self.currentThemeColorSource == nil else { return }
            if let colorStr = result as? String,
               let color = ThemeColorUtils.parseColor(from: colorStr) {
                let lum = ThemeColorUtils.luminance(of: color)
                // Only use body background if it's clearly non-white (lum < 0.85)
                // so we don't paint the toolbar white for default light pages
                if lum < 0.85, let processed = ThemeColorUtils.processExtractedColor(color) {
                    self.proposeThemeColor(processed, from: .bodyBackground)
                    return
                }
            }
            self.applyDefaultThemeColor()
        }
    }
    
    /// Accept a color only if it outranks the current source.
    func proposeThemeColor(_ color: NSColor, from source: ThemeColorSource) {
        if let existing = currentThemeColorSource, source < existing { return }
        currentThemeColorSource = source
        currentThemeColor = color
        applyThemeColor(color)
        
        if let host = _webView?.url?.host {
            Self.domainColorCache[host] = color
        }
    }
    
    /// Extract color from header/nav bar background (Priority 1 - visual accuracy)
    private func extractColorFromHeader(completion: @escaping (NSColor?) -> Void) {
        let script = """
        (function() {
            function isTopElement(el) {
                var rect = el.getBoundingClientRect();
                return rect.top >= -50 && rect.top <= 200;
            }
            function isValidColor(c) {
                return c && c !== 'transparent' &&
                       c !== 'rgba(0, 0, 0, 0)' &&
                       !c.includes('rgba(255, 255, 255, 0)');
            }
            // Extract a usable color from an element, checking both
            // backgroundColor and the background shorthand (for gradients).
            function extractColor(el) {
                var s = window.getComputedStyle(el);
                if (isValidColor(s.backgroundColor)) return s.backgroundColor;
                var bg = s.background || '';
                var m = bg.match(/rgba?\\([^)]+\\)/);
                if (m && isValidColor(m[0])) return m[0];
                return null;
            }
            var selectors = [
                'header', 'nav', '[role="banner"]', '.header', '.navbar',
                '.top-bar', '.site-header', '#header', '#navbar', '.main-header',
                '.navigation', '[class*="header"]', '[class*="navbar"]', '[class*="navigation"]'
            ];
            var candidates = [];
            for (var i = 0; i < selectors.length; i++) {
                var els = document.querySelectorAll(selectors[i]);
                for (var j = 0; j < els.length; j++) {
                    if (!isTopElement(els[j])) continue;
                    var color = extractColor(els[j]);
                    if (color) {
                        var rect = els[j].getBoundingClientRect();
                        candidates.push({ color: color, top: rect.top, width: rect.width });
                    }
                }
            }
            candidates.sort(function(a, b) {
                return Math.abs(a.top - b.top) < 10 ? b.width - a.width : a.top - b.top;
            });
            return candidates.length > 0 ? candidates[0].color : null;
        })();
        """
        
        guard let webView = _webView else {
            completion(nil)
            return
        }
        
        webView.evaluateJavaScript(script) { result, error in
            guard error == nil,
                  let colorString = result as? String,
                  let raw = ThemeColorUtils.parseColor(from: colorString),
                  let processed = ThemeColorUtils.processExtractedColor(raw) else {
                completion(nil)
                return
            }
            completion(processed)
        }
    }
    
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
        
        webView.evaluateJavaScript(script) { result, error in
            guard error == nil,
                  let colorString = result as? String,
                  let raw = ThemeColorUtils.parseColor(from: colorString),
                  let processed = ThemeColorUtils.processExtractedColor(raw) else {
                completion(nil)
                return
            }
            completion(processed)
        }
    }
    
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
            guard error == nil, let manifestURL = result as? String else {
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
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard error == nil, let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var result: NSColor?
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let colorStr = json["theme_color"] as? String,
               let raw = ThemeColorUtils.parseColor(from: colorStr) {
                result = ThemeColorUtils.processExtractedColor(raw)
            }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
    
    private func extractColorFromFavicon(completion: @escaping (NSColor?) -> Void) {
        guard let favicon = currentFavicon else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let color = Self.getDominantColor(from: favicon)
            DispatchQueue.main.async { completion(color) }
        }
    }
    
    // MARK: Dominant Color Extraction
    
    /// Pixel-sample an image and return the most common non-extreme color,
    /// processed through flatten + validate.
    private static func getDominantColor(from image: NSImage) -> NSColor? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        
        var colorCounts: [String: Int] = [:]
        // Stride per axis so we get roughly sqrt(1000) samples per dimension
        let side = max(1, Int(sqrt(Double(max(bitmap.pixelsWide, bitmap.pixelsHigh)))))
        let strideX = max(1, bitmap.pixelsWide / side)
        let strideY = max(1, bitmap.pixelsHigh / side)
        
        for y in stride(from: 0, to: bitmap.pixelsHigh, by: strideY) {
            for x in stride(from: 0, to: bitmap.pixelsWide, by: strideX) {
                guard let px = bitmap.colorAt(x: x, y: y),
                      let rgb = px.usingColorSpace(.deviceRGB) else { continue }
                
                let r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent
                if rgb.alphaComponent < 0.5 { continue }
                
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                if lum > 0.95 || lum < 0.05 { continue }
                
                let qR = (r * 20).rounded() / 20
                let qG = (g * 20).rounded() / 20
                let qB = (b * 20).rounded() / 20
                colorCounts["\(qR),\(qG),\(qB)", default: 0] += 1
            }
        }
        
        let sorted = colorCounts.sorted { $0.value > $1.value }
        guard let best = sorted.first else { return nil }
        
        // If the top color doesn't clearly dominate (< 1.5x the runner-up),
        // the icon is multi-colored (e.g. Google's G) and unreliable — skip it.
        if sorted.count >= 2 {
            let runnerUp = sorted[1].value
            if Double(best.value) < Double(runnerUp) * 1.5 { return nil }
        }
        
        let c = best.key.split(separator: ",").compactMap { Double($0) }
        guard c.count == 3 else { return nil }
        
        let raw = NSColor(red: CGFloat(c[0]), green: CGFloat(c[1]), blue: CGFloat(c[2]), alpha: 1.0)
        return ThemeColorUtils.processExtractedColor(raw)
    }
    
    // MARK: Color Application
    
    private func applyThemeColor(_ color: NSColor) {
        guard useThemeColors else { return }
        animateToolbarColor(color)
    }
    
    private func applyDefaultThemeColor() {
        guard useThemeColors else { return }
        animateToolbarColor(NSColor(white: 0.95, alpha: 1.0))
        currentThemeColor = nil
        currentThemeColorSource = nil
    }
    
    /// Animate toolbar, traffic-light area, and control bar to the new color.
    private func animateToolbarColor(_ color: NSColor) {
        let toolbarCG = color.withAlphaComponent(0.85).cgColor
        let trafficCG = color.withAlphaComponent(0.90).cgColor
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        toolbar.layer?.backgroundColor = toolbarCG
        trafficLightArea.layer?.backgroundColor = trafficCG
        
        if let panelWindow = view.window as? PanelWindow {
            panelWindow.applyThemeColorToControlBar(color)
        }
        
        CATransaction.commit()
        
        adaptUIElementColors(forBackgroundColor: color)
    }
    
    /// Adapt all toolbar UI elements for contrast against the given background.
    /// Uses ThemeColorUtils for consistent icon and URL-field color derivation.
    private func adaptUIElementColors(forBackgroundColor backgroundColor: NSColor) {
        let iconColor = ThemeColorUtils.contrastingIconColor(for: backgroundColor)
        
        backButton.contentTintColor = iconColor
        forwardButton.contentTintColor = iconColor
        reloadButton.contentTintColor = iconColor
        newBubbleButton.contentTintColor = iconColor
        lockIcon.contentTintColor = iconColor
        
        let urlColors = ThemeColorUtils.urlFieldColors(for: backgroundColor)
        urlField.backgroundColor = urlColors.background
        urlField.textColor = urlColors.text
        urlField.layer?.borderColor = urlColors.border.cgColor
        
        urlField.placeholderAttributedString = NSAttributedString(
            string: "Search or enter website",
            attributes: [
                .foregroundColor: urlColors.placeholder,
                .font: NSFont.systemFont(ofSize: 13)
            ]
        )
        
        addressBarProgressView.setColor(iconColor.withAlphaComponent(0.5))
    }
    
    // MARK: Mode Resets
    
    private func updateLockIcon() {
        guard let url = _webView?.url else {
            lockIcon.isHidden = true
            urlField.hasLockIcon = false
            return
        }
        
        let isSecure = url.scheme == "https"
        lockIcon.isHidden = !isSecure
        urlField.hasLockIcon = isSecure
        if isSecure {
            lockIcon.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: "Secure")
        }
        lockIcon.contentTintColor = backButton.contentTintColor
    }
    
    /// Reset to system defaults for frosted-glass (non-themed) mode.
    private func resetToFrostedGlassDefaults() {
        let defaultIconColor = NSColor.secondaryLabelColor
        
        backButton.contentTintColor = defaultIconColor
        forwardButton.contentTintColor = defaultIconColor
        reloadButton.contentTintColor = defaultIconColor
        newBubbleButton.contentTintColor = defaultIconColor
        lockIcon.contentTintColor = defaultIconColor
        
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
        urlField.textColor = NSColor.labelColor
        urlField.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        urlField.placeholderAttributedString = NSAttributedString(
            string: "Search or enter website",
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
        )
        
        addressBarProgressView.setColor(NSColor.controlAccentColor)
    }
    
    /// Called when theme color mode is toggled in preferences.
    func applyThemeColorForCurrentURL() {
        if useThemeColors {
            startThemeColorExtraction()
        } else {
            currentThemeColor = nil
            currentThemeColorSource = nil
        }
    }
}

// MARK: - SPA Navigation Message Handler

extension WebViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "themeColorObserver",
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        
        guard useThemeColors else { return }
        
        switch type {
        case "metaColorChanged":
            if let colorStr = body["color"] as? String,
               let raw = ThemeColorUtils.parseColor(from: colorStr),
               let processed = ThemeColorUtils.processExtractedColor(raw) {
                proposeThemeColor(processed, from: .metaTag)
            }
        case "navigation":
            // SPA route change — debounce so rapid pushState calls only trigger one extraction
            spaDebounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.startThemeColorExtraction()
            }
            spaDebounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        default:
            break
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

