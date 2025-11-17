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
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 450))
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedAppearance()
    }
    
    private func setupUI() {
        // MARK: - Appearance Section
        
        // Appearance title
        let appearanceTitle = NSTextField(labelWithString: "Bubble Appearance")
        appearanceTitle.frame = NSRect(x: 40, y: 340, width: 300, height: 30)
        appearanceTitle.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        appearanceTitle.alignment = .left
        view.addSubview(appearanceTitle)
        
        // Appearance description
        let appearanceDesc = NSTextField(labelWithString: "Choose your bubble style:")
        appearanceDesc.frame = NSRect(x: 40, y: 310, width: 300, height: 20)
        appearanceDesc.font = NSFont.systemFont(ofSize: 13)
        appearanceDesc.textColor = .secondaryLabelColor
        appearanceDesc.alignment = .left
        view.addSubview(appearanceDesc)
        
        // Appearance popup
        appearancePopup = NSPopUpButton(frame: NSRect(x: 40, y: 270, width: 200, height: 26))
        appearancePopup.removeAllItems()
        
        // Add all bubble appearances
        for appearance in BubbleAppearance.allCases {
            appearancePopup.addItem(withTitle: appearance.rawValue)
        }
        
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged)
        view.addSubview(appearancePopup)
        
        // Bubble preview
        bubblePreview = BubblePreviewView(frame: NSRect(x: 260, y: 260, width: 80, height: 80))
        view.addSubview(bubblePreview)
        
        NSLog("✅ AppearancePreferencesViewController: UI setup complete")
    }
    
    // MARK: - Appearance Methods
    
    private func loadSavedAppearance() {
        let currentAppearance = BubbleAppearance.getCurrentAppearance()
        appearancePopup.selectItem(withTitle: currentAppearance.rawValue)
        bubblePreview.updateAppearance(currentAppearance)
        NSLog("📖 Loaded saved appearance: \(currentAppearance.rawValue)")
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
}

// MARK: - Search Tab

class SearchPreferencesViewController: NSViewController {
    
    private let searchEngineKey = "defaultSearchEngine"
    private var searchEnginePopup: NSPopUpButton!
    private var previewLabel: NSTextField!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 450))
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedSearchEngine()
    }
    
    private func setupUI() {
        // Title
        let titleLabel = NSTextField(labelWithString: "Default Search Engine")
        titleLabel.frame = NSRect(x: 40, y: 380, width: 520, height: 30)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .left
        view.addSubview(titleLabel)
        
        // Description
        let descriptionLabel = NSTextField(labelWithString: "Choose which search engine to use when searching from the address bar:")
        descriptionLabel.frame = NSRect(x: 40, y: 330, width: 520, height: 40)
        descriptionLabel.font = NSFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .left
        descriptionLabel.lineBreakMode = .byWordWrapping
        descriptionLabel.maximumNumberOfLines = 2
        view.addSubview(descriptionLabel)
        
        // Search engine dropdown
        searchEnginePopup = NSPopUpButton(frame: NSRect(x: 40, y: 280, width: 200, height: 26))
        searchEnginePopup.removeAllItems()
        
        for engine in SearchEngine.allCases {
            searchEnginePopup.addItem(withTitle: engine.rawValue)
        }
        
        searchEnginePopup.target = self
        searchEnginePopup.action = #selector(searchEngineChanged)
        view.addSubview(searchEnginePopup)
        
        // Preview section
        let previewTitleLabel = NSTextField(labelWithString: "Search URL Preview:")
        previewTitleLabel.frame = NSRect(x: 40, y: 230, width: 520, height: 20)
        previewTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        previewTitleLabel.textColor = .secondaryLabelColor
        previewTitleLabel.alignment = .left
        view.addSubview(previewTitleLabel)
        
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.frame = NSRect(x: 40, y: 190, width: 520, height: 30)
        previewLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        previewLabel.textColor = .tertiaryLabelColor
        previewLabel.alignment = .left
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.isBezeled = false
        previewLabel.isEditable = false
        previewLabel.isSelectable = true
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
        UserDefaults.standard.synchronize()
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
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 450))
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedSettings()
    }
    
    private func setupUI() {
        // Title
        let titleLabel = NSTextField(labelWithString: "General Settings")
        titleLabel.frame = NSRect(x: 40, y: 380, width: 520, height: 30)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .left
        view.addSubview(titleLabel)
        
        // Haptics section
        let hapticsTitle = NSTextField(labelWithString: "Haptic Feedback")
        hapticsTitle.frame = NSRect(x: 40, y: 330, width: 520, height: 20)
        hapticsTitle.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        hapticsTitle.alignment = .left
        view.addSubview(hapticsTitle)
        
        // Haptics checkbox
        hapticsCheckbox = NSButton(checkboxWithTitle: "Enable haptic feedback when bubbles snap to screen edges", target: self, action: #selector(hapticsToggled))
        hapticsCheckbox.frame = NSRect(x: 40, y: 290, width: 520, height: 20)
        hapticsCheckbox.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(hapticsCheckbox)
        
        // Haptics description
        let hapticsDesc = NSTextField(labelWithString: "Subtle tactile confirmation when dragging bubbles near screen edges (MacBook only)")
        hapticsDesc.frame = NSRect(x: 60, y: 250, width: 500, height: 30)
        hapticsDesc.font = NSFont.systemFont(ofSize: 11)
        hapticsDesc.textColor = .secondaryLabelColor
        hapticsDesc.alignment = .left
        hapticsDesc.lineBreakMode = .byWordWrapping
        hapticsDesc.maximumNumberOfLines = 2
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
        UserDefaults.standard.synchronize()
        
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
        let verticalOffset: CGFloat = -10  // Push down to visually center (negative moves content down)
        iconLabel = NSTextField(labelWithString: "🌐")
        iconLabel.font = NSFont.systemFont(ofSize: 32)
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

