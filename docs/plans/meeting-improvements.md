# Meeting usability corrections — November 17, 2026

User-authorized implementation on the existing `meetings-fixes` branch. Preserve all unrelated work; no commit, push, hosted deployment or extra agents. Native SwiftUI/MapKit and existing Supabase services remain the architecture.

## Design

New proposals and location changes select a real MapKit search result containing a full address and coordinates. Store that selected place as part of each immutable revision, preserve it in drafts/reviews/retries and link it directly into Apple Maps. Existing free-text records remain readable and are explicitly labeled as lacking a selected address; a new/change proposal must select one. Meeting notes retain entrance/table instructions.

Meetings adds an accessible Propose a Game action and accepted-friend picker; selection opens/creates that friend's existing conversation behind the scenes and presents the existing reviewed proposal flow. No chat navigation is required and no meeting is auto-accepted.

Detail uses adaptive theme surfaces, normal text styles and one agreed-details section. Pending changes have a role-specific action section near the top, showing only fields that differ (date/time, address, note); the changed address opens in Maps. The original plan stays authoritative until acceptance. Expired times explain why acceptance is unavailable. Destructive cancellation is secondary.

Remove explicit Refresh controls throughout the app, leaving pull-to-refresh for manual reloads. User clarified: no history timeline. Replace the history dropdown with a separate current proposed-change page, changed fields only, Accept/Reject for recipient and Edit Change for sender. Automatic foreground updates remain enabled; pull-to-refresh is the only manual refresh control.

## Execution

- [x] Add focused failing tests for place validation/maps URL, changed-field comparison, exact-place transport/draft preservation and meeting creation from accepted friends.
- [x] Add additive 013 migration for revision places, authenticated exact-place proposal RPCs with retry identity/authorization preserved, and sender-only pending-change editing. Keep old records/RPCs compatible.
- [x] Implement place search service/model and address selection UI; carry selected address through review, persistence and change proposals.
- [x] Add Meetings friend picker and shared proposal route; redesign detail/changes and implement the current proposed-change page.
- [x] Remove explicit manual Refresh controls app-wide; verify pull-to-refresh. Apply local migration without resetting existing accounts.
- [x] Run focused checks, existing unit/backend suites and Debug/Release builds; inspect visual layout at normal and large text. Record evidence and limits.

Review focus: editing search text invalidates old selected address; stale search cannot replace newer results; Maps points at the exact selected coordinates; a failed send retries the identical place; declined changes preserve the original place; account teardown rejects late friend-picker/proposal results; old records never invent coordinates; no-change replacements are prevented.

## Implementation and verification record

Implemented the selected-address model, debounced MapKit search, persistent reviewed/draft/retry place snapshots, coordinate-based Apple Maps links, accepted-friend selection from Meetings, sender-only pending-change edits, recipient Accept/Reject on a changed-fields-only page, adaptive detail surfaces and removal of explicit Refresh controls/proposal history. Original agreements remain authoritative until acceptance. Existing text-only records remain readable without invented addresses. Automatic foreground updates remain enabled.

Local CLI applied pending 011, 012 and additive 013 to the already-running database at 127.0.0.1:54322, recording migration history without resetting accounts/data. No hosted deployment, commit or push.

Evidence:
- Address/place regression suite first failed on missing models; core checks subsequently pass. Pending-edit regression failed against the unsupported service default, then passes with concrete edit transport. A near-future meeting-time preservation regression failed before correcting the old one-hour shift. Responses now bind to the displayed version, preventing acceptance of an unseen sender edit.
- Final Swift unit run: **109 tests in 26 suites pass**, `/tmp/chess-meetings-final.log`.
- Focused real-backend/simulator flow passes: Meetings friend picker → MapKit search → select exact address; recipient's changed-location-only screen → accept → updated agreed address. Same log; normal-size screenshots were visually inspected in `/tmp/chess-meetings-ui-artifacts/`.
- Meeting database files: **78 assertions in 4 files pass**, including 15 new exact-place/edit/access/retry/version assertions, `/tmp/chess-meetings-db-final.log`.
- Debug compiles as part of the test run. Final Release simulator build passes, `/tmp/chess-meetings-release-final.log`. `git diff --check` passes.
- Review: self-review of code, authorization, retry identity, draft compatibility and changed-field rendering; no extra agents, consistent with the established verification scope.

Known verification limits:
- The broader database run has three unrelated failures in `dynamic_distance.test.sql` assertions 9–11: existing local discovery test accounts precede that file's 100-mile fixtures. No user data was deleted to satisfy fixture assumptions. `/tmp/chess-meetings-db-all.log`.
- The largest-text dark-mode audit still reports contrast issues on scrolling text (first a date at the bottom edge, then the title during scrolling). Explicit clipping prevents meeting content drawing through the tab bar; the automated contrast result is **not claimed passing**. The visible-content audit excludes offscreen contrast captures and rechecks after scrolling, but still flags the title. `/tmp/chess-meetings-final.log`. Normal-size visual inspection is clear; a complete accessibility certification is not claimed.
- Older broad meeting UI journeys were updated for address selection and the separate change page but were not rerun in full. The focused new flow is the verified UI scope.

## Follow-up — clear cancellation and centered confirmations

User's November 17 screenshot shows the cancellation confirmation as an arrowed popover near the top while its quiet action button is near the bottom. Replace `confirmationDialog` with native centered `alert`; add explicit Keep Meeting and destructive Cancel Meeting actions. Make the initiating button red with a visible outline. Apply the same centered alert treatment to sign-out and friend removal, with explicit safe alternatives. Keep all cancellation/request behavior unchanged.

Extend the existing focused UI check to verify Keep Meeting preserves confirmation and the destructive confirmation actually cancels. Verify the centered alert visually. No new backend or model changes are needed for this correction.

Follow-up verification: the extended focused simulator UI check passes (`/tmp/chess-cancel-alert-verified.log`). It verifies the native Alert is presented, Keep Meeting leaves the status Confirmed, and explicit Cancel Meeting changes it to Cancelled; sign-out via its centered alert also succeeds. The screenshot in `/tmp/chess-cancel-alert-artifacts/2FBC8C79-60EC-43DB-BFC5-B252CAC29DFC.png` was visually inspected: centered presentation without an arrow. Updated automation to target alert actions rather than the identically labeled toolbar button, and removed a native-alert accessibility modifier that exposed a duplicate button node. No backend/model behavior changed in this follow-up.
