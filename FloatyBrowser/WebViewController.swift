//
//  WebViewController.swift
//  FloatyBrowser
//
//  Manages WKWebView with navigation policy interception for new tabs.
//

import Cocoa
import WebKit

class WebViewController: NSViewController {
    private var webView: WKWebView!
    private let toolbar = NSView()
    private let backButton = NSButton()
    private let forwardButton = NSButton()
    private let reloadButton = NSButton()
    private let collapseToBubbleButton = NSButton()
    private let urlField = NSTextField()
    private let newBubbleButton = NSButton()
    private var progressIndicator: NSProgressIndicator!
    
    weak var delegate: WebViewControllerDelegate?
    
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
        setupToolbar()
        setupWebView()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure web view can receive keyboard events
        view.window?.makeFirstResponder(webView)
    }
    
    private func setupToolbar() {
        toolbar.frame = NSRect(x: 0, y: view.bounds.height - 40, width: view.bounds.width, height: 40)
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.wantsLayer = true
        toolbar.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        
        let buttonWidth: CGFloat = 30
        let buttonHeight: CGFloat = 24
        let buttonY: CGFloat = 8
        var xOffset: CGFloat = 8
        
        // Back button
        backButton.frame = NSRect(x: xOffset, y: buttonY, width: buttonWidth, height: buttonHeight)
        backButton.title = "◀"
        backButton.bezelStyle = .roundRect
        backButton.target = self
        backButton.action = #selector(goBack)
        backButton.isEnabled = false
        toolbar.addSubview(backButton)
        xOffset += buttonWidth + 4
        
        // Forward button
        forwardButton.frame = NSRect(x: xOffset, y: buttonY, width: buttonWidth, height: buttonHeight)
        forwardButton.title = "▶"
        forwardButton.bezelStyle = .roundRect
        forwardButton.target = self
        forwardButton.action = #selector(goForward)
        forwardButton.isEnabled = false
        toolbar.addSubview(forwardButton)
        xOffset += buttonWidth + 4
        
        // Reload button
        reloadButton.frame = NSRect(x: xOffset, y: buttonY, width: buttonWidth, height: buttonHeight)
        reloadButton.title = "⟳"
        reloadButton.bezelStyle = .roundRect
        reloadButton.target = self
        reloadButton.action = #selector(reload)
        toolbar.addSubview(reloadButton)
        xOffset += buttonWidth + 4
        
        // Collapse to bubble button
        collapseToBubbleButton.frame = NSRect(x: xOffset, y: buttonY, width: buttonWidth, height: buttonHeight)
        collapseToBubbleButton.title = "○"  // Circle symbol for bubble
        collapseToBubbleButton.bezelStyle = .roundRect
        collapseToBubbleButton.target = self
        collapseToBubbleButton.action = #selector(collapseToBubble)
        collapseToBubbleButton.toolTip = "Collapse to bubble"
        toolbar.addSubview(collapseToBubbleButton)
        xOffset += buttonWidth + 10
        
        // URL field - calculate remaining space
        let rightButtonsWidth: CGFloat = 42  // New bubble button + margin
        let urlFieldWidth = view.bounds.width - xOffset - rightButtonsWidth
        urlField.frame = NSRect(x: xOffset, y: buttonY, width: urlFieldWidth, height: buttonHeight)
        urlField.autoresizingMask = [.width]
        urlField.placeholderString = "Enter URL..."
        urlField.delegate = self
        toolbar.addSubview(urlField)
        
        // New bubble button (right-aligned)
        newBubbleButton.frame = NSRect(x: view.bounds.width - 42, y: buttonY, width: 34, height: buttonHeight)
        newBubbleButton.autoresizingMask = [.minXMargin]
        newBubbleButton.title = "+"
        newBubbleButton.bezelStyle = .roundRect
        newBubbleButton.target = self
        newBubbleButton.action = #selector(createNewBubble)
        newBubbleButton.toolTip = "Pop out to new bubble"
        toolbar.addSubview(newBubbleButton)
        
        view.addSubview(toolbar)
    }
    
    private func setupWebView() {
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.frame = NSRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height - 40)
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Allow keyboard events in WKWebView
        webView.allowsBackForwardNavigationGestures = true
        
        // Set custom user agent to identify as desktop browser
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15 FloatyBrowser/1.0"
        
        // Add progress indicator
        progressIndicator = NSProgressIndicator()
        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = false
        progressIndicator.frame = NSRect(x: 0, y: view.bounds.height - 42, width: view.bounds.width, height: 2)
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
        var urlToLoad = urlString
        
        // Add scheme if missing
        if !urlToLoad.hasPrefix("http://") && !urlToLoad.hasPrefix("https://") {
            urlToLoad = "https://" + urlToLoad
        }
        
        guard let url = URL(string: urlToLoad) else { return }
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
        // Tell the panel window to collapse
        view.window?.performClose(nil)
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

