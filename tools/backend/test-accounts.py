#!/usr/bin/env python3
"""End-to-end checks against this checkout's disposable LOCAL Supabase only."""
import json
import re
import time
import uuid
import urllib.error
import urllib.request
from pathlib import Path

status = json.loads(Path('.supabase/status.json').read_text())
values = status.get('env', status)
base = values['API_URL']
key = values['PUBLISHABLE_KEY']
assert base == 'http://127.0.0.1:54321', 'Refusing to create test accounts outside local Supabase'
mail = 'http://127.0.0.1:54324'


def request(path, body=None, token=None, expected=200, method='POST', send_key=True):
    headers = {'Content-Type': 'application/json'}
    if send_key: headers['apikey'] = key
    if token: headers['Authorization'] = 'Bearer ' + token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            code, raw = response.status, response.read()
    except urllib.error.HTTPError as error:
        code, raw = error.code, error.read()
    assert code == expected, f'{path}: expected HTTP {expected}, received {code}'
    return json.loads(raw) if raw else None


def email_code(email, subject):
    for _ in range(100):
        with urllib.request.urlopen(mail + '/api/v1/messages', timeout=10) as response:
            messages = json.load(response)['messages']
        for message in messages:
            if subject not in message['Subject']: continue
            if not any(to['Address'] == email for to in message['To']): continue
            with urllib.request.urlopen(mail + '/api/v1/message/' + message['ID'], timeout=10) as response:
                text = json.load(response)
            match = re.search(r'\b([0-9]{6})\b', text.get('Text', '') + text.get('HTML', ''))
            if match: return match[1]
        time.sleep(.1)
    raise AssertionError('Confirmation email was not captured by local Mailpit')


def new_account():
    email = 'phase2-' + uuid.uuid4().hex + '@example.com'
    password = 'Local-test-only-58!'
    result = request('/auth/v1/signup', {'email': email, 'password': password})
    assert 'access_token' not in result, 'Unconfirmed signup must not create a session'
    code = email_code(email, 'Confirm')
    result = request('/auth/v1/verify', {'email': email, 'token': code, 'type': 'signup'})
    return email, password, result

one_email, one_password, one = new_account()
two_email, two_password, two = new_account()
a = one['access_token']
b = two['access_token']
one_profile = request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'First player'}, a)[0]
two_profile = request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Second player'}, b)[0]
assert one_profile['id'] != one['user']['id']
assert one_profile['id'] != two_profile['id']
assert set(one_profile) == {'id', 'display_name'}
public = request('/rest/v1/rpc/get_player_profile', {'p_profile_id': one_profile['id']}, b)[0]
assert public == one_profile
request('/rest/v1/rpc/get_own_profile', {}, expected=401)
request('/rest/v1/profiles?select=owner_id', token=b, expected=403, method='GET')
request('/rest/v1/profiles?id=eq.' + one_profile['id'], {'display_name': 'Intruder'}, b, expected=403, method='PATCH')
request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Intruder', 'p_owner_id': one['user']['id']}, b, expected=404)
assert request('/rest/v1/rpc/get_own_profile', {}, a)[0]['display_name'] == 'First player'
assert request('/rest/v1/rpc/get_own_profile', {}, b)[0]['display_name'] == 'Second player'
print('PASS: confirmed accounts, private ownership, public projection, and cross-account isolation')

request('/auth/v1/token?grant_type=password', {'email': one_email, 'password': 'wrong-password'}, expected=400)
request('/auth/v1/recover', {'email': one_email})
code = email_code(one_email, 'Reset')
recovery = request('/auth/v1/verify', {'email': one_email, 'token': code, 'type': 'recovery'})
new_password = 'New-local-test-only-79!'
request('/auth/v1/user', {'password': new_password}, recovery['access_token'], method='PUT')
request('/auth/v1/token?grant_type=password', {'email': one_email, 'password': one_password}, expected=400)
signed_in = request('/auth/v1/token?grant_type=password', {'email': one_email, 'password': new_password})
refreshed = request('/auth/v1/token?grant_type=refresh_token', {'refresh_token': signed_in['refresh_token']})
assert refreshed['user']['id'] == one['user']['id']
request('/auth/v1/logout?scope=local', token=refreshed['access_token'], expected=204)
request('/auth/v1/token?grant_type=refresh_token', {'refresh_token': refreshed['refresh_token']}, expected=400)
print('PASS: password rejection, email-code recovery, password change, refresh rotation, and sign-out revocation')
