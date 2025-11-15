//
//  OnboardingViewController.swift
//  FloatyBrowser
//
//  View controller for page-based onboarding content.
//

import Cocoa

protocol OnboardingDelegate: AnyObject {
    func onboardingDidComplete()
    func onboardingDidSkip()
}

class OnboardingViewController: NSViewController {
    
    weak var delegate: OnboardingDelegate?
    
    // Current page
    private var currentPage = 0
    private let totalPages = 3
    
    // UI Elements
    private var imageView: NSImageView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var pageDotsStack: NSStackView!
    private var backButton: NSButton!
    private var nextButton: NSButton!
    private var skipButton: NSButton!
    
    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        self.view.wantsLayer = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NSLog("🎨 OnboardingViewController: Setting up UI")
        
        setupUI()
        showPage(0)
    }
    
    private func setupUI() {
        // Image/Video placeholder
        imageView = NSImageView(frame: NSRect(x: 220, y: 250, width: 200, height: 150))
        imageView.wantsLayer = true
        imageView.layer?.backgroundColor = NSColor.systemGray.withAlphaComponent(0.2).cgColor
        imageView.layer?.cornerRadius = 8
        imageView.imageScaling = .scaleProportionallyUpOrDown
        view.addSubview(imageView)
        
        // Placeholder label inside image view
        let placeholderLabel = NSTextField(labelWithString: "Video Preview")
        placeholderLabel.frame = NSRect(x: 50, y: 65, width: 100, height: 20)
        placeholderLabel.alignment = .center
        placeholderLabel.textColor = .secondaryLabelColor
        placeholderLabel.font = NSFont.systemFont(ofSize: 12)
        imageView.addSubview(placeholderLabel)
        
        // Title
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.frame = NSRect(x: 100, y: 180, width: 440, height: 40)
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isBezeled = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        view.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.frame = NSRect(x: 100, y: 140, width: 440, height: 30)
        subtitleLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.isBezeled = false
        subtitleLabel.isEditable = false
        subtitleLabel.backgroundColor = .clear
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.maximumNumberOfLines = 2
        view.addSubview(subtitleLabel)
        
        // Page dots
        pageDotsStack = NSStackView(frame: NSRect(x: 280, y: 70, width: 80, height: 12))
        pageDotsStack.orientation = .horizontal
        pageDotsStack.spacing = 8
        pageDotsStack.distribution = .fillEqually
        
        for _ in 0..<totalPages {
            let dot = NSView(frame: NSRect(x: 0, y: 0, width: 8, height: 8))
            dot.wantsLayer = true
            dot.layer?.cornerRadius = 4
            dot.layer?.backgroundColor = NSColor.systemGray.cgColor
            pageDotsStack.addArrangedSubview(dot)
        }
        view.addSubview(pageDotsStack)
        
        // Back button
        backButton = NSButton(frame: NSRect(x: 20, y: 20, width: 80, height: 32))
        backButton.title = "Back"
        backButton.bezelStyle = .rounded
        backButton.target = self
        backButton.action = #selector(backButtonTapped)
        backButton.keyEquivalent = ""
        view.addSubview(backButton)
        
        // Next button
        nextButton = NSButton(frame: NSRect(x: 540, y: 20, width: 80, height: 32))
        nextButton.title = "Next"
        nextButton.bezelStyle = .rounded
        nextButton.target = self
        nextButton.action = #selector(nextButtonTapped)
        nextButton.keyEquivalent = "\r" // Enter key
        view.addSubview(nextButton)
        
        // Skip button (top-right)
        skipButton = NSButton(frame: NSRect(x: 560, y: 440, width: 60, height: 24))
        skipButton.title = "Skip"
        skipButton.bezelStyle = .rounded
        skipButton.target = self
        skipButton.action = #selector(skipButtonTapped)
        skipButton.keyEquivalent = ""
        view.addSubview(skipButton)
        
        NSLog("✅ OnboardingViewController: UI setup complete")
    }
    
    private func showPage(_ page: Int) {
        currentPage = page
        NSLog("📄 OnboardingViewController: Showing page \(page)")
        
        // Update content based on page
        switch page {
        case 0:
            titleLabel.stringValue = "Welcome to Floaty Browser"
            subtitleLabel.stringValue = "Keep your favorite websites always accessible in floating bubbles"
            backButton.isHidden = true
            nextButton.title = "Next"
            
        case 1:
            titleLabel.stringValue = "Expand. Browse. Minimize."
            subtitleLabel.stringValue = "Click to expand, browse normally, then collapse back to a bubble"
            backButton.isHidden = false
            nextButton.title = "Next"
            
        case 2:
            titleLabel.stringValue = "Ready to Float?"
            subtitleLabel.stringValue = "Let's create your first bubble"
            backButton.isHidden = false
            nextButton.title = "Launch Your First Bubble"
            
        default:
            break
        }
        
        // Update page dots
        for (index, dotView) in pageDotsStack.arrangedSubviews.enumerated() {
            dotView.layer?.backgroundColor = (index == page) 
                ? NSColor.controlAccentColor.cgColor 
                : NSColor.systemGray.cgColor
        }
    }
    
    @objc private func nextButtonTapped() {
        NSLog("▶️ Next button tapped (page \(currentPage))")
        
        if currentPage < totalPages - 1 {
            // Go to next page
            showPage(currentPage + 1)
        } else {
            // Last page - complete onboarding
            NSLog("🎉 Completing onboarding")
            delegate?.onboardingDidComplete()
        }
    }
    
    @objc private func backButtonTapped() {
        NSLog("◀️ Back button tapped (page \(currentPage))")
        
        if currentPage > 0 {
            showPage(currentPage - 1)
        }
    }
    
    @objc private func skipButtonTapped() {
        NSLog("⏭️ Skip button tapped")
        
        let alert = NSAlert()
        alert.messageText = "Skip Onboarding?"
        alert.informativeText = "You can always learn about Floaty Browser features later."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Skip")
        alert.addButton(withTitle: "Continue")
        
        if let window = view.window {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    NSLog("✅ User confirmed skip")
                    self?.delegate?.onboardingDidSkip()
                }
            }
        }
    }
}

