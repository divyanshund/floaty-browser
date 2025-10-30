#!/bin/bash
# 
# Build and notarize script for Floaty Browser
# 
# Usage: ./build_release.sh
# 
# Requirements:
# - Xcode command line tools
# - Developer ID certificate installed
# - App-specific password for notarization stored in keychain
#

set -e

# Configuration
SCHEME="FloatyBrowser"
CONFIGURATION="Release"
PROJECT="FloatyBrowser.xcodeproj"
ARCHIVE_PATH="build/FloatyBrowser.xcarchive"
EXPORT_PATH="build/export"
APP_NAME="FloatyBrowser"
DMG_NAME="FloatyBrowser-v1.0.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Building Floaty Browser for Release${NC}"
echo ""

# Create build directory
mkdir -p build

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
xcodebuild clean -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" > /dev/null 2>&1

# Archive
echo -e "${YELLOW}📦 Creating archive...${NC}"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Automatic \
    | grep -E '(error|warning|BUILD|ARCHIVE)' || true

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}❌ Archive failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Archive created${NC}"

# Export
echo -e "${YELLOW}📤 Exporting application...${NC}"

# Create export options plist
cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist build/ExportOptions.plist \
    2>&1 | grep -E '(error|warning|EXPORT)' || true

if [ ! -d "$EXPORT_PATH/$APP_NAME.app" ]; then
    echo -e "${RED}❌ Export failed${NC}"
    echo -e "${YELLOW}ℹ️  For development builds, you can skip signing:${NC}"
    echo -e "   Just use the app from: build/FloatyBrowser.xcarchive/Products/Applications/"
    
    # Copy unsigned app
    mkdir -p "$EXPORT_PATH"
    cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$EXPORT_PATH/"
    echo -e "${GREEN}✅ Unsigned app copied to: $EXPORT_PATH/$APP_NAME.app${NC}"
fi

echo -e "${GREEN}✅ Application exported${NC}"

# Verify code signature
echo -e "${YELLOW}🔍 Verifying code signature...${NC}"
codesign --verify --verbose "$EXPORT_PATH/$APP_NAME.app" 2>&1 || {
    echo -e "${YELLOW}⚠️  App is not signed (development build)${NC}"
}

# Create DMG (optional)
echo -e "${YELLOW}💿 Creating DMG...${NC}"

if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$APP_NAME.app" 175 190 \
        --hide-extension "$APP_NAME.app" \
        --app-drop-link 425 190 \
        "build/$DMG_NAME" \
        "$EXPORT_PATH/$APP_NAME.app" || {
            echo -e "${YELLOW}⚠️  Could not create DMG${NC}"
        }
else
    # Fallback: simple DMG creation
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$EXPORT_PATH/$APP_NAME.app" \
        -ov -format UDZO \
        "build/$DMG_NAME" || {
            echo -e "${YELLOW}⚠️  Could not create DMG${NC}"
        }
fi

# Summary
echo ""
echo -e "${GREEN}✅ Build Complete!${NC}"
echo ""
echo "📂 Artifacts:"
echo "   App:     $EXPORT_PATH/$APP_NAME.app"
if [ -f "build/$DMG_NAME" ]; then
    echo "   DMG:     build/$DMG_NAME"
fi
echo ""

# Notarization instructions (if signed)
if codesign --verify "$EXPORT_PATH/$APP_NAME.app" 2>/dev/null; then
    echo -e "${YELLOW}📝 To notarize (requires Apple Developer account):${NC}"
    echo ""
    echo "  # 1. Create ZIP"
    echo "  ditto -c -k --keepParent '$EXPORT_PATH/$APP_NAME.app' build/$APP_NAME.zip"
    echo ""
    echo "  # 2. Submit for notarization"
    echo "  xcrun notarytool submit build/$APP_NAME.zip \\"
    echo "    --apple-id 'your@email.com' \\"
    echo "    --team-id 'TEAM_ID' \\"
    echo "    --password 'app-specific-password' \\"
    echo "    --wait"
    echo ""
    echo "  # 3. Staple the ticket"
    echo "  xcrun stapler staple '$EXPORT_PATH/$APP_NAME.app'"
    echo ""
else
    echo -e "${YELLOW}ℹ️  For development/testing:${NC}"
    echo "  Open '$EXPORT_PATH/$APP_NAME.app' directly"
    echo ""
fi

echo -e "${GREEN}🎉 Done!${NC}"

