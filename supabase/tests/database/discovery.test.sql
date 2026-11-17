begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
-- Isolate geographic counts from saved local players. The final rollback
-- restores their areas; accounts, profiles and persistent data are retained.
delete from public.profile_areas;
select has_function('public','save_own_profile_area',array['text','double precision','double precision','text','integer'],'profile area save exists');
select has_function('public','get_discovery_settings',array[]::text[],'private settings reader exists');
select has_function('public','search_players',array['double precision','double precision','integer','text','integer','text','integer','integer'],'paged geographic search exists');
insert into auth.users(id,email) values
 ('33333333-3333-3333-3333-333333333331','geo-one@example.test'),
 ('33333333-3333-3333-3333-333333333332','geo-two@example.test'),
 ('33333333-3333-3333-3333-333333333333','geo-three@example.test'),
 ('33333333-3333-3333-3333-333333333334','geo-no-area@example.test'),
 ('33333333-3333-3333-3333-333333333335','geo-far@example.test');
insert into public.profiles(id,owner_id,display_name) values
 ('44444444-4444-4444-4444-444444444441','33333333-3333-3333-3333-333333333331','Geo One'),
 ('44444444-4444-4444-4444-444444444442','33333333-3333-3333-3333-333333333332','Geo Two'),
 ('44444444-4444-4444-4444-444444444443','33333333-3333-3333-3333-333333333333','Geo Three'),
 ('44444444-4444-4444-4444-444444444444','33333333-3333-3333-3333-333333333334','No Area'),
 ('44444444-4444-4444-4444-444444444445','33333333-3333-3333-3333-333333333335','Far Away');
set local role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333331',true);
select is((select area_name from public.save_own_profile_area('New York, NY',40.712831,-74.006059,'US',3)),'New York, NY','explicit area completes profile');
select is((public.get_discovery_settings()->'area'->>'latitude')::numeric,40.71::numeric,'stored center is coarsened');
select is((public.get_discovery_settings()->>'radius')::int,3,'first area save initializes search radius');
select throws_ok($$select public.save_own_profile_area('Toronto',43.65,-79.38,'CA',5)$$,'22023','US areas only','foreign area rejected');
select throws_ok($$select public.save_own_profile_area('Invalid',91,0,'US',5)$$,'22023','Invalid area','invalid coordinates rejected');
select throws_ok($$select latitude from public.profile_areas$$,'42501',null,'profile centers are not publicly selectable');
select throws_ok($$select * from public.discovery_settings$$,'42501',null,'search settings are not publicly selectable');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333332',true);
select public.save_own_profile_area('Nearby neighborhood, NY',40.72,-74.01,'US',5);
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select public.save_own_profile_area('Wider neighborhood, NY',40.76,-74.01,'US',5);
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333335',true);
select public.save_own_profile_area('Boston, MA',42.36,-71.06,'US',5);
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333331',true);
select is(jsonb_array_length(public.search_players(40.71,-74.01,3,null,20)->'players'),1,'3-mile query excludes self, no-area, distant and just-outside profiles');
select is(public.search_players(40.71,-74.01,3,null,20)->'players'->0->>'display_name','Geo Two','nearby account is returned');
select is(jsonb_array_length(public.search_players(40.71,-74.01,5,null,20)->'players'),2,'wider radius changes actual results');
select is(public.search_players(40.71,-74.01,3,null,20)->'players'->0->>'distance_miles','0','public distance uses a whole-mile band');
select ok((public.search_players(40.71,-74.01,5,null,1)->>'next_cursor') is not null,'first short page has a cursor');
select is(public.search_players(40.71,-74.01,5,public.search_players(40.71,-74.01,5,null,1)->>'next_cursor',1)->'players'->0->>'display_name','Geo Three','next page does not duplicate the first');
select is(jsonb_array_length(public.search_players(10,10,10,null,20)->'players'),0,'empty query returns no fabricated players');
select throws_ok($$select public.search_players(40.71,-74.01,101,null,20)$$,'22023','Invalid search','unsupported radius rejected');
select throws_ok($$select public.search_players(40.71,-74.01,5,'invalid',20)$$,'22023','Invalid cursor','malformed cursor rejected');
select is((select array_agg(key order by key) from jsonb_object_keys((public.search_players(40.71,-74.01,3,null,20)->'players'->0)) as key),array['area_name','display_name','distance_miles','id','rating','ratings'],'discovery exposes only approved public fields including optional ratings');
select public.save_search_area('Boston, MA',42.36,-71.06,'US',10);
select is((select area_name from public.get_own_profile()),'New York, NY','search edit preserves public profile area');
select public.save_own_profile_area('Changed profile, NY',40.73,-74.01,'US',5);
select is(public.get_discovery_settings()->'area'->>'name','Boston, MA','later profile edit preserves independent search area');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333332',true);
select is(public.get_discovery_settings()->'area'->>'name','Nearby neighborhood, NY','settings belong to the authenticated account');
-- Center rounding fixes the finest meaningful boundary to the stored grid.
reset role;
insert into auth.users(id,email)
select ('55555555-5555-5555-5555-'||lpad(n::text,12,'0'))::uuid,'boundary-'||n||'@example.test' from generate_series(1,6) n;
insert into public.profiles(id,owner_id,display_name)
select ('66666666-6666-6666-6666-'||lpad(n::text,12,'0'))::uuid,('55555555-5555-5555-5555-'||lpad(n::text,12,'0'))::uuid,'Boundary '||n from generate_series(1,6) n;
insert into public.profile_areas(profile_id,name,latitude,longitude,country_code)
select ('66666666-6666-6666-6666-'||lpad(n::text,12,'0'))::uuid,'Kansas test area',38+offset_lat,-100,'US'
from (values(1,0.04),(2,0.05),(3,0.07),(4,0.08),(5,0.14),(6,0.15)) as positions(n,offset_lat);
set local role authenticated;
select is(jsonb_array_length(public.search_players(38,-100,3,null,20)->'players'),1,'3-mile boundary excludes center at 3.45 miles');
select is(jsonb_array_length(public.search_players(38,-100,5,null,20)->'players'),3,'5-mile boundary excludes center at 5.52 miles');
select is(jsonb_array_length(public.search_players(38,-100,10,null,20)->'players'),5,'10-mile boundary excludes center at 10.36 miles');
select is(public.search_players(38,-100,5,public.search_players(38,-100,5,null,1)->>'next_cursor',1)->'players'->0->>'display_name','Boundary 2','equal distance bands paginate by public UUID');
set local role anon;
select throws_ok($$select public.search_players(40.71,-74.01,5,null,20)$$,'42501',null,'unauthenticated discovery denied');
select throws_ok($$select public.get_discovery_settings()$$,'42501',null,'unauthenticated settings denied');
select * from finish();
rollback;
