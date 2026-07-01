# Codex Usage Widget

Native macOS dashboard and WidgetKit widget for keeping an eye on local Codex usage.

> English | [简体中文](README.zh-CN.md)

Codex Usage Widget reads usage information from the local Codex App Server, stores a local snapshot, and renders it in a macOS app, menu bar item, and desktop widgets. It is designed for people who use Codex heavily and want a quick view of remaining allowance, weekly limits, monthly usage patterns, and recent usage trends.

![Codex Usage UI preview](docs/previews/ui-preview.svg)

![Codex Usage app icon](docs/screenshots/app-icon.png)

## Highlights

- Native SwiftUI macOS app
- WidgetKit extension for small, medium, and large desktop widgets
- Overall remaining allowance and current usage progress
- Weekly remaining progress when Codex exposes weekly rate-limit data
- Current-month daily heatmap, generated from day 1 through the last day of the month
- Recent 7-day usage trend
- Configurable refresh interval
- Optional menu bar status item
- Launch at Login support
- Test data mode for UI and widget validation
- Diagnostics panel for refresh status, App Group access, cache path, and Codex executable path
- Local-only cache; no analytics, no external telemetry, no credential storage

## Important Status Notes

This is an open-source preview release. It is useful for local testing and personal workflows, but it is not an official OpenAI product and is not distributed through the Mac App Store.

The app depends on local Codex App Server methods:

- `account/rateLimits/read`
- `account/usage/read`

Usage data is available only when the local Codex installation and the signed-in account expose those APIs. Some authentication methods or accounts may return unsupported or unauthenticated responses.

## Requirements

- macOS 14 or newer
- Full Xcode, not only Command Line Tools
- Codex installed and signed in locally
- A usage-supported Codex account/auth method
- Apple development signing configured in Xcode if you want to install and use the system widget

You can run the main app window without Apple Developer Program membership. The desktop widget is stricter because macOS must install the WidgetKit extension and allow it to read the shared App Group container.

## Quick Start

Clone the repository:

```bash
git clone https://github.com/LilRayyyy/codex-usage-widget.git
cd codex-usage-widget
```

Run tests:

```bash
swift test
```

Run the app window without signing:

```bash
./script/build_and_run.sh --verify
```

This unsigned run path is useful for checking the dashboard, progress bars, monthly heatmap, settings, diagnostics, and local Codex usage loading.

## Widget Setup

To use the macOS desktop widget, both the app target and the widget extension target must use the same Apple Team and the same App Group.

Default open-source placeholder:

```text
$(AppIdentifierPrefix)group.com.example.CodexUsageWidget
```

In your fork, replace the bundle identifiers and App Group with your own reverse-DNS identifier. For example:

```text
PRODUCT_BUNDLE_IDENTIFIER = com.yourname.CodexUsageWidget
PRODUCT_BUNDLE_IDENTIFIER = com.yourname.CodexUsageWidget.Widget
$(AppIdentifierPrefix)group.com.yourname.CodexUsageWidget
```

Then in Xcode:

1. Open `CodexUsageWidget.xcodeproj`.
2. Select the `CodexUsageWidget` target.
3. Set your Team under `Signing & Capabilities`.
4. Add or confirm the App Groups capability.
5. Repeat the same Team and App Group for `CodexUsageWidgetWidgetExtension`.
6. Build and run the app once so it can write `usage-snapshot.json`.
7. Open macOS widget editing, search for `Codex Usage`, and add the widget.

If Xcode cannot provision App Groups or the widget extension for your account, the app window can still run locally, but full WidgetKit installation may require a paid Apple Developer Program team.

## Refresh Behavior

WidgetKit refresh timing is controlled by macOS. The widget displays the latest cached snapshot and may not update immediately after every app refresh.

The app:

- refreshes usage on the configured interval while it is running
- writes the latest snapshot to the shared App Group container
- asks WidgetKit to reload timelines after a successful refresh

The widget:

- reads the latest cached snapshot
- requests a new timeline roughly every 5 minutes
- may still be throttled by macOS

For more reliable background updates, enable **Launch at Login** in Settings.

## Settings

Open **Codex Usage Widget > Settings** to configure:

- **Refresh interval**: how often the running app refreshes Codex usage
- **Use test data**: writes generated sample usage data to the shared cache
- **Codex executable**: path to the local Codex executable used for App Server JSON-RPC calls
- **Show menu bar icon**: controls the menu bar item
- **Launch at login**: registers or unregisters the app with macOS login items

The Diagnostics tab shows:

- latest refresh status
- last refresh attempt
- last error
- App Group availability
- cache path
- Codex executable path
- live/test data mode

This information is useful when filing issues.

## Widget Empty States

The widget shows explicit guidance when it cannot render live data:

- open the app and refresh once if no cache exists yet
- sign in to Codex if the local Codex App Server reports unauthenticated
- check signing and App Group setup if the widget cannot access the shared container
- open Settings > Diagnostics if refresh failed

## Privacy

Codex Usage Widget is local-first:

- usage snapshots are stored locally as JSON
- the widget reads only the local snapshot written by the app
- the app does not upload analytics
- the app does not store Codex credentials
- the repository does not include personal signing identities, Team IDs, provisioning profiles, or prebuilt signed app bundles

## Development

Run core tests:

```bash
swift test
```

Run the optional live Codex App Server smoke test:

```bash
LIVE_CODEX_APP_SERVER_TEST=1 swift test --filter LiveCodexAppServerSmokeTests
```

Run the local app entrypoint:

```bash
./script/build_and_run.sh
```

Build a signed release zip locally:

```bash
./script/package_release.sh
```

The release script writes:

```text
release/CodexUsageWidget-0.1.0-macOS.zip
```

Only attach a prebuilt zip to public releases if you are intentionally distributing your own signed build. Non-notarized builds may trigger macOS Gatekeeper warnings on first launch.

## Distribution Notes

You do not need Mac App Store distribution to open-source this project. Other users can clone the repository and build it themselves with Xcode and their own signing team.

Publishing a notarized prebuilt app, or distributing through the Mac App Store, requires Apple Developer Program membership.

## Release Checklist

Before publishing a release:

1. Confirm `swift test` passes.
2. Confirm Xcode builds the app and widget targets.
3. Replace placeholder bundle identifiers and App Group values with your own if distributing a signed build.
4. Do not commit `DerivedData`, `.build`, `SignedDerivedData`, `release`, zip/dmg artifacts, provisioning profiles, or Xcode `xcuserdata`.
5. Confirm no personal Team ID, email address, token, local path, or signing identity appears in the repository.
6. Include the matching `CHANGELOG.md` entry in the release notes.

## License

MIT. See [LICENSE](LICENSE).
