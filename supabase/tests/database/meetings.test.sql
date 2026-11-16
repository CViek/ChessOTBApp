begin;
create extension if not exists pgtap with schema extensions;
select plan(33);
select has_function('public','create_meeting',array['uuid','uuid','timestamp with time zone','text','text','text'],'proposal endpoint');
insert into auth.users(id,email) values
 ('51111111-1111-1111-1111-111111111111','meeting-a@example.test'),
 ('52222222-2222-2222-2222-222222222222','meeting-b@example.test'),
 ('53333333-3333-3333-3333-333333333333','meeting-c@example.test');
insert into public.profiles(id,owner_id,display_name) values
 ('5aaaaaaa-1111-1111-1111-111111111111','51111111-1111-1111-1111-111111111111','Meeting A'),
 ('5bbbbbbb-2222-2222-2222-222222222222','52222222-2222-2222-2222-222222222222','Meeting B'),
 ('5ccccccc-3333-3333-3333-333333333333','53333333-3333-3333-3333-333333333333','Meeting C');
set local role authenticated;
select set_config('request.jwt.claim.sub','51111111-1111-1111-1111-111111111111',true);
create temporary table meeting_thread as select public.open_conversation('5bbbbbbb-2222-2222-2222-222222222222') as id;
grant select on meeting_thread to authenticated;
select throws_ok($$select public.create_meeting((select id from meeting_thread),gen_random_uuid(),'2099-05-17 18:00Z','America/New_York',E' \t\n ','')$$,'22023',null,'blank place rejected');
select throws_ok($$select public.create_meeting((select id from meeting_thread),gen_random_uuid(),'2099-05-17 18:00Z','Unknown/Zone','Library','')$$,'22023',null,'unknown zone rejected');
select throws_ok($$select public.create_meeting((select id from meeting_thread),gen_random_uuid(),'infinity','America/New_York','Library','')$$,'22023',null,'infinite instant rejected');
create temporary table proposal as select public.create_meeting((select id from meeting_thread),'50000000-0000-0000-0000-000000000001','2099-05-17 18:00Z','America/New_York','Library, main stairs','I can bring a board.') as value;
grant select on proposal to authenticated;
select is((select value->>'status' from proposal),'pending','sending does not confirm');
select is((select value->>'version' from proposal),'1','initial version');
select is((select value->'revision'->>'location' from proposal),'Library, main stairs','entered place preserved');
select is((select value->'revision'->>'time_zone' from proposal),'America/New_York','named zone preserved');
select is(public.create_meeting((select id from meeting_thread),'50000000-0000-0000-0000-000000000001','2099-05-17 18:00Z','America/New_York','Library, main stairs','I can bring a board.')->>'id',(select value->>'id' from proposal),'retry returns original meeting');
select throws_ok($$select public.create_meeting((select id from meeting_thread),'50000000-0000-0000-0000-000000000001','2099-05-17 18:00Z','America/New_York','Changed','I can bring a board.')$$,'22023',null,'request reuse cannot alter fields');
select is(jsonb_array_length(public.message_history((select id from meeting_thread))->'messages'),1,'one linked event after retry');
select is(public.message_history((select id from meeting_thread))->'messages'->0->>'meeting_id',(select value->>'id' from proposal),'thread event links to meeting');
select throws_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from proposal),gen_random_uuid(),1,'confirmed')$$,'42501',null,'proposer cannot accept');
select set_config('request.jwt.claim.sub','52222222-2222-2222-2222-222222222222',true);
select is(public.get_meeting((select (value->>'id')::uuid from proposal))->'revision',(select value->'revision' from proposal),'recipient sees same details');
select throws_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from proposal),gen_random_uuid(),2,'confirmed')$$,'PT409',null,'stale version rejected');
select throws_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from proposal),gen_random_uuid(),1,'cancelled')$$,'22023',null,'unsupported transition rejected');
select is(public.respond_to_meeting((select (value->>'id')::uuid from proposal),'50000000-0000-0000-0000-000000000002',1,'confirmed')->>'status','confirmed','recipient explicitly confirms');
select is(public.respond_to_meeting((select (value->>'id')::uuid from proposal),'50000000-0000-0000-0000-000000000002',1,'confirmed')->>'version','2','lost response retry is idempotent');
select throws_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from proposal),'50000000-0000-0000-0000-000000000002',1,'declined')$$,'22023',null,'action ID cannot change decision');
select throws_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from proposal),gen_random_uuid(),1,'declined')$$,'PT409',null,'second response rejected');
select is(jsonb_array_length(public.message_history((select id from meeting_thread))->'messages'),2,'one committed response event');
select is(jsonb_array_length(public.list_meetings()->'meetings'),1,'participant list contains arrangement');
select throws_ok($$select * from public.meetings$$,'42501',null,'direct meeting access denied');
select set_config('request.jwt.claim.sub','53333333-3333-3333-3333-333333333333',true);
select throws_ok($$select public.get_meeting((select (value->>'id')::uuid from proposal))$$,'42501',null,'outsider cannot read');
select throws_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from proposal),gen_random_uuid(),2,'declined')$$,'42501',null,'outsider cannot answer');
select set_config('request.jwt.claim.sub','51111111-1111-1111-1111-111111111111',true);
create temporary table rollback_proposal as select public.create_meeting((select id from meeting_thread),'50000000-0000-0000-0000-000000000003','2099-05-17 18:00Z','America/New_York','Library','') as value;
grant select on rollback_proposal to authenticated;
reset role;
create function pg_temp.reject_meeting_event() returns trigger language plpgsql as $$
begin raise exception using errcode='PT500',message='Injected event failure'; end; $$;
create trigger injected_event_failure before insert on public.messages for each row when(new.meeting_id is not null) execute function pg_temp.reject_meeting_event();
set local role authenticated;
select throws_ok($$select public.create_meeting((select id from meeting_thread),'50000000-0000-0000-0000-000000000004','2099-05-17 18:00Z','America/New_York','Library','')$$,'PT500',null,'event failure rejects proposal');
select is(jsonb_array_length(public.list_meetings()->'meetings'),2,'failed proposal leaves no partial meeting');
select set_config('request.jwt.claim.sub','52222222-2222-2222-2222-222222222222',true);
select throws_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from rollback_proposal),'50000000-0000-0000-0000-000000000005',1,'confirmed')$$,'PT500',null,'event failure rejects acceptance');
select is(public.get_meeting((select (value->>'id')::uuid from rollback_proposal))->>'status','pending','failed event cannot confirm meeting');
select is(public.get_meeting((select (value->>'id')::uuid from rollback_proposal))->>'version','1','failed event cannot advance version');
select is(jsonb_array_length(public.message_history((select id from meeting_thread))->'messages'),3,'failed operations leave no partial event');
reset role;
drop trigger injected_event_failure on public.messages;
set local role authenticated;
select lives_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from rollback_proposal),'50000000-0000-0000-0000-000000000005',1,'confirmed')$$,'retry after transaction failure succeeds');
set local role anon;
select throws_ok($$select public.list_meetings()$$,'42501',null,'anonymous list denied');
select * from finish();
rollback;
