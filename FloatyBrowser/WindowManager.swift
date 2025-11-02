//
//  WindowManager.swift
//  FloatyBrowser
//
//  Coordinates all bubble and panel windows, handles persistence and global shortcuts.
//

import Cocoa
import Carbon

class WindowManager: NSObject {
    static let shared = WindowManager()
    
    private var bubbles: [UUID: BubbleWindow] = [:]
    private var panels: [UUID: PanelWindow] = [:]
    
    private var isInitialized = false
    
    private override init() {
        super.init()
        NSLog("🔧 FloatyBrowser: WindowManager created (windows will be created after app launch)")
        
        // Observe when app terminates to save state
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    /// Must be called after app finishes launching
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true
        
        NSLog("🔧 FloatyBrowser: WindowManager initializing bubbles")
        NSLog("🔧 FloatyBrowser: About to load saved bubbles")
        loadSavedBubbles()
        NSLog("🔧 FloatyBrowser: WindowManager initialization complete")
    }
    
    // MARK: - Bubble Management
    
    func createBubble(url: String, position: CGPoint? = nil) -> BubbleWindow {
        let id = UUID()
        let bubblePosition = position ?? calculateNewBubblePosition()
        
        let bubble = BubbleWindow(id: id, url: url, position: bubblePosition)
        bubble.bubbleDelegate = self
        
        bubbles[id] = bubble
        
        // Ensure bubble is fully visible and ready for interaction
        // Using orderFrontRegardless ensures it appears even if app isn't active
        bubble.orderFrontRegardless()
        
        // Small delay to ensure window server has processed the window
        // This prevents the first click being lost due to window setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            bubble.orderFront(nil)
        }
        
        print("✅ Created bubble \(id) for \(url)")
        print("   Position: \(bubblePosition)")
        print("   Screen: \(bubble.screen?.localizedName ?? "unknown")")
        print("   Visible: \(bubble.isVisible)")
        
        saveAllBubbles()
        
        return bubble
    }
    
    func expandBubble(_ bubble: BubbleWindow) {
        guard panels[bubble.bubbleId] == nil else {
            // Already expanded
            panels[bubble.bubbleId]?.orderFront(nil)
            return
        }
        
        let panel = PanelWindow(id: bubble.bubbleId, url: bubble.currentURL, nearBubble: bubble.frame)
        panel.panelDelegate = self
        
        panels[bubble.bubbleId] = panel
        
        // Hide bubble while panel is showing
        bubble.orderOut(nil)
        
        panel.makeKeyAndOrderFront(nil)
        panel.animateIn()
        
        print("✅ Expanded bubble \(bubble.bubbleId) to panel")
    }
    
    func collapsePanel(_ panel: PanelWindow) {
        guard let bubble = bubbles[panel.panelId] else { return }
        
        // Update bubble URL with current panel URL
        let currentURL = panel.getCurrentURL()
        if !currentURL.isEmpty {
            bubble.updateURL(currentURL)
        }
        
        panel.animateOut { [weak self] in
            self?.panels.removeValue(forKey: panel.panelId)
            panel.close()
            
            // Show bubble again
            bubble.orderFront(nil)
            
            print("✅ Collapsed panel \(panel.panelId) to bubble")
            self?.saveAllBubbles()
        }
    }
    
    func closeBubble(_ bubble: BubbleWindow) {
        // Close associated panel if open
        if let panel = panels[bubble.bubbleId] {
            panels.removeValue(forKey: bubble.bubbleId)
            panel.close()
        }
        
        bubbles.removeValue(forKey: bubble.bubbleId)
        bubble.close()
        
        print("🗑️ Closed bubble \(bubble.bubbleId)")
        saveAllBubbles()
        
        // If no more bubbles, create a default one
        if bubbles.isEmpty {
            createDefaultBubble()
        }
    }
    
    private func calculateNewBubblePosition() -> CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 100, y: 100)
        }
        
        let visibleFrame = screen.visibleFrame
        let bubbleSize: CGFloat = 60
        let rightMargin: CGFloat = 20
        let verticalSpacing: CGFloat = 80
        
        // Position on the right side of the screen
        let xPosition = visibleFrame.maxX - bubbleSize - rightMargin
        
        // Start from top and stack downwards
        var yPosition = visibleFrame.maxY - 100  // Start below menu bar
        
        // Offset vertically for each existing bubble
        let existingCount = bubbles.count
        yPosition -= verticalSpacing * CGFloat(existingCount)
        
        // Ensure we don't go below the screen
        // If we run out of space, wrap to a second column on the left of the first
        if yPosition < visibleFrame.minY + 20 {
            let column = existingCount / 8  // 8 bubbles per column
            let row = existingCount % 8
            
            yPosition = visibleFrame.maxY - 100 - (verticalSpacing * CGFloat(row))
            let columnOffset = (bubbleSize + 20) * CGFloat(column)
            
            return CGPoint(
                x: visibleFrame.maxX - bubbleSize - rightMargin - columnOffset,
                y: max(yPosition, visibleFrame.minY + 20)
            )
        }
        
        return CGPoint(x: xPosition, y: yPosition)
    }
    
    func createDefaultBubble() {
        NSLog("🫧 FloatyBrowser: Creating default bubble")
        let bubble = createBubble(url: "https://www.google.com")
        NSLog("🫧 FloatyBrowser: Default bubble created - isVisible: \(bubble.isVisible), frame: \(bubble.frame)")
    }
    
    // MARK: - Persistence
    
    private func saveAllBubbles() {
        let states = bubbles.map { (id, bubble) -> BubbleState in
            let screenIndex = NSScreen.screens.firstIndex(where: { $0.frame.contains(bubble.frame.origin) }) ?? 0
            return BubbleState(
                id: id,
                url: bubble.currentURL,
                position: bubble.frame.origin,
                screenIndex: screenIndex
            )
        }
        
        PersistenceManager.shared.saveBubbles(states)
    }
    
    private func loadSavedBubbles() {
        print("📂 Loading saved bubbles...")
        let savedStates = PersistenceManager.shared.loadBubbles()
        
        if savedStates.isEmpty {
            print("ℹ️  No saved bubbles found, creating default...")
            // Create default bubble if no saved state
            createDefaultBubble()
            return
        }
        
        print("ℹ️  Found \(savedStates.count) saved bubble(s)")
        for state in savedStates {
            let validatedPosition = PersistenceManager.shared.validatePosition(state.position, screenIndex: state.screenIndex)
            let bubble = BubbleWindow(id: state.id, url: state.url, position: validatedPosition)
            bubble.bubbleDelegate = self
            bubbles[state.id] = bubble
            bubble.orderFrontRegardless()
            bubble.makeKeyAndOrderFront(nil)
            print("   • Restored bubble at \(validatedPosition)")
            
            // Fetch favicon for restored bubble
            fetchFaviconForBubble(bubble)
        }
        
        print("✅ Restored \(bubbles.count) bubble(s)")
    }
    
    @objc private func applicationWillTerminate() {
        saveAllBubbles()
    }
    
    // MARK: - Favicon Management
    
    private func fetchFaviconForBubble(_ bubble: BubbleWindow) {
        let urlString = bubble.currentURL
        guard let url = URL(string: urlString),
              let host = url.host else { return }
        
        // Use Google's high-quality favicon API (size 128 for Retina displays)
        let faviconURLString = "https://www.google.com/s2/favicons?domain=\(host)&sz=128"
        guard let faviconURL = URL(string: faviconURLString) else { return }
        
        URLSession.shared.dataTask(with: faviconURL) { [weak bubble] data, response, error in
            guard let data = data,
                  let image = NSImage(data: data),
                  error == nil else {
                print("⚠️ Failed to fetch favicon for \(host)")
                return
            }
            
            DispatchQueue.main.async {
                bubble?.updateFavicon(image)
                print("✅ Loaded high-quality favicon for \(host)")
            }
        }.resume()
    }
    
    // MARK: - Panel Management
    
    func toggleAllPanels() {
        if panels.isEmpty {
            // Expand all bubbles
            for bubble in bubbles.values {
                expandBubble(bubble)
            }
        } else {
            // Collapse all panels
            for panel in Array(panels.values) {
                collapsePanel(panel)
            }
        }
    }
    
    func getBubbleCount() -> Int {
        return bubbles.count
    }
    
    func getAllBubbleURLs() -> [String] {
        return bubbles.values.map { $0.currentURL }
    }
    
    func expandBubbleAtIndex(_ index: Int) {
        let bubbleArray = Array(bubbles.values)
        guard index < bubbleArray.count else { return }
        expandBubble(bubbleArray[index])
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - BubbleWindowDelegate

extension WindowManager: BubbleWindowDelegate {
    func bubbleWindowDidRequestExpand(_ bubble: BubbleWindow) {
        expandBubble(bubble)
    }
    
    func bubbleWindowDidRequestClose(_ bubble: BubbleWindow) {
        closeBubble(bubble)
    }
    
    func bubbleWindowDidMove(_ bubble: BubbleWindow) {
        saveAllBubbles()
    }
}

// MARK: - PanelWindowDelegate

extension WindowManager: PanelWindowDelegate {
    func panelWindowDidRequestCollapse(_ panel: PanelWindow) {
        collapsePanel(panel)
    }
    
    func panelWindow(_ panel: PanelWindow, didRequestNewBubble url: String) {
        // Create a new bubble near the current panel
        var newPosition = panel.frame.origin
        newPosition.x += 70
        newPosition.y -= 70
        
        _ = createBubble(url: url, position: newPosition)
    }
    
    func panelWindow(_ panel: PanelWindow, didUpdateURL url: String) {
        // Update bubble's URL when panel navigates
        if let bubble = bubbles[panel.panelId] {
            bubble.updateURL(url)
            saveAllBubbles()
        }
    }
    
    func panelWindow(_ panel: PanelWindow, didUpdateFavicon image: NSImage) {
        // Update bubble's favicon when fetched
        if let bubble = bubbles[panel.panelId] {
            NSLog("🎨 FloatyBrowser: Updating bubble favicon")
            bubble.updateFavicon(image)
        }
    }
}

