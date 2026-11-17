# Maintaining group listings

Only the database operator supplies listings. Before import, verify the group exists, that its area is a US city/neighborhood, and that its designated contact owns the selected public profile and agrees to be contacted for the group. Keep verification and consent evidence in the operator's private records, outside the app. Public descriptions must contain accurate group information, without private contact details or availability claims.

Use a trusted database connection as `postgres`, never an iOS client or a publishable/service key. `group_private` is not exposed through the Data API. All listing tables and private functions deny client access. Do not grant these privileges to application roles.

Import a JSON file through a parameterized SQL call to `group_private.import_listing(jsonb)`. Required fields: `id` (a stable UUID allocated by the operator), `name`, `area_name`, `latitude`, `longitude`, `description`, `contact_id` (the person's public profile UUID, not their auth UUID). Coordinates are rounded to two decimals. Verify the account identity through a trusted operator channel; display names alone are not proof. The import rejects missing/deleted/deactivated contacts. Reimporting the same listing UUID updates it atomically. Omit both introduction fields to remove a previous introduction.

Optional fields `introduction_text` and `introduction_profile_id` must appear together. Publish them only after both the contact and introduced player approve the text and profile link. Text is displayed as plain text. Never copy the prototype's Sam card into production. Review time-sensitive introductions regularly; remove them once stale or consent is withdrawn.

For deletion, call `select group_private.remove_listing('<listing UUID>');` as the operator. There is no client membership, registration, group chat or group event record. Removing a listing preserves individual conversations and meeting history. Deleting a contact profile clears its listing reference; deactivated/deleted auth accounts are excluded from contact/introduction projections. Listings remain visible with honest unavailable-contact copy so operators can repair them.

Check updates by searching the actual area/radius and opening the listing. Confirm contact and introduction profile identities against the approved records, then remove or correct outdated listings. No real listings were supplied with Phase 9, so production remains empty until verified imports. The test fixtures live in transaction-scoped database tests which roll back; previews are DEBUG-only.
