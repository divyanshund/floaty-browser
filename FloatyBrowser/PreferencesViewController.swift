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
    
    // UI Elements
    private var searchEnginePopup: NSPopUpButton!
    private var previewLabel: NSTextField!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("🎨 PreferencesViewController: Setting up UI")
        
        setupUI()
        loadSavedSearchEngine()
    }
    
    private func setupUI() {
        // Title label
        let titleLabel = NSTextField(labelWithString: "Search")
        titleLabel.frame = NSRect(x: 40, y: 340, width: 520, height: 30)
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .left
        view.addSubview(titleLabel)
        
        // Description
        let descriptionLabel = NSTextField(labelWithString: "Default search engine:")
        descriptionLabel.frame = NSRect(x: 40, y: 300, width: 200, height: 20)
        descriptionLabel.font = NSFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.alignment = .left
        view.addSubview(descriptionLabel)
        
        // Search engine dropdown
        searchEnginePopup = NSPopUpButton(frame: NSRect(x: 40, y: 260, width: 200, height: 26))
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
        previewTitleLabel.frame = NSRect(x: 40, y: 220, width: 520, height: 20)
        previewTitleLabel.font = NSFont.systemFont(ofSize: 13)
        previewTitleLabel.textColor = .secondaryLabelColor
        previewTitleLabel.alignment = .left
        view.addSubview(previewTitleLabel)
        
        // Preview URL
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.frame = NSRect(x: 40, y: 180, width: 520, height: 30)
        previewLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        previewLabel.textColor = .tertiaryLabelColor
        previewLabel.alignment = .left
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.isBezeled = false
        previewLabel.isEditable = false
        previewLabel.isSelectable = true
        previewLabel.backgroundColor = .clear
        view.addSubview(previewLabel)
        
        // Divider line
        let divider = NSBox(frame: NSRect(x: 20, y: 150, width: 560, height: 1))
        divider.boxType = .separator
        view.addSubview(divider)
        
        // Info note
        let infoLabel = NSTextField(labelWithString: "Type a search query in the address bar to search using your default search engine.")
        infoLabel.frame = NSRect(x: 40, y: 100, width: 520, height: 40)
        infoLabel.font = NSFont.systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.alignment = .left
        infoLabel.lineBreakMode = .byWordWrapping
        infoLabel.maximumNumberOfLines = 2
        view.addSubview(infoLabel)
        
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

