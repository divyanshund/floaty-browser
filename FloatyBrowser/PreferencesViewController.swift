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
        self.view = NSView()
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 500, height: 420)
        setupUI()
        loadSavedAppearance()
    }
    
    private func setupUI() {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
        
        let title = NSTextField(labelWithString: "Bubble Appearance")
        title.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        mainStack.addArrangedSubview(title)
        mainStack.setCustomSpacing(4, after: title)
        
        let description = NSTextField(labelWithString: "Choose your bubble style:")
        description.font = NSFont.systemFont(ofSize: 13)
        description.textColor = .secondaryLabelColor
        mainStack.addArrangedSubview(description)
        mainStack.setCustomSpacing(12, after: description)
        
        appearancePopup = NSPopUpButton()
        appearancePopup.translatesAutoresizingMaskIntoConstraints = false
        appearancePopup.font = NSFont.systemFont(ofSize: 13)
        appearancePopup.removeAllItems()
        for appearance in BubbleAppearance.allCases {
            appearancePopup.addItem(withTitle: appearance.rawValue)
        }
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged)
        appearancePopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        mainStack.addArrangedSubview(appearancePopup)
        mainStack.setCustomSpacing(20, after: appearancePopup)
        
        let previewSize: CGFloat = 80
        bubblePreview = BubblePreviewView(frame: NSRect(x: 0, y: 0, width: previewSize, height: previewSize))
        bubblePreview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bubblePreview.widthAnchor.constraint(equalToConstant: previewSize),
            bubblePreview.heightAnchor.constraint(equalToConstant: previewSize),
        ])
        mainStack.addArrangedSubview(bubblePreview)
        mainStack.setCustomSpacing(28, after: bubblePreview)
        
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
        mainStack.setCustomSpacing(20, after: separator)
        
        let themeColorsHeader = NSTextField(labelWithString: "Browser Window Colors")
        themeColorsHeader.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        mainStack.addArrangedSubview(themeColorsHeader)
        mainStack.setCustomSpacing(10, after: themeColorsHeader)
        
        themeColorsCheckbox = NSButton(checkboxWithTitle: "Use website theme colors for browser window", target: self, action: #selector(themeColorsToggled))
        themeColorsCheckbox.font = NSFont.systemFont(ofSize: 13)
        mainStack.addArrangedSubview(themeColorsCheckbox)
        mainStack.setCustomSpacing(4, after: themeColorsCheckbox)
        
        let descWrapper = makeIndentedLabel("Adapts window toolbar colors based on website theme. Disables translucent frosted glass effect.")
        mainStack.addArrangedSubview(descWrapper)
        descWrapper.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
    }
    
    private func makeIndentedLabel(_ text: String, indent: CGFloat = 22) -> NSView {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: indent),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])
        
        return wrapper
    }
    
    // MARK: - Appearance Methods
    
    private func loadSavedAppearance() {
        let currentAppearance = BubbleAppearance.getCurrentAppearance()
        appearancePopup.selectItem(withTitle: currentAppearance.rawValue)
        bubblePreview.updateAppearance(currentAppearance)
        
        let useThemeColors = UserDefaults.standard.object(forKey: useThemeColorsKey) as? Bool ?? false
        themeColorsCheckbox.state = useThemeColors ? .on : .off
    }
    
    @objc private func appearanceChanged() {
        guard let selectedTitle = appearancePopup.titleOfSelectedItem,
              let appearance = BubbleAppearance(rawValue: selectedTitle) else {
            return
        }
        
        appearance.saveAsCurrent()
        bubblePreview.updateAppearance(appearance)
    }
    
    @objc private func themeColorsToggled() {
        let isEnabled = themeColorsCheckbox.state == .on
        UserDefaults.standard.set(isEnabled, forKey: useThemeColorsKey)
        NotificationCenter.default.post(name: .themeColorModeChanged, object: nil, userInfo: ["enabled": isEnabled])
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
        self.view = NSView()
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 500, height: 260)
        setupUI()
        loadSavedSearchEngine()
    }
    
    private func setupUI() {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
        
        let title = NSTextField(labelWithString: "Default Search Engine")
        title.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        mainStack.addArrangedSubview(title)
        mainStack.setCustomSpacing(4, after: title)
        
        let desc = NSTextField(labelWithString: "Choose which search engine to use when searching from the address bar.")
        desc.font = NSFont.systemFont(ofSize: 13)
        desc.textColor = .secondaryLabelColor
        mainStack.addArrangedSubview(desc)
        mainStack.setCustomSpacing(12, after: desc)
        
        searchEnginePopup = NSPopUpButton()
        searchEnginePopup.translatesAutoresizingMaskIntoConstraints = false
        searchEnginePopup.font = NSFont.systemFont(ofSize: 13)
        searchEnginePopup.removeAllItems()
        for engine in SearchEngine.allCases {
            searchEnginePopup.addItem(withTitle: engine.rawValue)
        }
        searchEnginePopup.target = self
        searchEnginePopup.action = #selector(searchEngineChanged)
        searchEnginePopup.widthAnchor.constraint(equalToConstant: 220).isActive = true
        mainStack.addArrangedSubview(searchEnginePopup)
        mainStack.setCustomSpacing(24, after: searchEnginePopup)
        
        let previewTitle = NSTextField(labelWithString: "Preview")
        previewTitle.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        previewTitle.textColor = .secondaryLabelColor
        mainStack.addArrangedSubview(previewTitle)
        mainStack.setCustomSpacing(4, after: previewTitle)
        
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        previewLabel.textColor = NSColor.systemBlue.withAlphaComponent(0.8)
        previewLabel.lineBreakMode = .byTruncatingMiddle
        previewLabel.isSelectable = true
        mainStack.addArrangedSubview(previewLabel)
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
        self.view = NSView()
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 500, height: 220)
        setupUI()
        loadSavedSettings()
    }
    
    private func setupUI() {
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
        
        let title = NSTextField(labelWithString: "General Settings")
        title.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        mainStack.addArrangedSubview(title)
        mainStack.setCustomSpacing(20, after: title)
        
        let hapticsHeader = NSTextField(labelWithString: "Haptic Feedback")
        hapticsHeader.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        mainStack.addArrangedSubview(hapticsHeader)
        mainStack.setCustomSpacing(10, after: hapticsHeader)
        
        hapticsCheckbox = NSButton(checkboxWithTitle: "Enable haptic feedback when bubbles snap to edges", target: self, action: #selector(hapticsToggled))
        hapticsCheckbox.font = NSFont.systemFont(ofSize: 13)
        mainStack.addArrangedSubview(hapticsCheckbox)
        mainStack.setCustomSpacing(4, after: hapticsCheckbox)
        
        let descWrapper = makeIndentedLabel("Subtle tactile confirmation on MacBook trackpads.")
        mainStack.addArrangedSubview(descWrapper)
        descWrapper.widthAnchor.constraint(equalTo: mainStack.widthAnchor).isActive = true
    }
    
    private func makeIndentedLabel(_ text: String, indent: CGFloat = 22) -> NSView {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let wrapper = NSView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: indent),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])
        
        return wrapper
    }
    
    private func loadSavedSettings() {
        let hapticsEnabled = UserDefaults.standard.object(forKey: hapticsEnabledKey) as? Bool ?? true
        hapticsCheckbox.state = hapticsEnabled ? .on : .off
    }
    
    @objc private func hapticsToggled() {
        let isEnabled = hapticsCheckbox.state == .on
        UserDefaults.standard.set(isEnabled, forKey: hapticsEnabledKey)
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
        return .google
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
        
        layer?.cornerRadius = bounds.width / 2
        layer?.masksToBounds = true
        
        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.cornerRadius = bounds.width / 2
        layer?.insertSublayer(gradient, at: 0)
        self.gradientLayer = gradient
        
        iconLabel = NSTextField(labelWithString: "\u{1F310}")
        iconLabel.font = NSFont.systemFont(ofSize: 32)
        iconLabel.alignment = .center
        iconLabel.textColor = .white
        iconLabel.drawsBackground = false
        iconLabel.isBezeled = false
        iconLabel.isBordered = false
        iconLabel.isEditable = false
        iconLabel.isSelectable = false
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconLabel)
        
        NSLayoutConstraint.activate([
            iconLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.width / 2
        gradientLayer?.frame = bounds
        gradientLayer?.cornerRadius = bounds.width / 2
        frostedGlassView?.frame = bounds
        frostedGlassView?.layer?.cornerRadius = bounds.width / 2
    }
    
    func updateAppearance(_ appearance: BubbleAppearance) {
        if appearance == .frostedGlass {
            gradientLayer?.isHidden = true
            
            if frostedGlassView == nil {
                let glassView = NSVisualEffectView(frame: bounds)
                glassView.material = .hudWindow
                glassView.blendingMode = .behindWindow
                glassView.state = .active
                glassView.wantsLayer = true
                glassView.layer?.cornerRadius = bounds.width / 2
                glassView.layer?.masksToBounds = true
                
                let isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
                if isDarkMode {
                    glassView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.22).cgColor
                } else {
                    glassView.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.32).cgColor
                }
                
                glassView.layer?.borderWidth = 1.0
                glassView.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
                
                addSubview(glassView, positioned: .below, relativeTo: iconLabel)
                frostedGlassView = glassView
            }
            frostedGlassView?.isHidden = false
            
            let isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
            if isDarkMode {
                frostedGlassView?.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.22).cgColor
            } else {
                frostedGlassView?.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.32).cgColor
            }
            frostedGlassView?.layer?.borderColor = NSColor(white: 1.0, alpha: 0.25).cgColor
            
            iconLabel.textColor = .labelColor
        } else {
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
