-- Exact selected addresses are immutable revision facts. Legacy proposals remain readable.
alter table public.meeting_revisions add column place jsonb;

create function public.validate_meeting_place(p_place jsonb) returns void
language plpgsql immutable set search_path='' as $$
begin
 if p_place is null or jsonb_typeof(p_place)<>'object'
 or jsonb_typeof(p_place->'name') is distinct from 'string'
 or jsonb_typeof(p_place->'address') is distinct from 'string'
 or char_length(btrim(p_place->>'name')) not between 1 and 200
 or char_length(btrim(p_place->>'address')) not between 1 and 500
 or p_place->>'name' ~ '[[:cntrl:]]' or p_place->>'address' ~ '[[:cntrl:]]'
 or jsonb_typeof(p_place->'latitude') is distinct from 'number'
 or jsonb_typeof(p_place->'longitude') is distinct from 'number'
 then raise exception using errcode='22023',message='Select an exact meeting address'; end if;
 if (p_place->>'latitude')::numeric not between -90 and 90
 or (p_place->>'longitude')::numeric not between -180 and 180
 then raise exception using errcode='22023',message='Invalid meeting coordinates'; end if;
end; $$;
revoke all on function public.validate_meeting_place(jsonb) from public,anon,authenticated;

create function public.create_meeting_with_place(p_conversation_id uuid,p_request_id uuid,p_starts_at timestamptz,
 p_time_zone text,p_location text,p_place jsonb,p_note text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.require_conversation(p_conversation_id); peer uuid;
 existing public.meetings; revision public.meeting_revisions; saved_id uuid; revision_id uuid;
 place text:=btrim(p_location,E' \t\n\r'); note text:=btrim(coalesce(p_note,''),E' \t\n\r');
begin
 perform public.validate_meeting_place(p_place);
 if p_request_id is null or p_starts_at is null or not isfinite(p_starts_at)
 or p_time_zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_time_zone)
 or place is null or char_length(place) not between 1 and 500 or place !~ '[^[:space:]]' or char_length(note)>2000
 then raise exception using errcode='22023',message='Invalid proposal'; end if;
 select case when first_profile=actor then second_profile else first_profile end into peer
 from public.conversations where id=p_conversation_id for update;
 select * into existing from public.meetings where conversation_id=p_conversation_id and proposer_id=actor and request_id=p_request_id;
 if found then
  select * into revision from public.meeting_revisions where id=existing.initial_revision_id;
  if revision.starts_at<>p_starts_at or revision.time_zone<>p_time_zone or revision.location<>place or revision.note<>note or revision.place is distinct from p_place
  then raise exception using errcode='22023',message='Request ID already used'; end if;
  return public.meeting_document(existing.id);
 end if;
 if p_starts_at<=clock_timestamp() then raise exception using errcode='22023',message='Choose a future meeting time'; end if;
 insert into public.meetings(conversation_id,proposer_id,recipient_id,request_id) values(p_conversation_id,actor,peer,p_request_id) returning id into saved_id;
 insert into public.meeting_revisions(meeting_id,starts_at,time_zone,location,note,proposed_by,place)
 values(saved_id,p_starts_at,p_time_zone,place,note,actor,p_place) returning id into revision_id;
 update public.meetings set initial_revision_id=revision_id where id=saved_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(p_conversation_id,actor,gen_random_uuid(),'Game proposed. Awaiting recipient agreement.',saved_id,1,'proposal');
 return public.meeting_document(saved_id);
end; $$;

create function public.propose_meeting_change_with_place(p_meeting_id uuid,p_request_id uuid,p_expected_version integer,
 p_starts_at timestamptz,p_time_zone text,p_location text,p_place jsonb,p_note text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare thread uuid; actor uuid; saved public.meetings; previous public.meeting_mutations; revision_id uuid; result jsonb;
 place text:=btrim(p_location,E' \t\n\r'); note text:=btrim(coalesce(p_note,''),E' \t\n\r'); payload jsonb;
begin
 perform public.validate_meeting_place(p_place);
 select conversation_id into thread from public.meetings where id=p_meeting_id;
 actor:=public.require_conversation(thread);
 perform 1 from public.conversations where id=thread for update;
 select * into saved from public.meetings where id=p_meeting_id for update;
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or p_starts_at is null or not isfinite(p_starts_at)
 or p_time_zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_time_zone)
 or place is null or char_length(place) not between 1 and 500 or place !~ '[^[:space:]]' or char_length(note)>2000
 then raise exception using errcode='22023',message='Invalid replacement'; end if;
 payload:=jsonb_build_object('action','propose_change','version',p_expected_version,'starts_at',p_starts_at,'time_zone',p_time_zone,'location',place,'note',note,'place',p_place);
 select * into previous from public.meeting_mutations where meeting_id=p_meeting_id and actor_id=actor and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 if saved.version<>p_expected_version or saved.status<>'confirmed' or saved.pending_revision_id is not null
 then raise exception using errcode='PT409',message='Meeting changed; refresh before proposing'; end if;
 if p_starts_at<=clock_timestamp() then raise exception using errcode='22023',message='Choose a future meeting time'; end if;
 insert into public.meeting_revisions(meeting_id,starts_at,time_zone,location,note,proposed_by,place)
 values(p_meeting_id,p_starts_at,p_time_zone,place,note,actor,p_place) returning id into revision_id;
 update public.meetings set pending_revision_id=revision_id,pending_proposer_id=actor,version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),'New details proposed. The agreed plan stays confirmed.',p_meeting_id,saved.version+1,'change_proposed');
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_mutations values(p_meeting_id,actor,p_request_id,payload,result);
 return result;
end; $$;

create function public.edit_meeting_change_with_place(p_meeting_id uuid,p_request_id uuid,p_expected_version integer,
 p_starts_at timestamptz,p_time_zone text,p_location text,p_place jsonb,p_note text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare thread uuid; actor uuid; saved public.meetings; previous public.meeting_mutations; revision_id uuid; result jsonb;
 place text:=btrim(p_location,E' \t\n\r'); note text:=btrim(coalesce(p_note,''),E' \t\n\r'); payload jsonb;
begin
 perform public.validate_meeting_place(p_place);
 select conversation_id into thread from public.meetings where id=p_meeting_id;
 actor:=public.require_conversation(thread);
 perform 1 from public.conversations where id=thread for update;
 select * into saved from public.meetings where id=p_meeting_id for update;
 if p_request_id is null or p_expected_version is null or p_expected_version<1 or p_starts_at is null or not isfinite(p_starts_at)
 or p_time_zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_time_zone)
 or place is null or char_length(place) not between 1 and 500 or place !~ '[^[:space:]]' or char_length(note)>2000
 then raise exception using errcode='22023',message='Invalid replacement'; end if;
 payload:=jsonb_build_object('action','edit_change','version',p_expected_version,'starts_at',p_starts_at,'time_zone',p_time_zone,'location',place,'note',note,'place',p_place);
 select * into previous from public.meeting_mutations where meeting_id=p_meeting_id and actor_id=actor and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 if saved.version<>p_expected_version or saved.status<>'confirmed' or saved.pending_revision_id is null or saved.pending_proposer_id is distinct from actor
 then raise exception using errcode='PT409',message='Meeting changed; reload before editing'; end if;
 if p_starts_at<=clock_timestamp() then raise exception using errcode='22023',message='Choose a future meeting time'; end if;
 insert into public.meeting_revisions(meeting_id,starts_at,time_zone,location,note,proposed_by,place)
 values(p_meeting_id,p_starts_at,p_time_zone,place,note,actor,p_place) returning id into revision_id;
 update public.meetings set pending_revision_id=revision_id,pending_proposer_id=actor,version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),'Proposed change edited. The agreed plan stays confirmed.',p_meeting_id,saved.version+1,'change_proposed');
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_mutations values(p_meeting_id,actor,p_request_id,payload,result);
 return result;
end; $$;


revoke all on function public.create_meeting_with_place(uuid,uuid,timestamptz,text,text,jsonb,text),public.propose_meeting_change_with_place(uuid,uuid,integer,timestamptz,text,text,jsonb,text),public.edit_meeting_change_with_place(uuid,uuid,integer,timestamptz,text,text,jsonb,text) from public,anon;
grant execute on function public.create_meeting_with_place(uuid,uuid,timestamptz,text,text,jsonb,text),public.propose_meeting_change_with_place(uuid,uuid,integer,timestamptz,text,text,jsonb,text),public.edit_meeting_change_with_place(uuid,uuid,integer,timestamptz,text,text,jsonb,text) to authenticated;
