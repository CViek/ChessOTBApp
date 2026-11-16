# Phase 5 implementation record

Requested on November 16, 2026, on the existing `phase5` branch.

Source: `implementation.md`, Phase 5. Swift 6, iOS 27+, native SwiftUI,
protocol-based services, participant-only Supabase RPCs.

## Execution plan

1. Add failing database tests for participant authorization, Pending creation,
   recipient-only accept/decline, version checks, immutable revisions,
   idempotent requests, linked thread events, and stable pagination.
2. Add `005_meetings.sql` and run the complete database suite without resetting
   existing accounts. Meeting mutations and conversation events commit together.
3. Add failing Swift service/model tests, then account-bound meeting services
   and immutable DTOs. Verify the full unit suite.
4. Resolve Q4's future/past policy and recover complete F09–F12 references.
   Implement owned proposal drafts, review/back/send, recipient responses,
   meeting lists and event links; supply the missing Phase 4 navigation.
5. Verify backend races and HTTP behavior, unit/UI suites, Release build,
   two-account consistency, timezone/DST and failure/retry behavior; review.

## Open dependencies

- Figma Make `rTehrTBTS9tjgoMym5KS0U` still returns a literal truncation in
  ReviewProposal and MeetingDetail. Both session creation and screenshots reject
  Make files. Asked for complete Design frames or permission to finish the
  missing layouts from existing styles. No missing layout is approved yet.
- Asked whether proposals require future instants, become History after their
  time, and reject past acceptance (Q4). Awaiting the answer before implementing
  that policy.
- Phase 4's backend/models exist, but Inbox/Conversation views, dependency wiring,
  polling and cache lifecycle integration remain incomplete. Required for the
  Phase 5 customer journey.

## Review focus

Untrusted actor IDs; identical retries after lost acknowledgments; simultaneous
responses; forged/unknown time zones and malformed instants; account switching;
long location/note fields; pagination ties; all-or-nothing event writes.

## Evidence

- Initial local CLI needed the existing Node binary from `/tmp` added to PATH.
- Initial sandbox simulator connection and native stack startup failed. Retried
  both with explicit tool approval outside the sandbox.

Phase 5 is not complete. Results and remaining scope will be recorded here.

## Implemented core

- Added participant-only meeting creation, detail and paginated list RPCs;
  immutable initial revisions; recipient-only accept/decline with expected
  versions and durable retry receipts. A sent proposal starts Pending.
- Meeting mutations and linked proposal/response messages commit together under
  the same conversation lock used by text sends. Repeated requests reuse the
  meeting or response; conflicting response requests cannot both commit.
- Added account-bound Swift meeting services, Codable records, reviewed-payload
  structural validation and absolute-instant/named-zone transport. Places are
  limited to 500 Unicode scalars and optional notes to 2,000, on client and server.
- Message DTOs preserve meeting/event links through network decoding and cache
  encoding. HTTP 409 has a refresh-specific error message.
- Applied the additive migration directly to the existing local PostgreSQL
  database; existing accounts/messages were preserved. No hosted deployment.
  This direct local application is separate from CLI migration-history tracking.

## Verification

- Baseline: 62 Swift tests passed; `/tmp/chess-phase5-baseline-approved.log`.
- Database tests failed against missing meeting RPCs before implementation.
  Final suite: **108 assertions across five files pass**;
  `/tmp/chess-phase5-db-green.log`.
- Swift tests failed against missing meeting types, then missing event fields and
  conflict case. Final suite: **70 tests in 19 suites pass**;
  `/tmp/chess-phase5-service-green.log`.
- Real local HTTP checks pass for account regressions, shared A/B details,
  proposer/outsider denial, ten concurrent creates/retries, ten identical
  accepts, conflicting accept/decline requests, explicit decline, event/unread
  consistency and seven arrangements paginated without duplicates;
  `/tmp/chess-phase5-http.log`.
- The HTTP race test exposed stale responses mapping SQLSTATE `40001` to HTTP
  500. Explicit `PT409` now returns HTTP 409; the same race test passes.
- Injected event-insertion failure verifies rollback of new proposals and
  acceptance/version updates, followed by successful retry.
- Timestamp tests distinguish the two occurrences of 01:30 during a DST clock
  change and decode fractional seconds and numeric offsets.
- `git diff --check` passes. Debug builds as part of the test suite. Release
  simulator build succeeds; `/tmp/chess-phase5-release.log`.

## Independent review

Reviewer `/root/phase5_core_review` inspected the uncommitted core read-only and
found no additional important defects. Its suggested event-failure rollback
coverage was added and passes. The reviewer did not rerun tests or inspect the
later event-link/conflict mapping changes. Concurrent pagination across multiple
conversations and discarding in-flight results after account switching remain
integration verification work.

## Remaining work

No Phase 5 customer screens, draft/ViewModels, proposal actions or meeting list
segments have been implemented. The complete review/detail layout and Q4 policy
are still awaiting user input. Structural validation currently rejects invalid
instants/zones/fields; it does **not** enforce a future-time or past-answer rule.
My Meetings pagination currently returns all statuses; Upcoming/History policy
and filtering are pending. Phase 4 messaging UI/navigation and cache lifecycle
integration also remain necessary. No complete Phase 5 or UI acceptance claim
is made; no commits or pushes were performed.
