//
//  PersistenceManager.swift
//  FloatyBrowser
//
//  Manages persistence of bubble positions and URLs across app launches.
//

import Foundation
import Cocoa

struct BubbleState: Codable {
    let id: UUID
    let url: String
    let position: CGPoint
    let screenIndex: Int // Track which screen the bubble is on
    
    enum CodingKeys: String, CodingKey {
        case id, url, position, screenIndex
    }
    
    init(id: UUID, url: String, position: CGPoint, screenIndex: Int = 0) {
        self.id = id
        self.url = url
        self.position = position
        self.screenIndex = screenIndex
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(url, forKey: .url)
        try container.encode(["x": position.x, "y": position.y], forKey: .position)
        try container.encode(screenIndex, forKey: .screenIndex)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(String.self, forKey: .url)
        let posDict = try container.decode([String: CGFloat].self, forKey: .position)
        position = CGPoint(x: posDict["x"] ?? 0, y: posDict["y"] ?? 0)
        screenIndex = try container.decodeIfPresent(Int.self, forKey: .screenIndex) ?? 0
    }
}

class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let stateFileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("FloatyBrowser", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        stateFileURL = appDir.appendingPathComponent("bubbles.json")
        
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    /// Save the current state of all bubbles
    func saveBubbles(_ states: [BubbleState]) {
        do {
            let data = try encoder.encode(states)
            try data.write(to: stateFileURL, options: .atomic)
            print("✅ Saved \(states.count) bubble(s) to \(stateFileURL.path)")
        } catch {
            print("❌ Failed to save bubbles: \(error)")
        }
    }
    
    /// Load saved bubble states
    func loadBubbles() -> [BubbleState] {
        guard FileManager.default.fileExists(atPath: stateFileURL.path) else {
            print("ℹ️ No saved bubbles found")
            return []
        }
        
        do {
            let data = try Data(contentsOf: stateFileURL)
            let states = try decoder.decode([BubbleState].self, from: data)
            print("✅ Loaded \(states.count) bubble(s) from \(stateFileURL.path)")
            return states
        } catch {
            print("❌ Failed to load bubbles: \(error)")
            return []
        }
    }
    
    /// Clear all saved state
    func clearSavedState() {
        try? FileManager.default.removeItem(at: stateFileURL)
        print("🗑️ Cleared saved state")
    }
    
    /// Validate and adjust position to ensure bubble is on screen
    func validatePosition(_ position: CGPoint, screenIndex: Int) -> CGPoint {
        let screens = NSScreen.screens
        guard screenIndex < screens.count else {
            // Screen no longer exists, use main screen
            return validatePosition(position, for: NSScreen.main ?? screens.first!)
        }
        
        return validatePosition(position, for: screens[screenIndex])
    }
    
    private func validatePosition(_ position: CGPoint, for screen: NSScreen) -> CGPoint {
        let bubbleSize: CGFloat = 60
        let frame = screen.visibleFrame
        
        var validatedPosition = position
        
        // Ensure bubble is within screen bounds
        validatedPosition.x = max(frame.minX, min(position.x, frame.maxX - bubbleSize))
        validatedPosition.y = max(frame.minY, min(position.y, frame.maxY - bubbleSize))
        
        return validatedPosition
    }
}

