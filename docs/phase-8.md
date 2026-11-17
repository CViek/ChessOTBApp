# Phase 8 — Friends

Scope: participant-owned send/accept/decline/remove, pair uniqueness, profile state, incoming/outgoing requests and accepted friends, existing conversation/repeat-proposal routes. Crossed requests remain pending; acceptance is explicit. Removal retains conversations/meeting history. Native existing components provide empty/error/removal states. No groups, notifications or automatic meeting acceptance.

Plan: additive 010 migration with version checks and durable request receipts; account-bound service/shared model; Friends tab and profile action. Only focused database/model checks and a build, per user's minimal-token/test instruction. No journeys or extra agents. Status: complete at the requested minimal verification scope. Debug/Release simulator builds, 2 focused Swift tests and 10 database assertions pass.


Implemented: canonical versioned pairs and private retry receipts; owner-derived actors and recipient-only responses; account-bound Swift transport/shared state; Friends tab with incoming/sent/accepted lists and pagination; profile actions with removal confirmation; existing conversation links for fresh proposals. Synchronous sign-out cleanup rejects late results.

Checks: 2 focused Swift tests pass (`/tmp/chess-phase8-check.log`); 10 friendship database assertions pass (`/tmp/chess-phase8-db.log`). Migration 010 applied to the existing local endpoint at 127.0.0.1:54322 with migration history, without resetting accounts. The CLI's current branch stack conflicted with the already-running project's ports, so the existing database was targeted explicitly. No hosted deployment, commit, push, journeys or extra agents.

Release evidence: `/tmp/chess-phase8-release.log`. `git diff --check` passes. Full end-to-end UI verification is deferred per user instruction.
