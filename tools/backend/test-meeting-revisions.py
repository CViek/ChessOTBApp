#!/usr/bin/env python3
"""Local two-account revision/date and race contract. Never targets hosted data."""
import concurrent.futures
import runpy
import uuid
import time
from datetime import datetime, timedelta, timezone

core = runpy.run_path('tools/backend/test-meetings.py')
rpc, at, bt, ct, proposal = (core[k] for k in ('rpc', 'at', 'bt', 'ct', 'proposal'))

def new_confirmed():
    meeting = rpc('create_meeting', dict(proposal, p_request_id=str(uuid.uuid4())), at)
    return rpc('respond_to_meeting', dict(p_meeting_id=meeting['id'], p_request_id=str(uuid.uuid4()), p_expected_version=1, p_decision='confirmed'), bt)

def change(meeting, **kwargs):
    return dict(p_meeting_id=meeting['id'], p_request_id=str(uuid.uuid4()), p_expected_version=meeting['version'], p_starts_at='2099-06-17T18:00:00Z', p_time_zone='UTC', p_location='New library', p_note='Bring clock', **kwargs)

def answer(meeting, decision='confirmed'):
    return dict(p_meeting_id=meeting['id'], p_request_id=str(uuid.uuid4()), p_expected_version=meeting['version'], p_decision=decision)

m = new_confirmed()
original = m['revision']
payload = change(m)
rpc('propose_meeting_change', payload, ct, expected=403)
with concurrent.futures.ThreadPoolExecutor() as pool:
    results = list(pool.map(lambda _: rpc('propose_meeting_change', payload, bt), range(8)))
assert all(r == results[0] for r in results)
m = results[0]
assert m['status'] == 'confirmed' and m['revision'] == original
assert m['pending_revision']['location'] == 'New library'
assert m['pending_proposer_id'] == core['pb']['id']
assert len(m['revisions']) == 2
rpc('propose_meeting_change', dict(payload, p_location='Changed payload'), bt, expected=400)
rpc('propose_meeting_change', change(m), at, expected=409)
rpc('respond_to_meeting_change', answer(m), bt, expected=403)
rpc('respond_to_meeting_change', answer(m), ct, expected=403)
m = rpc('respond_to_meeting_change', answer(m, 'declined'), at)
assert m['status'] == 'confirmed' and m['revision'] == original and m['pending_revision'] is None
# Either participant may propose; acceptance replaces all agreed facts.
payload = change(m)
m = rpc('propose_meeting_change', payload, at)
response = answer(m)
with concurrent.futures.ThreadPoolExecutor() as pool:
    accepted = list(pool.map(lambda _: rpc('respond_to_meeting_change', response, bt), range(8)))
assert all(r == accepted[0] for r in accepted)
m = accepted[0]
assert m['revision']['location'] == 'New library' and m['pending_revision'] is None
assert len(m['revisions']) == 3 and original in m['revisions']
assert rpc('get_meeting', {'p_meeting_id': m['id']}, at) == rpc('get_meeting', {'p_meeting_id': m['id']}, bt)
# Date validation and cancellation invalidation.
rpc('create_meeting', dict(proposal, p_request_id=str(uuid.uuid4()), p_starts_at='2000-01-01T12:00:00Z'), at, expected=400)
rpc('propose_meeting_change', dict(change(m), p_starts_at='2000-01-01T12:00:00Z'), at, expected=400)
m = rpc('propose_meeting_change', change(m), bt)
stale = answer(m)
m = rpc('cancel_meeting', dict(p_meeting_id=m['id'], p_request_id=str(uuid.uuid4()), p_expected_version=m['version']), at)
assert m['status'] == 'cancelled' and m['pending_revision'] is None
rpc('respond_to_meeting_change', stale, at, expected=409)
# Replaying a historical mutation never resurrects a cancelled plan.
assert rpc('respond_to_meeting_change', response, bt)['status'] == 'confirmed'
assert rpc('get_meeting', {'p_meeting_id': m['id']}, bt)['status'] == 'cancelled'
# Concurrent cancellation / replacement acceptance has exactly one winner.
for _ in range(8):
    m = new_confirmed()
    m = rpc('propose_meeting_change', change(m), at)
    accept, cancel = answer(m), dict(p_meeting_id=m['id'], p_request_id=str(uuid.uuid4()), p_expected_version=m['version'])
    def race(which):
        try:
            return rpc('respond_to_meeting_change' if which else 'cancel_meeting', accept if which else cancel, bt)['status']
        except AssertionError as error:
            assert 'received 409' in str(error), str(error)
            return 'stale'
    with concurrent.futures.ThreadPoolExecutor() as pool:
        outcomes = list(pool.map(race, [True, False]))
    assert outcomes.count('stale') == 1, outcomes
    final = rpc('get_meeting', {'p_meeting_id': m['id']}, at)
    assert final['status'] in outcomes and final['version'] == m['version'] + 1
# A request acknowledged just before its start remains recoverable after that time.
soon = dict(proposal, p_request_id=str(uuid.uuid4()), p_starts_at=(datetime.now(timezone.utc) + timedelta(seconds=2)).isoformat())
ack = rpc('create_meeting', soon, at)
time.sleep(2.1)
assert rpc('create_meeting', soon, at)['id'] == ack['id']
print('Revision HTTP checks passed: both roles, immutable facts/history, decline/accept, retries, dates, isolation and eight accept/cancel races.')
