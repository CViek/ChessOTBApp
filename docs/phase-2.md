# Phase 2 implementation record

Status: Phase 2 implemented and automated checks passed. Phase 3 has not started. No Phase 3 work, commits, pushes, staging, or branch changes.

## Confirmed decisions

- Supabase database and Supabase-managed email/password authentication; no Apple Developer membership or Sign in with Apple required.
- User approved the necessary account screens in the established design style. Existing Figma F01/F14/F15 still guide profile/setup layout. Native email-code confirmation and password recovery avoid an invented web/deep-link dependency.
- Generated initials, basic display-name editor and persistent dark appearance; no photo, biography, area selection or rating editor in this phase.
- Development/test accounts only until launch privacy, deletion and retention decisions are resolved. This does not establish an external-user data retention policy.

## Sequence

1. Pin isolated local Supabase tooling; schema and owner/public-projection access tests.
2. URLSession API boundary, validated nonprivileged configuration, Keychain storage, auth/session services and tests.
3. Account/profile ViewModels and tests for restore, failure, cancellation and account isolation.
4. Native account/setup/profile/edit views, previews and UI journeys using real local accounts.
5. Clean build, unit/UI/backend suites, independent review, fixes, and final report; then stop for continue.

## Contracts

Supabase Auth owns credentials. The app never stores passwords, only session tokens in Keychain. Private profile ownership is separate from the public opaque profile ID; public responses expose only ID and display name. Database functions authorize the current authenticated user, and mutations return only successfully committed data. Onboarding remains incomplete until Phase 3 adds a saved area. Account changes discard feature state; cancelled or stale work cannot restore an earlier user's state.

Sources: https://supabase.com/docs/guides/auth/passwords, https://github.com/supabase/auth/blob/master/openapi.yaml, https://supabase.com/docs/guides/local-development/cli/getting-started.

## Local development setup

Run from the repository root:

```sh
./tools/backend/start-local.sh
```

This installs the pinned CLI if needed, starts the local native Supabase runtime (no Docker needed on this Apple silicon Mac), and writes `Config/Local.xcconfig` with only the local API URL and publishable client key. The runtime/cache, generated credentials and local configuration are ignored by Git. `supabase/supabase.lock` pins verified service artifacts. The native runtime is an explicitly enabled Supabase experimental feature; this is a development-tooling adaptation from the original Docker-oriented commands.

Open `ChessOTBApp.xcodeproj`, select the shared `ChessOTBApp` scheme, and run an iOS 27 simulator. Local confirmation and reset emails are captured at http://127.0.0.1:54324. They are not sent to external inboxes. A physical phone needs a reachable hosted development project instead of the simulator's loopback address.

Hosted development can use the ignored `Config/Local.xcconfig`; copy `Config/Local.xcconfig.example` and supply the project HTTPS URL and publishable client key. Hosted email templates must include `{{ .Token }}` for confirmation and recovery codes, matching `supabase/templates`. Production configuration is separate in ignored `Config/Production.xcconfig`; no hosted project, production deployment or external signups were configured in this phase.

Stop local services without deleting their data:

```sh
./tools/backend/supabase.sh stop
```

Development-only checks:

```sh
./tools/backend/supabase.sh test db
python3 tools/backend/test-accounts.py
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project ChessOTBApp.xcodeproj -scheme ChessOTBApp -destination 'platform=iOS Simulator,id=D74694E9-C818-41D9-81F1-3C6C317EF80D' -derivedDataPath /tmp/ChessOTBApp-Phase2 -parallel-testing-enabled NO CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES test
```

Use ad-hoc simulator signing (`CODE_SIGN_IDENTITY=-`) for real Keychain tests. Disabling signing entirely caused simulator Keychain error -34018. No paid Apple Developer membership is needed for this simulator setup. The UI account journey refuses non-loopback services and is enabled only by the generated local test configuration.

## Verification and review

- Observed the initial networking/session/name-validation tests fail before implementation. Then the account/profile state tests and account-form validation tests failed before their ViewModels were wired.
- Applied the migration to an empty disposable local database; 14 pgTAP authorization/validation tests passed. Separate real-API integration checks passed for confirmed accounts, public projections, denied private/direct writes, separate profiles, wrong passwords, recovery codes, changed passwords, refreshed tokens, and revoked refresh sessions.
- Unit tests include real Keychain write/read/delete isolation and stale restore after sign-out. No token/password is stored in UserDefaults; only the appearance preference uses it, with a required-reason declaration in the privacy manifest.
- Independent read-only review identified expired-token logout, consumed-code password-reset retry, and leaving an editor during a save. Regression tests reproduced both auth failures. Corrections refresh before server logout without repersisting credentials, keep a scoped in-memory recovery session for update retry, report incomplete revocation accurately, and prevent leaving/editing the profile form while it saves.
- UI journey execution initially skipped because Xcode inherited LaunchAction environment rather than TestAction environment. The shared scheme now uses its explicit test environment. Subsequent diagnostics identified native strong-password suggestions intercepting test input and partially obscured fields behind the keyboard. The test now dismisses that suggestion and scrolls fields fully into view; app password-manager support remains enabled. The complete native account journey then passed.

No manual VoiceOver reading, physical-device auth, external email delivery, or exact Figma screenshot comparison is claimed. The Make file does not provide screenshots through its MCP tools; original F01/F14/F15 source and CSS guided existing elements, and the user authorized the necessary new account UI. Chevron and moon vectors were exported from the original inline Figma paths into native asset slots.


## Final evidence

- `32` Swift Testing tests passed on iPhone 18 Pro and Pro Max (iOS 27.0), including parameterized networking/configuration, real Keychain isolation, auth restoration/revocation/recovery retry, malformed signup response, display-name validation, failed saves and stale restore protection.
- iPhone 18 Pro: both UI tests passed, zero skipped. The real account journey exercised UI signup, captured email confirmation, profile setup/edit, appearance persistence, relaunch, two-account switching, password recovery, rejection of the old password, successful new-password sign-in, and final sign-out. Log: `/tmp/chess-phase2-final-pro.log`.
- iPhone 18 Pro Max: clean Debug build, all unit tests and normal/large-text launch smoke test passed. Log: `/tmp/chess-phase2-final-max.log`. Full account journey was run on Pro; it was not needlessly duplicated on Max.
- Clean Release simulator build passed without development credentials or preview-only fixture references. Log: `/tmp/chess-phase2-release-build.log`.
- Local migration-from-empty and `14` pgTAP tests passed. Logs: `/tmp/chess-phase2-db-reset.log`, `/tmp/chess-phase2-db-tests.log`. Real HTTP integration checks passed: `/tmp/chess-phase2-integration.log`.
- Auth regressions were observed failing, fixed, then passed with the whole suite. Logs: `/tmp/chess-phase2-regressions-red.log` and `/tmp/chess-phase2-final-pro.log`. Malformed signup response regression was also observed failing before its fix.
- Saved profile screenshot after relaunch inspected in actual dark appearance; account entry/error and large-text layouts inspected across the two sizes. Native labels and hidden decorative assets were checked in accessibility hierarchy. Full manual VoiceOver reading is still a separate manual check.
- English string catalog merged from compiler-extracted keys, including account/error/recovery text. Privacy manifest declares app-only appearance preferences and account-functionality email/name/user ID usage.
- Final test-diagnostic cleanup recompiled and account-entry smoke test passed: `/tmp/chess-phase2-final-smoke.log`.
- Project/configuration/privacy plists validate and `git diff --check` is clean. Generated local configuration, backend secrets/cache and node_modules are ignored; app bundle has only the nonprivileged publishable client key.

Phase 2 adaptations: user-approved Supabase email/password login and native account controls; isolated local native Supabase tooling in place of an unprovisioned hosted project and unavailable Docker; ad-hoc simulator signing for genuine Keychain access; onboarding intentionally stops at a saved basic profile because area selection belongs to Phase 3. These decisions introduce no Phase 3 features.

No known important review findings remain. Hosted project configuration, external SMTP delivery, account deletion/retention decisions, physical-device checks and launch operations remain their documented later gates. Nothing was committed, staged, pushed, or branched. Stop here until the user says “continue”.
