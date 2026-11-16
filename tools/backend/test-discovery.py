#!/usr/bin/env python3
"""Real HTTP checks against loopback Supabase; creates only uniquely named fixtures."""
import runpy

account = runpy.run_path('tools/backend/test-accounts.py')
request = account['request']
new_account = account['new_account']
_, _, one = new_account()
_, _, two = new_account()
a, b = one['access_token'], two['access_token']
first = request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Discovery HTTP first'}, a)[0]
second = request('/rest/v1/rpc/save_own_profile', {'p_display_name': 'Discovery HTTP second'}, b)[0]
# Isolated named centers away from UI fixtures; no GPS is read by these checks.
def area(name, lat, lon, radius=5):
    return dict(p_name=name, p_latitude=lat, p_longitude=lon, p_country_code='US', p_radius_miles=radius)
request('/rest/v1/rpc/save_own_profile_area', area('Dodge City, KS',37.75283,-100.01705), a)
request('/rest/v1/rpc/save_own_profile_area', area('Nearby Kansas area',37.76,-100.02), b)
settings = request('/rest/v1/rpc/get_discovery_settings', {}, a)
assert settings['area']['latitude'] == 37.75 and settings['area']['longitude'] == -100.02
query = dict(p_latitude=37.75, p_longitude=-100.02, p_radius_miles=3, p_limit=50)
page = request('/rest/v1/rpc/search_players', query, a)
ids = {p['id'] for p in page['players']}
assert second['id'] in ids and first['id'] not in ids
player = next(p for p in page['players'] if p['id'] == second['id'])
assert set(player) == {'id','display_name','area_name','distance_miles'} and player['distance_miles'] == 0
public = request('/rest/v1/rpc/get_player_profile', {'p_profile_id': second['id']}, a)[0]
assert set(public) == {'id','display_name','area_name'}
request('/rest/v1/profile_areas?select=*',token=a,expected=403,method='GET')
request('/rest/v1/discovery_settings?select=*',token=b,expected=403,method='GET')
request('/rest/v1/rpc/save_search_area',area('Boston, MA',42.36,-71.06,10),a)
assert request('/rest/v1/rpc/get_own_profile',{},a)[0]['area_name']=='Dodge City, KS'
request('/rest/v1/rpc/save_own_profile_area',area('Changed Kansas area',37.77,-100.02),a)
assert request('/rest/v1/rpc/get_discovery_settings',{},a)['area']['name']=='Boston, MA'
assert request('/rest/v1/rpc/get_discovery_settings',{},b)['area']['name']=='Nearby Kansas area'
print('PASS: real nearby discovery, self exclusion, coarse storage, public privacy, and independent account settings')

for radius in (1, 7, 37, 100):
    request('/rest/v1/rpc/save_search_area', area('Boston, MA',42.36,-71.06,radius),a)
    assert request('/rest/v1/rpc/get_discovery_settings',{},a)['radius']==radius
    request('/rest/v1/rpc/search_players',dict(p_latitude=42.36,p_longitude=-71.06,p_radius_miles=radius),a)
for radius in (0, 101):
    request('/rest/v1/rpc/save_search_area',area('Boston, MA',42.36,-71.06,radius),a,expected=400)
assert request('/rest/v1/rpc/get_discovery_settings',{},a)['radius']==100
print('PASS: dynamic 1–100-mile distances, nonpreset saves/searches, and rejected out-of-range writes')
