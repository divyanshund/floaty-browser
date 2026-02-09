//
//  SharedWebConfiguration.swift
//  FloatyBrowser
//
//  Manages shared WebKit resources across all bubbles.
//  Enables session sharing, cookie persistence, and OAuth communication.
//

import Foundation
import WebKit

/// Singleton that provides shared WebKit resources for all browser bubbles.
/// This ensures cookies, sessions, and process pools are shared across all windows,
/// enabling OAuth flows, persistent login, and proper window.opener communication.
final class SharedWebConfiguration {
    
    // MARK: - Singleton
    
    static let shared = SharedWebConfiguration()
    
    private init() {
        print("🔧 SharedWebConfiguration: Initialized shared WebKit resources")
    }
    
    // MARK: - Shared Resources
    
    /// Shared process pool - enables JavaScript execution context sharing.
    /// All bubbles use the same process pool to:
    /// - Share cookies and sessions
    /// - Enable window.opener relationships
    /// - Support OAuth popup communication
    /// - Maintain consistent JavaScript state
    let processPool = WKProcessPool()
    
    /// Shared data store - manages cookies, local storage, and cache.
    /// Using default() ensures persistence across app launches.
    /// All bubbles share:
    /// - Cookies (login sessions)
    /// - Local storage
    /// - IndexedDB
    /// - Service workers
    let dataStore = WKWebsiteDataStore.default()
    
    // MARK: - Configuration Factory
    
    /// Creates a WKWebViewConfiguration with shared resources.
    /// Call this when creating new bubbles to ensure session sharing.
    ///
    /// - Returns: Pre-configured WKWebViewConfiguration with shared pool and data store
    func createConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        
        // Use shared resources
        config.processPool = processPool
        config.websiteDataStore = dataStore
        
        // Security settings
        config.preferences.javaScriptCanOpenWindowsAutomatically = true  // Enable OAuth popups
        config.allowsAirPlayForMediaPlayback = false
        
        // Modern WebKit preferences
        if #available(macOS 11.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            config.preferences.javaScriptEnabled = true
        }
        
        // User agent - identify as modern Safari on macOS
        config.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"
        
        print("🔧 SharedWebConfiguration: Created new configuration with shared resources")
        
        return config
    }
    
    // MARK: - Session Management
    
    /// Clears all cookies and website data (for logout/reset).
    /// Use this when user wants to "clear all data".
    func clearAllData(completion: @escaping () -> Void) {
        print("🗑️ SharedWebConfiguration: Clearing all website data...")
        
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: .distantPast) {
            print("✅ SharedWebConfiguration: All website data cleared")
            completion()
        }
    }
    
    /// Gets current cookie count (for debugging/info).
    func getCookieCount(completion: @escaping (Int) -> Void) {
        dataStore.httpCookieStore.getAllCookies { cookies in
            print("🍪 SharedWebConfiguration: Current cookie count: \(cookies.count)")
            completion(cookies.count)
        }
    }
}

