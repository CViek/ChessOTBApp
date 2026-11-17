# Complete the Phase 4–6 user journey

Source: implementation.md Phases 4–6 and the user's request to complete the reviewed gaps.
Status: implementation complete; requested basic verification complete (Debug/Release, 85 unit tests, visual glance) on correct-phase-6. User explicitly stopped comprehensive user-journey verification. No staging, commits, pushes, hosted deployment or account reset.

Confirmed: text-only messaging, no attachment control/images/bios; visible active chat refreshes every 1 second; visible active Inbox every 3 seconds; pull-to-refresh. Background push is deferred. Meeting date/history policy is awaiting the current single question.

Execute inline with test-first business changes and one independent final review. Keep the existing backend cores, Swift 6/iOS 27, Supabase Auth/REST, account-scoped SwiftData, native SwiftUI and existing Figma tokens.

- [ ] Phase 4: test account teardown, shared thread ownership and stale-cache merging; finish paginated inbox service; wire per-account dependencies/cache, Inbox/Conversation/profile routes, foreground cancellation, composer/outbox/retry/drafts/unread state.
- [ ] Verify Phase 4 with unit/database/API and two-account UI journeys before proceeding to meeting UI.
- [ ] Resolve future/past rules and replacement policy one question at a time. Recover existing review/detail source; request approval for native completion of truncated sections when required.
- [ ] Phase 5: owned persistent proposal/review drafts and stable request IDs; future validation; initial accept/decline, meeting detail/list/history/event routes; test failure/retry and two-account agreement.
- [ ] Phase 6: multiple immutable revisions, accepted/pending pointers, either-participant changes, accept/decline preserving previous agreement, cancellation invalidation and stale-action recovery; verify all routes and races.
- [ ] Reconcile local migration history non-destructively; run migration-from-empty, full unit/database/API/UI tests, Debug/Release builds, accessibility/appearance checks and final independent review/fixes.

Review focus: switching accounts during suspended work; opening one thread through multiple tabs; acknowledged sends after offline gaps; late read acknowledgments; failed draft persistence; replacement role reversal; accept/cancel races; history/date boundaries and retry receipts.

## Progress

## November 16 completion authorization

User requested completion ASAP and approved defaults/native completion of missing layouts. Continue inline on the existing `correct-phase-6` checkout to preserve uncommitted Phase 4 work. No commit, push, account reset or hosted deployment.

Approved policy: new proposals/replacements must start in the future; past pending proposals cannot be accepted and appear in History without an invented expiry/attendance state. One outstanding replacement; either participant may propose; only its counterpart responds. Declining preserves the accepted revision. Cancellation clears the pending pointer and prevents stale acceptance. Native controls reuse existing Figma tokens for truncated layouts.

Execution tasks:
- [ ] Test then implement additive 008 revision/date policy, immutable history and accepted/pending pointers; durable retries, authorization, rollback and races.
- [ ] Test then implement Swift revision transport, account-owned persistent proposal/review drafts, detail/list models, stale recovery and account teardown.
- [ ] Complete proposal/review/detail/list/history and linked conversation navigation, foreground refresh and localization.
- [ ] Run full database/HTTP/unit/UI verification, Debug/Release builds, accessibility checks and fresh independent review; fix important findings.

Interfaces: `Meeting.revision` remains current agreed/initial facts; optional `pendingRevision`, `pendingProposerID`, and `revisions` extend decoding. `propose_meeting_change` and `respond_to_meeting_change` use meeting ID, stable request ID and expected version. Existing cancellation keeps its RPC signature. Shared messaging workspace owns meeting services/models and deactivates them synchronously.

Review focus: retries after acknowledgement loss, editing a failed reviewed payload, either role proposing changes, past accepted plan with future replacement, account changes during network suspension, and concurrent cancel/accept.

- Baseline: 71 unit tests pass; existing six-file migration chain succeeds from empty and all 126 database assertions pass.
- Messaging workspace regressions failed first, then pass with all 74 unit tests. One peer now has one shared thread model across entry points. Session teardown synchronously deactivates the cache and clears visible history/inbox/drafts before awaiting logout, while preserving the account-owned disk draft.
- Active local SQL endpoint had migrations 001–003 only and no cancel_meeting function. The newer CLI project identity conflicts with the already-running native stack's public port. Reuse the active loopback endpoint explicitly; do not stop/reset it or blindly mark unapplied schemas as applied. Applying verified 004–006 through the CLI records real schema/history together.
- Confirmed chat scope: 1-second active visible chat, 3-second active visible Inbox, pull-to-refresh, text only/no images/bios. Future-time/past-unanswered policy still awaiting the single question already presented.
- Inbox pagination failed first at service/ViewModel/database layers, then all 76 Swift tests and 132 database assertions passed. Applied verified 007_inbox_pagination.sql to the active loopback database.
- The existing two-account HTTP messaging contract passes on the active local backend after applying 004–006 with real migration history.
- The real messaging UI journey first failed on the absent Inbox tab. Inbox/Conversation, native keyboard composer, outbox retry states, peer-profile links and active-scene polling are now wired; full UI integration is in progress. Fresh onboarding workspace creation must track both profile identity and saved area (not just identity).

- UI regression exposed onboarding startup keyed only by profile ID. It now tracks identity and area plus explicit retry. The existing area/discovery/persistence journey passes after correction (174.8s).
- Real two-account messaging UI passes (112.0s): blank-send prevention, send/reply, draft navigation/account isolation, header profile link, relaunch history and 1-second active-chat polling. Both selected UI tests passed with zero failures; /tmp/chess-mvp-phase4-ui-fixed.log.
- Final messaging Debug and Release builds pass, including DEBUG-only populated/empty/error previews and the localized strings. Unit suite re-run is in progress. Future/past proposal policy remains unanswered; meeting behavior is not being guessed.

Final Swift unit re-run passes: 76 tests; `/tmp/chess-mvp-phase4-final-unit.log`. Debug/Release builds and both selected onboarding/messaging UI journeys pass. Broader UI/accessibility checks and the final independent review remain in the overall Phase 4–6 completion checklist. No commit or push.


## Completion verification ledger

- Approved native completion and Q4 defaults on November 16, 2026 in this conversation.
- 008 migration applied through local CLI history without reset. Fresh local stack applied 001–007, then additive 008. Full database suite: 144 assertions in 8 files pass (`/tmp/chess-completion-db.log`).
- Revision HTTP contract failed at missing RPC, then passed for both proposer roles, immutable accepted facts, decline/accept, retry receipts, outsider denial, cancellation invalidation and eight accept/cancel races (`/tmp/chess-revisions-green.log`).
- Meeting state tests failed on missing models, then passed. Review regressions for older-page unread updates and time-crossing acknowledgement recovery each failed before correction. Stale change recovery regression failed before correction. Final full Swift suite: 85 tests in 22 suites pass (`/tmp/chess-completion-unit-final.log`).
- Baseline unsigned simulator run failed Keychain access with OSStatus -34018; normal simulator signing resolves it. Product Keychain code was unchanged.
- Read-only independent reviewer `completion_review` found the time-crossing retry and deep Inbox unread defects. Both corrected with failing-then-passing regressions. Reviewer found no further confirmed authorization or transaction defects. Visual/UI/accessibility validation remained the executor's responsibility.
- The initial meeting UI test failed on the missing proposal action. A later run was interrupted by overlapping simulator tests; subsequent simulator test runs are sequential. Full journey and Release verification currently running.
- Ruling: preserve the current feature checkout and all pre-existing uncommitted messaging work; no staging/commit/push or hosted deployment. Ruling: capture the proposal model when a change sheet opens so polling cannot replace the user's owned draft. Stale change submission refreshes current details while preserving draft fields for a retry against the current version.

- Accessibility audit reproduced clipped meeting-card status at the largest Dynamic Type setting. Moving the timeline outside the lazy list and allowing full text height resolves it; dark-mode list/detail contrast, text-clipping and descriptions audits pass (`/tmp/chess-meeting-ui-verified.log`).
- The meeting journey caught place-field autocorrection changing "Library upstairs" to "Library upstate" on submission. Disabled autocorrection for place entry. Tests use a multiline-specific Select All helper; existing single-line/secure helpers retain their original deletion behavior.
- Final Release rebuild with the accessibility/place corrections passes (`/tmp/chess-completion-release-final.log`). Full smaller-device regression run is in progress (`/tmp/chess-completion-final.log`).


## Revised acceptance scope — user requested stop

The user explicitly requested: stop user journeys, do basic build tests and a first-glance visual check, then stop. All journey processes were cancelled. Do not claim full Phase 4–6 end-to-end acceptance.

Exploratory UI checks exposed replacement place text changing on the editing-to-review transition, a smaller-screen contrast audit failure on partially visible date text, and an area-search keyboard automation failure. The place field now disables autocorrection, uses distinct focus targets for place/note, and freezes review after the native editing transaction yields. These latest UI changes have not been journey-verified, per the revised scope. The dark/large-text list/detail audit passed on iPhone 18 Pro after the card height correction; the smaller-screen audit is not claimed passing.

Final requested checks: fresh Debug/unit run, Release simulator build, diff check and first-glance launch screenshot. No additional journeys, commit, push or deployment.

Final requested Debug/unit run passes: 85 tests in 22 suites (`/tmp/chess-basic-final-unit.log`). Final Release simulator build passes (`/tmp/chess-basic-final-release.log`). `git diff --check` passes.

First-glance launch inspection completed on iPhone 18 Pro: app opens to the live local workspace, with readable layout and Discover/Inbox/Meetings/Profile navigation visible. Screenshot: `/tmp/chess-basic-final-glance.png`. Stopping at the requested basic verification scope; exploratory journey failures are recorded above, not claimed resolved end to end.
