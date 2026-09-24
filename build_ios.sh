#!/bin/bash
set -e

echo "==> Building music for iOS / iPadOS..."

SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)

echo "==> Compiling arm64 release binary with SDK: $SDK_PATH"
swift build -c release --sdk "$SDK_PATH" --triple arm64-apple-ios17.0

APP_NAME="music.app"
rm -rf "$APP_NAME" Payload music.ipa
mkdir -p "$APP_NAME"

# Locate compiled binary
BINARY_PATH=""
if [ -f ".build/arm64-apple-ios/release/music" ]; then
    BINARY_PATH=".build/arm64-apple-ios/release/music"
elif [ -f ".build/arm64-apple-ios17.0/release/music" ]; then
    BINARY_PATH=".build/arm64-apple-ios17.0/release/music"
elif [ -f ".build/release/music" ]; then
    BINARY_PATH=".build/release/music"
else
    BINARY_PATH=$(find .build -type f -name "music" -perm -111 -not -path "*/checkouts/*" 2>/dev/null | grep -E "release" | head -n 1)
fi

echo "==> Using compiled binary: $BINARY_PATH"
cp "$BINARY_PATH" "$APP_NAME/music"

# Copy Info.plist
cp music/Resources/iOS-Info.plist "$APP_NAME/Info.plist"

# Compile application icons and assets for iOS
if [ -d "music/Resources/Assets.xcassets" ]; then
    echo "==> Compiling application icons for iOS..."
    actool music/Resources/Assets.xcassets \
      --compile "$APP_NAME" \
      --platform iphoneos \
      --target-device iphone \
      --target-device ipad \
      --minimum-deployment-target 17.0 \
      --app-icon AppIcon \
      --output-partial-info-plist /tmp/assetcatalog_generated_info.plist || true
      
    if [ -f "/tmp/assetcatalog_generated_info.plist" ]; then
        /usr/libexec/PlistBuddy -c "Merge /tmp/assetcatalog_generated_info.plist" "$APP_NAME/Info.plist" 2>/dev/null || true
    fi
    
    # Enforce UIDeviceFamily [1, 2] and fullscreen false for native iPadOS support
    /usr/libexec/PlistBuddy -c "Delete :UIDeviceFamily" "$APP_NAME/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :UIDeviceFamily array" "$APP_NAME/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :UIDeviceFamily:0 integer 1" "$APP_NAME/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :UIDeviceFamily:1 integer 2" "$APP_NAME/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Set :UIRequiresFullScreen false" "$APP_NAME/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :UIRequiresFullScreen bool false" "$APP_NAME/Info.plist" 2>/dev/null || true
    
    # Also copy standard direct icon files into bundle root for maximum compatibility
    ICON_DIR="music/Resources/Assets.xcassets/AppIcon.appiconset"
    if [ -d "$ICON_DIR" ]; then
        cp "$ICON_DIR/app_icon_ios_128.png" "$APP_NAME/AppIcon60x60@2x.png" 2>/dev/null || true
        cp "$ICON_DIR/app_icon_ios_256.png" "$APP_NAME/AppIcon60x60@3x.png" 2>/dev/null || true
        cp "$ICON_DIR/app_icon_ios_256.png" "$APP_NAME/AppIcon76x76@2x~ipad.png" 2>/dev/null || true
        cp "$ICON_DIR/app_icon_ios_1024.png" "$APP_NAME/AppIcon.png" 2>/dev/null || true
    fi
fi

# Code sign with ad-hoc signature
echo "==> Signing application bundle..."
codesign --force --deep --sign - "$APP_NAME"

# Package into IPA
echo "==> Packaging into IPA archive..."
mkdir -p Payload
cp -r "$APP_NAME" Payload/
zip -qr music.ipa Payload
rm -rf Payload

echo "=========================================="
echo "==> Build successful!"
echo "  1. App bundle: $APP_NAME"
echo "  2. IPA archive: music.ipa"
echo "=========================================="
