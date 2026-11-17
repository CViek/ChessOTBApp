# Phase 4 implementation record

## Current completion status — November 16, 2026

Messaging UI, account teardown, pagination and native routes implemented. Independent review correction refreshes loaded Inbox pages so deep-thread unread counts converge.

85 Swift unit tests, 144 database assertions, local two-account meeting/revision/race HTTP contracts and Debug/Release simulator builds pass. The user stopped comprehensive UI journeys and requested basic build/unit checks plus a visual glance. Full end-to-end acceptance is not claimed; see [completion ledger](plans/finish-mvp1.md). No commit, push, hosted deployment or account reset.

## Historical implementation record

The following records describe earlier partial states; the current status above supersedes their remaining-scope lists.

Status: core verified; full UI integration verification is in progress on `correct-phase-6`. Inbox/Conversation views and app routing are implemented. No staging, commits, pushes or hosted deployment.

Scope: persistent participant-only direct text conversations, canonical profile pairs, idempotent client message IDs, stable paginated history, inbox previews/unread counts, account-scoped SwiftData history/outbox/drafts, retry and native navigation.

Sequence:
1. Database authorization, uniqueness, retry, ordering and read-watermark tests, then additive migration.
2. HTTP service and cache/ViewModel tests, then services and persistence.
3. Figma F07/F08 native UI and profile routing, then two-account integration/UI verification.
4. Full tests, Debug/Release builds and independent final review.

Confirmed November 16: text only, no attachments/images/bios; visible active chat polls every 1 second, Inbox every 3 seconds, with pull-to-refresh; background push deferred.

Figma: Make context read on November 16, 2026. `create_session` and `get_screenshot` reject Make files; source/CSS are available. No exact screenshot fidelity claim.

Pre-flight: database UUID/client-ID and sequence cursors feed Codable DTOs; the cache partitions by authenticated user ID; public profile IDs identify peers, never auth owner IDs. Read acknowledgments name a fetched sequence so concurrent unseen messages stay unread.

Verification and rulings will be appended as work proceeds.

## Completed core

- Additive `004_messaging.sql` applied to the local stack without resetting accounts. Tables deny direct client access; authenticated RPCs derive the sender from the session and verify conversation membership.
- Canonical profile pairs reuse one thread, including simultaneous reverse-pair opens. Per-thread serialization assigns stable message order; duplicate client IDs return the original acknowledgment and cannot alter text.
- History pages use sequence cursors; read watermarks advance monotonically through an explicitly fetched message. Inbox names/previews/unread counts come from persisted rows.
- Swift HTTP service binds to an authenticated account ID. Account-scoped SwiftData snapshots persist history, drafts and retryable outgoing text. A deactivated cache rejects late writes.
- ViewModels preserve offline rows/errors, normalize and validate text, retain failed sends, reconcile acknowledgments by sender/client ID and retrieve intervening history after an offline interval.

## Verification

- Baseline unit run passed before new implementation: `/tmp/chess-phase4-baseline.log`.
- SQL tests first failed against the missing messaging endpoint. Final full database suite: 75 assertions pass across four files; `/tmp/chess-phase4-db.log`.
- New service/state tests first failed to compile against missing implementations. Explicit `@MainActor` on the test-double methods resolves the same protocol-witness isolation issue recorded in Phase 3.
- Final Swift suite: 62 tests in 18 suites pass; `/tmp/chess-phase4-final-unit.log`, result bundle `/tmp/ChessOTB-Phase4/Logs/Test/Test-ChessOTBApp-2026.11.16_14-55-16--0500.xcresult`.
- Real local HTTP checks pass: confirmation/recovery/auth regression, concurrent reversed thread creation, concurrent idempotent sends, A/B shared history and replies, 56-message pagination, unread monotonicity and outsider/anonymous denial. `/tmp/chess-phase4-http.log`. The fixture was corrected to expect HTTP 204 for the void read-acknowledgment endpoint; product code was unchanged for that harness correction.
- Final Release simulator build succeeds: `/tmp/chess-phase4-final-release.log`. Debug compiles as part of the unit run. `git diff --check` passes.

## Independent core review

Read-only reviewer `/root/phase4_core_review` found a history gap when sending before catch-up after a long offline interval. A send acknowledgment advanced the newest local sequence, causing refresh to stop before fetching intervening replies. The paginated regression `sendingAfterOfflineIntervalDoesNotSkipInterveningHistory` failed with two assertions before correction, then passed with the full suite. History synchronization now tracks and persists its own sequence independently of send acknowledgments.

No additional definite core issues were found. The reviewer did not judge UI/navigation/polling or run the tests independently. Actual auth-switch removal of old published arrays, multiple live models writing snapshots for the same peer, physical-device behavior, disk/relaunch behavior and UI failure/retry remain integration verification work; they are not claimed complete.

## Current completion work

Inbox, conversation, public-profile return, Discover Message routes and a shared account-owned thread registry are wired. Synchronous account cleanup clears visible rows before logout awaits the network and preserves only account-owned persisted drafts. Additive migration 007 implements inbox cursor pagination. All 76 Swift unit tests and 132 database assertions passed before UI integration; the real two-account messaging HTTP checks also passed.

The UI journey exposed a workspace startup dependency on profile identity alone. Saving an initial search area preserves that identity, so startup must track both identity and area, with an explicit retry for cache/configuration failures. The existing area journey reproduced the failure before correction. Chat keeps native multiline entry and the explicit Send button; keyboard Return inserts a new line.

Two-account UI history, drafts, relaunch and foreground refresh are being verified. Preview fixtures remain DEBUG-only and cannot replace live accounts. No Phase 5 proposal action has been added. Full suite, Release build and final review remain outstanding.

Final Swift unit re-run passes: 76 tests; `/tmp/chess-mvp-phase4-final-unit.log`. Debug/Release builds and both selected onboarding/messaging UI journeys pass. Broader UI/accessibility checks and the final independent review remain in the overall Phase 4–6 completion checklist. No commit or push.
