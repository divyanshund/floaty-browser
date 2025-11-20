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
    private let backButton = HoverButton()
    private let forwardButton = HoverButton()
    private let reloadButton = HoverButton()
    private let urlField = BrowserStyleTextField()
    private let addressBarProgressView = AddressBarProgressView()
    private let newBubbleButton = HoverButton()
    private var progressIndicator: NSProgressIndicator!
    
    weak var delegate: WebViewControllerDelegate?
    
    // Check if theme colors are enabled (can change dynamically)
    private var useThemeColors: Bool
    
    // Theme color state
    private var currentThemeColor: NSColor?
    private var currentFavicon: NSImage?
    
    // Use shared configuration for session sharing across all bubbles
    private lazy var webConfiguration: WKWebViewConfiguration = {
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
            
            NSLog("🔄 viewDidLayout - Address bar width updated to: \(newUrlFieldWidth) (available: \(availableWidth))")
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
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - totalTopSpace)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Allow keyboard events in WKWebView
        webView.allowsBackForwardNavigationGestures = true
        
        // Set custom user agent to identify as modern Chrome on macOS for maximum compatibility
        // This ensures sites like WhatsApp Web work properly
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
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
            
            // Store favicon for color extraction
            self.currentFavicon = image
            
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
        // Note: Popup/new window requests are handled in WKUIDelegate.createWebView
        // We don't handle them here to avoid duplicate bubble creation
        
        // Allow all normal navigation
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
        
        // Extract and apply theme colors if enabled
        if useThemeColors {
            extractAndApplyThemeColor()
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
    /// Handle popup window requests (window.open(), target="_blank", etc.)
    /// This is the SINGLE point where new bubbles are created for popups
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else {
            NSLog("⚠️ Popup request with no URL, ignoring")
            return nil
        }
        
        NSLog("🪟 POPUP REQUEST: Creating new bubble for \(url.absoluteString)")
        NSLog("   ↳ Reason: \(navigationAction.navigationType.rawValue)")
        NSLog("   ↳ Target frame: \(navigationAction.targetFrame == nil ? "nil (new window)" : "exists")")
        
        // Request WindowManager to create a new bubble with shared session
        delegate?.webViewController(self, didRequestNewBubble: url.absoluteString)
        
        // Return nil to indicate we're not providing a WKWebView
        // (we're creating a new bubble window instead)
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

// MARK: - Theme Color Management

extension WebViewController {
    /// Main orchestrator - tries extraction methods in priority order
    func extractAndApplyThemeColor() {
        guard useThemeColors else {
            NSLog("⚠️ Theme colors disabled, skipping extraction")
            return
        }
        
        guard let url = webView.url, let host = url.host else {
            NSLog("⚠️ No URL for theme color extraction")
            applyDefaultThemeColor()
            return
        }
        
        NSLog("🎨 Starting theme color extraction for: \(host)")
        
        // Priority 1: Header/Nav color (visual accuracy)
        extractColorFromHeader { [weak self] color in
            guard let self = self else { return }
            
            if let color = color {
                NSLog("✅ Found theme color from header: \(color)")
                self.currentThemeColor = color
                self.applyThemeColor(color)
                return
            }
            
            NSLog("⚠️ No header color, trying meta tag...")
            
            // Priority 2: Meta tag
            self.extractColorFromMetaTag { [weak self] color in
                guard let self = self else { return }
                
                if let color = color {
                    NSLog("✅ Found theme color from meta tag: \(color)")
                    self.currentThemeColor = color
                    self.applyThemeColor(color)
                    return
                }
                
                NSLog("⚠️ No meta tag, trying manifest...")
                
                // Priority 3: Web manifest
                self.extractColorFromManifest { [weak self] color in
                    guard let self = self else { return }
                    
                    if let color = color {
                        NSLog("✅ Found theme color from manifest: \(color)")
                        self.currentThemeColor = color
                        self.applyThemeColor(color)
                        return
                    }
                    
                    NSLog("⚠️ No manifest, trying favicon...")
                    
                    // Priority 4: Favicon dominant color
                    self.extractColorFromFavicon { [weak self] color in
                        guard let self = self else { return }
                        
                        if let color = color {
                            NSLog("✅ Found theme color from favicon: \(color)")
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
            console.log('🔍 Starting header color extraction...');
            
            // Helper: Check if element is at/near top of viewport
            function isTopElement(el) {
                var rect = el.getBoundingClientRect();
                return rect.top >= -50 && rect.top <= 200; // Top or sticky header
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
            
            // Strategy 1: Find the TOPMOST visible header/nav with solid background
            var selectors = [
                'header',
                'nav',
                '[role="banner"]',
                '.header',
                '.navbar',
                '.top-bar',
                '.site-header',
                '#header',
                '#navbar',
                '.main-header',
                '.navigation',
                '[class*="header"]',
                '[class*="navbar"]',
                '[class*="navigation"]'
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
                                element: selectors[i] + '[' + j + ']',
                                color: bgColor,
                                top: rect.top,
                                width: rect.width,
                                height: rect.height
                            });
                        }
                    }
                }
            }
            
            console.log('🔍 Found ' + candidates.length + ' candidate headers');
            
            // Sort by: 1) closest to top, 2) widest
            candidates.sort(function(a, b) {
                if (Math.abs(a.top - b.top) < 10) {
                    return b.width - a.width; // Prefer wider
                }
                return a.top - b.top; // Prefer higher
            });
            
            if (candidates.length > 0) {
                var best = candidates[0];
                console.log('✅ Best header: ' + best.element);
                console.log('   Color: ' + best.color);
                console.log('   Position: top=' + best.top + ', width=' + best.width);
                return best.color;
            }
            
            console.log('⚠️ No header found, trying body background');
            
            // Fallback: try body background (some minimal sites)
            var bodyStyle = window.getComputedStyle(document.body);
            var bodyBg = bodyStyle.backgroundColor;
            if (isValidColor(bodyBg)) {
                console.log('✅ Using body background: ' + bodyBg);
                return bodyBg;
            }
            
            console.log('❌ No valid color found');
            return null;
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                NSLog("❌ Error extracting header color: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let colorString = result as? String else {
                NSLog("⚠️ No header color found")
                completion(nil)
                return
            }
            
            NSLog("🎨 Header color string: '\(colorString)'")
            let color = self?.parseColor(from: colorString)
            if let color = color {
                NSLog("🎨 Parsed header color to NSColor: \(color)")
                
                // Flatten color for modern look
                let flattenedColor = self?.flattenColor(color) ?? color
                
                // Validate color quality
                if let validColor = self?.validateColorQuality(flattenedColor) {
                    NSLog("✅ Header color passed quality check")
                    completion(validColor)
                } else {
                    NSLog("⚠️ Header color failed quality check (too light or too dark), skipping")
                    completion(nil)
                }
            } else {
                NSLog("❌ Failed to parse header color string: '\(colorString)'")
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
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                NSLog("❌ Error extracting meta tag: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let colorString = result as? String else {
                NSLog("⚠️ No meta tag found")
                completion(nil)
                return
            }
            
            NSLog("🎨 Meta tag color string: '\(colorString)'")
            let color = self?.parseColor(from: colorString)
            if let color = color {
                NSLog("🎨 Parsed to NSColor: \(color)")
                
                // Flatten color for modern look
                let flattenedColor = self?.flattenColor(color) ?? color
                
                // Validate color quality
                if let validColor = self?.validateColorQuality(flattenedColor) {
                    NSLog("✅ Color passed quality check")
                    completion(validColor)
                } else {
                    NSLog("⚠️ Color failed quality check (too light or too dark), skipping")
                    completion(nil)
                }
            } else {
                NSLog("❌ Failed to parse color string: '\(colorString)'")
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
            let pattern = #"rgba?\((\d+),\s*(\d+),\s*(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
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
        
        // Determine if background is light or dark
        // Threshold: 0.5 (50% gray)
        let isDarkBackground = luminance < 0.5
        
        // Choose appropriate icon color based on background
        let iconColor: NSColor
        
        if isDarkBackground {
            // Light icons for dark backgrounds
            iconColor = NSColor.white.withAlphaComponent(0.9)
            NSLog("🎨 Dark background detected (luminance: \(luminance)) → Using LIGHT icons")
        } else {
            // Dark icons for light backgrounds
            iconColor = NSColor.black.withAlphaComponent(0.7)
            NSLog("🎨 Light background detected (luminance: \(luminance)) → Using DARK icons")
        }
        
        // Apply to navigation buttons
        backButton.contentTintColor = iconColor
        forwardButton.contentTintColor = iconColor
        reloadButton.contentTintColor = iconColor
        newBubbleButton.contentTintColor = iconColor
        
        // Address bar text: Use darker/lighter version of address bar's own color for harmony
        // This creates better contrast while maintaining color consistency
        let addressBarTextColor = deriveTextColor(from: urlField.backgroundColor ?? NSColor.controlBackgroundColor)
        let addressBarPlaceholderColor = addressBarTextColor.withAlphaComponent(0.5)
        
        urlField.textColor = addressBarTextColor
        urlField.placeholderAttributedString = NSAttributedString(
            string: "Search or enter website",
            attributes: [
                .foregroundColor: addressBarPlaceholderColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
        )
        
        NSLog("🎨 Address bar text color derived from background")
        
        // Update URL field border based on toolbar background (for contrast with toolbar)
        if isDarkBackground {
            urlField.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        } else {
            urlField.layer?.borderColor = NSColor.black.withAlphaComponent(0.15).cgColor
        }
        
        NSLog("✅ UI elements adapted for accessibility")
    }
    
    /// Derive text color from background color
    /// Creates darker version for light backgrounds, lighter version for dark backgrounds
    /// Maintains color harmony while ensuring contrast
    private func deriveTextColor(from backgroundColor: NSColor) -> NSColor {
        guard let rgbColor = backgroundColor.usingColorSpace(.deviceRGB) else {
            return NSColor.labelColor  // Fallback to system label color
        }
        
        let red = rgbColor.redComponent
        let green = rgbColor.greenComponent
        let blue = rgbColor.blueComponent
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        
        if luminance < 0.5 {
            // Dark background → Lighten the color significantly
            let lightenFactor: CGFloat = 0.8  // 80% lighter for better contrast
            let textRed = red + (1.0 - red) * lightenFactor
            let textGreen = green + (1.0 - green) * lightenFactor
            let textBlue = blue + (1.0 - blue) * lightenFactor
            
            // Ensure minimum brightness (at least 0.7 for readability on dark backgrounds)
            let minBrightness: CGFloat = 0.7
            let textColor = NSColor(
                red: max(textRed, minBrightness),
                green: max(textGreen, minBrightness),
                blue: max(textBlue, minBrightness),
                alpha: 1.0
            )
            NSLog("🎨 Dark address bar (luminance: \(luminance)) → Lightened text (R:\(textRed) G:\(textGreen) B:\(textBlue))")
            return textColor
        } else {
            // Light background → Darken the color significantly
            let darkenFactor: CGFloat = 0.85  // 85% darker for strong contrast
            let textRed = red * (1.0 - darkenFactor)
            let textGreen = green * (1.0 - darkenFactor)
            let textBlue = blue * (1.0 - darkenFactor)
            
            // Ensure maximum darkness (at most 0.3 for readability on light backgrounds)
            let maxBrightness: CGFloat = 0.3
            let textColor = NSColor(
                red: min(textRed, maxBrightness),
                green: min(textGreen, maxBrightness),
                blue: min(textBlue, maxBrightness),
                alpha: 1.0
            )
            NSLog("🎨 Light address bar (luminance: \(luminance)) → Darkened text (R:\(textRed) G:\(textGreen) B:\(textBlue))")
            return textColor
        }
    }
    
    /// Reset icon and text colors to default (for frosted glass mode)
    private func resetToDefaultIconColors() {
        NSLog("🎨 Resetting to default icon colors (frosted glass mode)")
        
        // Default system colors (gray icons)
        let defaultIconColor = NSColor.secondaryLabelColor
        let defaultTextColor = NSColor.labelColor
        let defaultPlaceholderColor = NSColor.placeholderTextColor
        
        // Reset navigation buttons
        backButton.contentTintColor = defaultIconColor
        forwardButton.contentTintColor = defaultIconColor
        reloadButton.contentTintColor = defaultIconColor
        newBubbleButton.contentTintColor = defaultIconColor
        
        // Reset URL field text
        urlField.textColor = defaultTextColor
        urlField.placeholderAttributedString = NSAttributedString(
            string: "Search or enter website",
            attributes: [
                .foregroundColor: defaultPlaceholderColor,
                .font: NSFont.systemFont(ofSize: 13)
            ]
        )
        
        // Reset URL field border
        urlField.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
        
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
}

