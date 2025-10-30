# Floaty Browser

A production-quality macOS app that implements a floating, bubble-based mini-browser. Browse the web in always-on-top bubbles that stay visible while you work in other apps.

![macOS](https://img.shields.io/badge/macOS-11.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.0+-orange)
![AppKit](https://img.shields.io/badge/Framework-AppKit-green)

## Features

- 🫧 **Floating Bubbles**: Circular, draggable bubbles that float above all other windows
- 🌐 **Web Panels**: Click a bubble to expand into a full web browser panel
- ➕ **Multi-bubble Support**: Create multiple bubbles, each with its own URL
- 🔗 **Smart Link Handling**: Links that open in new tabs automatically create new bubbles
- 💾 **Persistent State**: Bubble positions and URLs are saved between app launches
- 🖥️ **Multi-monitor Support**: Bubbles stay on the monitor where you place them
- ⌨️ **Global Shortcuts**: Use ⌃⌥Space to toggle all panels at once
- 🎨 **Smooth Animations**: Polished transitions between bubble and panel states
- 📌 **Edge Snapping**: Bubbles snap to screen edges for convenient placement

## Architecture

### Core Components

#### 1. **WindowManager** (`WindowManager.swift`)
The central coordinator that manages all bubbles and panels:
- Creates and destroys bubble/panel windows
- Handles expand/collapse transitions
- Manages persistence through PersistenceManager
- Implements global keyboard shortcuts
- Coordinates multi-window interactions

#### 2. **BubbleWindow** (`BubbleWindow.swift`)
Circular, floating window representing a collapsed browser:
- Borderless NSPanel with `.floating` window level
- Circular shape using layer masking
- Drag-and-drop support with edge snapping
- Gentle idle animation when not interacting
- Hover effects and context menu (right-click)
- Domain-based icon display

#### 3. **PanelWindow** (`PanelWindow.swift`)
Full browser panel that hosts the web view:
- Floating NSPanel with custom titlebar
- Resizable with rounded corners
- Smooth scale/fade animations for expand/collapse
- Custom close button to return to bubble state
- Positioned intelligently near its bubble

#### 4. **WebViewController** (`WebViewController.swift`)
Manages the WKWebView and browser UI:
- Custom toolbar with back/forward/reload buttons
- URL field with auto-completion
- Progress indicator for page loads
- Intercepts new window requests (target="_blank", window.open)
- Navigation policy handling to create new bubbles
- JavaScript alert/confirm dialog support

#### 5. **PersistenceManager** (`PersistenceManager.swift`)
Handles state persistence across app launches:
- Saves bubble URLs, positions, and screen assignments
- JSON-based storage in Application Support directory
- Position validation to ensure bubbles remain on-screen
- Handles screen configuration changes gracefully

### Window Hierarchy

```
NSApplication
├── Menu Bar (Status Item)
└── WindowManager
    ├── BubbleWindow (UUID: xxx)
    │   └── BubbleView (circular, draggable)
    ├── BubbleWindow (UUID: yyy)
    │   └── BubbleView
    └── PanelWindow (UUID: xxx, when expanded)
        └── WebViewController
            └── WKWebView
```

## Technical Details

### Window Levels & Behavior

**Bubbles:**
- `level = .floating` - Stays above normal windows
- `styleMask = [.borderless, .nonactivatingPanel]` - No chrome, doesn't steal focus on click
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`
- `hidesOnDeactivate = false` - Remains visible when switching apps

**Panels:**
- `level = .floating` - Same level as bubbles
- `styleMask = [.titled, .closable, .resizable, .fullSizeContentView]`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- `hidesOnDeactivate = false` - Persists across app switches

### WebKit Configuration

WKWebView instances are configured with:
- Separate process pool for isolation
- JavaScript enabled but with controlled window opening
- Sandboxed content processes
- No arbitrary file access
- Navigation delegate for policy interception
- UI delegate for new window handling

### New Tab Interception

The app intercepts new tab/window requests through two mechanisms:

1. **Navigation Delegate** (`webView(_:decidePolicyFor:decisionHandler:)`)
   - Checks if `navigationAction.targetFrame == nil`
   - This catches target="_blank" links
   - Cancels the navigation and creates a new bubble instead

2. **UI Delegate** (`webView(_:createWebViewWith:for:windowFeatures:)`)
   - Handles `window.open()` JavaScript calls
   - Returns `nil` after creating a new bubble
   - Prevents the default popup behavior

### Multi-monitor Support

- Each `BubbleState` stores a `screenIndex` identifying which display it's on
- On load, validates that the screen still exists (handles unplugged monitors)
- If screen is missing, falls back to main screen
- Position validation ensures bubbles remain within visible frame bounds

### Performance Optimizations

- **Lazy WKWebView Creation**: Web views are created only when panels are expanded
- **Suspension on Collapse**: Background JavaScript execution is paused when collapsed
- **Resource Cleanup**: WKWebView instances are destroyed when panels close
- **Efficient Persistence**: State saves are debounced and only occur on meaningful changes

## macOS Focus Model Limitations

Due to macOS window management constraints:

1. **Floating Windows & Full-Screen Apps**: 
   - Floaty Browser windows appear over Mission Control and Spaces
   - May be occluded by exclusive full-screen apps (games, video players)
   - Use `.fullScreenAuxiliary` to remain visible over most full-screen content

2. **Focus Stealing Prevention**:
   - Bubbles use `.nonactivatingPanel` to avoid stealing focus
   - Clicking a bubble to expand doesn't interrupt your current app
   - Clicking inside a panel activates it for keyboard input

3. **Global Shortcuts**:
   - Require Accessibility permission to work system-wide
   - App gracefully degrades if permission is denied
   - Menu bar provides alternative access

## Building & Distribution

### Requirements

- Xcode 15.0+
- macOS 11.0+ deployment target
- Swift 5.0+

### Building for Development

```bash
# Open the project
open FloatyBrowser.xcodeproj

# Or build from command line
xcodebuild -project FloatyBrowser.xcodeproj \
           -scheme FloatyBrowser \
           -configuration Debug \
           build
```

### Distribution Options

#### Option 1: Direct Distribution (Recommended)

For distribution outside the Mac App Store:

1. **Enable Hardened Runtime**:
   - Already configured in project settings
   - Required for notarization

2. **Code Signing**:
   ```bash
   # Sign the app with your Developer ID certificate
   codesign --deep --force --verify --verbose \
            --sign "Developer ID Application: Your Name (TEAM_ID)" \
            --options runtime \
            FloatyBrowser.app
   ```

3. **Notarization** (requires Apple Developer account):
   ```bash
   # Create a ZIP archive
   ditto -c -k --keepParent FloatyBrowser.app FloatyBrowser.zip
   
   # Submit for notarization
   xcrun notarytool submit FloatyBrowser.zip \
                    --apple-id "your@email.com" \
                    --team-id "TEAM_ID" \
                    --password "app-specific-password" \
                    --wait
   
   # Staple the notarization ticket
   xcrun stapler staple FloatyBrowser.app
   ```

4. **Distribution**:
   - Create a DMG or ZIP for distribution
   - Users can drag to Applications folder
   - No Gatekeeper warnings after notarization

#### Option 2: Mac App Store

To submit to the Mac App Store:

1. **Update Entitlements**:
   - Change `com.apple.security.app-sandbox` to `true` in entitlements
   - This may restrict some functionality (global shortcuts might need workarounds)

2. **App Sandbox Considerations**:
   - Network access is already declared
   - Remove global event tap if sandboxed
   - Use alternative methods for shortcuts (NSMenu, Dock menu)

3. **Submission**:
   - Use Xcode's Archive & Upload workflow
   - Follow App Store Review Guidelines
   - Declare use of WKWebView in review notes

### Automated Build Script

Create a `build_release.sh` script:

```bash
#!/bin/bash
set -e

SCHEME="FloatyBrowser"
CONFIGURATION="Release"
ARCHIVE_PATH="build/FloatyBrowser.xcarchive"
EXPORT_PATH="build/export"

# Clean
xcodebuild clean -project FloatyBrowser.xcodeproj -scheme "$SCHEME"

# Archive
xcodebuild archive \
    -project FloatyBrowser.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH"

# Export
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist ExportOptions.plist

echo "✅ Build complete: $EXPORT_PATH/FloatyBrowser.app"
```

## Usage

### Getting Started

1. **Launch the App**: Open FloatyBrowser from Applications
2. **First Bubble**: A default bubble appears with Google
3. **Interact with Bubbles**:
   - Click to expand into a browser panel
   - Drag to reposition (snaps to edges)
   - Right-click for context menu

### Creating New Bubbles

- **From Panel**: Click the "+" button in the toolbar
- **From Links**: Click links with target="_blank"
- **From Menu**: Select "New Bubble" from menu bar icon

### Keyboard Shortcuts

- **⌃⌥Space**: Toggle all panels (requires Accessibility permission)
- **⌘W**: Close current panel (returns to bubble)
- **⌘N**: Create new bubble (when menu bar is focused)

### Persistence

- Bubble positions and URLs are automatically saved
- Restored on app relaunch
- Survives system reboots
- Stored in `~/Library/Application Support/FloatyBrowser/bubbles.json`

## Testing

Run unit tests:

```bash
xcodebuild test \
    -project FloatyBrowser.xcodeproj \
    -scheme FloatyBrowser \
    -destination 'platform=macOS'
```

Or use Xcode: `⌘U`

Tests cover:
- Persistence (save/load bubble state)
- Position validation
- URL encoding/decoding
- Navigation policy interception
- Performance benchmarks

## Privacy & Security

- **No Analytics**: No user tracking or data collection
- **Sandboxed WebKit**: WKWebView runs in isolated process
- **Network Only**: Only network access permission required
- **Local Storage**: Bubble state stored locally only
- **No Telemetry**: No data sent to external servers

## Limitations

1. **Resource Usage**: Each panel creates a WKWebView process (memory intensive)
2. **Concurrent Panels**: Recommend limiting to 5-10 open panels
3. **Exclusive Full-Screen**: May be hidden by some full-screen games
4. **Global Shortcuts**: Require Accessibility permission
5. **No Extensions**: WKWebView doesn't support Safari extensions

## Troubleshooting

### Bubbles Not Appearing on Launch
- Check `~/Library/Application Support/FloatyBrowser/bubbles.json`
- Delete the file to reset state
- App will create a default bubble

### Global Shortcuts Not Working
- Open System Settings > Privacy & Security > Accessibility
- Add FloatyBrowser to the allowed apps list
- Restart the app

### High Memory Usage
- Each open panel uses 100-200MB of RAM
- Close unused panels to free memory
- Consider limiting concurrent panels

### Bubbles Reset Position
- Occurs when monitor configuration changes
- Bubbles reposition to main screen if assigned screen is disconnected
- Manually reposition and app will remember new locations

## Contributing

This is a production-ready reference implementation. Potential enhancements:

- [ ] Actual favicon fetching instead of domain-based icons
- [ ] Tab groups (multiple URLs per bubble)
- [ ] Customizable bubble colors
- [ ] Picture-in-Picture mode for videos
- [ ] Ad blocking via WKContentRuleList
- [ ] Export/import bubble configurations
- [ ] Keyboard navigation between bubbles

## License

Copyright © 2025. All rights reserved.

This code is provided as-is for educational and commercial use.

---

**Built with ❤️ using Swift and AppKit**

