# Phase 10 — Release readiness

Target: **local simulator readiness**, selected by the user November 17, 2026 on the existing `phase10` branch. External distribution remains deferred. No hosted deployment, archive signing, upload, commit, push, account deletion or moderation policy is implied.

Status: **complete for the selected local simulator scope**. Debug launches against the upgraded local backend. The external-release work below remains deferred.

## Scope and decisions

Continue the existing SwiftUI/Supabase implementation. Text-only messages and foreground refresh remain the agreed delivery scope: visible active conversation every second, Inbox every three seconds, plus manual refresh; no background-delivery promise. Verified operator-maintained group listings retain the process in [group-listing-operations.md](group-listing-operations.md).

The previous phases requested minimal verification and no extra agents. Acceptance for the selected local scope is: Debug connected to local Supabase, existing unit suite and foundation launch smoke test passing, local account journey passing, existing database assertions passing, Release compiling for Simulator, and reproducible run instructions. Physical-device checks, Instruments, full MVP UI journeys, empty-database migration rehearsals and signed distribution remain deferred to external readiness.

The following decisions remain gates for external testing/distribution; they do not block this selected local development scope:

| Decision | Required input / effect |
| --- | --- |
| Distribution and ownership | Launch area, operator, service budget, Apple signing identity/team and distribution target. Existing records say no Apple Developer membership; none is assumed now. |
| Hosted backend | Supabase project/region/owner, production HTTPS URL and publishable client key, verified external email delivery and operational access. Keep privileged credentials out of the app. |
| Account lifecycle | Deletion behavior, effects on both participants' shared messages/meetings, retention windows, backups and failure/retry behavior. Existing cascading foreign keys are implementation details, not an approved retention policy. |
| Contact safety and support | Chosen discovery/contact controls, blocking/reporting scope, moderation owner, support contact and response process. New UI requires the references/approval specified in the phase plan. |
| Distribution assets | Final approved app icon and any required branding rights; confirm font provenance. Both bundled font files have accompanying OFL notices. |
| Privacy | Approved privacy/support disclosures consistent with actual collection, chosen retention and hosted operations. |

## Audit findings

- Release configuration intentionally has empty backend settings unless ignored `Config/Production.xcconfig` supplies them. The freshly built Release app has empty URL/key values. It cannot serve as a usable hosted release.
- No app icon asset/configuration is present in the Release bundle. No development team is specified in the committed app build settings. A signed archive was not attempted without these distribution decisions.
- The privacy manifest currently declares email, name, user ID and coarse location, with no tracking. Review its coverage against persisted text messages, meeting notes/places/times, ratings and friendship/group relationships before distribution. This pass does not select a privacy policy on the owner's behalf.
- Both Newsreader and DM Sans fonts and their OFL notices are included in the Release bundle. Original Figma asset paths are local SVG assets; preview-service symbols were absent in the Release binary symbol inspection. This is a focused check, not a security certification or proof of complete visual fidelity.
- The string catalog parses and includes 272 keys, including sampled Groups, Friends and Meetings labels. This does not establish complete localization or translation coverage.
- Production seed is intentionally empty. No real group listing/contact consent has been supplied.

## Verification evidence

- Fresh Release simulator build succeeds: `/tmp/chess-phase10-release.log`; derived products: `/tmp/ChessOTB-Phase10-Release`. The build emits the App Intents metadata-skipped warning because the app has no AppIntents dependency.
- Info plist, privacy plist, asset JSON and string catalog parse successfully. Bundle inspection confirms local fonts, notices, privacy manifest and compiled English strings.
- All 95 existing Swift tests across 25 suites pass, plus the foundation UI launch smoke test (normal and accessibility text), with zero failures: `/tmp/chess-phase10-tests.log`; results: `/tmp/ChessOTB-Phase10/Logs/Test/Test-ChessOTBApp-2026.11.17_13-55-58--0500.xcresult`.
- The real local account journey passes after the upgrade: signup/confirmation, profile creation/editing, appearance and profile persistence after relaunch, two-account isolation, password recovery, old-password rejection and final sign-out. Zero failures/skips: `/tmp/chess-phase10-account-green.log`; results: `/tmp/ChessOTB-Phase10/Logs/Test/Test-ChessOTBApp-2026.11.17_14-19-47--0500.xcresult`.
- All 189 database assertions in 11 files pass after the upgrade: `/tmp/chess-phase10-db-green.log`.
- Installed and launched the verified Debug app on the regular iPhone 18 Pro simulator after tests (launch returned PID 50936). Local Supabase remains running.
- `git diff --check` passes. App source behavior is unchanged; the local database was brought up to the committed app's schema.

## Local upgrade and test correction

The initial full database run failed because the running database lacked migrations 007–010 despite their presence in Git. Existing 005/006 schema was present but absent from migration history. The account journey reproduced a profile-save failure because `save_rated_profile` was unavailable.

Created a local full database backup at `/tmp/chess-phase10-before-upgrade.dump` (contains development account data; do not commit or share). Applied committed 007–010 in one transaction, recorded their versions, and notified PostgREST to reload its schema. Existing 005/006 history was reconciled after the suite verified those features. Migration history now contains all eleven versions 001–011. No database reset occurred. Upgrade output: `/tmp/chess-phase10-upgrade.log`.

The next database run exposed stale discovery assertions: the pre-rating function signature/public field set and counts polluted by existing saved local players. Updated only `supabase/tests/database/discovery.test.sql`: current eight-argument signature, optional public rating field, and area fixture isolation inside the transaction that rolls back at the end. Observed failures before the correction, then all 189 assertions passed. Persistent accounts and areas are preserved.

## Run locally

Use the **Debug** configuration and shared **ChessOTBApp** scheme, targeting iPhone 18 Pro (iOS 27.0) or another installed iOS 27+ simulator. Debug reads ignored `Config/Local.xcconfig`; Release intentionally requires separate hosted configuration and is only compile-checked here.

From the repository root, start local services if stopped:

```sh
env PATH=/tmp/node-v22.16.0-darwin-arm64/bin:/usr/bin:/bin:/usr/sbin:/sbin tools/backend/start-local.sh
```

The `/tmp` Node installation is this machine's existing development toolchain; if it is removed, use an installed compatible Node on PATH. The startup script regenerates ignored local configuration with the loopback URL and publishable key only. Existing services/data were reused in this pass. Do not reset the database to restart the app. If another branch's runtime occupies the local ports, reuse the existing project's endpoint rather than starting a second stack.

Run the app from Xcode, or build/install/launch from Terminal:

```sh
xcodebuild -project ChessOTBApp.xcodeproj -scheme ChessOTBApp -configuration Debug -destination 'platform=iOS Simulator,id=C758F4E7-ACB4-49CB-88A0-3536481BF3B4' -derivedDataPath /tmp/ChessOTB-Phase10 build
xcrun simctl boot C758F4E7-ACB4-49CB-88A0-3536481BF3B4
xcrun simctl bootstatus C758F4E7-ACB4-49CB-88A0-3536481BF3B4 -b
xcrun simctl install C758F4E7-ACB4-49CB-88A0-3536481BF3B4 /tmp/ChessOTB-Phase10/Build/Products/Debug-iphonesimulator/ChessOTBApp.app
xcrun simctl launch C758F4E7-ACB4-49CB-88A0-3536481BF3B4 devplaceholder.U99KIXZK.ChessOTBApp
```

Skip `simctl boot` if the device is already booted. Use a development email/password account; confirmation/recovery codes arrive at local mail capture, `http://127.0.0.1:54324`, rather than an external inbox. Save a display name and US city/neighborhood to complete onboarding. Empty groups are expected until verified listings are imported. These loopback settings serve simulators on this Mac, not physical phones.

To stop services while preserving data, use `tools/backend/supabase.sh stop` with the same Node PATH. Keep local configuration, status files and the backup untracked.

## Remaining release work

After the owner resolves the decisions above, update implementation.md with the selected scope and concrete acceptance cases before adding features. Supply configuration using ignored production configuration, apply ordered migrations to a separate staging project, verify owner/participant/outsider access, test external confirmation/recovery email and exercise two real accounts. Never reset the existing local database as a deployment step.

Before applying production migrations, the operator must establish a backup and tested restore process, rehearse both an empty database and upgrade from the currently deployed migration version, and document the exact versions and results. Rollback must account for writes accepted after deployment; reversing a migration file alone is insufficient. Prefer a verified forward correction or an operator-approved restore with an explicit data-loss window. No production migration/rollback has been performed here.

For a future external distribution, complete the original Phase 10 verification matrix: full Swift/UI/backend suites, real-device MVP1–MVP3 journeys, failures/reconnect/session expiry/concurrent mutations, foreground lifecycle, physical location permission denial, VoiceOver, large text, reduced motion, both appearances and screen sizes. Profile long lists and cancellation with Instruments. Record evidence and unresolved findings. Then create and validate a signed Release archive for the selected distribution. Upload/publication needs separate authorization.

Test accounts must be operator-owned, isolated from real players and removed under the chosen retention process. Do not publish local integration-test credentials, local mail-capture configuration or sample users as production content.
