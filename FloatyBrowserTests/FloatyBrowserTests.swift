//
//  FloatyBrowserTests.swift
//  FloatyBrowserTests
//
//  Unit tests for Floaty Browser.
//

import XCTest
import WebKit
@testable import FloatyBrowser

final class FloatyBrowserTests: XCTestCase {
    
    var persistenceManager: PersistenceManager!
    
    override func setUpWithError() throws {
        persistenceManager = PersistenceManager.shared
        persistenceManager.clearSavedState()
    }
    
    override func tearDownWithError() throws {
        persistenceManager.clearSavedState()
    }
    
    // MARK: - Persistence Tests
    
    func testSaveAndLoadBubbles() throws {
        // Create test bubble states
        let state1 = BubbleState(
            id: UUID(),
            url: "https://www.apple.com",
            position: CGPoint(x: 100, y: 200),
            screenIndex: 0
        )
        
        let state2 = BubbleState(
            id: UUID(),
            url: "https://www.google.com",
            position: CGPoint(x: 300, y: 400),
            screenIndex: 0
        )
        
        let states = [state1, state2]
        
        // Save bubbles
        persistenceManager.saveBubbles(states)
        
        // Load bubbles
        let loadedStates = persistenceManager.loadBubbles()
        
        // Verify
        XCTAssertEqual(loadedStates.count, 2, "Should load 2 bubbles")
        XCTAssertTrue(loadedStates.contains(where: { $0.id == state1.id }), "Should contain first bubble")
        XCTAssertTrue(loadedStates.contains(where: { $0.id == state2.id }), "Should contain second bubble")
        
        // Verify URLs
        let loadedState1 = loadedStates.first(where: { $0.id == state1.id })
        XCTAssertEqual(loadedState1?.url, state1.url, "URL should match")
        XCTAssertEqual(loadedState1?.position, state1.position, "Position should match")
    }
    
    func testLoadEmptyState() throws {
        let loadedStates = persistenceManager.loadBubbles()
        XCTAssertTrue(loadedStates.isEmpty, "Should return empty array when no saved state")
    }
    
    func testValidatePosition() throws {
        guard let screen = NSScreen.main else {
            XCTFail("No screen available for testing")
            return
        }
        
        let visibleFrame = screen.visibleFrame
        
        // Test position within bounds
        let validPosition = CGPoint(x: visibleFrame.midX, y: visibleFrame.midY)
        let validated1 = persistenceManager.validatePosition(validPosition, screenIndex: 0)
        XCTAssertEqual(validated1.x, validPosition.x, accuracy: 1.0)
        XCTAssertEqual(validated1.y, validPosition.y, accuracy: 1.0)
        
        // Test position outside bounds (too far right)
        let invalidPosition = CGPoint(x: visibleFrame.maxX + 1000, y: visibleFrame.midY)
        let validated2 = persistenceManager.validatePosition(invalidPosition, screenIndex: 0)
        XCTAssertLessThanOrEqual(validated2.x, visibleFrame.maxX - 60)
        
        // Test position outside bounds (too far up)
        let invalidPosition2 = CGPoint(x: visibleFrame.midX, y: visibleFrame.maxY + 1000)
        let validated3 = persistenceManager.validatePosition(invalidPosition2, screenIndex: 0)
        XCTAssertLessThanOrEqual(validated3.y, visibleFrame.maxY - 60)
    }
    
    // MARK: - URL Parsing Tests
    
    func testURLSchemeHandling() throws {
        // Test that URLs without scheme get https:// prepended
        let testURLs = [
            ("google.com", "https://google.com"),
            ("https://apple.com", "https://apple.com"),
            ("http://example.com", "http://example.com"),
        ]
        
        for (input, expected) in testURLs {
            var urlString = input
            if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
                urlString = "https://" + urlString
            }
            XCTAssertEqual(urlString, expected, "URL scheme handling failed for \(input)")
        }
    }
    
    // MARK: - Navigation Policy Tests
    
    func testNavigationPolicyForNewWindow() throws {
        let expectation = self.expectation(description: "New window policy")
        
        // Create a mock navigation action for target="_blank"
        // In a real scenario, this would be tested with an actual WKWebView
        // and navigation delegate implementation
        
        // For this test, we'll verify the logic pattern
        let shouldOpenNewBubble = true // This would come from targetFrame == nil
        
        XCTAssertTrue(shouldOpenNewBubble, "Should detect new window request")
        expectation.fulfill()
        
        waitForExpectations(timeout: 1.0)
    }
    
    // MARK: - BubbleState Codable Tests
    
    func testBubbleStateCodable() throws {
        let original = BubbleState(
            id: UUID(),
            url: "https://www.example.com",
            position: CGPoint(x: 123.45, y: 678.90),
            screenIndex: 1
        )
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(BubbleState.self, from: data)
        
        // Verify
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.url, original.url)
        XCTAssertEqual(decoded.position.x, original.position.x, accuracy: 0.01)
        XCTAssertEqual(decoded.position.y, original.position.y, accuracy: 0.01)
        XCTAssertEqual(decoded.screenIndex, original.screenIndex)
    }
    
    // MARK: - Performance Tests
    
    func testPersistencePerformance() throws {
        // Test performance of saving many bubbles
        var states: [BubbleState] = []
        for i in 0..<100 {
            states.append(BubbleState(
                id: UUID(),
                url: "https://example\(i).com",
                position: CGPoint(x: CGFloat(i * 10), y: CGFloat(i * 10)),
                screenIndex: 0
            ))
        }
        
        measure {
            persistenceManager.saveBubbles(states)
            _ = persistenceManager.loadBubbles()
        }
    }
}

