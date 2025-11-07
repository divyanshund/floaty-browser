#!/bin/bash
# 
# Build Floaty Browser for sharing with friends
# 
# This creates an unsigned development build that can be shared directly.
# Your friend will need to right-click > Open the first time to bypass Gatekeeper.
#

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🫧 Building Floaty Browser for sharing...${NC}"
echo ""

# Configuration
PROJECT="FloatyBrowser.xcodeproj"
SCHEME="FloatyBrowser"
BUILD_DIR="build"
APP_NAME="FloatyBrowser.app"
ZIP_NAME="FloatyBrowser.zip"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build for release
echo -e "${YELLOW}🔨 Building app...${NC}"
xcodebuild -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    clean build \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    | grep -E 'BUILD|error|warning' || true

# Find the built app
BUILT_APP="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo -e "${RED}❌ Build failed - app not found at $BUILT_APP${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build successful!${NC}"

# Copy to build directory
echo -e "${YELLOW}📦 Packaging app...${NC}"
cp -R "$BUILT_APP" "$BUILD_DIR/"

# Create ZIP file
echo -e "${YELLOW}🗜️  Creating ZIP file...${NC}"
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME" "$ZIP_NAME"
cd ..

# Get file size
FILE_SIZE=$(du -h "$BUILD_DIR/$ZIP_NAME" | cut -f1)

# Create installation instructions
cat > "$BUILD_DIR/INSTALLATION_INSTRUCTIONS.txt" <<'EOF'
🫧 Floaty Browser Installation Instructions
==========================================

Thank you for trying Floaty Browser! 🎉

📦 INSTALLATION:

1. Unzip the FloatyBrowser.zip file
2. Drag FloatyBrowser.app to your Applications folder
3. Right-click on FloatyBrowser.app and select "Open"
   (You may see a warning since this is an unsigned build)
4. Click "Open" in the security dialog
5. The app will launch with a floating bubble!

🚀 HOW TO USE:

• A bubble will appear on the right side of your screen
• Click the bubble to expand it into a web browser
• Click the "○" button to minimize back to bubble
• Click the "+" button to create a new bubble
• Drag bubbles anywhere on screen
• Right-click a bubble for more options

⚙️ FEATURES:

✓ Floating bubbles stay on top of other apps
✓ Multiple bubbles for different websites
✓ Bubbles remember their positions and URLs
✓ Offline Snake game when no internet
✓ Clean, minimal interface

❓ TROUBLESHOOTING:

Q: "Cannot open app" error?
A: Right-click > Open (don't double-click the first time)

Q: Bubble disappeared?
A: Check the menu bar icon (🫧) to create a new one

Q: Global shortcuts not working?
A: Grant Accessibility permission in System Settings

---

Enjoy floating! 🫧
EOF

# Summary
echo ""
echo -e "${GREEN}✅ ✅ ✅ Build Complete! ✅ ✅ ✅${NC}"
echo ""
echo -e "${BLUE}📂 Files ready to share:${NC}"
echo ""
echo "   📦 $BUILD_DIR/$ZIP_NAME ($FILE_SIZE)"
echo "   📄 $BUILD_DIR/INSTALLATION_INSTRUCTIONS.txt"
echo ""
echo -e "${YELLOW}📤 NEXT STEPS:${NC}"
echo ""
echo "1. Share these files with your friend:"
echo "   • $ZIP_NAME"
echo "   • INSTALLATION_INSTRUCTIONS.txt"
echo ""
echo "2. They can:"
echo "   • Upload to cloud storage (Dropbox, Google Drive, etc.)"
echo "   • Send via email (may be blocked by some providers)"
echo "   • Use a file transfer service (WeTransfer, etc.)"
echo "   • Share via AirDrop"
echo ""
echo -e "${BLUE}💡 TIP:${NC} Your friend will see a security warning the first time."
echo "   Tell them to right-click > Open to bypass Gatekeeper."
echo ""
echo -e "${GREEN}🎉 Happy Floating!${NC}"
echo ""

