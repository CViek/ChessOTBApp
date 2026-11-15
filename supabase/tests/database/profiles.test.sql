begin;
create extension if not exists pgtap with schema extensions;
select plan(14);
select has_function('public', 'save_own_profile', array['text'], 'own profile mutation exists');
select has_function('public', 'get_own_profile', array[]::text[], 'own profile reader exists');
select has_function('public', 'get_player_profile', array['uuid'], 'restricted public reader exists');
-- Test identities exist only in this rolled-back transaction.
insert into auth.users(id, email) values
 ('11111111-1111-1111-1111-111111111111', 'one@example.test'),
 ('22222222-2222-2222-2222-222222222222', 'two@example.test');
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select is((select display_name from public.save_own_profile('  Zoë 李  ')), 'Zoë 李', 'save trims a Unicode name');
select is((select display_name from public.get_own_profile()), 'Zoë 李', 'owner reads saved value');
select throws_ok($$select public.save_own_profile('   ')$$, '22023', 'Invalid display name', 'blank name rejected');
select throws_ok($$select public.save_own_profile(repeat('x',61))$$, '22023', 'Invalid display name', 'overlong name rejected');
select throws_ok($$select public.save_own_profile(E'Alex\nMorgan')$$, '22023', 'Invalid display name', 'control characters rejected');
select throws_ok($$update public.profiles set display_name='intruder'$$, '42501', null, 'direct profile writes denied');
select throws_ok($$select owner_id from public.profiles$$, '42501', null, 'private owner IDs are not exposed');
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select is((select count(*)::int from public.get_own_profile()), 0, 'another user has no inherited profile');
select lives_ok($$select public.save_own_profile('Second player')$$, 'second account saves its own profile');
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select is((select display_name from public.get_own_profile()), 'Zoë 李', 'second save cannot overwrite first account');
set local role anon;
select throws_ok($$select public.get_own_profile()$$, '42501', null, 'unauthenticated reads denied');
select * from finish();
rollback;
