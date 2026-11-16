#!/usr/bin/env python3
"""Initial agreement HTTP/race contract, against the existing LOCAL stack only."""
import concurrent.futures
import runpy
import uuid

accounts = runpy.run_path('tools/backend/test-accounts.py')
request, new_account = accounts['request'], accounts['new_account']
_, _, a = new_account()
_, _, b = new_account()
_, _, outsider = new_account()
at, bt, ct = a['access_token'], b['access_token'], outsider['access_token']
pa = request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Meeting A'}, at)[0]
pb = request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Meeting B'}, bt)[0]
request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Meeting C'}, ct)


def rpc(name, body, token, expected=200):
    return request('/rest/v1/rpc/' + name, body, token, expected=expected)


thread = rpc('open_conversation', {'p_peer_id': pb['id']}, at)
proposal = dict(p_conversation_id=thread, p_request_id=str(uuid.uuid4()),
                p_starts_at='2099-05-17T18:00:00Z', p_time_zone='America/New_York',
                p_location='Library, main stairs', p_note='I can bring a board.')
with concurrent.futures.ThreadPoolExecutor() as pool:
    created = list(pool.map(lambda _: rpc('create_meeting', proposal, at), range(10)))
assert len({m['id'] for m in created}) == 1, 'Concurrent retries created duplicate meetings'
meeting = created[0]
assert meeting['status'] == 'pending' and meeting['version'] == 1
assert meeting['proposer_id'] == pa['id'] and meeting['recipient_id'] == pb['id']
assert rpc('get_meeting', {'p_meeting_id': meeting['id']}, bt) == meeting
assert 'owner_id' not in str(meeting), 'Auth owner IDs escaped public projection'
rpc('get_meeting', {'p_meeting_id': meeting['id']}, ct, expected=403)
rpc('create_meeting', proposal, ct, expected=403)
response = dict(p_meeting_id=meeting['id'], p_request_id=str(uuid.uuid4()), p_expected_version=1, p_decision='confirmed')
rpc('respond_to_meeting', response, at, expected=403)
rpc('respond_to_meeting', response, ct, expected=403)
with concurrent.futures.ThreadPoolExecutor() as pool:
    accepted = list(pool.map(lambda _: rpc('respond_to_meeting', response, bt), range(10)))
assert all(m['status'] == 'confirmed' and m['version'] == 2 for m in accepted)
events = rpc('message_history', {'p_conversation_id': thread}, at)['messages']
assert len(events) == 2 and [m['event_kind'] for m in events] == ['proposal', 'confirmed']
assert all(m['meeting_id'] == meeting['id'] for m in events)
assert rpc('list_conversations', {}, at)[0]['unread_count'] == 1
rpc('respond_to_meeting', dict(response, p_decision='declined'), bt, expected=400)

# Independently valid opposing decisions race for the same expected version.
race = rpc('create_meeting', dict(proposal, p_request_id=str(uuid.uuid4()), p_note='Race'), at)


def race_response(decision):
    body = dict(response, p_meeting_id=race['id'], p_request_id=str(uuid.uuid4()), p_decision=decision)
    try:
        return rpc('respond_to_meeting', body, bt)['status']
    except AssertionError as error:
        assert 'received 409' in str(error), str(error)
        return 'stale'


with concurrent.futures.ThreadPoolExecutor() as pool:
    outcomes = list(pool.map(race_response, ['confirmed', 'declined']))
assert outcomes.count('stale') == 1, 'Exactly one conflicting response must commit'
final = rpc('get_meeting', {'p_meeting_id': race['id']}, at)
assert final['status'] in outcomes and final['version'] == 2
events = rpc('message_history', {'p_conversation_id': thread}, bt)['messages']
assert len(events) == 4 and events[-1]['event_kind'] == final['status']

# Explicit decline retains immutable proposal facts without confirming anything.
declined = rpc('create_meeting', dict(proposal, p_request_id=str(uuid.uuid4()), p_note=''), at)
result = rpc('respond_to_meeting', dict(response, p_meeting_id=declined['id'], p_request_id=str(uuid.uuid4()), p_decision='declined'), bt)
assert result['status'] == 'declined' and result['revision'] == declined['revision']

# Stable pages include every arrangement once, even with identical start times.
for _ in range(4):
    rpc('create_meeting', dict(proposal, p_request_id=str(uuid.uuid4())), at)
seen, cursor = [], None
while True:
    body = {'p_limit': 2}
    if cursor is not None:
        body['p_before'] = cursor
    page = rpc('list_meetings', body, bt)
    seen.extend(m['id'] for m in page['meetings'])
    cursor = page['next_cursor']
    if cursor is None:
        break
assert len(seen) == 7 and len(set(seen)) == 7
assert rpc('list_meetings', {}, ct)['meetings'] == []
print('Meeting HTTP checks passed: authorization, shared details, concurrent retries, response races, decline, events, unread and stable pagination.')
