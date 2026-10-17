#!/usr/bin/env bash
# Build the app and widget without a signing identity.
#
# A recognized signing, provisioning, or App Group failure is reported and
# skipped. Any other xcodebuild failure, including Swift compile and link
# errors, fails this script.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="$ROOT/DerivedData/Unsigned"
LOG_DIR="$(mktemp -d)"
EMPTY_ENTITLEMENTS="$LOG_DIR/empty.entitlements"

cat >"$EMPTY_ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild is not available. Run this on a Mac with full Xcode." >&2
  exit 1
fi

write_summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$1" >>"$GITHUB_STEP_SUMMARY"
  fi
}

has_compile_or_link_error() {
  grep -E -q '\.swift:[0-9]+:[0-9]+: error:|linker command failed|Undefined symbol|no such module|unable to resolve module|Build input file cannot be found' "$1"
}

has_signing_error() {
  grep -E -q -i 'requires a development team|entitlements that require signing|code signing is required|provisioning profile|embedded binary is not signed|no signing certificate|no profiles for|CodeSign error|codesign failed' "$1"
}

# Writes the xcodebuild status to "$LOG_DIR/last-status".
# The caller reads that file. The build log stays on the console via tee
# and is not captured by command substitution.
run_build() {
  local log="$1"
  shift
  local status=0
  set +e
  set +o pipefail
  xcodebuild \
    -project "$ROOT/CodexUsageWidget.xcodeproj" \
    -scheme CodexUsageWidget \
    -configuration Debug \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    DEVELOPMENT_TEAM="" \
    "$@" \
    build 2>&1 | tee "$log"
  status=${PIPESTATUS[0]}
  set -o pipefail
  set -e
  printf '%s\n' "$status" >"$LOG_DIR/last-status"
}

classify_failure() {
  local log="$1"
  local status="$2"
  if has_compile_or_link_error "$log"; then
    echo "Unsigned build hit a Swift compile or link error." >&2
    exit "$status"
  fi
  if has_signing_error "$log"; then
    return 0
  fi
  echo "Unsigned build failed for a reason other than signing or App Group provisioning." >&2
  exit "$status"
}

run_build "$LOG_DIR/with-entitlements.log"
first_status="$(cat "$LOG_DIR/last-status")"
if [[ "$first_status" -eq 0 ]]; then
  message="Unsigned xcodebuild succeeded with the checked-in App Group entitlements. This does not install the widget or read an App Group container."
  echo "$message"
  write_summary "$message"
  exit 0
fi

classify_failure "$LOG_DIR/with-entitlements.log" "$first_status"
echo "Checked-in entitlements require signing or App Group provisioning. Retrying without entitlements so the sources still have to compile and link."

run_build "$LOG_DIR/without-entitlements.log" CODE_SIGN_ENTITLEMENTS="$EMPTY_ENTITLEMENTS" CODE_SIGN_STYLE=Manual
second_status="$(cat "$LOG_DIR/last-status")"
if [[ "$second_status" -eq 0 ]]; then
  message="The entitled unsigned build stopped on signing or App Group provisioning. A second build without those entitlements compiled and linked the app and widget. That does not install the widget or prove the App Group."
  echo "$message"
  write_summary "$message"
  exit 0
fi

if has_compile_or_link_error "$LOG_DIR/without-entitlements.log"; then
  echo "Unsigned build hit a Swift compile or link error after removing entitlements." >&2
  exit "$second_status"
fi

if has_signing_error "$LOG_DIR/without-entitlements.log"; then
  message="Unsigned xcodebuild could not produce the app and widget. The entitled build and a retry without entitlements both stopped on signing or App Group provisioning. swift test is still the CI check for Core behavior."
  echo "$message"
  write_summary "$message"
  exit 0
fi

echo "Unsigned build failed after the entitlements retry." >&2
exit "$second_status"
