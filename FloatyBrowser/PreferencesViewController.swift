//
//  PreferencesViewController.swift
//  FloatyBrowser
//
//  View controllers for preferences UI with tabbed interface.
//

import Cocoa

// Search engine options
enum SearchEngine: String, CaseIterable {
    case google = "Google"
    case duckDuckGo = "DuckDuckGo"
    case bing = "Bing"
    case brave = "Brave"
    case ecosia = "Ecosia"
    
    var searchURL: String {
        switch self {
        case .google:
            return "https://www.google.com/search?q="
        case .duckDuckGo:
            return "https://duckduckgo.com/?q="
        case .bing:
            return "https://www.bing.com/search?q="
        case .brave:
            return "https://search.brave.com/search?q="
        case .ecosia:
            return "https://www.ecosia.org/search?q="
        }
    }
}

// MARK: - Appearance Tab

class AppearancePreferencesViewController: NSViewController {
    
    private var appearancePopup: NSPopUpButton!
    private var bubblePreview: BubblePreviewView!
    private var themeColorsCheckbox: NSButton!
    
    private let useThemeColorsKey = "useWebsiteThemeColors"
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 580))  // Increased from 450 to 580
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedAppearance()
    }
    
    private func setupUI() {
        let margin: CGFloat = 60
        var yPos: CGFloat = 490  // Increased from 360 to 490 (130 more to match height increase)
        
        // Title
        let title = NSTextField(labelWithString: "Bubble Appearance")
        title.frame = NSRect(x: margin, y: yPos, width: 480, height: 32)
        title.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        view.addSubview(title)
        yPos -= 55
        
        // Description
        let description = NSTextField(labelWithString: "Choose your bubble style:")
        description.frame = NSRect(x: margin, y: yPos, width: 450, height: 20)
        description.font = NSFont.systemFont(ofSize: 13)
        description.textColor = .secondaryLabelColor
        view.addSubview(description)
        yPos -= 45
        
        // Appearance popup
        appearancePopup = NSPopUpButton(frame: NSRect(x: margin, y: yPos, width: 220, height: 28))
        appearancePopup.font = NSFont.systemFont(ofSize: 13)
        appearancePopup.removeAllItems()
        
        for appearance in BubbleAppearance.allCases {
            appearancePopup.addItem(withTitle: appearance.rawValue)
        }
        
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged)
        view.addSubview(appearancePopup)
        yPos -= 60
        
        // Preview label
        let previewLabel = NSTextField(labelWithString: "Preview")
        previewLabel.frame = NSRect(x: margin, y: yPos, width: 450, height: 20)
        previewLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        previewLabel.textColor = .secondaryLabelColor
        view.addSubview(previewLabel)
        yPos -= 30
        
        // Bubble preview
        let previewSize: CGFloat = 100
        bubblePreview = BubblePreviewView(frame: NSRect(
            x: margin,
            y: yPos,
            width: previewSize,
            height: previewSize
        ))
        view.addSubview(bubblePreview)
        yPos -= 130
        
        // Theme colors section
        let separator1 = NSBox(frame: NSRect(x: margin, y: yPos, width: 480, height: 1))
        separator1.boxType = .separator
        view.addSubview(separator1)
        yPos -= 35
        
        let themeColorsHeader = NSTextField(labelWithString: "Browser Window Colors")
        themeColorsHeader.frame = NSRect(x: margin, y: yPos, width: 480, height: 22)
        themeColorsHeader.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        view.addSubview(themeColorsHeader)
        yPos -= 35
        
        // Theme colors checkbox
        themeColorsCheckbox = NSButton(checkboxWithTitle: "Use website theme colors for browser window", target: self, action: #selector(themeColorsToggled))
        themeColorsCheckbox.frame = NSRect(x: margin, y: yPos, width: 450, height: 18)
        themeColorsCheckbox.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(themeColorsCheckbox)
        yPos -= 30
        
        // Theme colors description
        let themeColorsDesc = NSTextField(labelWithString: "Adapts window toolbar colors based on website theme. Disables translucent frosted glass effect.")
        themeColorsDesc.frame = NSRect(x: margin + 20, y: yPos, width: 430, height: 34)
        themeColorsDesc.font = NSFont.systemFont(ofSize: 12)
        themeColorsDesc.textColor = .tertiaryLabelColor
        themeColorsDesc.drawsBackground = false
        themeColorsDesc.isBezeled = false
        themeColorsDesc.isBordered = false
        themeColorsDesc.maximumNumberOfLines = 2
        themeColorsDesc.lineBreakMode = .byWordWrapping
        view.addSubview(themeColorsDesc)
        
        NSLog("✅ AppearancePreferencesViewController: UI setup complete")
    }
    
    // MARK: - Appearance Methods
    
    private func loadSavedAppearance() {
        let currentAppearance = BubbleAppearance.getCurrentAppearance()
        appearancePopup.selectItem(withTitle: currentAppearance.rawValue)
        bubblePreview.updateAppearance(currentAppearance)
        NSLog("📖 Loaded saved appearance: \(currentAppearance.rawValue)")
        
        // Load theme colors setting (default: OFF)
        let useThemeColors = UserDefaults.standard.object(forKey: useThemeColorsKey) as? Bool ?? false
        themeColorsCheckbox.state = useThemeColors ? .on : .off
        NSLog("📖 Loaded theme colors setting: \(useThemeColors)")
    }
    
    @objc private func appearanceChanged() {
        guard let selectedTitle = appearancePopup.titleOfSelectedItem,
              let appearance = BubbleAppearance(rawValue: selectedTitle) else {
            return
        }
        
        NSLog("🎨 Appearance changed to: \(appearance.rawValue)")
        
        // Save preference
        appearance.saveAsCurrent()
        
        // Update preview
        bubblePreview.updateAppearance(appearance)
        
        NSLog("💾 Saved appearance: \(appearance.rawValue)")
    }
    
    @objc private func themeColorsToggled() {
        let isEnabled = themeColorsCheckbox.state == .on
        UserDefaults.standard.set(isEnabled, forKey: useThemeColorsKey)
        
        NSLog("💾 Theme colors \(isEnabled ? "enabled" : "disabled")")
        
        // Notify all open windows to update their mode
        NotificationCenter.default.post(name: .themeColorModeChanged, object: nil, userInfo: ["enabled": isEnabled])
        NSLog("📢 Broadcasted theme color mode change to all windows")
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let themeColorModeChanged = Notification.Name("themeColorModeChanged")
}

// MARK: - Public helper to check if theme colors are enabled

extension AppearancePreferencesViewController {
    static func isThemeColorsEnabled() -> Bool {
        return UserDefaults.standard.object(forKey: "useWebsiteThemeColors") as? Bool ?? false
    }
}

// MARK: - Search Tab

class SearchPreferencesViewController: NSViewController {
    
    private let searchEngineKey = "defaultSearchEngine"
    private var searchEnginePopup: NSPopUpButton!
    private var previewLabel: NSTextField!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 580))  // Match window height
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedSearchEngine()
    }
    
    private func setupUI() {
        let margin: CGFloat = 60
        var yPos: CGFloat = 490  // Match Appearance tab starting position
        
        // Title
        let title = NSTextField(labelWithString: "Default Search Engine")
        title.frame = NSRect(x: margin, y: yPos, width: 480, height: 32)
        title.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        view.addSubview(title)
        yPos -= 55
        
        // Description
        let desc = NSTextField(labelWithString: "Choose which search engine to use when searching from the address bar.")
        desc.frame = NSRect(x: margin, y: yPos, width: 450, height: 20)
        desc.font = NSFont.systemFont(ofSize: 13)
        desc.textColor = .secondaryLabelColor
        view.addSubview(desc)
        yPos -= 45
        
        // Search engine dropdown
        searchEnginePopup = NSPopUpButton(frame: NSRect(x: margin, y: yPos, width: 200, height: 28))
        searchEnginePopup.font = NSFont.systemFont(ofSize: 13)
        searchEnginePopup.removeAllItems()
        
        for engine in SearchEngine.allCases {
            searchEnginePopup.addItem(withTitle: engine.rawValue)
        }
        
        searchEnginePopup.target = self
        searchEnginePopup.action = #selector(searchEngineChanged)
        view.addSubview(searchEnginePopup)
        yPos -= 60
        
        // Preview label
        let previewTitle = NSTextField(labelWithString: "Preview")
        previewTitle.frame = NSRect(x: margin, y: yPos, width: 450, height: 20)
        previewTitle.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        previewTitle.textColor = .secondaryLabelColor
        view.addSubview(previewTitle)
        yPos -= 30
        
        // Preview URL
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.frame = NSRect(x: margin, y: yPos, width: 450, height: 22)
        previewLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        previewLabel.textColor = NSColor.systemBlue.withAlphaComponent(0.8)
        previewLabel.lineBreakMode = .byTruncatingMiddle
        previewLabel.isBezeled = false
        previewLabel.isEditable = false
        previewLabel.isSelectable = true
        previewLabel.drawsBackground = false
        previewLabel.backgroundColor = .clear
        view.addSubview(previewLabel)
        
        NSLog("✅ SearchPreferencesViewController: UI setup complete")
    }
    
    private func loadSavedSearchEngine() {
        if let savedEngine = UserDefaults.standard.string(forKey: searchEngineKey),
           let engine = SearchEngine(rawValue: savedEngine) {
            searchEnginePopup.selectItem(withTitle: engine.rawValue)
            updatePreview(for: engine)
        } else {
            searchEnginePopup.selectItem(withTitle: SearchEngine.google.rawValue)
            updatePreview(for: .google)
        }
    }
    
    @objc private func searchEngineChanged() {
        guard let selectedTitle = searchEnginePopup.titleOfSelectedItem,
              let engine = SearchEngine(rawValue: selectedTitle) else {
            return
        }
        
        UserDefaults.standard.set(engine.rawValue, forKey: searchEngineKey)
        updatePreview(for: engine)
        
        NSLog("💾 Saved search engine: \(engine.rawValue)")
    }
    
    private func updatePreview(for engine: SearchEngine) {
        let exampleQuery = "floaty browser"
        let exampleURL = engine.searchURL + exampleQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        previewLabel.stringValue = exampleURL
    }
}

// MARK: - General Tab

class GeneralPreferencesViewController: NSViewController {
    
    private let hapticsEnabledKey = "hapticsEnabled"
    private var hapticsCheckbox: NSButton!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 580))  // Match window height
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedSettings()
    }
    
    private func setupUI() {
        let margin: CGFloat = 60
        var yPos: CGFloat = 490  // Match Appearance tab starting position
        
        // Title
        let title = NSTextField(labelWithString: "General Settings")
        title.frame = NSRect(x: margin, y: yPos, width: 480, height: 32)
        title.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        view.addSubview(title)
        yPos -= 70
        
        // Haptics section header
        let hapticsHeader = NSTextField(labelWithString: "Haptic Feedback")
        hapticsHeader.frame = NSRect(x: margin, y: yPos, width: 480, height: 22)
        hapticsHeader.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        view.addSubview(hapticsHeader)
        yPos -= 35
        
        // Haptics checkbox
        hapticsCheckbox = NSButton(checkboxWithTitle: "Enable haptic feedback when bubbles snap to edges", target: self, action: #selector(hapticsToggled))
        hapticsCheckbox.frame = NSRect(x: margin, y: yPos, width: 450, height: 18)
        hapticsCheckbox.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(hapticsCheckbox)
        yPos -= 35
        
        // Haptics description (shorter, cleaner text)
        let hapticsDesc = NSTextField(labelWithString: "Subtle tactile confirmation on MacBook trackpads.")
        hapticsDesc.frame = NSRect(x: margin + 20, y: yPos, width: 430, height: 20)
        hapticsDesc.font = NSFont.systemFont(ofSize: 12)
        hapticsDesc.textColor = .tertiaryLabelColor
        hapticsDesc.drawsBackground = false
        hapticsDesc.isBezeled = false
        hapticsDesc.isBordered = false
        view.addSubview(hapticsDesc)
        
        NSLog("✅ GeneralPreferencesViewController: UI setup complete")
    }
    
    private func loadSavedSettings() {
        // Haptics enabled by default
        let hapticsEnabled = UserDefaults.standard.object(forKey: hapticsEnabledKey) as? Bool ?? true
        hapticsCheckbox.state = hapticsEnabled ? .on : .off
    }
    
    @objc private func hapticsToggled() {
        let isEnabled = hapticsCheckbox.state == .on
        UserDefaults.standard.set(isEnabled, forKey: hapticsEnabledKey)
        
        NSLog("💾 Haptics \(isEnabled ? "enabled" : "disabled")")
    }
}

// MARK: - Public helper to get current search engine

extension SearchPreferencesViewController {
    static func getCurrentSearchEngine() -> SearchEngine {
        let key = "defaultSearchEngine"
        if let savedEngine = UserDefaults.standard.string(forKey: key),
           let engine = SearchEngine(rawValue: savedEngine) {
            return engine
        }
        return .google // Default
    }
}

// MARK: - Public helper to check if haptics are enabled

extension GeneralPreferencesViewController {
    static func isHapticsEnabled() -> Bool {
        return UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }
}

// MARK: - Bubble Preview View

class BubblePreviewView: NSView {
    private var gradientLayer: CAGradientLayer?
    private var frostedGlassView: NSVisualEffectView?
    private var iconLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        
        // Circular shape
        layer?.cornerRadius = bounds.width / 2
        layer?.masksToBounds = true
        
        // Gradient layer (will be configured by updateAppearance)
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.cornerRadius = bounds.width / 2
        layer?.insertSublayer(gradient, at: 0)
        self.gradientLayer = gradient
        
        // Icon label
        // NSTextField doesn't center text vertically by default, so we offset it manually
        let iconSize: CGFloat = bounds.width > 85 ? 40 : 32  // Larger icon for bigger preview
        let verticalOffset: CGFloat = bounds.width > 85 ? -12 : -10  // Adjust offset for size
        iconLabel = NSTextField(labelWithString: "🌐")
        iconLabel.font = NSFont.systemFont(ofSize: iconSize)
        iconLabel.alignment = .center
        iconLabel.frame = NSRect(x: 0, y: verticalOffset, width: bounds.width, height: bounds.height)
        iconLabel.textColor = .white
        iconLabel.drawsBackground = false
        iconLabel.isBezeled = false
        iconLabel.isBordered = false
        iconLabel.isEditable = false
        iconLabel.isSelectable = false
        addSubview(iconLabel)
    }
    
    func updateAppearance(_ appearance: BubbleAppearance) {
        if appearance == .frostedGlass {
            // Use frosted glass
            gradientLayer?.isHidden = true
            
            if frostedGlassView == nil {
                let glassView = NSVisualEffectView(frame: bounds)
                glassView.material = .hudWindow
                glassView.blendingMode = .behindWindow
                glassView.state = .active
                glassView.wantsLayer = true
                glassView.layer?.cornerRadius = bounds.width / 2
                glassView.layer?.masksToBounds = true
                
                // Add tinted overlay for better visibility (same as actual bubble)
                let isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
                if isDarkMode {
                    glassView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.22).cgColor
                } else {
                    glassView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.32).cgColor
                }
                
                // Add subtle frosted glass stroke for definition
                glassView.layer?.borderWidth = 1.0
                glassView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
                
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
            frostedGlassView?.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
            
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
}

