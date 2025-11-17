//
//  PreferencesViewController.swift
//  FloatyBrowser
//
//  View controller for preferences UI.
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

class PreferencesViewController: NSViewController {
    
    // UserDefaults key
    private let searchEngineKey = "defaultSearchEngine"
    
    // UI Elements - Search
    private var searchEnginePopup: NSPopUpButton!
    private var previewLabel: NSTextField!
    
    // UI Elements - Appearance
    private var appearancePopup: NSPopUpButton!
    private var bubblePreview: BubblePreviewView!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("🎨 PreferencesViewController: Setting up UI")
        
        setupUI()
        loadSavedSearchEngine()
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
        
        // Appearance divider
        let appearanceDivider = NSBox(frame: NSRect(x: 20, y: 230, width: 560, height: 1))
        appearanceDivider.boxType = .separator
        view.addSubview(appearanceDivider)
        
        // MARK: - Search Section
        
        // Search title label
        let titleLabel = NSTextField(labelWithString: "Search")
        titleLabel.frame = NSRect(x: 40, y: 190, width: 520, height: 30)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .left
        view.addSubview(titleLabel)
        
        // Description
        let descriptionLabel = NSTextField(labelWithString: "Default search engine:")
        descriptionLabel.frame = NSRect(x: 40, y: 150, width: 200, height: 20)
        descriptionLabel.font = NSFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .left
        view.addSubview(descriptionLabel)
        
        // Search engine dropdown
        searchEnginePopup = NSPopUpButton(frame: NSRect(x: 40, y: 110, width: 200, height: 26))
        searchEnginePopup.removeAllItems()
        
        // Add all search engines
        for engine in SearchEngine.allCases {
            searchEnginePopup.addItem(withTitle: engine.rawValue)
        }
        
        searchEnginePopup.target = self
        searchEnginePopup.action = #selector(searchEngineChanged)
        view.addSubview(searchEnginePopup)
        
        // Preview section
        let previewTitleLabel = NSTextField(labelWithString: "Search URL preview:")
        previewTitleLabel.frame = NSRect(x: 40, y: 70, width: 520, height: 20)
        previewTitleLabel.font = NSFont.systemFont(ofSize: 13)
        previewTitleLabel.textColor = .secondaryLabelColor
        previewTitleLabel.alignment = .left
        view.addSubview(previewTitleLabel)
        
        // Preview URL
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.frame = NSRect(x: 40, y: 30, width: 520, height: 30)
        previewLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        previewLabel.textColor = .tertiaryLabelColor
        previewLabel.alignment = .left
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.isBezeled = false
        previewLabel.isEditable = false
        previewLabel.isSelectable = true
        previewLabel.backgroundColor = .clear
        view.addSubview(previewLabel)
        
        NSLog("✅ PreferencesViewController: UI setup complete")
    }
    
    private func loadSavedSearchEngine() {
        // Load saved search engine or default to Google
        if let savedEngine = UserDefaults.standard.string(forKey: searchEngineKey),
           let engine = SearchEngine(rawValue: savedEngine) {
            searchEnginePopup.selectItem(withTitle: engine.rawValue)
            updatePreview(for: engine)
            NSLog("📖 Loaded saved search engine: \(engine.rawValue)")
        } else {
            // Default to Google
            searchEnginePopup.selectItem(withTitle: SearchEngine.google.rawValue)
            updatePreview(for: .google)
            NSLog("📖 Using default search engine: Google")
        }
    }
    
    @objc private func searchEngineChanged() {
        guard let selectedTitle = searchEnginePopup.titleOfSelectedItem,
              let engine = SearchEngine(rawValue: selectedTitle) else {
            return
        }
        
        NSLog("🔄 Search engine changed to: \(engine.rawValue)")
        
        // Save to UserDefaults
        UserDefaults.standard.set(engine.rawValue, forKey: searchEngineKey)
        UserDefaults.standard.synchronize()
        
        // Update preview
        updatePreview(for: engine)
        
        NSLog("💾 Saved search engine: \(engine.rawValue)")
    }
    
    private func updatePreview(for engine: SearchEngine) {
        let exampleQuery = "floaty browser"
        let exampleURL = engine.searchURL + exampleQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        previewLabel.stringValue = exampleURL
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

// MARK: - Public helper to get current search engine

extension PreferencesViewController {
    static func getCurrentSearchEngine() -> SearchEngine {
        let key = "defaultSearchEngine"
        if let savedEngine = UserDefaults.standard.string(forKey: key),
           let engine = SearchEngine(rawValue: savedEngine) {
            return engine
        }
        return .google // Default
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
        iconLabel = NSTextField(labelWithString: "🌐")
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        iconLabel.alignment = .center
        iconLabel.frame = bounds
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
                
                addSubview(glassView, positioned: .below, relativeTo: iconLabel)
                frostedGlassView = glassView
            }
            frostedGlassView?.isHidden = false
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

