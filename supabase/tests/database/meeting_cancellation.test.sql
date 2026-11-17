begin;
create extension if not exists pgtap with schema extensions;
select plan(18);
insert into auth.users(id,email) values
 ('61111111-1111-1111-1111-111111111111','cancel-a@example.test'),
 ('62222222-2222-2222-2222-222222222222','cancel-b@example.test'),
 ('63333333-3333-3333-3333-333333333333','cancel-c@example.test');
insert into public.profiles(id,owner_id,display_name) values
 ('6aaaaaaa-1111-1111-1111-111111111111','61111111-1111-1111-1111-111111111111','A'),
 ('6bbbbbbb-2222-2222-2222-222222222222','62222222-2222-2222-2222-222222222222','B'),
 ('6ccccccc-3333-3333-3333-333333333333','63333333-3333-3333-3333-333333333333','C');
set local role authenticated;
select set_config('request.jwt.claim.sub','61111111-1111-1111-1111-111111111111',true);
create temporary table ct as select public.open_conversation('6bbbbbbb-2222-2222-2222-222222222222') id;
create temporary table cm as select public.create_meeting((select id from ct),gen_random_uuid(),'2099-05-17 18:00Z','UTC','Library','') value;
grant select on ct,cm to authenticated;
select throws_ok($$select public.cancel_meeting((select (value->>'id')::uuid from cm),gen_random_uuid(),2)$$,'PT409',null,'stale cancellation denied');
select is(public.cancel_meeting((select (value->>'id')::uuid from cm),'60000000-0000-0000-0000-000000000001',1)->>'status','cancelled','sender withdraws pending proposal');
select is(public.cancel_meeting((select (value->>'id')::uuid from cm),'60000000-0000-0000-0000-000000000001',1)->>'version','2','identical retry returns receipt');
select throws_ok($$select public.cancel_meeting((select (value->>'id')::uuid from cm),'60000000-0000-0000-0000-000000000001',2)$$,'22023',null,'receipt payload is immutable');
select is(jsonb_array_length(public.message_history((select id from ct))->'messages'),2,'retry creates one cancellation event');
select set_config('request.jwt.claim.sub','62222222-2222-2222-2222-222222222222',true);
select throws_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from cm),gen_random_uuid(),1,'confirmed')$$,'PT409',null,'cancelled proposal cannot be accepted');
select throws_ok($$select public.cancel_meeting((select (value->>'id')::uuid from cm),gen_random_uuid(),2)$$,'PT409',null,'terminal cancellation rejected');
create temporary table recipient_cm as select public.create_meeting((select id from ct),gen_random_uuid(),'2099-05-17 18:00Z','UTC','Cafe','') value;
grant select on recipient_cm to authenticated;
select set_config('request.jwt.claim.sub','61111111-1111-1111-1111-111111111111',true);
select lives_ok($$select public.cancel_meeting((select (value->>'id')::uuid from recipient_cm),gen_random_uuid(),1)$$,'recipient can cancel pending');
create temporary table confirmed_cm as select public.create_meeting((select id from ct),gen_random_uuid(),'2099-05-17 18:00Z','UTC','Park','') value;
grant select on confirmed_cm to authenticated;
select set_config('request.jwt.claim.sub','62222222-2222-2222-2222-222222222222',true);
select lives_ok($$select public.respond_to_meeting((select (value->>'id')::uuid from confirmed_cm),gen_random_uuid(),1,'confirmed')$$,'recipient confirms');
reset role;
create function pg_temp.fail_cancel_event() returns trigger language plpgsql as $$
begin raise exception using errcode='PT500',message='Injected failure'; end; $$;
create trigger fail_cancel_event before insert on public.messages for each row when(new.event_kind='cancelled') execute function pg_temp.fail_cancel_event();
set local role authenticated;
select throws_ok($$select public.cancel_meeting((select (value->>'id')::uuid from confirmed_cm),'60000000-0000-0000-0000-000000000002',2)$$,'PT500',null,'event failure rolls back cancellation');
select is(public.get_meeting((select (value->>'id')::uuid from confirmed_cm))->>'status','confirmed','failed event preserves confirmed plan');
select is(public.get_meeting((select (value->>'id')::uuid from confirmed_cm))->>'version','2','failed event preserves version');
reset role;
select is((select count(*)::integer from public.messages where meeting_id=(select (value->>'id')::uuid from confirmed_cm) and event_kind='cancelled'),0,'failed transaction leaves no cancellation event');
select is((select count(*)::integer from public.meeting_mutations where meeting_id=(select (value->>'id')::uuid from confirmed_cm)),0,'failed transaction leaves no retry receipt');
drop trigger fail_cancel_event on public.messages;
set local role authenticated;
select lives_ok($$select public.cancel_meeting((select (value->>'id')::uuid from confirmed_cm),'60000000-0000-0000-0000-000000000002',2)$$,'recipient cancels confirmed plan');
select set_config('request.jwt.claim.sub','63333333-3333-3333-3333-333333333333',true);
select throws_ok($$select public.cancel_meeting((select (value->>'id')::uuid from confirmed_cm),gen_random_uuid(),3)$$,'42501',null,'outsider denied');
select throws_ok($$select * from public.meeting_mutations$$,'42501',null,'mutation receipts private');
set local role anon;
select throws_ok($$select public.cancel_meeting(gen_random_uuid(),gen_random_uuid(),1)$$,'42501',null,'anonymous denied');
select * from finish();
rollback;
