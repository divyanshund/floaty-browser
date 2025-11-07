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
        // Check if panel already exists (was just hidden, not destroyed)
        if let existingPanel = panels[bubble.bubbleId] {
            NSLog("♻️ Panel already exists - reusing it (website never stopped!)")
            
            // Hide bubble first
            bubble.orderOut(nil)
            
            // Restore the panel to its saved size and show it
            existingPanel.restoreAndShow()
            return
        }
        
        NSLog("🆕 Creating new panel for bubble")
        let panel = PanelWindow(id: bubble.bubbleId, url: bubble.currentURL, nearBubble: bubble.frame)
        panel.panelDelegate = self
        
        panels[bubble.bubbleId] = panel
        
        // Hide bubble while panel is showing
        bubble.orderOut(nil)
        
        panel.makeKeyAndOrderFront(nil)
        panel.animateIn()  // Only animate for new panels
        
        print("✅ Expanded bubble to new panel")
    }
    
    func collapsePanel(_ panel: PanelWindow) {
        NSLog("🟢 collapsePanel() called - MINIMIZE to bubble (keep website running)")
        NSLog("🟢 Panel ID: %@", panel.panelId.uuidString)
        
        guard let bubble = bubbles[panel.panelId] else {
            NSLog("❌ ERROR: No bubble found for panel")
            return
        }
        
        NSLog("🟢 Found bubble, updating URL and collapsing")
        
        // Update bubble URL with current panel URL
        let currentURL = panel.getCurrentURL()
        if !currentURL.isEmpty {
            bubble.updateURL(currentURL)
        }
        
        // CRITICAL: Save the panel's current frame BEFORE animating out
        panel.saveFrameBeforeHiding()
        
        panel.animateOut { [weak self] in
            // DON'T remove panel from dictionary - keep it alive!
            // DON'T close panel - just hide it!
            // This keeps WKWebView running in background
            
            NSLog("🟢 Hiding panel (keeping website alive in background)")
            panel.orderOut(nil)  // Hide the window
            
            NSLog("🟢 Making bubble visible again")
            // Show bubble again
            bubble.alphaValue = 1.0
            bubble.orderFront(nil)
            
            NSLog("✅ Panel hidden, bubble visible, website still running!")
            self?.saveAllBubbles()
        }
    }
    
    func closeBubble(_ bubble: BubbleWindow) {
        let bubbleId = bubble.bubbleId
        NSLog("🗑️ closeBubble called for ID: %@", bubbleId.uuidString)
        
        // Close associated panel if open
        if let panel = panels[bubbleId] {
            NSLog("🗑️ Closing associated panel")
            panels.removeValue(forKey: bubbleId)
            panel.close()
        } else {
            NSLog("🗑️ No associated panel found")
        }
        
        NSLog("🗑️ Removing bubble from dictionary")
        bubbles.removeValue(forKey: bubbleId)
        
        NSLog("🗑️ Ordering bubble out and closing window")
        bubble.orderOut(nil)  // Remove from window list first
        bubble.close()         // Then close
        
        NSLog("🗑️ Saving %d bubble(s) to persistence", bubbles.count)
        saveAllBubbles()
        
        NSLog("✅ Bubble closed successfully. Remaining bubbles: %d", bubbles.count)
        
        // Don't auto-create default bubble when user explicitly closes one
        // Default bubble is only created on app launch if no saved bubbles exist
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
            // Always position bubbles on the right side, ignoring saved positions
            let validatedPosition = calculateNewBubblePosition()
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
    
    func panelWindowDidRequestClose(_ panel: PanelWindow) {
        // Red close button = completely delete bubble and panel
        NSLog("🔴 FloatyBrowser: Closing panel and bubble completely - ID: %@", panel.panelId.uuidString)
        NSLog("🔴 Before close - Bubbles count: %d, Panels count: %d", bubbles.count, panels.count)
        
        let bubbleId = panel.panelId
        
        // Remove panel from dictionary and close it
        panels.removeValue(forKey: bubbleId)
        panel.close()
        NSLog("🔴 Panel closed and removed from dictionary")
        
        // Find and completely close the associated bubble
        if let bubble = bubbles[bubbleId] {
            NSLog("🔴 Found bubble, calling closeBubble()")
            closeBubble(bubble)  // This removes from dictionary and persistence
            NSLog("🔴 closeBubble() completed")
        } else {
            NSLog("❌ ERROR: No bubble found with ID: %@", bubbleId.uuidString)
        }
        
        NSLog("✅ After close - Bubbles count: %d, Panels count: %d", bubbles.count, panels.count)
    }
    
    func panelWindow(_ panel: PanelWindow, didRequestNewBubble url: String) {
        // Create a new bubble on the rightmost side of the screen
        _ = createBubble(url: url)
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

