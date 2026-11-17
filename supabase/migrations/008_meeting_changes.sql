-- Immutable replacement proposals. Accepted facts remain authoritative until agreement.
alter table public.meeting_revisions drop constraint meeting_revisions_meeting_id_key;
alter table public.meeting_revisions add column proposed_by uuid references public.profiles(id);
alter table public.meetings add column initial_revision_id uuid references public.meeting_revisions(id);
alter table public.meetings add column accepted_revision_id uuid references public.meeting_revisions(id);
alter table public.meetings add column pending_revision_id uuid references public.meeting_revisions(id);
alter table public.meetings add column pending_proposer_id uuid references public.profiles(id);
update public.meetings m set initial_revision_id=r.id,
 accepted_revision_id=case when m.status='confirmed' then r.id else null end
 from public.meeting_revisions r where r.meeting_id=m.id;
update public.meeting_revisions r set proposed_by=m.proposer_id from public.meetings m where m.id=r.meeting_id;
alter table public.messages drop constraint message_event_shape;
alter table public.messages add constraint message_event_shape check(
 (event_kind='text' and meeting_id is null and meeting_version is null) or
 (event_kind in ('proposal','confirmed','declined','cancelled','change_proposed','change_accepted','change_declined') and meeting_id is not null and meeting_version>0)
);

create or replace function public.meeting_document(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(m) || jsonb_build_object('revision',to_jsonb(r),
 'pending_revision',(select to_jsonb(p) from public.meeting_revisions p where p.id=m.pending_revision_id),
 'revisions',(select coalesce(jsonb_agg(to_jsonb(h) order by h.starts_at,h.id),'[]'::jsonb) from public.meeting_revisions h where h.meeting_id=m.id),
 'proposer_name',a.display_name,'recipient_name',b.display_name)
 from public.meetings m join public.meeting_revisions r on r.id=coalesce(m.accepted_revision_id,m.initial_revision_id)
 join public.profiles a on a.id=m.proposer_id join public.profiles b on b.id=m.recipient_id where m.id=p_id;
$$;

create or replace function public.create_meeting(p_conversation_id uuid,p_request_id uuid,p_starts_at timestamptz,
 p_time_zone text,p_location text,p_note text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.require_conversation(p_conversation_id); peer uuid;
 existing public.meetings; revision public.meeting_revisions; saved_id uuid; revision_id uuid;
 place text:=btrim(p_location,E' \t\n\r'); note text:=btrim(coalesce(p_note,''),E' \t\n\r');
begin
 if p_request_id is null or p_starts_at is null or not isfinite(p_starts_at)
 or p_time_zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_time_zone)
 or place is null or char_length(place) not between 1 and 500 or place !~ '[^[:space:]]' or char_length(note)>2000
 then raise exception using errcode='22023',message='Invalid proposal'; end if;
 select case when first_profile=actor then second_profile else first_profile end into peer
 from public.conversations where id=p_conversation_id for update;
 select * into existing from public.meetings where conversation_id=p_conversation_id and proposer_id=actor and request_id=p_request_id;
 if found then
  select * into revision from public.meeting_revisions where id=existing.initial_revision_id;
  if revision.starts_at<>p_starts_at or revision.time_zone<>p_time_zone or revision.location<>place or revision.note<>note
  then raise exception using errcode='22023',message='Request ID already used'; end if;
  return public.meeting_document(existing.id);
 end if;
 if p_starts_at<=clock_timestamp() then raise exception using errcode='22023',message='Choose a future meeting time'; end if;
 insert into public.meetings(conversation_id,proposer_id,recipient_id,request_id) values(p_conversation_id,actor,peer,p_request_id) returning id into saved_id;
 insert into public.meeting_revisions(meeting_id,starts_at,time_zone,location,note,proposed_by)
 values(saved_id,p_starts_at,p_time_zone,place,note,actor) returning id into revision_id;
 update public.meetings set initial_revision_id=revision_id where id=saved_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(p_conversation_id,actor,gen_random_uuid(),'Game proposed. Awaiting recipient agreement.',saved_id,1,'proposal');
 return public.meeting_document(saved_id);
end; $$;

create or replace function public.respond_to_meeting(p_meeting_id uuid,p_request_id uuid,p_expected_version integer,p_decision text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare thread uuid; actor uuid; saved public.meetings; previous public.meeting_responses; result jsonb;
begin
 select conversation_id into thread from public.meetings where id=p_meeting_id;
 actor:=public.require_conversation(thread);
 perform 1 from public.conversations where id=thread for update;
 select * into saved from public.meetings where id=p_meeting_id for update;
 if saved.recipient_id<>actor then raise insufficient_privilege using message='Only the recipient may respond'; end if;
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or p_decision is null or p_decision not in ('confirmed','declined')
 then raise exception using errcode='22023',message='Invalid response'; end if;
 select * into previous from public.meeting_responses where meeting_id=p_meeting_id and actor_id=actor and request_id=p_request_id;
 if found then
  if previous.expected_version<>p_expected_version or previous.decision<>p_decision then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 if saved.version<>p_expected_version or saved.status<>'pending' then raise exception using errcode='PT409',message='Proposal changed; refresh before responding'; end if;
 if p_decision='confirmed' and (select starts_at from public.meeting_revisions where id=saved.initial_revision_id)<=clock_timestamp()
 then raise exception using errcode='PT409',message='This proposal is in the past; arrange another game'; end if;
 update public.meetings set status=p_decision,accepted_revision_id=case when p_decision='confirmed' then initial_revision_id else null end,
 version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),case when p_decision='confirmed' then 'Proposal accepted. Meeting confirmed.' else 'Proposal declined.' end,p_meeting_id,saved.version+1,p_decision);
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_responses values(p_meeting_id,actor,p_request_id,p_expected_version,p_decision,result);
 return result;
end; $$;

create function public.propose_meeting_change(p_meeting_id uuid,p_request_id uuid,p_expected_version integer,
 p_starts_at timestamptz,p_time_zone text,p_location text,p_note text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare thread uuid; actor uuid; saved public.meetings; previous public.meeting_mutations; revision_id uuid; result jsonb;
 place text:=btrim(p_location,E' \t\n\r'); note text:=btrim(coalesce(p_note,''),E' \t\n\r'); payload jsonb;
begin
 select conversation_id into thread from public.meetings where id=p_meeting_id;
 actor:=public.require_conversation(thread);
 perform 1 from public.conversations where id=thread for update;
 select * into saved from public.meetings where id=p_meeting_id for update;
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or p_starts_at is null or not isfinite(p_starts_at)
 or p_time_zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_time_zone)
 or place is null or char_length(place) not between 1 and 500 or place !~ '[^[:space:]]' or char_length(note)>2000
 then raise exception using errcode='22023',message='Invalid replacement'; end if;
 payload:=jsonb_build_object('action','propose_change','version',p_expected_version,'starts_at',p_starts_at,'time_zone',p_time_zone,'location',place,'note',note);
 select * into previous from public.meeting_mutations where meeting_id=p_meeting_id and actor_id=actor and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 if saved.version<>p_expected_version or saved.status<>'confirmed' or saved.pending_revision_id is not null
 then raise exception using errcode='PT409',message='Meeting changed; refresh before proposing'; end if;
 if p_starts_at<=clock_timestamp() then raise exception using errcode='22023',message='Choose a future meeting time'; end if;
 insert into public.meeting_revisions(meeting_id,starts_at,time_zone,location,note,proposed_by)
 values(p_meeting_id,p_starts_at,p_time_zone,place,note,actor) returning id into revision_id;
 update public.meetings set pending_revision_id=revision_id,pending_proposer_id=actor,version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),'New details proposed. The agreed plan stays confirmed.',p_meeting_id,saved.version+1,'change_proposed');
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_mutations values(p_meeting_id,actor,p_request_id,payload,result);
 return result;
end; $$;

create function public.respond_to_meeting_change(p_meeting_id uuid,p_request_id uuid,p_expected_version integer,p_decision text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare thread uuid; actor uuid; saved public.meetings; previous public.meeting_mutations; payload jsonb; result jsonb;
begin
 select conversation_id into thread from public.meetings where id=p_meeting_id;
 actor:=public.require_conversation(thread);
 perform 1 from public.conversations where id=thread for update;
 select * into saved from public.meetings where id=p_meeting_id for update;
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or p_decision is null or p_decision not in ('confirmed','declined')
 then raise exception using errcode='22023',message='Invalid response'; end if;
 payload:=jsonb_build_object('action','respond_change','version',p_expected_version,'decision',p_decision);
 select * into previous from public.meeting_mutations where meeting_id=p_meeting_id and actor_id=actor and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 if saved.version<>p_expected_version or saved.status<>'confirmed' or saved.pending_revision_id is null
 then raise exception using errcode='PT409',message='Meeting changed; refresh before responding'; end if;
 if saved.pending_proposer_id=actor then raise insufficient_privilege using message='Only the counterpart may respond'; end if;
 if p_decision='confirmed' and (select starts_at from public.meeting_revisions where id=saved.pending_revision_id)<=clock_timestamp()
 then raise exception using errcode='PT409',message='These details are in the past; decline and propose another time'; end if;
 update public.meetings set accepted_revision_id=case when p_decision='confirmed' then pending_revision_id else accepted_revision_id end,
 pending_revision_id=null,pending_proposer_id=null,version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),case when p_decision='confirmed' then 'New details accepted.' else 'Change declined. The agreed plan is unchanged.' end,
 p_meeting_id,saved.version+1,case when p_decision='confirmed' then 'change_accepted' else 'change_declined' end);
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_mutations values(p_meeting_id,actor,p_request_id,payload,result);
 return result;
end; $$;

revoke all on function public.propose_meeting_change(uuid,uuid,integer,timestamptz,text,text,text),public.respond_to_meeting_change(uuid,uuid,integer,text) from public,anon;
grant execute on function public.propose_meeting_change(uuid,uuid,integer,timestamptz,text,text,text),public.respond_to_meeting_change(uuid,uuid,integer,text) to authenticated;

create or replace function public.cancel_meeting(p_meeting_id uuid,p_request_id uuid,p_expected_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare thread uuid; actor uuid; saved public.meetings; previous public.meeting_mutations;
 payload jsonb:=jsonb_build_object('action','cancel','version',p_expected_version); result jsonb;
begin
 select conversation_id into thread from public.meetings where id=p_meeting_id;
 actor:=public.require_conversation(thread);
 perform 1 from public.conversations where id=thread for update;
 select * into saved from public.meetings where id=p_meeting_id for update;
 if p_request_id is null or p_expected_version is null or p_expected_version<1
 then raise exception using errcode='22023',message='Invalid cancellation'; end if;
 select * into previous from public.meeting_mutations where meeting_id=p_meeting_id and actor_id=actor and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 if saved.version<>p_expected_version or saved.status not in ('pending','confirmed')
 then raise exception using errcode='PT409',message='Meeting changed; refresh before cancelling'; end if;
 update public.meetings set status='cancelled',pending_revision_id=null,pending_proposer_id=null,version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),'Meeting cancelled.',p_meeting_id,saved.version+1,'cancelled');
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_mutations values(p_meeting_id,actor,p_request_id,payload,result);
 return result;
end; $$;
revoke all on function public.cancel_meeting(uuid,uuid,integer) from public,anon;
grant execute on function public.cancel_meeting(uuid,uuid,integer) to authenticated;
