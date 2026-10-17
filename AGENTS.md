# AGENTS.md

This file is for people and agents changing the repo. Behavior checks live in code and CI. This document only points at them.

## Layout

- `Sources/CodexUsageCore` — models, cache, the Codex app-server client, and widget timeline policy. No SwiftUI and no WidgetKit.
- `CodexUsageWidgetApp` — SwiftUI app, preferences, and menu bar. It refreshes usage through Core and asks WidgetKit to reload timelines.
- `CodexUsageWidgetWidget` — WidgetKit views plus a thin timeline adapter. It calls `WidgetTimeline` and does not talk to the app server.
- `Tests/CodexUsageCoreTests` — what `swift test` runs. Recorded payloads live in `Fixtures/` and are excluded from the SwiftPM target so they are not compiled.
- `script/` — local run, the release zip, and the unsigned CI build.
- `project.yml` — XcodeGen spec. `CodexUsageWidget.xcodeproj/xcshareddata/xcschemes/CodexUsageWidget.xcscheme` is the shared scheme CI and `script/build_and_run.sh` use. After `xcodegen generate`, commit the scheme it writes.

Do not add the app or widget as SwiftPM targets. `swift test` cannot see WidgetKit, and a second copy of those sources would drift from the Xcode targets.

## Layering

- The widget reads the snapshot the app writes. It does not launch Codex or call `account/usage/read` or `account/rateLimits/read`.
- Timeline decisions belong in `WidgetTimeline`: the five-minute reload, the placeholder, and the split between a missing App Group container and a missing cache. Do not re-inline that policy in `UsageProvider`.
- `loadEntry` returns a readable snapshot even when its status is an error. The widget view maps that status through `WidgetUnavailableReason`. A missing container is `.missingAppGroup`. A missing or unreadable cache is `.needsFirstRefresh`.
- `CodexAppServerStdioFraming` owns the stdin handshake and the `id == 2` response filter. `CodexStdioTransport` only starts the process.
- Change an unpublished app-server payload only together with a fixture in `Tests/CodexUsageCoreTests/Fixtures` and a failing-then-passing test in `CodexAppServerFixtureTests` or `CodexAppServerStdioFramingTests`.

## Commands

| Command | What it checks | Signing or GUI |
| --- | --- | --- |
| `swift test` | Core, fixtures, and timeline policy | Neither. This is the default check. |
| `swiftlint lint --strict` | `.swiftlint.yml`. CI installs SwiftLint 0.65.1. | Neither. |
| `./script/ci_unsigned_build.sh` | `xcodebuild` of the app and widget scheme | Tries an unsigned build. See below. |
| `./script/build_and_run.sh` | Debug app window | Builds with `CODE_SIGNING_ALLOWED=NO`, then opens the app. Needs a Mac GUI. Does not install the desktop widget. |
| `./script/build_and_run.sh --verify` | Launches the app and checks that the process is running | Same unsigned build, plus a GUI session. Do not run it in CI. |
| `./script/build_and_run.sh --debug` | Same build under lldb | Needs a Mac GUI. |
| `./script/package_release.sh` | Release zip at `release/CodexUsageWidget-0.1.0-macOS.zip` | Uses the Xcode signing settings. Do not change the version or the zip name as part of unrelated work. |
| `LIVE_CODEX_APP_SERVER_TEST=1 swift test --filter LiveCodexAppServerSmokeTests` | Live local Codex at `/Applications/Codex.app/Contents/Resources/codex` | Needs a signed-in Codex install. CI does not set the variable, so the test skips. |

`swift test` does not compile the app or widget targets. Use the unsigned build script for that.

## App Group placeholder

The open-source identifier is `AppGroup.placeholderIdentifier`:

```text
$(AppIdentifierPrefix)group.com.example.CodexUsageWidget
```

`AppGroupPlaceholderTests` keeps these in lockstep:

- the constant stays that example value
- every `*.entitlements` file contains it once and no other `group.` identifier
- `project.yml` keeps `bundleIdPrefix: com.example`, `com.example.CodexUsageWidget`, and `com.example.CodexUsageWidget.Widget`

A fork that wants a real widget replaces the constant, both entitlements files, both bundle identifiers, and the example value in that test together. Keep the `$(AppIdentifierPrefix)` prefix. Do not commit a Team ID, a provisioning profile, or a group id that only one target uses.

`AppGroup.containerURL()` is nil unless the process has the entitlement. Tests pass a directory into `WidgetTimeline.loadEntry` instead of calling it. The app falls back to Application Support when the container is nil; the widget cannot, and shows setup needed.

## CI

`.github/workflows/ci.yml` runs on a GitHub-hosted `macos-26` runner. It selects Xcode, runs `swift test`, runs SwiftLint 0.65.1, then `./script/ci_unsigned_build.sh`.

The unsigned script builds `-scheme CodexUsageWidget` with signing disabled. If that fails for a recognized signing, provisioning, or App Group reason, it retries once with an empty entitlements file. The job summary states which of those happened.

These are not CI checks:

- installing or rendering the WidgetKit extension
- reading a real App Group container
- `./script/build_and_run.sh` and `--verify`
- `./script/package_release.sh`
- the live Codex smoke test

A green unsigned retry means the sources compiled and linked without the sandbox and App Group entitlements. It does not mean the desktop widget installed.

Swift compile errors, link errors, and any unrecognized `xcodebuild` failure still fail the job.
