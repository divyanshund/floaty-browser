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
    
    override func mouseDown(with event: NSEvent) {
        let wasEditing = isCurrentlyEditing
        
        // Call super to handle the click
        super.mouseDown(with: event)
        
        // Check if we're now editing
        if currentEditor() != nil {
            isCurrentlyEditing = true
            
            // If this is the first click (wasn't editing before), select all
            if !wasEditing {
                if let fieldEditor = currentEditor() as? NSTextView {
                    fieldEditor.selectedRange = NSRange(location: 0, length: fieldEditor.string.count)
                }
            }
        }
    }
    
    override func textDidEndEditing(_ notification: Notification) {
        super.textDidEndEditing(notification)
        isCurrentlyEditing = false
    }
}

class WebViewController: NSViewController {
    private var webView: WKWebView!
    private let trafficLightArea = NSVisualEffectView()
    private let toolbar = NSVisualEffectView()
    private let minimizeToBubbleButton = NSButton()
    private let backButton = NSButton()
    private let forwardButton = NSButton()
    private let reloadButton = NSButton()
    private let urlField = BrowserStyleTextField()
    private let newBubbleButton = NSButton()
    private var progressIndicator: NSProgressIndicator!
    
    weak var delegate: WebViewControllerDelegate?
    
    // UserDefaults key for tracking first-time minimize
    private let hasMinimizedBeforeKey = "hasMinimizedToBubbleBefore"
    
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
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure web view can receive keyboard events
        view.window?.makeFirstResponder(webView)
    }
    
    private func setupTrafficLightArea() {
        let trafficLightHeight: CGFloat = 30
        trafficLightArea.frame = NSRect(x: 0, y: view.bounds.height - trafficLightHeight, width: view.bounds.width, height: trafficLightHeight)
        trafficLightArea.autoresizingMask = [.width, .minYMargin]
        
        // Configure vibrancy effect
        trafficLightArea.material = .titlebar
        trafficLightArea.blendingMode = .behindWindow
        trafficLightArea.state = .active
        
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
        
        toolbar.frame = NSRect(x: 0, y: view.bounds.height - totalTopHeight, width: view.bounds.width, height: toolbarHeight)
        toolbar.autoresizingMask = [.width, .minYMargin]
        
        // Configure vibrancy effect
        toolbar.material = .headerView
        toolbar.blendingMode = .behindWindow
        toolbar.state = .active
        
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
        
        // URL field - modern rounded style
        let rightButtonsWidth: CGFloat = 50  // New bubble button + margin
        let urlFieldWidth = view.bounds.width - xOffset - rightButtonsWidth
        let urlFieldHeight: CGFloat = 28
        let urlFieldY = (toolbarHeight - urlFieldHeight) / 2
        
        urlField.frame = NSRect(x: xOffset, y: urlFieldY, width: urlFieldWidth, height: urlFieldHeight)
        urlField.autoresizingMask = [.width]
        urlField.placeholderString = "Enter URL or search..."
        urlField.delegate = self
        urlField.font = NSFont.systemFont(ofSize: 13)
        
        // Modern URL field styling
        urlField.wantsLayer = true
        urlField.layer?.cornerRadius = 6
        urlField.layer?.borderWidth = 0.5
        urlField.layer?.borderColor = NSColor.separatorColor.cgColor
        urlField.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.5)
        urlField.focusRingType = .none
        
        // Add padding to URL field
        if let cell = urlField.cell as? NSTextFieldCell {
            cell.usesSingleLineMode = true
            cell.wraps = false
            cell.isScrollable = true
        }
        
        toolbar.addSubview(urlField)
        
        // New bubble button (right-aligned) - modern style
        newBubbleButton.frame = NSRect(x: view.bounds.width - 44, y: buttonY, width: buttonSize, height: buttonSize)
        newBubbleButton.autoresizingMask = [.minXMargin]
        newBubbleButton.image = NSImage(systemSymbolName: "plus.circle", accessibilityDescription: "New Bubble")
        newBubbleButton.imagePosition = .imageOnly
        newBubbleButton.isBordered = false
        newBubbleButton.bezelStyle = .regularSquare
        newBubbleButton.contentTintColor = .controlAccentColor
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
        
        // Add hover effect using tracking area
        let trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: ["button": button]
        )
        button.addTrackingArea(trackingArea)
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
            progressIndicator.doubleValue = webView.estimatedProgress
            progressIndicator.isHidden = webView.estimatedProgress >= 1.0
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
        let searchEngine = PreferencesViewController.getCurrentSearchEngine()
        
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

// MARK: - Delegate Protocol

protocol WebViewControllerDelegate: AnyObject {
    func webViewController(_ controller: WebViewController, didRequestNewBubble url: String)
    func webViewController(_ controller: WebViewController, didUpdateURL url: String)
    func webViewController(_ controller: WebViewController, didUpdateFavicon image: NSImage)
}

