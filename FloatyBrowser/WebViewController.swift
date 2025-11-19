//
//  WebViewController.swift
//  FloatyBrowser
//
//  Manages WKWebView with navigation policy interception for new tabs.
//

import Cocoa
import WebKit

// Custom text field with browser-style select-all behavior
// Selects all text on first click, allows normal cursor positioning while editing
class BrowserStyleTextField: NSTextField {
    private var isCurrentlyEditing = false
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupFocusGlow()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFocusGlow()
    }
    
    private func setupFocusGlow() {
        wantsLayer = true
        layer?.borderWidth = 0 // Start with no border
        layer?.borderColor = NSColor.clear.cgColor
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
                if let fieldEditor = self?.currentEditor() as? NSTextView {
                    fieldEditor.selectedRange = NSRange(location: 0, length: fieldEditor.string.count)
                }
            }
        }
    }
    
    override func textDidBeginEditing(_ notification: Notification) {
        super.textDidBeginEditing(notification)
        isCurrentlyEditing = true
        animateFocusGlow(isFocused: true)
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        isCurrentlyEditing = false
        animateFocusGlow(isFocused: false)
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
    private var webView: WKWebView!
    private var trafficLightArea: NSView!  // Can be NSVisualEffectView OR NSView
    private var toolbar: NSView!  // Can be NSVisualEffectView OR NSView
    private let minimizeToBubbleButton = NSButton()
    private let backButton = HoverButton()
    private let forwardButton = HoverButton()
    private let reloadButton = HoverButton()
    private let urlField = BrowserStyleTextField()
    private let addressBarProgressView = AddressBarProgressView()
    private let newBubbleButton = HoverButton()
    private var progressIndicator: NSProgressIndicator!
    
    weak var delegate: WebViewControllerDelegate?
    
    // UserDefaults key for tracking first-time minimize
    private let hasMinimizedBeforeKey = "hasMinimizedToBubbleBefore"
    
    // Check if theme colors are enabled (can change dynamically)
    private var useThemeColors: Bool
    
    private let webConfiguration: WKWebViewConfiguration = {
        let config = WKWebViewConfiguration()
        config.processPool = WKProcessPool()
        
        // Security settings
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.allowsAirPlayForMediaPlayback = false
        
        if #available(macOS 11.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }
        
        // Inject viewport meta tag for responsive design
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
        
        return config
    }()
    
    var currentURL: String {
        return webView.url?.absoluteString ?? ""
    }
    
    init() {
        // Decide mode at initialization - NEVER changes after this
        self.useThemeColors = AppearancePreferencesViewController.isThemeColorsEnabled()
        super.init(nibName: nil, bundle: nil)
        NSLog("🎨 WebViewController initialized with theme colors: \(useThemeColors)")
    }
    
    required init?(coder: NSCoder) {
        // Decide mode at initialization
        self.useThemeColors = AppearancePreferencesViewController.isThemeColorsEnabled()
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
        setupTrafficLightArea()
        setupToolbar()
        setupWebView()
        
        // Listen for theme color mode changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeColorModeChanged(_:)),
            name: .themeColorModeChanged,
            object: nil
        )
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure web view can receive keyboard events
        view.window?.makeFirstResponder(webView)
    }
    
    private func setupTrafficLightArea() {
        let trafficLightHeight: CGFloat = 30
        
        if useThemeColors {
            // Mode 1: Solid colored view
            let solidView = NSView(frame: NSRect(x: 0, y: view.bounds.height - trafficLightHeight, width: view.bounds.width, height: trafficLightHeight))
            solidView.autoresizingMask = [.width, .minYMargin]
            solidView.wantsLayer = true
            solidView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor  // Start with default, will be colored later
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
        
        // Add minimize to bubble button
        setupMinimizeToBubbleButton()
        
        view.addSubview(trafficLightArea)
    }
    
    private func setupMinimizeToBubbleButton() {
        let hasMinimizedBefore = UserDefaults.standard.bool(forKey: hasMinimizedBeforeKey)
        
        // Configure button
        minimizeToBubbleButton.isBordered = false
        minimizeToBubbleButton.bezelStyle = .inline
        minimizeToBubbleButton.target = self
        minimizeToBubbleButton.action = #selector(collapseToBubble)
        
        // Set title/image based on whether user has minimized before
        if hasMinimizedBefore {
            // Icon only - modern SF Symbol
            minimizeToBubbleButton.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Minimize to Bubble")
            minimizeToBubbleButton.imagePosition = .imageLeading
            minimizeToBubbleButton.title = ""
            minimizeToBubbleButton.frame = NSRect(x: 72, y: 5, width: 24, height: 20)
        } else {
            // Icon + text for first-time users
            minimizeToBubbleButton.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Minimize to Bubble")
            minimizeToBubbleButton.imagePosition = .imageLeading
            minimizeToBubbleButton.title = "Minimize to Bubble"
            minimizeToBubbleButton.frame = NSRect(x: 72, y: 5, width: 160, height: 20)
        }
        
        // Style the button
        minimizeToBubbleButton.font = NSFont.systemFont(ofSize: 11)
        minimizeToBubbleButton.contentTintColor = .secondaryLabelColor
        
        // Add tooltip for when text is hidden
        if hasMinimizedBefore {
            minimizeToBubbleButton.toolTip = "Minimize to Bubble"
        }
        
        trafficLightArea.addSubview(minimizeToBubbleButton)
    }
    
    private func setupToolbar() {
        // Add space for traffic lights (standard macOS titlebar height is ~28px, we'll use 30 for comfort)
        let trafficLightHeight: CGFloat = 30
        let toolbarHeight: CGFloat = 44  // Slightly taller for better spacing
        let totalTopHeight = trafficLightHeight + toolbarHeight
        
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
        xOffset += buttonSize + 12
        
        // Calculate plus button position (need this for address bar width calculation)
        let rightMargin: CGFloat = 12
        let plusButtonX = view.bounds.width - buttonSize - rightMargin
        
        // URL field - positioned BETWEEN reload button and plus button
        let spacingBeforePlus: CGFloat = 12  // Match spacing with reload button
        let urlFieldWidth = plusButtonX - xOffset - spacingBeforePlus
        let urlFieldHeight: CGFloat = 32  // Taller for better vertical centering
        let urlFieldY = (toolbarHeight - urlFieldHeight) / 2
        
        urlField.frame = NSRect(x: xOffset, y: urlFieldY, width: urlFieldWidth, height: urlFieldHeight)
        // No autoresizing - keep fixed gap between address bar and plus button
        urlField.placeholderString = "Search or enter website"
        urlField.delegate = self
        urlField.font = NSFont.systemFont(ofSize: 13)
        urlField.alignment = .left
        
        // Modern URL field styling - very rounded, clean look
        urlField.isBezeled = true
        urlField.bezelStyle = .roundedBezel  // Use native rounded bezel for proper centering
        urlField.focusRingType = .none
        urlField.wantsLayer = true
        urlField.layer?.cornerRadius = 16  // Very rounded
        urlField.layer?.masksToBounds = true
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
        
        // Add subtle border
        urlField.layer?.borderWidth = 0.5
        urlField.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
        toolbar.addSubview(urlField)
        
        // Address bar progress view - positioned at the bottom of the address bar
        let progressBarHeight: CGFloat = 3
        addressBarProgressView.frame = NSRect(
            x: urlField.frame.origin.x,
            y: urlField.frame.origin.y,
            width: urlField.frame.width,
            height: progressBarHeight
        )
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
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - totalTopSpace)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Allow keyboard events in WKWebView
        webView.allowsBackForwardNavigationGestures = true
        
        // Set custom user agent to identify as desktop browser
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15 FloatyBrowser/1.0"
        
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
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
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
                urlField.stringValue = url.absoluteString
                delegate?.webViewController(self, didUpdateURL: url.absoluteString)
                // Don't fetch favicon here - wait for page to load
            }
        }
    }
    
    func loadURL(_ urlString: String) {
        let trimmedInput = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedInput.isEmpty else { return }
        
        // Determine if input is a URL or search query
        if isURL(trimmedInput) {
            // It's a URL - load it directly
            var urlToLoad = trimmedInput
            
            // Add scheme if missing
            if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
                urlToLoad = "https://" + urlToLoad
            }
            
            guard let url = URL(string: urlToLoad) else { return }
            NSLog("🌐 Loading URL: \(urlToLoad)")
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
        // Get the current search engine from preferences
        let searchEngine = SearchPreferencesViewController.getCurrentSearchEngine()
        
        // Encode the query for URL
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return
        }
        
        // Construct search URL
        let searchURLString = searchEngine.searchURL + encodedQuery
        
        guard let url = URL(string: searchURLString) else { return }
        NSLog("🔍 Searching for: \(query) using \(searchEngine.rawValue)")
        webView.load(URLRequest(url: url))
    }
    
    @objc private func goBack() {
        webView.goBack()
    }
    
    @objc private func goForward() {
        webView.goForward()
    }
    
    @objc private func reload() {
        webView.reload()
    }
    
    @objc private func createNewBubble() {
        if let url = webView.url {
            delegate?.webViewController(self, didRequestNewBubble: url.absoluteString)
        }
    }
    
    @objc private func collapseToBubble() {
        // Tell the panel window to collapse (NOT close/delete)
        NSLog("🔵 WebViewController: Collapse button clicked")
        
        // Check if this is the first time user is minimizing
        let hasMinimizedBefore = UserDefaults.standard.bool(forKey: hasMinimizedBeforeKey)
        if !hasMinimizedBefore {
            // First time! Update button to show only icon
            UserDefaults.standard.set(true, forKey: hasMinimizedBeforeKey)
            animateButtonToIconOnly()
        }
        
        guard let panelWindow = view.window as? PanelWindow else {
            NSLog("❌ Window is not a PanelWindow")
            return
        }
        NSLog("🔵 Calling panelDelegate.panelWindowDidRequestCollapse")
        panelWindow.panelDelegate?.panelWindowDidRequestCollapse(panelWindow)
    }
    
    private func animateButtonToIconOnly() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            // Animate the button size to icon-only
            minimizeToBubbleButton.animator().frame = NSRect(x: 72, y: 5, width: 24, height: 20)
        }, completionHandler: { [weak self] in
            // After animation, remove the title (keep icon only)
            self?.minimizeToBubbleButton.title = ""
            self?.minimizeToBubbleButton.toolTip = "Minimize to Bubble"
        })
    }
    
    func suspendWebView() {
        // Suspend rendering to save resources when collapsed
        webView.evaluateJavaScript("document.hidden = true;", completionHandler: nil)
    }
    
    func resumeWebView() {
        webView.evaluateJavaScript("document.hidden = false;", completionHandler: nil)
    }
    
    private func fetchFavicon() {
        NSLog("🎨 FloatyBrowser: Attempting to fetch favicon")
        
        // JavaScript to extract favicon from the page
        let script = """
        (function() {
            var links = document.getElementsByTagName('link');
            for (var i = 0; i < links.length; i++) {
                var link = links[i];
                var rel = link.getAttribute('rel');
                if (rel && (rel.toLowerCase().includes('icon'))) {
                    return link.href;
                }
            }
            // Fallback to default favicon location
            return window.location.origin + '/favicon.ico';
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
            
            // Update on main thread
            DispatchQueue.main.async {
                self.delegate?.webViewController(self, didUpdateFavicon: image)
            }
        }.resume()
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
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
        
        // Re-apply colors if we switched to colored mode
        if enabled {
            applyThemeColorForCurrentURL()
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
        webView.loadFileURL(gameURL, allowingReadAccessTo: gameURL.deletingLastPathComponent())
        print("🎮 FloatyBrowser: Loading Snake Game - no internet detected")
    }
}

// MARK: - NSTextFieldDelegate

extension WebViewController: NSTextFieldDelegate {
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            // User pressed Enter
            loadURL(urlField.stringValue)
            view.window?.makeFirstResponder(nil) // Dismiss keyboard focus
            return true
        }
        return false
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Intercept new window requests (target="_blank", window.open)
        if navigationAction.targetFrame == nil {
            // This is a request to open in a new window/tab
            if let url = navigationAction.request.url {
                delegate?.webViewController(self, didRequestNewBubble: url.absoluteString)
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressIndicator.isHidden = false
        progressIndicator.doubleValue = 0
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressIndicator.isHidden = true
        
        // Fetch favicon after page fully loads
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.fetchFavicon()
        }
        
        // Apply theme colors if enabled
        if useThemeColors {
            applyThemeColorForCurrentURL()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressIndicator.isHidden = true
        print("❌ Navigation failed: \(error.localizedDescription)")
        if isNetworkError(error) {
            loadSnakeGame()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        progressIndicator.isHidden = true
        print("❌ Provisional navigation failed: \(error.localizedDescription)")
        if isNetworkError(error) {
            loadSnakeGame()
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle window.open() and similar calls
        if let url = navigationAction.request.url {
            delegate?.webViewController(self, didRequestNewBubble: url.absoluteString)
        }
        return nil
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
}

// MARK: - Theme Color Management (Test Implementation)

extension WebViewController {
    func applyThemeColorForCurrentURL() {
        guard let url = webView.url, let host = url.host else {
            NSLog("⚠️ No URL for theme color")
            return
        }
        
        let color = getTestColorFor(host: host)
        NSLog("🎨 Applying test color for \(host): \(color)")
        
        // Apply to toolbar
        toolbar.layer?.backgroundColor = color.cgColor
        NSLog("✅ Toolbar background set to: \(color)")
        NSLog("📏 Toolbar frame: \(toolbar.frame)")
        NSLog("🔧 Toolbar has layer: \(toolbar.layer != nil)")
        
        // Apply to traffic light area
        trafficLightArea.layer?.backgroundColor = color.cgColor
        NSLog("✅ Traffic light area background set to: \(color)")
        NSLog("📏 Traffic light area frame: \(trafficLightArea.frame)")
        NSLog("🔧 Traffic light area has layer: \(trafficLightArea.layer != nil)")
        NSLog("🎭 Traffic light area class: \(type(of: trafficLightArea))")
        
        // Apply to PanelWindow's custom control bar if we're in a panel
        if let panelWindow = view.window as? PanelWindow {
            panelWindow.applyThemeColorToControlBar(color)
            NSLog("✅ Applied color to PanelWindow control bar")
        }
        
        NSLog("✅ Theme color applied successfully")
    }
    
    private func getTestColorFor(host: String) -> NSColor {
        // Hardcoded test colors
        if host.contains("youtube.com") {
            NSLog("🔴 RED for YouTube")
            return NSColor.systemRed
        } else if host.contains("google.com") {
            NSLog("🔵 BLUE for Google")
            return NSColor.systemBlue
        } else {
            // Random color for everything else
            let randomColor = NSColor(
                red: CGFloat.random(in: 0.3...0.9),
                green: CGFloat.random(in: 0.3...0.9),
                blue: CGFloat.random(in: 0.3...0.9),
                alpha: 1.0
            )
            NSLog("🎲 RANDOM color for \(host)")
            return randomColor
        }
    }
}

// MARK: - Delegate Protocol

protocol WebViewControllerDelegate: AnyObject {
    func webViewController(_ controller: WebViewController, didRequestNewBubble url: String)
    func webViewController(_ controller: WebViewController, didUpdateURL url: String)
    func webViewController(_ controller: WebViewController, didUpdateFavicon image: NSImage)
}

