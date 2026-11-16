begin;
create extension if not exists pgtap with schema extensions;
select no_plan();
insert into auth.users(id,email) values
 ('77777777-7777-7777-7777-777777777701','distance-owner@example.test'),
 ('77777777-7777-7777-7777-777777777702','distance-one@example.test'),
 ('77777777-7777-7777-7777-777777777703','distance-two@example.test');
insert into public.profiles(id,owner_id,display_name) values
 ('88888888-8888-8888-8888-888888888801','77777777-7777-7777-7777-777777777701','Distance Owner'),
 ('88888888-8888-8888-8888-888888888802','77777777-7777-7777-7777-777777777702','Hundred One'),
 ('88888888-8888-8888-8888-888888888803','77777777-7777-7777-7777-777777777703','Hundred Two');
insert into public.profile_areas values
 ('88888888-8888-8888-8888-888888888801','Kansas center',38,-100,'US'),
 ('88888888-8888-8888-8888-888888888802','Kansas northern area',39.44,-99.97,'US'),
 ('88888888-8888-8888-8888-888888888803','Kansas northern area',39.44,-99.97,'US');
-- Return null for the old unsupported-radius/cursor error, so all RED assertions run.
create function pg_temp.try_distance_search(radius integer, cursor text default null) returns jsonb
language plpgsql as $$ begin return public.search_players(38,-100,radius,cursor,1);
exception when invalid_parameter_value then return null; end; $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','77777777-7777-7777-7777-777777777701',true);
select lives_ok($$select public.save_search_area('Kansas center',38,-100,'US',7)$$,'custom whole-mile radius saves');
select is(public.get_discovery_settings()->>'radius','7','custom radius persists as a number');
select lives_ok($$select public.save_search_area('Kansas center',38,-100,'US',1)$$,'minimum radius saves');
select lives_ok($$select public.save_search_area('Kansas center',38,-100,'US',100)$$,'maximum radius saves');
select is(public.get_discovery_settings()->>'radius','100','100-mile radius persists');
select throws_ok($$select public.save_search_area('Kansas center',38,-100,'US',0)$$,'22023','Invalid area','zero radius rejected');
select throws_ok($$select public.save_search_area('Kansas center',38,-100,'US',101)$$,'22023','Invalid area','above maximum rejected');
select lives_ok($$select public.search_players(38,-100,7,null,20)$$,'custom radius can be queried');
select is(pg_temp.try_distance_search(100)->'players'->0->>'distance_miles','100','rounded 100-mile band is returned');
select ok((pg_temp.try_distance_search(100)->>'next_cursor') like '100:%','cursor supports three-digit distance band');
select is(pg_temp.try_distance_search(100,pg_temp.try_distance_search(100)->>'next_cursor')->'players'->0->>'display_name','Hundred Two','100-mile cursor retrieves the next unique player');
select throws_ok($$select public.search_players(38,-100,101,null,20)$$,'22023','Invalid search','search above maximum rejected');
select * from finish();
rollback;
