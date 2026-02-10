//
//  HistoryWindowController.swift
//  FloatyBrowser
//
//  Window controller for browsing and searching history.
//

import Cocoa

/// Protocol for history item selection
protocol HistoryWindowDelegate: AnyObject {
    func historyWindow(_ controller: HistoryWindowController, didSelectURL url: String)
}

/// Window controller for displaying browsing history
class HistoryWindowController: NSWindowController {
    
    weak var delegate: HistoryWindowDelegate?
    
    private let historyManager = HistoryManager.shared
    
    // UI Elements
    private var searchField: NSSearchField!
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var clearButton: NSButton!
    private var countLabel: NSTextField!
    
    // Data
    private var displayedEntries: [HistoryEntry] = []
    private var groupedEntries: [(date: String, entries: [HistoryEntry])] = []
    private var isGrouped = true
    
    // MARK: - Initialization
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
        window.center()
        window.minSize = NSSize(width: 500, height: 300)
        window.isReleasedWhenClosed = false
        
        self.init(window: window)
        
        setupUI()
        loadHistory()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        // Create visual effect view for modern look
        let visualEffectView = NSVisualEffectView(frame: contentView.bounds)
        visualEffectView.autoresizingMask = [.width, .height]
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .windowBackground
        contentView.addSubview(visualEffectView)
        
        // Top toolbar area
        let toolbarHeight: CGFloat = 44
        let padding: CGFloat = 12
        
        // Search field
        searchField = NSSearchField(frame: NSRect(
            x: padding,
            y: contentView.bounds.height - toolbarHeight - padding + 8,
            width: 250,
            height: 28
        ))
        searchField.autoresizingMask = [.minYMargin]
        searchField.placeholderString = "Search history"
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        searchField.sendsSearchStringImmediately = true
        contentView.addSubview(searchField)
        
        // Count label
        countLabel = NSTextField(labelWithString: "")
        countLabel.frame = NSRect(
            x: padding + 260,
            y: contentView.bounds.height - toolbarHeight - padding + 12,
            width: 200,
            height: 20
        )
        countLabel.autoresizingMask = [.minYMargin, .maxXMargin]
        countLabel.font = NSFont.systemFont(ofSize: 12)
        countLabel.textColor = .secondaryLabelColor
        contentView.addSubview(countLabel)
        
        // Clear button
        clearButton = NSButton(title: "Clear History...", target: self, action: #selector(clearHistoryClicked(_:)))
        clearButton.frame = NSRect(
            x: contentView.bounds.width - 120 - padding,
            y: contentView.bounds.height - toolbarHeight - padding + 6,
            width: 120,
            height: 28
        )
        clearButton.autoresizingMask = [.minXMargin, .minYMargin]
        clearButton.bezelStyle = .rounded
        contentView.addSubview(clearButton)
        
        // Scroll view with table
        scrollView = NSScrollView(frame: NSRect(
            x: 0,
            y: 0,
            width: contentView.bounds.width,
            height: contentView.bounds.height - toolbarHeight - padding
        ))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        
        // Table view
        tableView = NSTableView()
        tableView.style = .inset
        tableView.rowHeight = 48
        tableView.gridStyleMask = []
        tableView.backgroundColor = .clear
        tableView.headerView = nil  // No header
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(tableDoubleClicked(_:))
        tableView.target = self
        
        // Single column for custom cells
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("HistoryColumn"))
        column.width = contentView.bounds.width - 20
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // Enable keyboard navigation
        window?.initialFirstResponder = searchField
    }
    
    // MARK: - Data Loading
    
    private func loadHistory() {
        groupedEntries = historyManager.getEntriesGroupedByDate()
        displayedEntries = historyManager.getAllEntries()
        updateCountLabel()
        tableView.reloadData()
    }
    
    private func updateCountLabel() {
        let count = displayedEntries.count
        if count == 0 {
            countLabel.stringValue = "No history"
        } else if count == 1 {
            countLabel.stringValue = "1 item"
        } else {
            countLabel.stringValue = "\(count) items"
        }
    }
    
    // MARK: - Actions
    
    @objc private func searchChanged(_ sender: NSSearchField) {
        let query = sender.stringValue
        
        if query.isEmpty {
            loadHistory()
        } else {
            displayedEntries = historyManager.search(query: query)
            isGrouped = false
            updateCountLabel()
            tableView.reloadData()
        }
    }
    
    @objc private func tableDoubleClicked(_ sender: Any) {
        let row = tableView.clickedRow
        guard row >= 0, row < displayedEntries.count else { return }
        
        let entry = displayedEntries[row]
        openURL(entry.url)
    }
    
    @objc private func clearHistoryClicked(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Clear History"
        alert.informativeText = "Choose how much history to clear:"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Last Hour")
        alert.addButton(withTitle: "Today")
        alert.addButton(withTitle: "All History")
        
        let response = alert.runModal()
        
        switch response {
        case .alertSecondButtonReturn: // Last Hour
            let oneHourAgo = Date().addingTimeInterval(-3600)
            historyManager.clearHistory(olderThan: oneHourAgo)
        case .alertThirdButtonReturn: // Today
            let calendar = Calendar.current
            if let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: Date()) {
                historyManager.clearHistory(olderThan: startOfDay)
            }
        case NSApplication.ModalResponse(rawValue: NSApplication.ModalResponse.alertThirdButtonReturn.rawValue + 1): // All History
            historyManager.clearAllHistory()
        default:
            return // Cancel
        }
        
        loadHistory()
    }
    
    private func openURL(_ urlString: String) {
        // Notify delegate to open in a bubble
        delegate?.historyWindow(self, didSelectURL: urlString)
        
        // If no delegate, use WindowManager directly
        if delegate == nil {
            _ = WindowManager.shared.createBubble(url: urlString)
        }
        
        // Close history window after selection
        window?.close()
    }
    
    // MARK: - Context Menu
    
    private func showContextMenu(for entry: HistoryEntry, at point: NSPoint) {
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: "Open in New Bubble", action: #selector(contextMenuOpen(_:)), keyEquivalent: "")
        openItem.representedObject = entry
        openItem.target = self
        menu.addItem(openItem)
        
        let copyItem = NSMenuItem(title: "Copy URL", action: #selector(contextMenuCopyURL(_:)), keyEquivalent: "")
        copyItem.representedObject = entry
        copyItem.target = self
        menu.addItem(copyItem)
        
        menu.addItem(.separator())
        
        let deleteItem = NSMenuItem(title: "Delete", action: #selector(contextMenuDelete(_:)), keyEquivalent: "")
        deleteItem.representedObject = entry
        deleteItem.target = self
        menu.addItem(deleteItem)
        
        NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: tableView)
    }
    
    @objc private func contextMenuOpen(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        openURL(entry.url)
    }
    
    @objc private func contextMenuCopyURL(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.url, forType: .string)
    }
    
    @objc private func contextMenuDelete(_ sender: NSMenuItem) {
        guard let entry = sender.representedObject as? HistoryEntry else { return }
        historyManager.deleteEntry(entry)
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    func refresh() {
        loadHistory()
    }
}

// MARK: - NSTableViewDataSource

extension HistoryWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedEntries.count
    }
}

// MARK: - NSTableViewDelegate

extension HistoryWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < displayedEntries.count else { return nil }
        
        let entry = displayedEntries[row]
        
        // Create or reuse cell view
        let identifier = NSUserInterfaceItemIdentifier("HistoryCell")
        var cellView = tableView.makeView(withIdentifier: identifier, owner: nil) as? HistoryCellView
        
        if cellView == nil {
            cellView = HistoryCellView(frame: NSRect(x: 0, y: 0, width: tableView.bounds.width, height: 48))
            cellView?.identifier = identifier
        }
        
        cellView?.configure(with: entry)
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let deleteAction = NSTableViewRowAction(style: .destructive, title: "Delete") { [weak self] _, row in
                guard let self = self, row < self.displayedEntries.count else { return }
                let entry = self.displayedEntries[row]
                self.historyManager.deleteEntry(entry)
                self.loadHistory()
            }
            return [deleteAction]
        }
        return []
    }
}

// MARK: - History Cell View

/// Custom cell view for history entries
class HistoryCellView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let urlLabel = NSTextField(labelWithString: "")
    private let timeLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Icon
        iconView.frame = NSRect(x: 12, y: 10, width: 28, height: 28)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 6
        iconView.layer?.masksToBounds = true
        addSubview(iconView)
        
        // Title
        titleLabel.frame = NSRect(x: 52, y: 24, width: bounds.width - 140, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.autoresizingMask = [.width]
        addSubview(titleLabel)
        
        // URL
        urlLabel.frame = NSRect(x: 52, y: 6, width: bounds.width - 140, height: 16)
        urlLabel.font = NSFont.systemFont(ofSize: 11)
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.autoresizingMask = [.width]
        addSubview(urlLabel)
        
        // Time
        timeLabel.frame = NSRect(x: bounds.width - 80, y: 16, width: 70, height: 16)
        timeLabel.font = NSFont.systemFont(ofSize: 11)
        timeLabel.textColor = .tertiaryLabelColor
        timeLabel.alignment = .right
        timeLabel.autoresizingMask = [.minXMargin]
        addSubview(timeLabel)
    }
    
    func configure(with entry: HistoryEntry) {
        titleLabel.stringValue = entry.title
        urlLabel.stringValue = entry.domain
        timeLabel.stringValue = formatTime(entry.visitDate)
        
        // Set placeholder icon with first letter
        let letter = entry.domain.prefix(1).uppercased()
        iconView.image = createLetterIcon(letter: letter)
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    private func createLetterIcon(letter: String) -> NSImage {
        let size = NSSize(width: 28, height: 28)
        let image = NSImage(size: size)
        
        image.lockFocus()
        
        // Background
        let bgColor = NSColor.systemBlue.withAlphaComponent(0.15)
        bgColor.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 6, yRadius: 6).fill()
        
        // Letter
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.systemBlue
        ]
        let attributedString = NSAttributedString(string: letter, attributes: attributes)
        let stringSize = attributedString.size()
        let stringRect = NSRect(
            x: (size.width - stringSize.width) / 2,
            y: (size.height - stringSize.height) / 2,
            width: stringSize.width,
            height: stringSize.height
        )
        attributedString.draw(in: stringRect)
        
        image.unlockFocus()
        
        return image
    }
}
