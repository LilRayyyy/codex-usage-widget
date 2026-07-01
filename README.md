# Codex Usage Widget

Native macOS app and WidgetKit widget for viewing local Codex usage.

## What It Shows

- Remaining Codex allowance
- Current usage progress
- Weekly remaining progress, when Codex exposes it
- Current month daily heatmap
- Recent 7-day usage trend
- Last refresh time
- Diagnostics for refresh, cache, App Group, and Codex executable status

## App Features

- Configurable automatic refresh interval
- Optional menu bar status item
- Optional test data mode for UI and widget checks
- Launch at Login support through the macOS Service Management API
- Settings window with diagnostics
- Small, medium, and large WidgetKit layouts tuned for different information density

## Screenshots

![Codex Usage UI preview](docs/previews/ui-preview.svg)

![Codex Usage app icon](docs/screenshots/app-icon.png)

## Requirements

- macOS 14 or newer
- Full Xcode for building the app and widget
- Codex installed and authenticated with a usage-supported auth method
- An Apple Development signing team for installing the WidgetKit extension locally

## Supported Data Source

The app uses the local Codex App Server JSON-RPC integration. Usage data is
available only when the user's Codex authentication method exposes usage APIs.

The core client maps these Codex App Server methods:

- `account/rateLimits/read`
- `account/usage/read`

## Widget Refresh Limitation

WidgetKit refresh timing is controlled by macOS. The widget displays the latest
cached snapshot and may not update immediately after every app refresh.
The app refreshes its cache on the configured interval while it is running and
asks WidgetKit to reload timelines after a successful refresh. The widget also
requests a new timeline roughly every 5 minutes, but macOS may throttle this.

For the most stable widget data, enable **Launch at login** in Settings so the
app can keep the shared cache current in the background.

## Running As A macOS Widget

The project contains both a normal macOS app target and a WidgetKit extension:

- `CodexUsageWidget`: reads live Codex usage and writes a local snapshot.
- `CodexUsageWidgetWidgetExtension`: reads that snapshot and renders system
  small, medium, and large widget layouts.

For the widget to appear in macOS widget picker and read the app cache, both
targets must be signed with the same Apple Team and the same App Group:

```text
$(AppIdentifierPrefix)group.com.example.CodexUsageWidget
```

Xcode expands `$(AppIdentifierPrefix)` to your Team ID prefix, for example
`ABCDE12345.group.com.example.CodexUsageWidget`. The app and widget read the
effective App Group from their signed entitlements at runtime.

In Xcode:

1. Open `CodexUsageWidget.xcodeproj`.
2. Select the `CodexUsageWidget` target, then set your Team under
   `Signing & Capabilities`.
3. Add or confirm the App Groups capability using the Team ID-prefixed value
   generated from `$(AppIdentifierPrefix)group.com.example.CodexUsageWidget`.
4. Repeat the same Team and App Group for
   `CodexUsageWidgetWidgetExtension`.
5. Build and run the app once so it can write `usage-snapshot.json`.
6. Open Settings and confirm the refresh interval, menu bar icon, test data, and
   Launch at Login preferences.
7. Open macOS widget editing, search for `Codex Usage`, and add the widget.

Unsigned local debug builds can run the app window, but the system widget
requires a valid development signature and matching App Group entitlement.

## Local Testing Without App Store Distribution

You can test the app window without an Apple Developer Program membership:

```bash
./script/build_and_run.sh --verify
```

That command builds with `CODE_SIGNING_ALLOWED=NO`, launches the app, and is
useful for checking live Codex usage loading, the progress view, and the monthly
heatmap.

Testing the system widget is stricter because macOS must install the WidgetKit
extension and allow it to read the shared App Group container. In Xcode, select
your Apple ID or Personal Team for both targets and keep the same App Group on
both targets:

- `CodexUsageWidget`
- `CodexUsageWidgetWidgetExtension`

If Xcode allows that local development signing setup, build and run the app once,
then add `Codex Usage` from macOS widget editing. If Xcode reports that App
Groups or the widget extension cannot be provisioned for your account, the app
can still be tested locally, but full system-widget installation will require a
paid Apple Developer Program team.

## Settings And Diagnostics

Open **Codex Usage Widget > Settings** to configure:

- **Refresh interval**: how often the running app refreshes Codex usage.
- **Use test data**: writes generated usage data to the shared cache for UI and
  widget testing.
- **Codex executable**: path to the local Codex executable used for App Server
  JSON-RPC calls.
- **Show menu bar icon**: controls the menu bar extra.
- **Launch at login**: registers or unregisters the app with macOS login items.

The Diagnostics tab shows the latest refresh status, last refresh attempt, last
error, App Group availability, cache path, and Codex executable path. Include
this information when filing GitHub issues.

## Widget Empty States

The widget gives explicit guidance when it cannot show live data:

- Open the app and refresh once if no cache exists yet.
- Sign in to Codex if the local Codex App Server reports unauthenticated.
- Check signing and App Group setup if the widget cannot access the shared
  container.
- Open Settings > Diagnostics if refresh failed.

## Privacy

The app stores usage snapshots locally and does not upload analytics or
credentials. The widget reads only the local JSON snapshot written by the app.

## Local Data

Cached snapshots are written to the app group's local container as JSON. The app
does not store Codex credentials.

## Development

Run core tests:

```bash
swift test
```

Run the optional live Codex App Server smoke test:

```bash
LIVE_CODEX_APP_SERVER_TEST=1 swift test --filter LiveCodexAppServerSmokeTests
```

Run the local app entrypoint after the app target exists:

```bash
./script/build_and_run.sh
```

Build a signed release zip for GitHub Releases:

```bash
./script/package_release.sh
```

The script writes:

```text
release/CodexUsageWidget-0.1.0-macOS.zip
```

The zip contains the `.app` bundle with the embedded WidgetKit extension. It must
be built with valid signing settings for the widget to work on another Mac.

## GitHub Release Checklist

1. Confirm `swift test` passes.
2. Confirm `xcodebuild -project CodexUsageWidget.xcodeproj -scheme CodexUsageWidget -configuration Release build` passes with signing.
3. Run `./script/package_release.sh`.
4. Attach `release/CodexUsageWidget-0.1.0-macOS.zip` to a GitHub Release.
5. Include the matching `CHANGELOG.md` entry in the release notes.
6. Mention that non-notarized builds may show a macOS Gatekeeper warning on
   first launch.

## Distribution Notes

You do not need App Store distribution to open source the project on GitHub.
Other users can build the project themselves with Xcode and their own signing
team. A prebuilt zip is more convenient, but without notarization macOS may warn
users on first launch. App Store distribution and notarization both require an
Apple Developer Program membership.

## Current Build Status

The shared Swift core, SwiftUI app sources, WidgetKit sources, and App Group
entitlements are present. `CodexUsageWidget.xcodeproj` is generated from
`project.yml` with XcodeGen. Full Xcode is still required to build and run the
app/widget targets; Command Line Tools alone cannot compile them.
