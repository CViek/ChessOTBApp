#!/usr/bin/env python3
"""Cancellation and response races against the existing LOCAL stack only."""
import concurrent.futures
import runpy
import uuid

# Reuse the two-account initial agreement journey, including auth regressions.
core = runpy.run_path('tools/backend/test-meetings.py')
rpc, proposal, at, bt, ct = (core[key] for key in ('rpc', 'proposal', 'at', 'bt', 'ct'))
thread = core['thread']


def create():
    return rpc('create_meeting', dict(proposal, p_request_id=str(uuid.uuid4())), at)


def cancel(meeting, token, request_id=None, expected_version=None):
    return rpc('cancel_meeting', {
        'p_meeting_id': meeting['id'],
        'p_request_id': request_id or str(uuid.uuid4()),
        'p_expected_version': expected_version or meeting['version'],
    }, token)


pending = create()
rpc('cancel_meeting', dict(p_meeting_id=pending['id'], p_request_id=str(uuid.uuid4()), p_expected_version=1), ct, expected=403)
receipt_id = str(uuid.uuid4())
with concurrent.futures.ThreadPoolExecutor() as pool:
    results = list(pool.map(lambda _: cancel(pending, at, receipt_id), range(10)))
assert all(m['status'] == 'cancelled' and m['version'] == 2 for m in results)
assert rpc('get_meeting', {'p_meeting_id': pending['id']}, bt) == results[0]
assert results[0]['revision'] == pending['revision'], 'Cancellation modified immutable details'
rpc('respond_to_meeting', dict(p_meeting_id=pending['id'], p_request_id=str(uuid.uuid4()), p_expected_version=1, p_decision='confirmed'), bt, expected=409)

# Both valid actions target exactly version 1. Only one transaction may commit.
for _ in range(12):
    meeting = create()

    def perform(action):
        try:
            if action == 'cancel':
                return cancel(meeting, at)['status']
            return rpc('respond_to_meeting', dict(p_meeting_id=meeting['id'], p_request_id=str(uuid.uuid4()), p_expected_version=1, p_decision='confirmed'), bt)['status']
        except AssertionError as error:
            assert 'received 409' in str(error), str(error)
            return 'stale'

    with concurrent.futures.ThreadPoolExecutor() as pool:
        outcomes = list(pool.map(perform, ['cancel', 'accept']))
    assert outcomes.count('stale') == 1, outcomes
    final = rpc('get_meeting', {'p_meeting_id': meeting['id']}, bt)
    assert final['version'] == 2 and final['status'] in outcomes
    events = rpc('message_history', {'p_conversation_id': thread}, at)['messages']
    linked = [m for m in events if m['meeting_id'] == meeting['id']]
    assert len(linked) == 2 and linked[-1]['event_kind'] == final['status']
    # The other participant can cancel a confirmed appointment after refresh.
    if final['status'] == 'confirmed':
        final = cancel(final, bt)
        assert final['status'] == 'cancelled' and final['version'] == 3
        assert rpc('get_meeting', {'p_meeting_id': final['id']}, at) == final

# A retry still returns the original acknowledgement after other actions.
confirmed = create()
accept_request = dict(p_meeting_id=confirmed['id'], p_request_id=str(uuid.uuid4()), p_expected_version=1, p_decision='confirmed')
confirmed = rpc('respond_to_meeting', accept_request, bt)
assert cancel(confirmed, at)['status'] == 'cancelled'
assert rpc('respond_to_meeting', accept_request, bt) == confirmed, 'Retry must return its original acknowledgement'
assert rpc('get_meeting', {'p_meeting_id': confirmed['id']}, bt)['status'] == 'cancelled', 'Receipt replay must not undo cancellation'
print('Cancellation HTTP checks passed: both actors, shared state, ten identical retries, twelve accept/cancel races, immutable details and atomic events.')
