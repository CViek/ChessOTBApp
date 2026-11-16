#!/usr/bin/env python3
"""Real HTTP messaging contract on loopback only; preserves existing accounts."""
import concurrent.futures
import runpy
import uuid

accounts = runpy.run_path('tools/backend/test-accounts.py')
request, new_account = accounts['request'], accounts['new_account']
_, _, a = new_account()
_, _, b = new_account()
_, _, outsider = new_account()
at, bt, ct = a['access_token'], b['access_token'], outsider['access_token']
pa = request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Messaging A'}, at)[0]
pb = request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Messaging B'}, bt)[0]
request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Messaging C'}, ct)

def rpc(name, body, token, expected=200):
    if name == 'mark_conversation_read' and expected == 200: expected = 204
    return request('/rest/v1/rpc/' + name, body, token, expected=expected)

with concurrent.futures.ThreadPoolExecutor() as pool:
    threads = list(pool.map(lambda index: rpc('open_conversation', {'p_peer_id': pb['id'] if index % 2 == 0 else pa['id']}, at if index % 2 == 0 else bt), range(12)))
assert len(set(threads)) == 1, 'Concurrent reversed pairs must create one thread'
thread = threads[0]
body = {'p_conversation_id': thread, 'p_client_id': str(uuid.uuid4()), 'p_body': 'Hello from A'}
with concurrent.futures.ThreadPoolExecutor() as pool:
    sent = list(pool.map(lambda _: rpc('send_message', body, at), range(12)))
assert len({m['id'] for m in sent}) == 1, 'Concurrent retry must return one acknowledgment'
first = sent[0]
assert first['sender_id'] == pa['id'] and first['body'] == 'Hello from A'
assert 'owner_id' not in first
assert rpc('list_conversations', {}, bt)[0]['unread_count'] == 1
rpc('send_message', dict(body, p_body='Changed payload'), at, expected=400)
rpc('send_message', dict(body, p_client_id=str(uuid.uuid4()), p_body='\n\t '), at, expected=400)
for index in range(55):
    rpc('send_message', dict(body, p_client_id=str(uuid.uuid4()), p_body=f'Reply {index}'), bt)
page = rpc('message_history', {'p_conversation_id': thread, 'p_limit': 50}, at)
assert len(page['messages']) == 50 and page['next_cursor'] is not None
older = rpc('message_history', {'p_conversation_id': thread, 'p_before': page['next_cursor'], 'p_limit': 50}, at)
assert len(older['messages']) == 6 and older['next_cursor'] is None
all_messages = older['messages'] + page['messages']
assert len({m['id'] for m in all_messages}) == 56
assert [m['sequence'] for m in all_messages] == sorted(m['sequence'] for m in all_messages)
rpc('mark_conversation_read', {'p_conversation_id': thread, 'p_through': page['messages'][-1]['sequence']}, at)
assert rpc('list_conversations', {}, at)[0]['unread_count'] == 0
new_message = rpc('send_message', dict(body, p_client_id=str(uuid.uuid4()), p_body='Unseen after fetch'), bt)
# A stale acknowledgment must leave a newer message unread.
rpc('mark_conversation_read', {'p_conversation_id': thread, 'p_through': first['sequence']}, at)
assert rpc('list_conversations', {}, at)[0]['unread_count'] == 1
for name, payload in [('message_history', {'p_conversation_id': thread}), ('send_message', dict(body, p_client_id=str(uuid.uuid4()))), ('mark_conversation_read', {'p_conversation_id': thread, 'p_through': new_message['sequence']})]:
    rpc(name, payload, ct, expected=403)
assert rpc('list_conversations', {}, ct) == []
request('/rest/v1/messages?select=*', token=at, expected=403, method='GET')
rpc('list_conversations', {}, None, expected=401)
reopened = rpc('message_history', {'p_conversation_id': thread}, bt)
assert reopened['messages'][-1]['body'] == 'Unseen after fetch'
print('PASS: real two-account history, concurrent canonical threads/idempotent sends, pagination, unread watermarks, outsider and anonymous denial')
