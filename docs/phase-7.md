# Phase 7 — Optional ratings and comparable search

Scope: one optional self-reported rating, profile add/update/remove, exact source/format search with inclusive optional bounds, persisted filters, clear and empty recovery. No integrations, conversions, ratings changes from meetings, friends or groups.

Implementation choices: named picker choices for Chess.com rapid/blitz/bullet, Lichess rapid/blitz/bullet/classical, US Chess regular/quick/blitz. Whole-number values 1–4000. One combined source/format picker avoids a new screen. These are implementation defaults for the previously unresolved Q5.

Plan: additive migration 009; small rating models and service extensions; profile editor/discovery filters and rating display using existing native controls/tokens. Preserve account ownership and existing area/radius behavior. Verify with a few focused model/database tests and a build. Per user: no journeys, broad regression suite, extra agents, commit or deployment.

Status: complete at the requested minimal verification scope. Debug and Release simulator builds pass, as do the focused checks.

Implemented: atomic owner-only profile name/rating save and removal; public self-report labels; exact comparison keys and optional inclusive bounds combined with geographic search; persisted filters, real filter counts, removable rating chip and empty-result recovery. Area/radius edits preserve ratings and filters.

Checks: 2 focused Swift tests pass (`/tmp/chess-phase7-check.log`); 14 assertions in the rating database file pass (`/tmp/chess-phase7-db.log`). Release build: `/tmp/chess-phase7-release.log`. `git diff --check` passes. No broad suite or UI journeys were run. The local 009 migration was applied without resetting accounts; its area-projection correction was applied directly from the same final migration definition. No hosted migration, commit or push.

