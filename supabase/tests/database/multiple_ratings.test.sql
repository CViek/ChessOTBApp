begin;
create extension if not exists pgtap with schema extensions;
select plan(21);
insert into auth.users(id,email) values
 ('81111111-1111-1111-1111-111111111111','multi-rating-a@example.test'),
 ('82222222-2222-2222-2222-222222222222','multi-rating-b@example.test');
insert into public.profiles(id,owner_id,display_name) values
 ('8aaaaaaa-1111-1111-1111-111111111111','81111111-1111-1111-1111-111111111111','A'),
 ('8bbbbbbb-2222-2222-2222-222222222222','82222222-2222-2222-2222-222222222222','B');
insert into public.profile_areas values
 ('8aaaaaaa-1111-1111-1111-111111111111','Test area',40,-74,'US'),
 ('8bbbbbbb-2222-2222-2222-222222222222','Test area',40,-74,'US');
set local role authenticated;
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
select lives_ok($$select public.save_profile_ratings('B','[{"kind":"chess_com_rapid","value":1500},{"kind":"lichess_blitz","value":1700}]')$$,'save two ratings');
select is((select jsonb_array_length(ratings) from public.get_own_profile()),2,'both ratings reload');
select is((select count(*)::integer from public.get_own_profile()),1,'one profile row for multiple ratings');
select is((select jsonb_array_length(ratings) from public.get_player_profile('8bbbbbbb-2222-2222-2222-222222222222')),2,'public profile includes both ratings');
select throws_ok($$select public.save_rated_profile('Legacy edit','chess_com_rapid',1600)$$,'22023',null,'legacy editor cannot overwrite multiple ratings');
select is((select display_name from public.get_own_profile()),'B','rejected legacy edit preserves display name');
select is((select jsonb_array_length(ratings) from public.get_own_profile()),2,'rejected legacy edit preserves all ratings');
select throws_ok($$select public.save_profile_ratings('Bad','[{"kind":"chess_com_rapid","value":1500},{"kind":"lichess_blitz","value":4001}]')$$,'22023',null,'invalid second value rejected');
select is((select display_name from public.get_own_profile()),'B','invalid ratings preserve name');
select is((select jsonb_array_length(ratings) from public.get_own_profile()),2,'invalid ratings preserve entries');
select throws_ok($$select public.save_profile_ratings('Bad','[{"kind":"chess_com_rapid","value":1500},{"kind":"chess_com_rapid","value":1700}]')$$,'22023',null,'duplicate kinds rejected');
select throws_ok($$select public.save_profile_ratings('Bad','[{"kind":"chess_com_rapid","value":null}]')$$,'22023',null,'null value rejected');
select throws_ok($$select public.save_profile_ratings('Bad','[{"kind":"chess_com_rapid","value":1500.5}]')$$,'22023',null,'fraction rejected');
select set_config('request.jwt.claim.sub','81111111-1111-1111-1111-111111111111',true);
select is(jsonb_array_length(public.search_players(40,-74,5,null,20)->'players'),1,'multiple ratings do not duplicate search results');
select is(jsonb_array_length(public.search_players(40,-74,5,null,20,'lichess_blitz',1700,1700)->'players'),1,'filter matches second rating');
select is(jsonb_array_length(public.search_players(40,-74,5,null,20,'chess_com_blitz',null,null)->'players'),0,'filter excludes other formats');
select set_config('request.jwt.claim.sub','82222222-2222-2222-2222-222222222222',true);
select is((select jsonb_array_length(ratings) from public.save_own_profile_area('New area',40,-74,'US',5)),2,'area editing preserves all ratings');
select is((select jsonb_array_length(ratings) from public.save_profile_ratings('B','[{"kind":"lichess_blitz","value":1800}]')),1,'remove one rating');
select is((select ratings->0->>'value' from public.get_own_profile()),'1800','remaining rating can be updated');
select is((select ratings from public.save_profile_ratings('B','[]')),'[]'::jsonb,'remove all ratings');
select set_config('request.jwt.claim.sub','',true);
select throws_ok($$select public.save_profile_ratings('Bad','[]')$$,'42501',null,'authentication required');
select * from finish();
rollback;
