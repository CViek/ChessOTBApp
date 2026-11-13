# Phase 1 implementation record

Status: implemented and automated checks passed, including the user-approved dark text contrast correction. Manual verification limitations are recorded below. Phase 2 has not started.

## Approved scope and adaptations

- User approved adapting the existing `ChessOTBApp` project, keeping its name, and downloading Newsreader/DM Sans with their licenses.
- App/project/scheme name stays `ChessOTBApp`; displayed brand is ChessOTB. Existing bundle identifier is retained for simulator development; production team/identifier remains a Phase 2 decision.
- Swift 6 strict concurrency, iOS 27.0 minimum, native iPhone/iPad layouts. Removed starter macOS/visionOS destinations because this plan describes an iOS app.
- Replaced the starter with only the Figma F01 brand introduction. No account form, fake profiles, feature tabs, backend, networking, or persistence. NavigationStack is ready; routes and dependencies will be added when real destinations/services exist, avoiding empty future modules.
- Built semantic light/dark colors, Dynamic Type typography, button variants, initials avatars, informational notice, and native board mark. Components have SwiftUI previews. The 24-point spacing exception mirrors CSS's setup-copy margin; the named base scale otherwise uses 4/8/12/16/22/28.
- Removed a pre-existing stray filesystem path before `import SwiftUI` in the starter entry point and the unrelated starter Playground.
- Added explicit font registration, string catalog, privacy manifest, unit/UI test targets and shared scheme. No data collection or required-reason API use in Phase 1; update the manifest when future services are added.

## Design and asset provenance

Source: Figma Make `rTehrTBTS9tjgoMym5KS0U`, root `0:1`, read November 13, 2026 through Figma MCP. `src/App.tsx` and `src/index.css` supplied board geometry, SVG info icon, avatar treatments, button/notice styles and tokens. The info vector preserves the 24-unit paths and 1.8 stroke, rendered in its evidenced 19-point notice slot as a template SVG asset. No temporary Figma URLs are in the app.

Make rejects `create_session` and `get_screenshot`. Consequently no screenshot fidelity is claimed; native screenshots can be inspected for layout, but cannot establish an exact visual match against a recovered Figma render. Missing ReviewProposal/MeetingDetail markup and additional auth/error/destructive states remain later-phase design gates. App icon remains unprovided and is deferred to release requirements. Unused PNG resources have no evidenced app slot and were not imported.

Fonts downloaded November 13, 2026 from the official Google Fonts repository. Both are bundled variable TrueType files, with their upstream SIL Open Font License 1.1 notices. Runtime makes no font download.

| Local resource | Upstream URL | SHA-256 |
| --- | --- | --- |
| `Newsreader.ttf` | https://raw.githubusercontent.com/google/fonts/main/ofl/newsreader/Newsreader%5Bopsz,wght%5D.ttf | `8a08d13f8a6c0d51be379a60af84f945f65369a67e509ee3c3bdcc421254d7c1` |
| `DMSans.ttf` | https://raw.githubusercontent.com/google/fonts/main/ofl/dmsans/DMSans%5Bopsz,wght%5D.ttf | `8cd08d97e89c24d0aa92edd2f0f4c8ee6195eee9b7c9f154865a58b02f0c1c0d` |

Licenses: sibling `Newsreader-OFL.txt` and `DMSans-OFL.txt` from each upstream directory's `OFL.txt`. Both notices are included in the app bundle. Native PostScript names were inspected via CoreText, then tested through UIFont to catch silent system-font fallback.

## Verification evidence

Xcode 27.1, iOS Simulator SDK 27.1. The machine's default xcode-select points to CommandLineTools; use `env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` before Xcode commands instead of changing the user's global setting.

- `xcodebuild -list` lists app, unit and UI targets and shared ChessOTBApp scheme. `-showdestinations` resolves simulator destinations.
- Clean generic simulator build succeeded. Log: `/tmp/chess-phase1-build.log`.
- Before implementation: both font family checks failed because registration was missing, and the UI launch assertion failed because the introduction was absent. Log: `/tmp/chess-phase1-red.log`.
- iPhone 18 Pro, iOS 27.0 (`D74694E9-C818-41D9-81F1-3C6C317EF80D`): both parameterized font tests (six cases) and the UI launch smoke test passed, zero failures. Log: `/tmp/chess-phase1-test-pro.log`.
- iPhone 18 Pro Max, iOS 27.0 (`2D4652AF-5746-45F1-9251-ED5FC19E109C`): same suite passed, zero failures. Log: `/tmp/chess-phase1-test-max.log`.
- UI test checks the real introduction and absence of unimplemented actions/tabs, then relaunches with accessibility-size text and attaches screenshots. The first attempt's AppleInterfaceStyle launch argument did not enable dark mode; corrected the test labels/arguments, and use simulator appearance controls for actual dark verification.
- Corrected launch test rerun in actual simulator dark appearance: full font/UI suite passed, zero failures. Log: `/tmp/chess-phase1-test-dark.log`.
- Rendered light, actual simulator dark appearance, and large-text introduction screenshots inspected. Native status bar/safe area used; large text wraps in a scroll view. Font names resolve to bundled families.
- Independent code review found no additional functional or resource packaging issues. It confirmed the dark accent contrast issue below. Full manual VoiceOver reading, pressed/disabled control interactions in previews, and recovered Figma visual comparison are not yet claimed as verified.
- Xcode emits its SDK build-number diagnostic and skips AppIntents metadata because this app has no AppIntents dependency; no Swift compilation errors.

Reproduce tests (outside restricted simulator sandbox):

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChessOTBApp.xcodeproj -scheme ChessOTBApp -destination 'platform=iOS Simulator,id=D74694E9-C818-41D9-81F1-3C6C317EF80D' -derivedDataPath /tmp/ChessOTBApp-Phase1 -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

- After the approved dark text correction: build and full font/UI suite passed, zero failures. Log: `/tmp/chess-phase1-contrast.log`. Contrast calculations from the actual asset values passed 4.5:1 on both dark paper and surface.

## Approved design correction

The unmodified Figma dark oxblood (#9B4039) on paper (#13201E) is 2.54:1 contrast; danger (#A23F39) is 2.64:1. The user approved correcting these text accents. Dark Oxblood is now #D99189 (6.67:1 on paper, 5.88:1 on surface); dark Danger is #E3948C (7.09:1 on paper, 6.24:1 on surface). Both exceed 4.5:1 for normal text. Light variants and font families are unchanged. This is an explicitly approved adaptation from the Figma palette.

No commits, pushes, staging, or branch changes were performed. Stop for explicit “continue” before Phase 2. Phase 2 still requires backend/auth selection, account lifecycle/profile decisions, and approved authentication designs as listed in implementation.md.
