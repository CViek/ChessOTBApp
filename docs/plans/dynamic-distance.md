# Dynamic distance correction

Approved scope: a slider and editable whole-mile value from 1 through 100, retaining the 5-mile default. Existing saved 3/5/10-mile searches remain valid. Swift and PostgreSQL must enforce the same bounds. Invalid typed values cannot be applied; reset returns to 5; empty-state widening doubles the current radius up to 100 and stops there.

Implement inline using the existing Swift/Supabase architecture. No commits, staging, pushes, account resets or hosted deployment. Keep the database change additive: 003_dynamic_distance.sql, followed by Phase 4 in 004_messaging.sql. Later unimplemented migration paths will be renumbered in implementation.md.

- [x] Observe failing tests for nonpreset values, bounds and numeric Codable compatibility, and server acceptance of dynamic distances.
- [x] Implement validated whole-mile radius/input models, slider/number input, and widening.
- [x] Add and apply the additive server migration; support three-digit rounded-distance pagination bands.
- [x] Verify unit/database/API tests, dynamic-distance UI persistence and invalid input, and builds. Preserve existing relevant UI coverage.

Phase 4 remains requested. Its refresh/attachment/bio decisions are pending the user's response; no dependent implementation starts before they are resolved.


## Verified outcome

- 55 Swift tests and all five UI tests pass: `/tmp/chess-dynamic-full.log`.
- 55 isolated PostgreSQL assertions pass, including three-digit 100-mile pagination: `/tmp/chess-dynamic-db-green.log`.
- Real local API acceptance/persistence for 1/7/37/100 and rejection of 0/101 pass: `/tmp/chess-dynamic-api.log`.
- The additive migration was applied with `migration up`; existing accounts/areas were not reset.
- Clean Release build passes: `/tmp/chess-dynamic-release.log`; final adaptive-layout Release build passes: `/tmp/chess-dynamic-release-final.log`.
- Second-size discovery/widening regression and typed/slider/large-text checks pass: `/tmp/chess-dynamic-max.log`, `/tmp/chess-dynamic-layout.log`. Normal and accessibility screenshots were inspected from `/tmp/chess-dynamic-screenshots`.
- A fresh read-only review found no application/SQL blocker. Its test-maintenance observation was addressed: the tab-return assertion now checks the actual dynamic 3→6 selection and guards against an unintended second widening to 12.
- All newly extracted app strings are in the string catalog. No staging, commits, pushes or hosted deployment.

XCTest documents normalized slider positioning as best effort; on this simulator its upper adjustment landed on 99. The UI test checks near-upper movement, then explicitly types 100 and confirms the saved server value. Native controls and server validation retain the full 1–100 range.

Phase 4 has not started: the user approved the distance range but has not yet answered the pending Q7/Q9 clarification (foreground refresh behavior and text-only attachment/bio scope). The explicit request to complete Phase 4 remains pending those decisions; no later phase has been substituted or started.
