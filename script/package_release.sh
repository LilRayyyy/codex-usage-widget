#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Codex Usage Widget"
SCHEME="CodexUsageWidget"
PROJECT="CodexUsageWidget.xcodeproj"
BUILD_DIR="$(pwd)/release/DerivedData"
OUTPUT_DIR="$(pwd)/release"
APP_BUNDLE="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
ZIP_PATH="$OUTPUT_DIR/CodexUsageWidget-0.1.0-macOS.zip"

mkdir -p "$OUTPUT_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing built app bundle: $APP_BUNDLE" >&2
  exit 2
fi

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
echo "$ZIP_PATH"
