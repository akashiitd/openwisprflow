#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$PROJECT_DIR/OpenWisprFlow"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="OpenWisprFlow"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

echo "==> Expanding Info.plist variables..."
EXPANDED_PLIST="$BUILD_DIR/Info.plist"
sed -e 's/$(EXECUTABLE_NAME)/OpenWisprFlow/g' \
    -e 's/$(PRODUCT_BUNDLE_IDENTIFIER)/com.akashsoni.OpenWisprFlow/g' \
    -e 's/$(MARKETING_VERSION)/1.0/g' \
    -e 's/$(CURRENT_PROJECT_VERSION)/1/g' \
    -e 's/$(DEVELOPMENT_LANGUAGE)/en/g' \
    -e 's/$(MACOSX_DEPLOYMENT_TARGET)/14.0/g' \
    "$SRC_DIR/Info.plist" > "$EXPANDED_PLIST"

echo "==> Compiling Swift sources (with embedded Info.plist)..."
# Convert plist to binary for __info_plist section embedding
plutil -convert binary1 -o "$BUILD_DIR/Info.plist.bin" "$EXPANDED_PLIST"

swiftc \
  -o "$MACOS_DIR/$APP_NAME" \
  -target arm64-apple-macosx14.0 \
  -sdk "$(xcrun --show-sdk-path)" \
  -framework SwiftUI \
  -framework AppKit \
  -framework Speech \
  -framework AVFoundation \
  -framework Carbon \
  -framework ApplicationServices \
  -parse-as-library \
  -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$EXPANDED_PLIST" \
  "$SRC_DIR/OpenWisprFlowApp.swift" \
  "$SRC_DIR/AppDelegate.swift" \
  "$SRC_DIR/AppState.swift" \
  "$SRC_DIR/ContentView.swift" \
  "$SRC_DIR/SettingsView.swift" \
  "$SRC_DIR/CodingSpeechFormatter.swift" \
  "$SRC_DIR/FillerWordFilter.swift" \
  "$SRC_DIR/SnippetStore.swift" \
  "$SRC_DIR/LLMRewriter.swift" \
  "$SRC_DIR/HotKeyManager.swift" \
  "$SRC_DIR/SpeechDictationService.swift" \
  "$SRC_DIR/TextInjector.swift"

echo "==> Creating app bundle..."
cp "$EXPANDED_PLIST" "$CONTENTS/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS/PkgInfo"

echo "==> Code signing (ad-hoc)..."
codesign --force --sign - \
  --entitlements "$SRC_DIR/OpenWisprFlow.entitlements" \
  "$APP_BUNDLE"

echo "==> Build complete: $APP_BUNDLE"
echo ""
echo "Run with:"
echo "  open $APP_BUNDLE"
