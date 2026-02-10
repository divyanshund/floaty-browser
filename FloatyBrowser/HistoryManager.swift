//
//  HistoryManager.swift
//  FloatyBrowser
//
//  Manages browsing history persistence and retrieval.
//

import Foundation

/// Represents a single history entry
struct HistoryEntry: Codable, Identifiable {
    let id: UUID
    let url: String
    let title: String
    let domain: String
    let visitDate: Date
    
    init(url: String, title: String, visitDate: Date = Date()) {
        self.id = UUID()
        self.url = url
        self.title = title.isEmpty ? url : title
        self.domain = HistoryEntry.extractDomain(from: url)
        self.visitDate = visitDate
    }
    
    /// Extract domain from URL for display
    private static func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString),
              let host = url.host else {
            return urlString
        }
        // Remove www. prefix
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }
}

/// Manages browsing history with persistence and auto-cleanup
class HistoryManager {
    static let shared = HistoryManager()
    
    // MARK: - Configuration
    
    /// Maximum number of history entries to keep
    private let maxEntries = 10000
    
    /// Number of days to retain history
    private let retentionDays = 30
    
    // MARK: - Storage
    
    private let historyFileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    /// In-memory cache of history entries (most recent first)
    private var entries: [HistoryEntry] = []
    
    /// Last recorded URL to prevent duplicate consecutive entries
    private var lastRecordedURL: String?
    
    // MARK: - Initialization
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("FloatyBrowser", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        
        historyFileURL = appDir.appendingPathComponent("history.json")
        
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        
        // Load existing history
        loadHistory()
        
        // Perform cleanup on launch
        performCleanup()
    }
    
    // MARK: - Public API
    
    /// Record a new history entry
    /// - Parameters:
    ///   - url: The URL that was visited
    ///   - title: The page title
    func recordVisit(url: String, title: String) {
        // Skip empty URLs
        guard !url.isEmpty else { return }
        
        // Skip internal URLs
        if url.hasPrefix("about:") || url.hasPrefix("data:") || url.hasPrefix("blob:") {
            return
        }
        
        // Skip duplicate consecutive visits (prevents redirect spam)
        if url == lastRecordedURL {
            return
        }
        
        lastRecordedURL = url
        
        let entry = HistoryEntry(url: url, title: title)
        
        // Insert at beginning (most recent first)
        entries.insert(entry, at: 0)
        
        // Trim if exceeding max entries
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        
        // Save asynchronously to avoid blocking UI
        saveHistoryAsync()
        
        print("📜 History: Recorded visit to \(entry.domain)")
    }
    
    /// Get all history entries (most recent first)
    func getAllEntries() -> [HistoryEntry] {
        return entries
    }
    
    /// Get recent history entries for menu display
    /// - Parameter limit: Maximum number of entries to return
    func getRecentEntries(limit: Int = 15) -> [HistoryEntry] {
        return Array(entries.prefix(limit))
    }
    
    /// Search history by title or URL
    /// - Parameter query: Search query
    func search(query: String) -> [HistoryEntry] {
        guard !query.isEmpty else { return entries }
        
        let lowercasedQuery = query.lowercased()
        return entries.filter { entry in
            entry.title.lowercased().contains(lowercasedQuery) ||
            entry.url.lowercased().contains(lowercasedQuery) ||
            entry.domain.lowercased().contains(lowercasedQuery)
        }
    }
    
    /// Get history entries grouped by date
    func getEntriesGroupedByDate() -> [(date: String, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [String: [HistoryEntry]] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        
        for entry in entries {
            let key: String
            
            if calendar.isDateInToday(entry.visitDate) {
                key = "Today"
            } else if calendar.isDateInYesterday(entry.visitDate) {
                key = "Yesterday"
            } else if let daysAgo = calendar.dateComponents([.day], from: entry.visitDate, to: now).day, daysAgo < 7 {
                // Within last week - show day name
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "EEEE" // Full day name
                key = dayFormatter.string(from: entry.visitDate)
            } else {
                // Older - show full date
                key = dateFormatter.string(from: entry.visitDate)
            }
            
            if groups[key] == nil {
                groups[key] = []
            }
            groups[key]?.append(entry)
        }
        
        // Sort groups by most recent entry in each group
        let sortedGroups = groups.map { (date: $0.key, entries: $0.value) }
            .sorted { group1, group2 in
                guard let date1 = group1.entries.first?.visitDate,
                      let date2 = group2.entries.first?.visitDate else {
                    return false
                }
                return date1 > date2
            }
        
        return sortedGroups
    }
    
    /// Clear all history
    func clearAllHistory() {
        entries.removeAll()
        lastRecordedURL = nil
        saveHistory()
        print("🗑️ History: Cleared all entries")
    }
    
    /// Clear history older than specified date
    func clearHistory(olderThan date: Date) {
        let countBefore = entries.count
        entries.removeAll { $0.visitDate < date }
        let removed = countBefore - entries.count
        if removed > 0 {
            saveHistory()
            print("🗑️ History: Removed \(removed) entries older than \(date)")
        }
    }
    
    /// Delete a specific history entry
    func deleteEntry(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        saveHistoryAsync()
    }
    
    /// Get total number of history entries
    var count: Int {
        return entries.count
    }
    
    // MARK: - Private Methods
    
    /// Load history from disk
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: historyFileURL.path) else {
            print("ℹ️ History: No existing history file")
            return
        }
        
        do {
            let data = try Data(contentsOf: historyFileURL)
            entries = try decoder.decode([HistoryEntry].self, from: data)
            print("✅ History: Loaded \(entries.count) entries")
        } catch {
            print("❌ History: Failed to load - \(error.localizedDescription)")
            // Don't crash, just start with empty history
            entries = []
        }
    }
    
    /// Save history to disk
    private func saveHistory() {
        do {
            let data = try encoder.encode(entries)
            try data.write(to: historyFileURL, options: .atomic)
            print("✅ History: Saved \(entries.count) entries")
        } catch {
            print("❌ History: Failed to save - \(error.localizedDescription)")
        }
    }
    
    /// Save history asynchronously
    private func saveHistoryAsync() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.saveHistory()
        }
    }
    
    /// Perform cleanup of old entries
    private func performCleanup() {
        let calendar = Calendar.current
        guard let cutoffDate = calendar.date(byAdding: .day, value: -retentionDays, to: Date()) else {
            return
        }
        
        let countBefore = entries.count
        entries.removeAll { $0.visitDate < cutoffDate }
        let removed = countBefore - entries.count
        
        if removed > 0 {
            saveHistory()
            print("🧹 History: Cleaned up \(removed) entries older than \(retentionDays) days")
        }
    }
}
