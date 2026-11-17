#!/usr/bin/env python3
"""Create realistic, repeatable presentation fixtures in LOCAL Supabase only.

Never runs as an app startup hook or production seed. Existing accounts, passwords,
conversations and meeting decisions are preserved. See docs/presentation-demo.md.
"""
import argparse
import datetime as dt
import json
import pathlib
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import uuid
from zoneinfo import ZoneInfo

ROOT = pathlib.Path(__file__).resolve().parents[2]
NAMESPACE = uuid.UUID('ec007366-37c3-44a4-9ec1-a32701f4326b')
DEMO_PASSWORD = 'GroveCity-demo-2026!'
AREA = dict(p_name='Grove City, PA', p_latitude=41.16, p_longitude=-80.08, p_country_code='US', p_radius_miles=5)
PLACE = dict(name='Breen Student Union', address='100 N Campus Dr, Grove City, PA 16127, United States',
             latitude=41.1548158, longitude=-80.0778329)
PEOPLE = [
    ('alex.morgan', 'Alex Morgan', 41.16, -80.08, [('chess_com_rapid', 1450), ('lichess_rapid', 1630)]),
    ('jamie.parker', 'Jamie Parker', 41.16, -80.09, [('chess_com_rapid', 1320)]),
    ('sam.taylor', 'Sam Taylor', 41.17, -80.08, [('lichess_rapid', 1550)]),
    ('morgan.reed', 'Morgan Reed', 41.15, -80.09, [('chess_com_rapid', 1580)]),
    ('casey.bennett', 'Casey Bennett', 41.17, -80.10, []),
    ('riley.brooks', 'Riley Brooks', 41.18, -80.08, [('chess_com_rapid', 1180)]),
    ('jordan.ellis', 'Jordan Ellis', 41.15, -80.07, [('lichess_rapid', 1720)]),
]


def literal(value):
    if value is None:
        return 'null'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, (dict, list)):
        return literal(json.dumps(value, separators=(',', ':'))) + '::jsonb'
    return "'" + str(value).replace("'", "''") + "'"


class LocalDemo:
    def __init__(self):
        status = json.loads((ROOT / '.supabase/status.json').read_text())
        self.config = status.get('env', status)
        self.api = self.config['API_URL']
        self.database = self.config['DB_URL']
        api = urllib.parse.urlparse(self.api)
        database = urllib.parse.urlparse(self.database)
        if api.scheme != 'http' or api.hostname not in ('localhost', '127.0.0.1') or api.port != 54321:
            raise RuntimeError('Presentation fixtures are restricted to the local development API.')
        if database.hostname not in ('localhost', '127.0.0.1') or database.port != 54322:
            raise RuntimeError('Presentation fixtures are restricted to the local development database.')
        self.psql = next((ROOT / '.supabase/cache/stack').rglob('bin/psql'))

    def sql(self, statement):
        result = subprocess.run([str(self.psql), self.database, '-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1'],
                                input=statement, text=True, capture_output=True, cwd=ROOT)
        if result.returncode:
            raise RuntimeError(result.stderr.strip())
        lines = [line for line in result.stdout.splitlines() if line.strip()]
        return json.loads(lines[-1]) if lines else None

    def user(self, email, create=False):
        owner = self.sql('select to_jsonb(id) from auth.users where lower(email)=lower(' + literal(email) + ');')
        if owner or not create:
            return owner
        # The key stays in ignored local configuration, never in this script or its output.
        key = self.config['SERVICE_ROLE_KEY']
        request = urllib.request.Request(self.api + '/auth/v1/admin/users',
                    data=json.dumps(dict(email=email, password=DEMO_PASSWORD, email_confirm=True)).encode(),
                    headers={'Content-Type': 'application/json', 'apikey': key, 'Authorization': 'Bearer ' + key}, method='POST')
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)['id']

    def rpc(self, owner, name, **parameters):
        if not re.fullmatch('[a-z_]+', name):
            raise ValueError('Invalid RPC name')
        arguments = ','.join(key + '=>' + literal(value) for key, value in parameters.items())
        # Exercise the real participant-authorized functions; do not bypass meeting state rules.
        return self.sql('begin; set local request.jwt.claim.sub=' + literal(owner) + '; set local role authenticated; '
                        + 'select to_jsonb(public.' + name + '(' + arguments + ')); commit;')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--email', required=True, help='Existing LOCAL presentation account email')
    parser.add_argument('--create-target', action='store_true', help='Create a missing local target with the documented demo password')
    parser.add_argument('--start-date', type=dt.date.fromisoformat, default=dt.datetime.now(ZoneInfo('America/New_York')).date() + dt.timedelta(days=2))
    parser.add_argument('--round', default='presentation', help='Use another label for a fresh set of invitations after rehearsal')
    args = parser.parse_args()
    demo = LocalDemo()
    target = demo.user(args.email, create=args.create_target)
    if not target:
        raise RuntimeError('Target account does not exist locally. Sign up first or use --create-target for a new demo account.')
    own = demo.rpc(target, 'get_own_profile')
    if not own:
        own = demo.rpc(target, 'save_own_profile', p_display_name='Jordan Miller')
    if not own.get('area_name'):
        demo.rpc(target, 'save_own_profile_area', **AREA)
    demo.rpc(target, 'save_search_area', **AREA)
    demo.rpc(target, 'save_search_filters', p_radius_miles=5)
    run = str(target) + ':' + args.round + ':' + args.start_date.isoformat()

    def identity(label):
        return str(uuid.uuid5(NAMESPACE, run + ':' + label))

    people = {}
    for handle, name, latitude, longitude, ratings in PEOPLE:
        email = handle + '@presentation.chessotb.test'
        owner = demo.user(email, create=True)
        profile = demo.rpc(owner, 'save_profile_ratings', p_display_name=name,
                           p_ratings=[dict(kind=kind, value=value) for kind, value in ratings])
        demo.rpc(owner, 'save_own_profile_area', **dict(AREA, p_latitude=latitude, p_longitude=longitude))
        people[handle] = dict(owner=owner, profile=profile, email=email)

    def relationship(handle, accepted):
        person = people[handle]
        row = demo.rpc(target, 'get_friendship', p_peer_id=person['profile']['id'])
        if row['state'] == 'none':
            row = demo.rpc(person['owner'], 'mutate_friendship', p_peer_id=own['id'], p_action='send',
                           p_request_id=identity(handle + ':friend:' + str(row['version'])), p_expected_version=row['version'])
        if accepted and row['state'] == 'pending':
            actor, peer = (target, person['profile']['id']) if row['requester_id'] == person['profile']['id'] else (person['owner'], own['id'])
            demo.rpc(actor, 'mutate_friendship', p_peer_id=peer, p_action='accept',
                     p_request_id=identity(handle + ':accept:' + str(row['version'])), p_expected_version=row['version'])

    for handle in ('alex.morgan', 'jamie.parker', 'sam.taylor'):
        relationship(handle, True)
    for handle in ('morgan.reed', 'casey.bennett'):
        relationship(handle, False)

    threads = {}
    for handle, greeting in [
        ('alex.morgan', 'Hi! Would you like a casual game at the student union this week?'),
        ('jamie.parker', 'A relaxed afternoon game sounds great. I can bring a board.'),
        ('sam.taylor', 'Would you like to try a longer time control this weekend?'),
        ('morgan.reed', 'Hi! I am looking for more local people to play chess with.'),
    ]:
        person = people[handle]
        thread = demo.rpc(target, 'open_conversation', p_peer_id=person['profile']['id'])
        threads[handle] = thread
        demo.rpc(person['owner'], 'send_message', p_conversation_id=thread, p_client_id=identity(handle + ':hello'), p_body=greeting)
        if handle != 'morgan.reed':
            demo.rpc(target, 'send_message', p_conversation_id=thread, p_client_id=identity(handle + ':reply'),
                     p_body='That sounds good. Let us agree on a time and place.')

    def invitation(handle, label, offset, hour, incoming, note):
        start = dt.datetime.combine(args.start_date + dt.timedelta(days=offset), dt.time(hour), ZoneInfo('America/New_York'))
        actor = people[handle]['owner'] if incoming else target
        return demo.rpc(actor, 'create_meeting_with_place', p_conversation_id=threads[handle], p_request_id=identity(label),
                        p_starts_at=start.isoformat(), p_time_zone='America/New_York', p_location=PLACE['name'], p_place=PLACE, p_note=note)

    meetings = [
        invitation('alex.morgan', 'incoming-alex', 0, 16, True, 'Meet in the commuter lounge. I can bring a board.'),
        invitation('jamie.parker', 'incoming-jamie', 1, 14, True, 'A casual game near the main entrance.'),
        invitation('sam.taylor', 'outgoing-sam', 2, 13, False, 'A longer game in the lounge. Bring a board if you have one.'),
    ]
    confirmed = invitation('jamie.parker', 'confirmed-jamie', 3, 15, False, 'Meet in the lounge for a relaxed game.')
    if confirmed['status'] == 'pending':
        confirmed = demo.rpc(people['jamie.parker']['owner'], 'respond_to_meeting', p_meeting_id=confirmed['id'],
                             p_request_id=identity('confirm-jamie'), p_expected_version=confirmed['version'], p_decision='confirmed')
    if confirmed['status'] == 'confirmed' and not confirmed.get('pending_revision'):
        # Do not recreate a change already accepted/declined during this presentation round.
        receipt = demo.sql('select to_jsonb(count(*)>0) from public.meeting_mutations where meeting_id=' + literal(confirmed['id'])
                           + ' and request_id=' + literal(identity('change-jamie')) + ';')
        if not receipt:
            replacement = dt.datetime.combine(args.start_date + dt.timedelta(days=3), dt.time(16), ZoneInfo('America/New_York'))
            confirmed = demo.rpc(people['jamie.parker']['owner'], 'propose_meeting_change_with_place', p_meeting_id=confirmed['id'],
                                 p_request_id=identity('change-jamie'), p_expected_version=confirmed['version'],
                                 p_starts_at=replacement.isoformat(), p_time_zone='America/New_York', p_location=PLACE['name'],
                                 p_place=PLACE, p_note='Meet in the lounge for a relaxed game.')
    meetings.append(confirmed)

    for label, name, contact, introduction in [
        ('local-group', 'Grove City Casual Chess', 'alex.morgan', 'sam.taylor'),
        ('campus-group', 'Campus Chess Circle', 'jamie.parker', None),
    ]:
        listing = dict(id=str(uuid.uuid5(NAMESPACE, 'group:' + label)), name=name, area_name='Grove City, PA', latitude=41.16, longitude=-80.08,
                       description='A small local group for relaxed over-the-board games. Message the designated contact to discuss a game.',
                       contact_id=people[contact]['profile']['id'])
        if introduction:
            listing.update(introduction_profile_id=people[introduction]['profile']['id'], introduction_text='Sam enjoys slower games and is happy to meet local players.')
        demo.sql('select group_private.import_listing(' + literal(listing) + ');')

    # Correct the specifically identified old example name only when it is a contact of this account.
    renamed = demo.sql("update public.profiles p set display_name='Cameron Blake' where lower(p.display_name) in ('meeting second','second meeting') "
                       + 'and exists(select 1 from public.conversations c where ' + literal(own['id'])
                       + ' in(c.first_profile,c.second_profile) and p.id in(c.first_profile,c.second_profile)) returning to_jsonb(display_name);')
    result = dict(players=len(people), friends=3, incoming_friend_requests=2, conversations=len(threads),
                  meetings=[dict(id=m['id'], status=m['status'], date=m['revision']['starts_at']) for m in meetings],
                  groups=2, start_date=args.start_date.isoformat(), round=args.round,
                  note='Reruns preserve actions already taken; use a new --round for fresh meeting invites.')
    if renamed:
        result['renamed_old_example'] = renamed
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (RuntimeError, OSError, urllib.error.URLError, StopIteration, KeyError, ValueError) as error:
        raise SystemExit(str(error))
