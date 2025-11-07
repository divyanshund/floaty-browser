#!/bin/bash

# Script to generate all macOS app icon sizes from a single source image

SOURCE_IMAGE="FloatyBrowser/Assets.xcassets/AppIcon.appiconset/floaty icon.png"
OUTPUT_DIR="FloatyBrowser/Assets.xcassets/AppIcon.appiconset"

echo "🎨 Generating app icons from: $SOURCE_IMAGE"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: Source image not found at $SOURCE_IMAGE"
    exit 1
fi

# Generate all required icon sizes for macOS
sips -z 16 16     "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_16x16.png"
sips -z 32 32     "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_16x16@2x.png"
sips -z 32 32     "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_32x32.png"
sips -z 64 64     "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_32x32@2x.png"
sips -z 128 128   "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_128x128.png"
sips -z 256 256   "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_128x128@2x.png"
sips -z 256 256   "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_256x256.png"
sips -z 512 512   "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_256x256@2x.png"
sips -z 512 512   "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_512x512.png"
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$OUTPUT_DIR/icon_512x512@2x.png"

echo "✅ All icon sizes generated successfully!"
echo ""
echo "Generated files:"
ls -lh "$OUTPUT_DIR"/*.png | awk '{print "  " $9 " (" $5 ")"}'

