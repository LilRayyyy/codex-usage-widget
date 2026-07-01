#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Codex Usage Widget"
SCHEME="CodexUsageWidget"
PROJECT="CodexUsageWidget.xcodeproj"
BUILD_DIR="$(pwd)/DerivedData"
APP_BUNDLE="$BUILD_DIR/Build/Products/Debug/$APP_NAME.app"
BUNDLE_ID="com.example.CodexUsageWidget"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-NO}"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if [[ ! -d "$PROJECT" ]]; then
  echo "Missing $PROJECT. Complete the Xcode project task before running the app." >&2
  exit 2
fi

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug -derivedDataPath "$BUILD_DIR" CODE_SIGNING_ALLOWED="$CODE_SIGNING_ALLOWED" build

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
