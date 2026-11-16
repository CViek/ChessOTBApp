# Phase 3 implementation record

Status: complete. No Phase 4 work, commits, staging, pushes or deployments.

## Confirmed decisions

- Swift uses Supabase Auth and its database APIs directly. No Python application backend or Vercel deployment.
- US area lookup only. Profiles publish chosen city/neighborhood names, not home addresses or device GPS coordinates. Saved centers are additionally rounded to two decimal degrees on the server (approximately kilometer scale); public projections omit coordinates.
- Saving a profile area opts into discovery. Nearby never implies immediate availability.
- First setup initializes both profile and search area. Later search changes preserve the public profile area; the profile editor changes that area explicitly.
- Radius defaults to 5 miles, with 3/5/10 choices. Public distances use rounded whole miles or “less than 1 mile.”
- Core Location permission only after an explicit tap; Apple MapKit resolves named areas; manual entry and explicit disambiguation remain available after denial or errors.
- Real results only, with self/out-of-range/no-area profiles excluded. Ratings, messaging, friendships and groups remain in later phases.

## Sequence

1. Failing tests for area validation, denial/ambiguity, search ordering and data-access boundaries.
2. Additive migration for private approximate areas/search settings and server-filtered, paginated public discovery.
3. Swift services, ViewModels and current MapKit/Core Location adapters.
4. Native onboarding/discovery/filters/player/profile-area screens using existing Figma F02/F03/F05/F06/F15 elements.
5. Database, unit, integration and UI tests; clean builds; independent review and fixes. Stop after Phase 3.

Existing user accounts must be preserved. Apply migrations to the current development database without resetting it; test migration-from-empty in a separate disposable local stack. Figma Make has source/CSS but unsupported screenshot tools, as recorded in Phases 1–2; no screenshot-fidelity claim is made.

## Verification record

- Watched missing database functions fail, then passed the isolated migration and pgTAP suite. Expanded boundary checks cover centers just inside/outside 3/5/10 miles and equal-band UUID pagination: 43 assertions pass.
- Area validation/denial/ambiguity and discovery loading/pagination/stale-response tests failed against stubs before implementation. HTTP service tests failed against missing implementations before being wired to RPCs. Area-selection tests failed before resolution/save behavior was implemented.
- First full Swift unit run: 46 tests passed. Two additional regression checks cover late area resolution and offline lookup recovery.
- Real local HTTP checks pass for auth regression, two-account discovery, self exclusion, coarsened centers, public DTO keys, denied direct table access and independent profile/search settings.
- Additive migration applied to existing development accounts with `migration up`; no reset. A separate native stack in `/tmp/chess-phase3-database` was used for migration/test fixtures.
- Release simulator build passes. Final UI and second-size validation results are recorded below.
- UI test harness corrections: native location alert belongs to SpringBoard; error banners expose their `account.error` identifier and an “Error:” accessible prefix. Neither needed a product behavior change.
- Toolchain workaround: explicit MainActor isolation on small test doubles avoids inferred `nonisolated` actor-initializer diagnostics in Xcode 27.1. Tests continue to control suspended requests deterministically.

## Local usage

Run `./tools/backend/start-local.sh` before launching the Debug simulator app. Existing accounts now continue from a saved display name into area onboarding. Search a US city/neighborhood, explicitly choose one of Apple's returned named areas, then save. Only the completed Discover and Profile tabs are present in this phase.

The discovery area control changes private search settings. Profile → Edit profile → Profile area changes the public discoverable area. First setup initializes both; later edits remain independent. Nearby profiles are never presented as immediately available.

For an existing database, use `./tools/backend/supabase.sh migration up`; do not reset a database whose accounts you want to keep. Automated SQL fixtures belong in a separate disposable local database. `python3 tools/backend/test-discovery.py` creates uniquely named local test accounts and runs the auth and discovery HTTP checks. It refuses any API URL other than `http://127.0.0.1:54321`. Local confirmation mail stays in Mailpit at `http://127.0.0.1:54324`.

## Independent review and correction pass

Fresh read-only reviewer: `/root/phase3_review`. No critical security issue found. Review identified repeated sheet values failing to trigger refresh, completed actions potentially replaying on reappearance, an obsolete pagination spinner after failed refresh, an older radius save replacing a newer area, and a UI fixture assuming the first page.

- Suspended pagination + failed refresh and delayed radius save + newer area were reproduced by failing unit tests. Corrected request-generation/loading-state handling; the entire 50-test unit suite passes afterward.
- Added real UI regressions for a tab return after widening and resaving an earlier area/radius pair. Test now searches/paginates for its uniquely identified fixture instead of assuming that random UUID sorts onto page one.
- Review exclusions: messaging/friends/ratings/groups/meetings and launch moderation/deletion/hosting remain their planned later work. A chosen area is a user declaration; this phase does not verify physical residence. Apple lookup guides legitimate selections, but the database validates a US country flag/name/coordinate range rather than verifying a claimed place against a trusted server geocoder. Figma pixel fidelity, physical-device location and manual VoiceOver reading are not claimed. Pending tests require actual author verification before completion.

Final UI harness findings were also resolved rather than hidden: the empty-state fixture city originally overlapped a public profile created by the new repeated-save test, so regression fixtures now keep their public area in New York and use separate private search areas. The empty journey uses Juneau. A smaller-device lookup failure was traced in its saved accessibility hierarchy to the actual input `Juneau, AKIN`: cursor-based backspacing left old letters. Exact-input assertions then showed that a scroll gesture crossing the keyboard swipe-typed “IN” after entry. The final helper preserves the previously verified clearing behavior, submits area lookup with the keyboard’s native Search key, and asserts the exact entered text before submitting. Real Apple lookup remains in use; no service response is substituted.

Populated/empty/loading/error previews were added for the new applicable screens, with injected environments and DEBUG-only services. Light/dark native screenshots and the very large text discovery/player flows have been inspected. A clean Release build excludes those services.


## Final evidence

- iPhone 18 Pro: 50 Swift tests in 13 suites and all four XCTest UI cases pass, zero failures or skips. UI cases cover real signup/confirmation/name setup, denial/manual lookup, real player navigation, pagination-safe fixture lookup, distance changes/widening, empty results, independent search/profile areas, preserved name drafts, tab-return action consumption, repeated saved settings, relaunch persistence, large text, appearance, two-account isolation and password recovery. Log: `/tmp/chess-phase3-final-validation.log`; result bundle: `/tmp/ChessOTBApp-Phase3/Logs/Test/Test-ChessOTBApp-2026.11.15_16-57-30--0500.xcresult`.
- iPhone 18 Pro Max: 50 Swift tests plus the expanded discovery/profile-area/large-text journey pass. Log: `/tmp/chess-phase3-final-max2.log`. Normal and large-text account entry also passed in `/tmp/chess-phase3-max.log`.
- Final Debug build: `/tmp/chess-phase3-debug-checked.log`. Clean Release build: `/tmp/chess-phase3-release-checked.log`. Both report BUILD SUCCEEDED; Release has no DEBUG preview-service symbols.
- Isolated migration-from-empty/additive migration and all 43 pgTAP assertions pass: `/tmp/chess-phase3-db-final.log`. Real auth/discovery API checks pass: `/tmp/chess-phase3-discovery-integration.log`.
- Review corrections verified RED→GREEN: obsolete pagination loading, delayed radius save vs newer area, completed action replay on tab return, and repeated sheet values. The final complete suite passes after those corrections. Fixture lookup now handles pagination without deleting accounts. No review findings remain unresolved.
- All extracted app strings are catalogued; Info.plist/privacy manifest parse successfully; shared app scheme and both test targets are listed; `git diff --check` passes. The final small loading-state badge correction was additionally compiled in both Debug and Release.
- No Python application backend, hosted deployment, future-phase functionality, staging, commit or push. Existing development accounts were preserved. Local integration/UI checks create uniquely named test users; they are development fixtures, not shipped sample results.

The confirmed scope and architecture were retained. Apple city/neighborhood lookup, server-side two-decimal center rounding, private independent search settings and whole-mile public distance bands implement Q3. Native recovery/disambiguation states use the approved existing visual language. No physical-device GPS test, manual VoiceOver reading, or exact Figma screenshot fidelity is claimed. Phase 4 has not started.
