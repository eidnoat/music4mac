#!/bin/bash
set -e

echo "==> Compiling music Release binary..."
swift build -c release

APP_NAME="music.app"

echo "==> Assembling $APP_NAME..."
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# Copy executable
cp .build/release/music "$APP_NAME/Contents/MacOS/"

# Copy Info.plist
cp music/Resources/Info.plist "$APP_NAME/Contents/"

# Compile app icon assets
if [ -d "music/Resources/Assets.xcassets" ]; then
    echo "==> Compiling application icons..."
    actool music/Resources/Assets.xcassets \
      --compile "$APP_NAME/Contents/Resources" \
      --platform macosx \
      --minimum-deployment-target 15.0 \
      --app-icon AppIcon \
      --output-partial-info-plist /tmp/assetcatalog_generated_info.plist || true
fi

# Code sign
echo "==> Signing application bundle..."
codesign --force --deep --sign - \
  --entitlements music/Resources/music.entitlements \
  "$APP_NAME"

# Prepare distribution directory (retaining root music.app bundle structure for CI artifact zip)
DIST_DIR="dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
ditto "$APP_NAME" "$DIST_DIR/$APP_NAME"

# Generate local zip archive (using ditto to preserve macOS permissions, attributes, and resource forks)
ditto -c -k --sequesterRsrc --keepParent "$APP_NAME" music.zip

echo "=========================================="
echo "==> Build successful!"
echo "  1. App bundle: $APP_NAME"
echo "  2. Output dir: $DIST_DIR/$APP_NAME"
echo "  3. Zip archive: music.zip"
echo "=========================================="
