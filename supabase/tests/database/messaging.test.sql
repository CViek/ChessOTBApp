begin;
create extension if not exists pgtap with schema extensions;
select plan(20);
select has_function('public','open_conversation',array['uuid'],'canonical thread endpoint');
insert into auth.users(id,email) values
 ('11111111-1111-1111-1111-111111111111','message-a@example.test'),
 ('22222222-2222-2222-2222-222222222222','message-b@example.test'),
 ('33333333-3333-3333-3333-333333333333','message-c@example.test');
insert into public.profiles(id,owner_id,display_name) values
 ('aaaaaaaa-1111-1111-1111-111111111111','11111111-1111-1111-1111-111111111111','A'),
 ('bbbbbbbb-2222-2222-2222-222222222222','22222222-2222-2222-2222-222222222222','B'),
 ('cccccccc-3333-3333-3333-333333333333','33333333-3333-3333-3333-333333333333','C');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',true);
create temporary table thread as select public.open_conversation('bbbbbbbb-2222-2222-2222-222222222222') as id;
grant select on thread to authenticated;
select is(public.open_conversation('bbbbbbbb-2222-2222-2222-222222222222'),(select id from thread),'opening twice reuses thread');
select throws_ok($$select public.open_conversation('aaaaaaaa-1111-1111-1111-111111111111')$$,'22023',null,'self thread rejected');
select throws_ok($$select public.send_message((select id from thread),'10000000-0000-0000-0000-000000000001',E' \n\t ')$$,'22023',null,'blank message rejected');
select throws_ok($$select public.send_message((select id from thread),'10000000-0000-0000-0000-000000000001',repeat('x',4001))$$,'22023',null,'oversized message rejected');
select lives_ok($$select public.send_message((select id from thread),'10000000-0000-0000-0000-000000000001','Hello B')$$,'A sends');
select lives_ok($$select public.send_message((select id from thread),'10000000-0000-0000-0000-000000000001','Hello B')$$,'identical retry accepted');
select throws_ok($$select public.send_message((select id from thread),'10000000-0000-0000-0000-000000000001','Changed')$$,'22023',null,'ID reuse cannot change text');
select is(jsonb_array_length(public.message_history((select id from thread),null,50)->'messages'),1,'retry creates one message');
select throws_ok($$select * from public.messages$$,'42501',null,'direct table access denied');
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',true);
select is(public.open_conversation('aaaaaaaa-1111-1111-1111-111111111111'),(select id from thread),'reverse pair reuses thread');
select is((public.list_conversations()->0->>'unread_count')::integer,1,'incoming text unread');
select lives_ok($$select public.mark_conversation_read((select id from thread),(public.message_history((select id from thread),null,50)->'messages'->0->>'sequence')::bigint)$$,'read through fetched message');
select is((public.list_conversations()->0->>'unread_count')::integer,0,'read clears unread');
select lives_ok($$select public.send_message((select id from thread),'20000000-0000-0000-0000-000000000001','Reply A')$$,'B replies');
select is(jsonb_array_length(public.message_history((select id from thread),null,1)->'messages'),1,'history limit honored');
select ok((public.message_history((select id from thread),null,1)->>'next_cursor') is not null,'history exposes older cursor');
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',true);
select throws_ok($$select public.message_history((select id from thread),null,50)$$,'42501',null,'outsider history denied');
select throws_ok($$select public.send_message((select id from thread),'30000000-0000-0000-0000-000000000001','Intrusion')$$,'42501',null,'outsider send denied');
set local role anon;
select throws_ok($$select public.list_conversations()$$,'42501',null,'anonymous inbox denied');
select * from finish();
rollback;
