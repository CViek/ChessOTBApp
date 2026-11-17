# Presentation data — local Grove City demo

The presentation fixtures live in the local Supabase database, so simulators connected to that database share them and app restarts preserve them. They are fictional demonstration people and groups, not real community listings. They are created only by explicitly running `tools/backend/seed-presentation.py`; production `supabase/seed.sql` stays empty.

The user's existing local account keeps its name, password, messages and meetings. Its search area is set to Grove City, PA, within five miles, with rating filters cleared so all demo players are visible. One older example contact named “Meeting second” is renamed “Cameron Blake” when connected to that account; its account and history are retained.

## What is ready

| Feature | Prepared examples |
| --- | --- |
| Discover | Alex Morgan, Jamie Parker, Sam Taylor, Morgan Reed, Casey Bennett, Riley Brooks and Jordan Ellis, all near Grove City |
| Ratings | A mix of optional Chess.com rapid and Lichess rapid ratings; Casey is unrated |
| Friends | Alex Morgan, Jamie Parker and Sam Taylor already accepted |
| Incoming friend requests | Morgan Reed and Casey Bennett |
| Inbox | Four conversations with natural greetings and replies |
| Incoming meeting invites | Alex on November 19 at 4 p.m.; Jamie on November 20 at 2 p.m. |
| Sent invitation | Sam on November 21 at 1 p.m.; open it and choose **Edit Invitation** |
| Confirmed meeting/change | Jamie on November 22 at 3 p.m., with an incoming proposal to move it to 4 p.m. |
| Groups | Grove City Casual Chess and Campus Chess Circle, linked to the actual demo contact profiles |

All times are America/New_York. These November 2026 dates use `--start-date 2026-11-19`; another start date shifts the examples accordingly. Meetings use the Breen Student Union address selected through MapKit in local development: 100 N Campus Dr, Grove City, PA 16127. This is a proposed meeting location, not a venue reservation or claim of visitor access. The [college's facility page](https://www.gcc.edu/Home/Experience-the-Grove/Facilities/Breen-Student-Union) identifies the student union, and its [driving directions](https://www.gcc.edu/Info/Visit/Driving-Directions) identify the campus address.

## Recreate after cloning/pulling the project

Database records are not stored in GitHub. The script, migrations and these instructions travel with the project once committed and pushed. Each independent local database runs the setup separately; phones/other Macs do not automatically connect to this Mac's loopback backend.

1. Start the local stack with `tools/backend/start-local.sh` using the project's installed Node toolchain. This generates the ignored `.supabase/status.json` and local Xcode configuration. Never reset an existing database just to run this demo.
2. Apply all current local migrations, including 013 (addresses) and 014 (editing unanswered invitations):

   ```sh
   tools/backend/supabase.sh migration up --remote=postgresql://postgres:postgres@127.0.0.1:54322/postgres
   ```

3. Sign up in the Debug app using your desired local presentation email. Then seed that existing account:

   ```sh
   python3 tools/backend/seed-presentation.py --email your-local-email@example.test --start-date 2026-11-19
   ```

   Alternatively, explicitly create a separate local presentation account:

   ```sh
   python3 tools/backend/seed-presentation.py --email presenter@chessotb.test --create-target --start-date 2026-11-19
   ```

   A newly created target uses the name Jordan Miller and the local-only demo password below. The script never changes an existing target's password.

4. Build/run the Debug app. Sign in normally. Automatic refresh or pulling down in Discover, Friends, Inbox or Meetings loads the records.

The script refuses non-loopback APIs/databases and uses the ignored local service-role key only to create fictional demo accounts. It uses the normal participant-authorized RPCs for profiles, friendships, messages and meetings, so acceptance and editing work for real through the existing app.

## Two-device live demo

Keep the presentation account on one simulator and use one of these fictional accounts on the other. Both simulators must point to the same local backend.

- Alex: `alex.morgan@presentation.chessotb.test`
- Jamie: `jamie.parker@presentation.chessotb.test`
- Sam: `sam.taylor@presentation.chessotb.test`
- Morgan: `morgan.reed@presentation.chessotb.test`
- Casey: `casey.bennett@presentation.chessotb.test`

All newly created fictional accounts use **`GroveCity-demo-2026!`**. This password is intentionally public, local-only demonstration data. Do not use it for real accounts or any hosted deployment.

A short walkthrough: accept Morgan's friend request; accept Alex's incoming meeting invitation; edit the sent invitation to Sam; respond to Jamie's proposed time change. On a second simulator, sign in as Sam to see and accept the edited invitation.

## Rehearsing and rerunning

Rerunning the same start date and round reuses the demo accounts, conversations and meeting request IDs rather than duplicating invitations. It preserves meeting decisions already made. It can resend a declined/removed demo friendship request, but it never removes an accepted friendship to force an incoming request back into the UI.

For a fresh set of meeting invitations after rehearsal, use a different round label:

```sh
python3 tools/backend/seed-presentation.py --email your-local-email@example.test --start-date 2026-11-19 --round rehearsal-2
```

That adds another small set of invitations while retaining earlier history. The default start date, when omitted, is two days after the day the script runs. Demo actors are reused across local presentation accounts; meeting/conversation records remain participant-specific. Group listings use stable local demo IDs.
