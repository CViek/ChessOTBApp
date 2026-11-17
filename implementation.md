# ChessOTB Implementation Plan

## App summary and source of truth

ChessOTB is a free iOS app for people who want nearby opponents for in-person chess. Its core journey is **set an area → find a player → message → propose a time and place → receive explicit agreement → reconnect**. A nearby profile does not imply availability; a message does not book a game. Players choose the location themselves, without a hosted event or venue reservation.

The cumulative releases are:

- **MVP1, through Phase 6:** accounts, approximate local discovery, profiles, persistent conversations, reviewed proposals, acceptance, decline, revision, cancellation, and My Meetings.
- **MVP2, through Phase 7:** one optional self-reported rating and filters that compare the same rating system.
- **MVP3, through Phase 9:** mutual friendships, repeat arrangements, and nearby group listings with a designated contact.
- **Phase 10:** release verification and the launch decisions needed for a usable distribution.

**Sources read:** [CLAUDE.md](CLAUDE.md), [project_description.md](project_description.md) in full, and the [ChessOTB Figma Make project](https://www.figma.com/make/rTehrTBTS9tjgoMym5KS0U/Design-ChessOTB-iOS-App). The supplied description path resolves to `project_description.md`. The supplied placeholder `[App Name]` is resolved by the description's explicit name, **ChessOTB**.

**Precedence:** Figma controls layout, visual styling, and screen structure. The description controls behavior, data, and business rules. `CLAUDE.md` controls native implementation standards. Missing designs and conflicting requirements are recorded below; they are not permission to invent screens.

**Inspection date:** November 13, 2026. The repository contains planning documents and no existing app target. Local tools report Xcode 27.1 and iOS/iOS Simulator SDK 27.1, compatible with the project's iOS 27.0 minimum. No app code, project scaffolding, dependencies, or backend have been created by this plan.

## Figma evidence and screen inventory

Figma MCP `get_design_context` successfully accessed Make file `rTehrTBTS9tjgoMym5KS0U` using its supported Make root `0:1`. It returned `src/App.tsx`, `src/index.css`, `DESIGN_NOTES.md`, `MVP_COVERAGE.md`, package metadata, and image resources. References below are **Make component names and CSS selectors**, not invented Design-frame IDs. All component references refer to that linked Make project.

**Inspection limits:** `create_session` explicitly rejected Make files. The advertised `get_screenshot` and `get_variable_defs` tools do not support Make; no screenshot or variable-collection verification is claimed. Tokens are extracted from the actual CSS and design notes. Two reads of `src/App.tsx` returned a literal truncation marker spanning part of `ReviewProposal` and the opening of `MeetingDetail`. Their existence, navigation, retained content, and styles are evidenced, but the missing markup must be recovered through Figma before implementing those portions. The accessible source is sufficient to plan the surrounding work without guessing the omitted layout.

| ID | Screen / Figma component | Purpose, visible structure, and states | Phase |
| --- | --- | --- | --- |
| F01 | Account Setup — `Setup`, step 0 | Board mark, introduction, display-name field, public-profile privacy explanation, disabled continue for blank name. | 2 |
| F02 | Search Area and Distance — `Setup`, step 1 | Approximate-area explanation; current-location, manual-entry, and Not now actions; manual city/neighborhood and 3/5/10-mile selector; location-off notice. | 3 |
| F03 | Nearby Players — `Discovery`, players mode | Brand/title, Players/Groups segment, area/radius button, filter button/badge, applied chips, player rows; results, skeleton loading, and recoverable empty states. | 3, 7 |
| F04 | Nearby Groups — `Discovery`, groups mode | Same discovery structure, group glyph/listing rows, approximate area/distance and description; results, loading, empty. | 9 |
| F05 | Player Profile — `PlayerProfile` | Initials avatar, name, approximate proximity, rating or unrated block, profile note, availability disclaimer, Message to Arrange a Game, friendship states. | 3, 4, 7, 8 |
| F06 | Search Filters — `Filters` | Distance, source, minimum/maximum, same-source disclosure, Clear, Show Matching/All Players; active and cleared states. | 3 distance only; 7 ratings |
| F07 | Inbox — `Inbox` | Conversation rows with avatar, preview, timestamp, unread indicator; empty state. | 4 |
| F08 | Conversation — `Conversation` | Back/title/avatar, Propose a Game strip, discussion disclaimer, incoming/outgoing bubbles, date divider, proposal slip, composer/send and an unwired attachment affordance. | 4–6 |
| F09 | Meeting Proposal — `ProposalForm` | Opponent, date/time controls, explicit time zone, specific location, optional note, venue disclaimer, Review Proposal; inline missing-location error. | 5, 6 |
| F10 | Review Proposal — `ReviewProposal` | Review title, recipient context and notation-card styling; send routing is present. Part of markup is truncated; CSS includes send-error/retry styling. Recover complete layout before implementation. | 5 |
| F11 | Meeting Detail — `MeetingDetail` route and retained JSX | Status banner, participants, date/time/zone, location, note, role-dependent actions; pending, confirmed, declined, cancelled, and change-awaiting-agreement with old/new details. Opening markup is truncated. | 5, 6 |
| F12 | My Meetings — `Meetings` | Upcoming/History segments; status strip, date stamp, opponent, time and place; empty upcoming/history. | 5, 6 |
| F13 | Friends and Friend Requests — `Friends` | Requests are cards within Friends, not a separate designed route. Accept/Decline and accepted-friend rows leading to conversation. | 8 |
| F14 | Own Profile — `Profile` | Identity, approximate area/rating summary, edit row, dark-appearance toggle, privacy footnote; prototype-only notes/reset rows. | 2, 7 |
| F15 | Edit Profile — `EditProfile` | Display name, approximate area, optional rating source/value, Remove rating, self-report disclosure and Save. | 2 basic fields; 3 area; 7 ratings |
| F16 | Group Detail — `GroupDetail` | Group glyph/name/area, description, designated-contact card, Message Contact, sample introduction/profile link, listing-only scope note. | 9 |
| F17 | Prototype Notes — `DesignNotes` | Device assumptions, design rationale, signature, coverage and self-review. Documentation/debug reference, not a proposed customer feature. | Reference only |

### Navigation

- Setup precedes the main app. Main tabs are **Discover, Inbox, Meetings, Friends, Profile**, in that order. The prototype shows tabs only at destination roots.
- Discover → Player Profile → Conversation → Meeting Proposal → Review Proposal → Meeting Detail. Meeting Detail also opens from a conversation slip or My Meetings.
- Discover → Search Filters; the area button must open the existing F02 area workflow when wired. Groups uses the Discover segment, then Group Detail → designated-contact conversation or an actual introduced player's profile.
- Inbox → Conversation. Friends → existing Conversation → a fresh proposal. Profile → Edit Profile or dark appearance.
- Use native `TabView` and value-based `NavigationStack` destinations. Preserve the source screen and selected person on back navigation; the prototype's unconditional return-to-root callbacks are not the required product behavior. A conversation must retain a path to the counterpart's profile.

### Reusable components and state coverage

| Component / source | Reuse and states |
| --- | --- |
| `Button`, `TopBar`, `TabBar`, `.segmented` | Primary, secondary, quiet, danger; disabled/pressed; selected tab/segment; unread badge. Native navigation supplies system behavior. |
| `Avatar`, `.player-row`, `.group-row`, `.row-copy` | Initials at three sizes, four tones; rated/unrated rows; context-specific profile, inbox and friend rows. |
| `.area-button`, `.filter-button`, `.active-filters` | Area/distance summary, applied-filter count, removable filter chips. Counts and chips must reflect real state. |
| `.loading-list`, `.skeleton-row`, `.empty-state`, `.notice` | Discovery loading, no results and recovery; inbox/meeting empty states; location-off and filter-cleared notices. |
| `.bubble`, `.composer`, `.proposal-slip` | Incoming/outgoing text, empty/nonempty composer; pending/confirmed/declined/cancelled/replacement proposal summaries. |
| `.notation-card`, `.status-banner`, `.previous-details`, `.meeting-card` | Review, explicit agreement status, retained accepted details, proposed replacement, upcoming/history summaries. |
| Form fields, `.field-error`, `.send-error` | Normal/focused/error fields, optional note, inline location validation, send-error styling. Some send-error markup is unavailable. |
| `.request-card`, `.contact-card`, `.introduction-card` | Incoming friend request, accepted contact, group contact and introduction. Outgoing-request text also exists on Player Profile. |

General network errors, stale/offline state, auth recovery, friend removal, and some empty/request states are **not fully designed**. Reuse evidenced components only where their layout is sufficient; obtain Figma coverage for missing screens or materially different states before implementing their UI.

## Design tokens and assets — establish in Phase 1

The selected direction is **Quiet notation**: pale paper, dark green ink, restrained social accents and proposal cards resembling notation slips. CSS is the most concrete visual reference where the prose notes differ.

| Semantic token | Light | Dark |
| --- | --- | --- |
| Paper/background | `#F5F4EF` | `#13201E` |
| Surface | `#FFFEF9` | `#1B2B28` |
| Ink | `#172724` | `#F3F0E7` |
| Muted text | `#66736F` | `#AEBBB6` |
| Divider/border | `#D8DDD8` | `#354743` |
| Forest/action | `#24463F` | `#B9D5C7` |
| Forest secondary | `#1D3934` | `#D6E7DF` |
| Oxblood/social accent | `#9B4039` | Inherits light value |
| Sage/secondary surface | `#DBE5DC` | `#2C413B` |
| Amber/pending | `#E3A94B` | Inherits light value |
| Success | `#2F6E55` | `#83C6A3` |
| Danger | `#A23F39` | Inherits light value |

- **Typography:** Newsreader 600/700 for identity, titles and meeting moments; DM Sans 400/500/600/700 for controls and coordination text. Bundle licensed fonts rather than loading Google Fonts at runtime. CSS uses setup title 39, large-list title 36, player title 32, group title 31, section title 24, status/empty title 25, and body/supporting text mostly 12–17. The design notes' generic screen-title value of 32 is not the CSS value of 36 for `.large-header h1`. Create semantic, Dynamic Type-scaled styles, not fixed native font sizes.
- **Spacing:** named base scale 4, 8, 12, 16, 22, 28; common page inset 22 and setup inset 28. Preserve documented component exceptions such as 18-point meeting-list margins. Reference viewport is 390 × 844, not a hardcoded application size or a verified device model.
- **Corners:** actions 12; fields 10; segmented container/selection 9/7; area/filter controls 11; meeting cards 12; previous-details card 8; compact proposal slip 3. Preserve message-tail radii and asymmetric group-glyph corners. Circular shapes are for people and compact controls.
- **Sizing:** default primary button/field minimum height 50; icon controls 44; area/filter controls 56; avatars 40/56/90. Some prototype chips/segments/retry controls are only 32–38 high: retain visual proportions while expanding the native accessible hit area to at least 44 × 44 points.
- **Avatar tones:** sage `#CBDCCF`, clay `#E4C9B8`, blue `#C9D8DF`, gold `#EAD8A9`, with dark ink initials. These are initials treatments, not photographs.
- **Notation surfaces:** `#FFFDF4` with ink `#172724`; slip border `#D8D2BD`, review border `#D4CDB5`. Review shadow corresponds to offset 0/12, blur 30, dark green at 12% in light appearance and black at 28% in dark; slip shadow 0/5, blur 12 at 8%. The source uses slight rotations of −0.4° and −0.3°. These remain distinct from system navigation surfaces.
- **Status:** always pair text with tint/icon. Source banner tint proportions are pending 15%, confirmed 13%, declined/cancelled 10%, replacement 10%; meeting-card strips use 20%, 18%, and 15% respectively. Never communicate agreement using color alone.
- **Motion:** brief button feedback and loading pulse appear in CSS. Respect Reduce Motion; do not add an animation system.

**Asset inventory:** `Icon` defines 17 inline line icons: discover, inbox, meetings, friends, profile, chevron, back, pin, tune, send, plus, clock, check, close, moon, info and people. Icons use a 24 × 24 view box, 1.8 stroke and rounded joins/caps. Preserve the supplied vectors through native-compatible asset export, using system equivalents only if visually exact. Board marks, area-orbit rings, empty-state rings, initials and group glyphs are code-native artwork; implement their observed geometry with native shapes. Do not reproduce the web phone frame, fake status bar, sensor or home indicator.

The Make resource manifest also exposes `public/favicon.png` and four PNG resources (`513c096…`, `64669ae…`, `b93d4f0…`, `c11d998…`). No image import or slot for them appears in the retrieved app/CSS. Two rendered as flat backgrounds; two could not be visually processed. Their app use is unverified: do not assign them invented roles. A production iOS app icon and final font-license files still need confirmed assets. No camera, photo library, avatar upload, map illustration or AI asset pipeline is specified.

## Reconciliation: mismatches and open questions

### Feature differences and prototype gaps

| Difference | Required treatment |
| --- | --- |
| Description requires actual accounts and persistence; Figma uses local React state and sample identities. | Add a real authenticated shared backend. Auth entry/recovery/sign-out UI has no complete Figma reference; resolve Q1 before Phase 2. |
| Description requires editable area/distance and location-denial fallback. Figma shows these controls, but current location simply finishes setup, the discovery area button has no handler, and empty recovery just restores samples. | Wire genuine permission/geocoding/discovery behavior in Phase 3 using the existing area layout. Never fabricate nearby users. |
| Description requires persistent messaging and a route back to profile. Prototype messages reset on remount, some inbox rows are inert, and the header avatar is not a profile link. | Persist per-conversation messages, route every real row, and make the existing header identity open the correct profile. |
| Review is a distinct Figma screen; the description includes review as part of proposing. | Keep the separate Review Proposal screen. Recover its missing source before Phase 5. |
| Prototype uses one global meeting status, fixed Alex/date/place, and an actor-switch control. | Use authenticated participants, multiple meeting IDs, actual entered details and server authorization. Actor switching belongs only in test fixtures. |
| Figma adds a `revised` presentation state. Its decline-change handler marks the whole meeting declined; accept-change does not persist replacement fields. | Model a pending replacement separately from the accepted revision. Preserve the accepted plan until a replacement is accepted; declining a change preserves that agreement. See Q4 for other replacement policies. |
| Description allows either participant to cancel; Figma exposes Cancel only while confirmed. | Include pending cancellation/withdrawal behavior and authorization in Phase 6; obtain its missing control placement. |
| Description does not equate past meetings with played games. Prototype History contains only declined/cancelled arrangements and fixed dates. | Classify actual past arrangements without manufacturing attendance, scores or rating updates. Resolve unanswered-past handling in Q4. |
| Description allows a named rating source, with systems/time controls open. Figma fixes Chess.com, Lichess, US Chess and sample range 1300–1600. | Optional source-aware rating remains required; exact supported systems/formats need Q5. Filters and profile edits must persist and change real results. |
| Description names Friend Requests as a screen; Figma places request cards within Friends. Prototype decline is inert, state is disconnected from profile requests, and remove-friend UI is absent. | Preserve the single Friends destination; implement mutual request lifecycle and removal, obtaining the missing states/control placement before Phase 8. |
| Description requires messaging the designated group contact. Prototype always routes to Sam regardless of displayed Maya/Theo contact. | Resolve contact by stored user ID. Do not treat sample introduction text as a real introduction. Group listing ownership and introduction supply require Q6. |
| Figma includes profile bio text, initials/color avatars, unread dots, appearance toggle, Upcoming/History and a sample-introduction card, beyond the description's minimum detail. | Preserve evidenced presentation. Bio authoring, unread semantics, appearance persistence and introductions are explicit decisions below; avoid inventing an editor or introduction workflow. |
| Figma includes an attachment button, preview-state links, persona switching, restart setup and Prototype Notes. Description requests no attachments or such customer features. | Preview/debug controls stay outside production. Attachment behavior is unscoped; obtain a Figma revision removing it or defining it before shipping Conversation. No camera/media permission follows from the icon. |
| Product operations mention notifications, privacy, blocking/reporting as unresolved. Figma has no complete flows. | Resolve scope before external launch and design any chosen flows. Do not silently add push, moderation or privacy screens. |
| CSS and notes disagree on title scale; CSS uses undersized hit targets and fixed phone chrome, whereas `CLAUDE.md` requires native adaptive controls. | Use measured CSS typography, native system chrome and accessible hit areas. Record visual compromises in the Figma acceptance review. |
| Light notation surfaces inherit pale dark-mode action/success colors in places. | Verify contrast with a recovered visual reference; obtain a design-token correction where necessary, rather than quietly changing the palette. |

### Decisions still needed

These are explicitly unresolved decisions, not assumptions already approved. They block only the dependent scope; earlier independent phases can proceed. Resolve them at the named phase entrance and update this document before executing that phase. Missing screen structure must be supplied through Figma.

| ID | Open question and proposed direction | Resolve before |
| --- | --- | --- |
| Q1 | Which backend/project owner, region and authentication method should be used? Confirmed for Phase 2: Supabase/PostgreSQL plus Supabase email/password authentication, recoverable sessions and sign-out. User has no Apple Developer membership, so Sign in with Apple is excluded. Hosted provisioning remains to be supplied; local isolated development may proceed. Retain the current simulator bundle ID. No Apple team is needed for local simulator development. User approved necessary native account layouts; hosted project ownership, region and provisioning remain deployment decisions. | Phase 2 |
| Q2 | Confirmed November 16 for Phases 4–6: user approved completing truncated Review Proposal/Meeting Detail and missing states with native controls matching existing design tokens. Make source remains available; Make screenshot/session calls remain unsupported, so no exact screenshot-fidelity claim is made. | Phase 4–6 resolved; later phases retain their design gates |
| Q3 | How coarse is public location; does editing search area also change the discoverable profile area; how does a user become open to contact? Confirmed for Phase 3: US locations only; explicitly saved city/neighborhood profile areas opt into discovery; independently adjustable search area; no raw GPS stored in Supabase or shown to players; distances computed from approximate centers and displayed as rounded whole miles or less than 1 mile. Default radius 5 miles. User-approved correction: slider and editable whole-mile value from 1 to 100. On-demand location permission, Apple area lookup, manual fallback and explicit ambiguous-area selection. First area save initializes profile and search; later search changes do not alter the profile area. | Phase 3 |
| Q4 | Confirmed November 16: new proposals/replacements use future instants; past pending proposals cannot be accepted and appear in History without expiry/attendance claims. One outstanding replacement; either participant proposes and only the counterpart responds. Declining preserves the accepted plan. Stale mutations conflict; cancellation clears the replacement. Native cancellation action uses the detail action group and confirmation dialog for pending/confirmed meetings. | Phases 5–6 resolved |
| Q5 | Phase 7 implementation defaults: one optional self-reported entry; Chess.com rapid/blitz/bullet, Lichess rapid/blitz/bullet/classical, US Chess regular/quick/blitz; whole numbers 1–4000. A single native picker names the exact source and format. No custom-source workflow, conversion or provider integration. Defaults are documented implementation choices for the requested minimal scope. | Phase 7 implemented |
| Q6 | Phase 9 implementation defaults: operator-maintained verified listings through private database import/update/removal, no in-app administration. Contacts require live accounts and operator verification/consent. Introduction text and profile links require approved records; absent introductions omit the card. These are implementation choices for the requested minimal scope; Figma Make's sample introduction is not production data. See docs/group-listing-operations.md. | Phase 9 implemented |
| Q7 | Confirmed November 16: text-only messaging; visible active chat refreshes every 1 second, visible active Inbox every 3 seconds, plus pull-to-refresh. Stop polling when hidden, inactive or signed out. Background push remains deferred. | Phase 4 confirmed; Phase 10 delivery scope |
| Q8 | What are launch privacy/contact controls, blocking/reporting, moderation ownership, account deletion and retention rules? Confirm required scope and Figma flows; the description lists these as unresolved, not preapproved functionality. | Before external user testing; implement chosen launch requirements in Phase 10 |
| Q9 | Confirmed: generated initials, existing sage avatars, persistent dark toggle; no photos, images, attachments or bios. Remove the attachment affordance from text-only chat. | Phase 4 confirmed |
| Q10 | What is the launch area, distribution target, operating budget/owner, final app icon and font licensing source? No revenue features are planned. | Phase 1 font assets; Phase 10 distribution |

## Technical approach

**Planning status:** this is the requested plan, not approval to implement. Superpowers brainstorming informed the product reconciliation and alternatives; writing-plans informed sequencing and verification. Open decisions are listed here rather than resolved through an unsolicited implementation. For later execution, use `superpowers:executing-plans` or an explicitly chosen `superpowers:subagent-driven-development` workflow, one phase at a time.

**Approaches considered:**

1. **Recommended baseline — native SwiftUI plus a managed relational backend.** It keeps shared conversations and transactional meeting agreement authoritative while limiting infrastructure work. Supabase is a concrete candidate because its documentation covers [row-level access rules](https://supabase.com/docs/guides/database/postgres/row-level-security), [database functions](https://supabase.com/docs/guides/database/functions), and [native Apple authentication](https://supabase.com/docs/guides/auth/social-sign-in/auth-apple). The user selected Supabase for Phase 2, including its email/password authentication instead of Sign in with Apple.
2. **Alternative — native SwiftUI plus a dedicated custom API and PostgreSQL.** It offers more server implementation control but introduces a separate server application, deployment and operations. Choose it if an existing service/team requires it; update backend paths and verification commands before Phase 2.

The phase paths below use the recommended Supabase baseline to make the work concrete. Do not build both backends. An entirely local app cannot satisfy communication and shared agreement between two real users.

### Native structure and ownership

- `ChessOTB/App/`: `ChessOTBApp.swift`, `RootView.swift`, `AppDependencies.swift`, `AppRoute.swift`, `SessionViewModel.swift`. The app owns a single global session instance and injects it with Observation; feature ViewModels remain feature-owned.
- `ChessOTB/Features/`: `Account`, `Discovery`, `Players`, `Messaging`, `Meetings`, `Profile`, `Friends`, `Groups`. Each contains its own `Views`, `ViewModels`, `Models`, and service implementations as needed. Do not create empty future modules in advance.
- `ChessOTB/Core/Networking/`: `APIClient.swift`, `APIError.swift`; injected `URLSession`, Codable requests/responses, checked HTTP status, explicit cancellation and typed failures.
- `ChessOTB/Core/Persistence/`: SwiftData cache and account-scoped draft storage, added only when consumers need them. `Core/Security/KeychainStore.swift` holds session secrets. `Core/Location/AreaService.swift` contains device/geocoding work, not view logic.
- `ChessOTB/Shared/Constants/DesignTokens.swift`, `Shared/Components/`, and `Resources/{Assets.xcassets,Fonts,Localizable.xcstrings,PrivacyInfo.xcprivacy}` hold reused design resources.
- `ChessOTBTests/Features/<Feature>/` mirrors feature tests; `ChessOTBUITests/` contains critical journey tests. `supabase/migrations/` and `supabase/tests/` add schema, transaction functions and authorization tests in the phase that owns them.

Use Swift 6 strict concurrency and iOS **27.0+**. Feature ViewModels are `@MainActor final class`, `ObservableObject`/`@Published`, owned using `@StateObject` and passed using `@ObservedObject`; global session uses `@Observable` and `@Environment(Type.self)`. No `@EnvironmentObject`, state singletons, business logic in views, or SwiftUI imports in ViewModels. Inject protocol-based services; begin I/O from lifecycle tasks, not initializers. Use actors or nonisolated asynchronous work for expensive operations. All cross-actor value models are `Sendable`.

Use SwiftData for local cache/drafts and preferences for appearance/filter choices; the **server remains authoritative** for accounts, messages, friendship and meeting agreement. Keychain stores credentials. Never put privileged server credentials into an iOS bundle, including through `.xcconfig`; bundle only nonprivileged configuration, with environment URLs in `.xcconfig`. Do not implement a general offline write/synchronization framework.

### Data and service boundaries

Define each model/interface only in its owning phase. IDs are stable UUIDs, times are server timestamps/absolute instants, and paginated results use opaque cursors. Method names below establish contracts; DTO details belong beside their feature.

| Phase | Main contracts and invariants |
| --- | --- |
| 2 | `AuthServiceProtocol`: sign in, restore and sign out. `ProfileServiceProtocol`: read/save own profile and read permitted public profile. Public `PlayerProfile` excludes auth identifiers and private location data. |
| 3 | `AreaServiceProtocol.resolve(query:) async throws -> [AreaCandidate]`; optional device-location resolution returns an approximate area. `DiscoveryServiceProtocol.searchPlayers(query:cursor:) async throws -> PlayerPage`. `SearchQuery` carries center/radius; rating criteria arrive only in Phase 7. |
| 4 | `ConversationServiceProtocol.openConversation(with:)`, `listConversations(cursor:)`, `loadMessages(conversationID:cursor:)`, `sendMessage(conversationID:text:clientID:)`, and `markRead(conversationID:through:)`, all async throwing. One thread per unordered user pair; participant-only access, stable message IDs and retry deduplication. |
| 5 | `MeetingServiceProtocol.propose(conversationID:draft:requestID:)`, `respond(meetingID:revisionID:decision:expectedVersion:)`, `meeting(id:)`, `listMeetings(cursor:)`, all async throwing. `MeetingDraft` carries instant, time-zone identifier, location and optional note; `MeetingDecision` is accept/decline. |
| 6 | Add `proposeReplacement(meetingID:draft:expectedVersion:requestID:)` and `cancel(meetingID:expectedVersion:)`. `Meeting` points to accepted and/or pending revision IDs; immutable `MeetingRevision` records retain author, recipient and actual agreed fields. |
| 7 | `RatingEntry` is optional and contains value plus a canonical comparison key for source/format. `RatingCriteria` contains that key and optional inclusive bounds. No cross-system conversion or verification API. |
| 8 | `FriendshipServiceProtocol`: request, respond, list incoming/outgoing/accepted, remove. Pair uniqueness and server-enforced actor roles; friendship does not grant meeting acceptance. |
| 9 | `GroupServiceProtocol.searchGroups(query:cursor:)` and `group(id:)`. `GroupListing` contains approximate area, description, designated contact's user ID and only genuine, approved introduction references. |

Meeting operations must be database transactions: validate actor, state, revision and expected version; apply the mutation; append its conversation event atomically. A retry must not create another proposal/event. A stale action refreshes the authoritative record instead of overwriting a later decision. The proposer cannot accept their own proposal. Authenticated nonparticipants cannot read or change a thread or meeting.

**Meeting semantics:** initial send creates Pending; recipient acceptance creates Confirmed; recipient decline creates Declined; participant cancellation creates Cancelled. A replacement is a Pending revision attached to an existing agreement, not a fifth terminal meeting status. Acceptance switches the agreed revision atomically; rejection of the replacement does not erase the previous acceptance. A past Confirmed record remains an agreement, never proof of a game, score or rating update.

**Location and platform APIs:** use on-demand Core Location and MapKit area lookup behind services, with manual entry always available. No map screen is present in Figma. Keep precise device coordinates out of public DTOs, logs and analytics. No camera, AI, engine, digital chessboard, venue booking, subscriptions, tournaments or external rating synchronization belongs to this plan.

## Verification rules for every phase

- A phase begins only after its dependencies and listed decision/design prerequisites are satisfied. Implement only that phase. Future destinations may be unavailable in internal builds; do not add fake success behavior or ship misleading placeholders. The final navigation retains Figma's five tabs.
- Add Swift Testing tests for domain rules and ViewModels with injected fakes. For a new business rule, observe the meaningful failing test before implementing it. Use XCTest for critical UI flows, not for duplicating SwiftUI internals. Use backend transaction/access tests whenever shared data changes.
- Every view gets previews for applicable populated, empty, loading and error states, with required global environments injected. Check light/dark, Dynamic Type, VoiceOver, keyboard/safe areas, minimum tap targets and at least two available simulator sizes as the screen is added. Verify rendered output against actual Figma references; do not claim screenshot fidelity without a recovered render.
- After each phase, run a clean build, that phase's focused tests and the existing relevant suite. No phase is done with compile/test failures. Capture results in that phase's change review; checkpoint only its files. Backend fixtures must be isolated from real user data.

Once Phase 1 creates the shared `ChessOTB` scheme, use these baseline checks, substituting a real simulator ID reported by Xcode:

```sh
xcodebuild -list -project ChessOTB.xcodeproj
xcodebuild -showdestinations -project ChessOTB.xcodeproj -scheme ChessOTB
xcodebuild -project ChessOTB.xcodeproj -scheme ChessOTB -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ChessOTB.xcodeproj -scheme ChessOTB -destination 'platform=iOS Simulator,id=<available-simulator-UUID>' test
```

Expected evidence: the app/test schemes are listed, build exits successfully with `BUILD SUCCEEDED`, and tests finish with zero failures. Do not copy the placeholder UUID into a claimed result. For the chosen Supabase baseline, Phase 2 establishes a pinned local toolchain and uses `supabase start`, `supabase db reset --local`, and `supabase test db`; resets apply **only to the disposable local test database**. Each backend phase must pass migration-from-empty and its database tests. Auth-provider staging checks supplement local tests.

### Review focus

1. **Cross-account data exposure or stale responses after sign-out:** server authorization plus account-scoped cache/session cancellation tests, Phases 2 and 4.
2. **Duplicate/reordered mutations or concurrent acceptance/cancellation:** idempotency and version-conflict tests, Phases 4–6.
3. **Different device zones, DST gaps/overlaps and past dates:** round-trip/date-validation tests, Phases 5–6; never show different instants as one agreed time.
4. **Denied location, ambiguous manual areas or stale search responses:** fallback and request-ordering tests, Phase 3.
5. **Unrated people, mixed sources/formats and inverted bounds:** filtering/validation tests, Phase 7; no silent cross-system comparisons.

## Phase 1 — Native foundation and verified visual primitives

**Goal:** Establish a buildable SwiftUI app and the reusable visual foundation without implementing future features.

**Dependencies / entrance decisions:** `CLAUDE.md`; available Figma tokens/components; Q2 for any unverified primitive and Q10 for font assets. Do not block verified base colors/layout on the truncated meeting screen.

**Scope and main files:** `ChessOTB.xcodeproj`; `ChessOTB/App/{ChessOTBApp,RootView,AppDependencies,AppRoute}.swift`; `Shared/Constants/DesignTokens.swift`; `Shared/Components/{PrimaryButton,InitialsAvatar,StateNotice}.swift`; resource catalogs/fonts/privacy manifest; test and UI-test targets. Navigation contains only currently implemented destinations; use preview galleries for isolated components, not customer demo screens.

**Figma references:** `TabBar`, `TopBar`, `Button`, `Avatar`, `.notice`, `DESIGN_NOTES.md`, full `src/index.css` token declarations. Native system status/navigation chrome replaces only the prototype's browser/device simulation.

**Sequential work:**

- [ ] Create the app/schemes with iOS 27.0 and Swift 6 strict concurrency; establish feature-oriented groups and simulator launch.
- [ ] Add semantic light/dark colors, scaled fonts, spacing/radii, approved icon assets and the small shared components already needed. Record provenance and unavailable assets; do not download or add unrelated images.
- [ ] Create the app composition/navigation foundation, localized strings and preview fixtures. Do not add networking, database schemas or feature ViewModels prematurely.
- [ ] Run baseline build/launch checks and inspect component previews with accessibility settings.

**Definition of Done:** Clean checkout builds and launches; resources load locally; tokens match the inspected source; native controls work at different sizes; no fake content is presented as live data. Missing visual references remain documented rather than fabricated.

**Verification:** One UI launch smoke test; no low-value unit tests for constant color values. Manually inspect 390 × 844 reference proportions and a second size, light/dark, large text, VoiceOver labels, 44-point hit targets and missing-font behavior. Confirm no hardcoded web phone frame or copied status bar.

## Phase 2 — Real identity and basic profile ownership

**Goal:** Give each real user a recoverable identity and a persisted basic profile.

**Dependencies / entrance decisions:** Phase 1; Q1 auth/provider/ownership and Figma auth coverage; Q9 profile fields; clarify account deletion/retention expectations in Q8 before real external accounts are collected.

**Scope and main files:** `Features/Account/{Views/AccountSetupView,ViewModels/AccountSetupViewModel,Services/AuthService}.swift`; `Features/Profile/{Views/ProfileView,Views/EditProfileView,ViewModels/ProfileViewModel,Models/PlayerProfile,Services/ProfileService}.swift`; `App/SessionViewModel.swift`; `Core/{Networking/APIClient,Networking/APIError,Security/KeychainStore}.swift`; environment `.xcconfig` files; `supabase/migrations/001_profiles.sql`; account/profile tests. Basic profile editing includes display name; area completion belongs to Phase 3 and ratings to Phase 7.

**Figma references:** F01, F14, basic fields of F15; User explicitly approved adding the necessary native account screens in the established visual style. Use email/password entry, email confirmation/recovery codes, and sign-out; preserve F01/F14/F15 layouts for the evidenced profile elements.

**Sequential work:**

- [x] Establish the chosen backend's isolated development environment, authentication configuration and profile migration with owner-only writes and restricted public reads.
- [x] Test restore/sign-out, invalid display name, failed save, unauthorized profile update and nonprivileged configuration before implementing service/ViewModel behavior.
- [x] Implement authenticated session lifecycle, Keychain storage, basic profile save/load and appearance preference. Keep onboarding incomplete until an area is saved in Phase 3.
- [x] Connect the approved native screens; persist only successful changes, preserve edits on failure, and verify with two independent accounts.

**Definition of Done:** Relaunch restores the correct account/profile; another account cannot edit it; sign-out clears credentials and account state. Public profile responses contain only intended public fields. Network failures never masquerade as a completed save. No disposable anonymous identity is presented as a finished account strategy.

**Verification:** Swift Testing `SessionViewModelTests`, `ProfileViewModelTests`, `APIClientTests`; URLSession stubs for non-2xx, malformed response and expired session. Backend tests prove owner/other/unauthenticated access behavior. Manual first sign-in, cancellation, restore, sign-out/re-sign-in and two-account isolation; run baseline build/test commands.

## Phase 3 — Area selection, nearby discovery and player profiles

**Goal:** Complete onboarding and let real users find actual nearby people using a chosen area and distance.

**Dependencies / entrance decisions:** Phase 2; Q3 privacy, search/profile area distinction, units/rounding and geocoding behavior. Obtain Figma coverage for ambiguous-area selection and permission/service failures if existing components cannot express them.

**Scope and main files:** `Core/Location/AreaService.swift`; `Features/Discovery/{Views/SearchAreaView,Views/NearbyPlayersView,Views/SearchFiltersView,ViewModels/DiscoveryViewModel,Models/SearchQuery,Services/DiscoveryService}.swift`; `Features/Players/{Views/PlayerProfileView,ViewModels/PlayerProfileViewModel}.swift`; account/profile area integration; `supabase/migrations/002_discovery.sql`; discovery/location tests.

**Figma references:** F02, F03, F05, distance portion of F06; `.area-button`, filter chips, skeleton rows and empty-state recovery. Rating controls and Groups remain unavailable until their owning phases.

**Sequential work:**

- [x] Test permission denial, manual resolution/ambiguity, radius boundaries, stale response cancellation and privacy projection. Define approximate-area storage/search using the resolved Q3 policy.
- [x] Implement manual area entry and optional device-location lookup; request location only when tapped. Save the user's explicitly chosen profile area and search settings without exposing raw GPS.
- [x] Implement paginated distance search, deterministic ordering, self exclusion, 1–100-mile slider/numeric controls, actual applied chips, loading/failure/empty recovery and public profile navigation.
- [x] Wire the discovery area button and empty recovery to real settings changes. Complete onboarding only after a valid area/profile save.

**Definition of Done:** Two accounts in the chosen radius can discover each other; out-of-range/self profiles do not appear; changing area/radius changes results. Denial still permits full manual discovery. Empty results remain empty until a real query produces matches. Profiles never claim immediate availability.

**Verification:** `AreaServiceTests`, `DiscoveryViewModelTests`, geospatial boundary and public-column access database tests. UI flow: name → decline location → manual area → browse → profile → back. Manually check denied/restricted location, offline lookup, ambiguous input, rapid area changes, loading, zero results and wider-distance recovery. Run baseline checks.

### Approved distance correction after Phase 3

The user replaced the original 3/5/10 presets with a slider and editable whole-mile radius from 1 to 100, retaining the 5-mile default. Migration `003_dynamic_distance.sql` preserves existing data and expands server validation and pagination. Subsequent, unimplemented migration filenames advance by one; Phase 4 uses `004_messaging.sql`.

## Phase 4 — Persistent inbox and direct conversations

**Goal:** Let two authenticated people exchange and revisit real text messages.

**Dependencies / entrance decisions:** Phase 3; Q7 foreground update contract; Q9 attachment disposition and any bio-source decision; missing messaging failure states through Q2.

**Scope and main files:** `Features/Messaging/{Views/InboxView,Views/ConversationView,ViewModels/InboxViewModel,ViewModels/ConversationViewModel,Models/Conversation,Models/Message,Services/ConversationService}.swift`; `Core/Persistence/{AccountCache,MessageDraftStore}.swift`; `supabase/migrations/004_messaging.sql`; messaging/access tests. No proposal sending yet; add the proposal strip's action in Phase 5.

**Figma references:** F07/F08, F05 Message action, `Avatar`, `.bubble`, `.composer`, unread indicators and empty Inbox. Preserve a profile route through the existing conversation header identity.

**Sequential work:**

- [x] Test canonical pair/thread uniqueness, participant-only reads/writes, blank messages, idempotent retry, pagination order and pending/failed-send state before adding persistence and services.
- [x] Implement server message history, real inbox previews/unread state and account-scoped SwiftData cache/drafts. Drafts survive navigation; account changes never expose another user's messages.
- [x] Connect all real rows and profile Message actions to the correct conversation; add the selected foreground refresh behavior with cancellation on disappearance/sign-out.
- [x] Distinguish locally sending/failed text from server-confirmed messages; retain text for retry and reconcile duplicate acknowledgments by client ID.

**Definition of Done:** Account A sends to B, B reads/replies, both can reopen the same thread after relaunch. No hardcoded Alex routing, fabricated messages or cross-thread state. Inbox empty/unread states derive from stored data.

**Verification:** `ConversationServiceTests`, `InboxViewModelTests`, `ConversationViewModelTests`; backend thread/message authorization and duplicate-request tests. UI profile → thread → profile/back, long text, keyboard, empty composer, failure/retry and inbox revisit. Two-device/accounts verify actual shared history and the agreed refresh latency; account-switch test checks that stale tasks cannot repopulate cleared cache. Run baseline checks.

## Phase 5 — Reviewed proposals and initial explicit agreement

**Implementation status (November 16, 2026):** Initial agreement UI, owned persistent drafts and meeting navigation are implemented. Q4 defaults and native missing-layout completion are approved. The user requested basic build/unit and first-glance verification and stopped further UI journeys; full end-to-end acceptance is not claimed; see [completion ledger](docs/plans/finish-mvp1.md).

**Goal:** Send a real proposal, let only its recipient accept/decline it, and show the same initial arrangement to both participants.

**Dependencies / entrance decisions:** Phase 4; recover complete F10/F11 source/render under Q2; Q4 date/past-pending rules. Do not guess missing Review Proposal layout.

**Scope and main files:** `Features/Meetings/{Views/MeetingProposalView,Views/ReviewProposalView,Views/MeetingDetailView,Views/MyMeetingsView,ViewModels/ProposalViewModel,ViewModels/MeetingDetailViewModel,ViewModels/MyMeetingsViewModel,Models/Meeting,Models/MeetingRevision,Models/MeetingDraft,Services/MeetingService}.swift`; Messaging proposal-event rendering; `supabase/migrations/005_meetings.sql`; meeting tests.

**Figma references:** F09–F12; F08 proposal slip; `.notation-card`, `.status-banner`, `.meeting-facts`, `.meeting-card`, date stamp and initial recipient actions.

**Sequential work:**

- [x] Test that whitespace-only places and disallowed dates fail validation, review preserves all entered fields, and send creates Pending rather than Confirmed. Store an absolute instant plus named time zone; exercise DST ambiguity explicitly.
- [x] Implement proposal/revision records and transactional create/accept/decline functions with actor validation, request IDs and expected versions. Append a linked conversation event in the same transaction.
- [x] Bind proposal → review → send to one owned draft; allow review/back edits without losing text. Use the actual opponent, date, place and note throughout.
- [x] Implement recipient actions, sender waiting state, My Meetings pagination/segments and proposal links. Derive upcoming/history from real timestamps and the resolved past-pending policy.

**Definition of Done:** Both accounts see the same proposed details, and only recipient acceptance creates a confirmed appointment. Decline leaves no appointment. Retrying after a timeout produces one meeting/event. No actor-switch controls exist in production. This is an intermediate build, not yet the complete MVP1 release.

**Verification:** `ProposalViewModelTests`, `MeetingServiceTests`, `MyMeetingsViewModelTests`; backend recipient/proposer/outsider permissions, retry deduplication and simultaneous responses. UI conversation → proposal → review → send; recipient accept/decline; list/detail/thread consistency. Manually verify different time zones, DST transition dates, long place/note, optional blank note, offline send and relaunch. Run baseline checks.

## Phase 6 — Revisions, cancellation and complete MVP1

**Goal:** Preserve explicit agreement during changed or cancelled plans and finish the usable discovery-to-arrangement experience.

**Dependencies / entrance decisions:** Phase 5; Q4 replacement/concurrency policy and Figma placement for pending cancellation. Both participants must be able to propose changes, not only the original sender.

**Scope and main files:** extend meeting models/service/ViewModels and F09/F11/F12 views; `Features/Messaging/Models/ConversationEvent.swift`; `supabase/migrations/006_meeting_revisions.sql`; `ChessOTBTests/Features/Meetings/MeetingTransitionTests.swift`; `ChessOTBUITests/MVP1JourneyTests.swift`.

**Figma references:** F11 change-awaiting-agreement, `.previous-details`, proposed replacement facts, Accept New Details/Decline Change, Cancel Meeting; F08 stateful slips; F12 History.

**Sequential work:**

- [x] Test replacement acceptance/rejection, preserved accepted fields, role reversal, cancellation of pending/confirmed meetings, retry and concurrent accept/cancel against versioned records.
- [x] Implement immutable revision history, one accepted pointer and the resolved pending-replacement policy. Reuse the proposal/review flow for new values; do not hardcode the sample 3:30 PM café change.
- [x] Implement atomic cancellation and event updates; invalidate outstanding replacements according to Q4. Show previously agreed and newly proposed details distinctly until acceptance.
- [ ] Full verification of every MVP1 route with two accounts is deferred at the user’s request. Recovery and timestamp-based history are implemented; no results or attendance claims are added.

**Definition of Done:** Declining a replacement preserves the old confirmed plan; acceptance changes all surfaces to the new agreed values; cancellation is visible to both people and prevents stale acceptance. Repeated meetings have separate IDs. MVP1 supports the full description flow across devices, restart and recoverable failures.

**Verification:** Transition matrix tests for every actor/state/action; backend race tests assert one consistent committed outcome and one corresponding event. Two-account journey covers manual area, discovery, message, review, acceptance, revision acceptance/rejection, cancellation and history. Verify no automatic played-game count or rating update for past meetings. Run baseline and full MVP1 UI suites.

Subsequent migration numbers account for additive `007_inbox_pagination.sql` and `008_meeting_changes.sql`; future migrations begin at 009.

## Phase 7 — Optional ratings and comparable search

**Status:** Implemented with the user-requested minimal verification scope. See [Phase 7 record](docs/phase-7.md).

**Goal:** Add MVP2 opponent selection while preserving access for unrated users.

**Dependencies / entrance decisions:** Phase 6; Q5 canonical sources/formats, validation limits and Figma additions if needed.

**Scope and main files:** `Features/Profile/Models/RatingEntry.swift`; profile editor/service/model extensions; `Features/Discovery/Models/RatingCriteria.swift`; filter ViewModel/view and search service/query extensions; rated player rows/profile block; `supabase/migrations/009_ratings.sql`; rating/filter tests.

**Figma references:** F15 optional-rating controls/removal, F06 source/range/clear, F03 applied chips and rated/unrated rows, F05 rating detail, self-report notices.

**Sequential work:**

- [x] Test absent rating, add/update/remove, invalid values, inclusive bounds, one-sided bounds, min greater than max, and source/format mismatches using the approved comparison keys.
- [x] Persist one optional self-reported entry and render its source accurately; blank means no rating, not zero. Do not call rating-provider APIs.
- [x] Combine rating and geographic predicates on the server. Persist applied settings, implement Clear, and display true filter count/range/source.
- [x] Wire no-result recovery by widening/removing filters, preserving existing profile/message routes. Per user request, verification is limited to builds and focused rating/database tests; no user journeys or broad regression runs.

**Definition of Done:** Same-source/format filters return only valid matches; searches with no rating filter include unrated players; removing a rating restores unrated presentation. Saving or clearing affects subsequent searches/relaunch. No conversion, automatic pairing or balanced-game guarantee is introduced.

**Verification:** `RatingValidationTests`, `RatingFilterTests`, updated profile/discovery ViewModel tests and backend combined-query tests. UI add/edit/remove rating; apply/clear source/range; empty recovery; select result and arrange a game. Include another source with the same numeric value and an unrated account. Per the user’s revised instructions, run only a build check and focused rating tests; defer full UI and regression journeys.

## Phase 8 — Mutual friends and repeat scheduling

**Status:** Implemented with minimal focused checks, per user instruction. See [Phase 8 record](docs/phase-8.md).

**Goal:** Implement MVP3's friendship flow and make another individually agreed meeting easy to arrange.

**Dependencies / entrance decisions:** Phase 7; retain the description's mutual-request model unless explicitly changed; obtain Figma coverage for removal and missing request/empty states under Q2.

**Scope and main files:** `Features/Friends/{Views/FriendsView,Views/FriendRequestCard,ViewModels/FriendsViewModel,Models/Friendship,Services/FriendshipService}.swift`; Player Profile friendship action and shared navigation; `supabase/migrations/010_friendships.sql`; friends tests. Use the existing message/proposal services.

**Figma references:** F13 Friends with embedded request cards; F05 Add Friend/Request Sent/Friends states; F08/F09/F10 existing repeat-game path. The description's conversation entry point is optional wording; the already designed Profile action supplies the required request entry.

**Sequential work:**

- [x] Test request/send/accept/decline/remove with actor authorization, self-request prevention, duplicate/crossed requests and account-specific state.
- [x] Implement pair-unique requests and accepted relationships; keep outstanding incoming/outgoing requests distinct from accepted friends and derive profile button state from the same record.
- [x] Wire Friends and approved removal UI, including genuine loading/empty/failure states; update both participants after acceptance/removal.
- [x] Route accepted-friend rows to the existing conversation and create a fresh proposal using the established review/acceptance flow.

**Definition of Done:** A cannot accept A's own request; decline and removal work for the correct people; one player's action does not affect every profile. Friends can arrange a new game, and a friendship never auto-confirms it.

**Verification:** `FriendsViewModelTests`, friendship transition tests and backend pair uniqueness/access tests. Two-account request → decline → request/accept → list → repeat proposal → new acceptance → removal, plus crossed requests. Verify existing conversations/meeting history follow the decided retention behavior after removal. Per user instruction, verification is limited to focused friendship checks and builds; no journeys or broad regression runs.

## Phase 9 — Nearby groups and real designated contacts

**Status:** Implemented with focused checks and builds; see [Phase 9 record](docs/phase-9.md). Full UI journeys and broad regression remain deferred under the prior minimal verification preference.

**Goal:** Finish MVP3 with genuine local group listings that lead into individual coordination.

**Dependencies / entrance decisions:** Phase 8; Q6 listing owner/maintenance/contact/introduction model and conditional introduction layout. A designated contact must correspond to an actual account.

**Scope and main files:** `Features/Groups/{Views/NearbyGroupsView,Views/GroupDetailView,ViewModels/GroupsViewModel,Models/GroupListing,Services/GroupService}.swift`; Discover segment routing and shared area/distance query; `supabase/migrations/011_groups.sql`; private operator listing-import procedure and group tests. Do not add in-app group administration, membership, group chat or events.

**Figma references:** F04 group segment/results/loading/empty, F16 contact and introduction cards, F05/F08 reuse; `.group-glyph`, `.contact-card`, `.introduction-card`.

**Sequential work:**

- [x] Test geographic filtering, no results, missing/deactivated contact and correct contact/profile ID routing. Rating filters must not silently filter group listings.
- [x] Implement read-only discovery/detail and the agreed controlled listing maintenance process. Test fixtures are isolated; production discovery contains only genuine listings.
- [x] Bind Message Contact to the listing's designated person. Render introduction/profile links only from real approved records; never manufacture the prototype's Sam introduction.
- [x] Wire contact → individual profile/conversation → reviewed proposal → explicit agreement using the existing services. Contact/profile identity verified with focused tests; full UI agreement journey deferred.

**Definition of Done:** Groups respond to the actual area/radius; the correct contact receives messages; missing listings/contacts have honest recoverable states. The complete group-assisted path reaches the same one-on-one arrangement flow without requiring event registration.

**Verification:** `GroupsViewModelTests`, group-service and listing-write authorization tests; use two listings with different contacts to catch the prototype's fixed-Sam bug. UI switch Players/Groups, widen area from empty, view detail, message contact, follow genuine introduction, arrange a game. Manually verify operator update/removal and absent introductions. Verification scope follows the prior minimal preference: focused group/affected discovery tests, focused group SQL assertions and Debug/Release builds; baseline, full UI journeys and prior regression suites deferred.

## Phase 10 — Release readiness and agreed operating requirements

**Goal:** Verify and package the complete app for the chosen distribution, with real service configuration and resolved launch responsibilities.

**Dependencies / entrance decisions:** Phase 9; resolve Q7–Q10 and all remaining design gaps. No unresolved auth, privacy, group ownership or incomplete meeting UI can be treated as release-ready. If new operational requirements are chosen, specify their Figma references and acceptance tests inside this phase before implementation; revise the plan if they materially expand the product.

**Scope and main files:** `Resources/{Assets.xcassets,Localizable.xcstrings,PrivacyInfo.xcprivacy}`, entitlements/build configurations, release scheme; `ChessOTBUITests/{MVP1JourneyTests,MVP2JourneyTests,MVP3JourneyTests,AccessibilitySmokeTests}.swift`; feature-owned account/privacy/support files only for explicitly selected launch scope; associated backend migrations/functions and operational documentation. No unrelated feature work.

**Figma references:** F01–F16 across supported states/appearances, plus exact new references supplied for selected account/privacy/reporting/notification flows. F17, persona switches, preview links and restart-demo controls remain development artifacts.

**Sequential work:**

- [ ] Implement the resolved launch requirements: account lifecycle/retention and chosen contact-safety operations; notification delivery only if selected. Backend authorization, cache invalidation and failure handling receive tests alongside these changes.
- [ ] Audit all routes, real data identities, filters/statuses, localization, font/icon licenses, accessibility and privacy disclosures. Confirm no sample records, debug controls, secrets or temporary Figma asset URLs enter the release build.
- [ ] Run the full app and backend suites, clean-database migration and existing-install upgrade checks, plus real-device two-account journeys. Exercise offline/reconnect, permission denial, expired sessions, simultaneous actions and background/foreground refresh.
- [ ] Profile long inbox/discovery/history lists and memory/cancellation with Instruments; fix measured issues. Verify light/dark and Dynamic Type against recovered Figma visuals and record approved native differences.
- [ ] Create a signed archive for the selected distribution and document deployment, migration/rollback, service ownership and test-account procedure. Upload/publish only when separately authorized; an archive is sufficient for this plan's preparation step.

**Definition of Done:** Every committed MVP1–MVP3 behavior works between two real accounts; all decision gates affecting release are resolved; clean build, tests and archive succeed; shared data remains consistent through failures; final screens are grounded in Figma. The release has a configured backend and an identified operator, not just local fixtures. Store submission or public launch is not implied by completion of this planning document.

**Verification:** Full Swift Testing/XCTest/backend results with zero failures; signed archive validation on the configured toolchain; manual two-device journeys for all three MVPs; account/access isolation; migration/upgrade and data-retention checks; VoiceOver, large text, reduced motion, light/dark, small/large screens and physical-device location/auth. If push is selected, separately verify permission denial, background/terminated delivery and authorized deep-link routing; otherwise verify the app makes no background-delivery promise.
