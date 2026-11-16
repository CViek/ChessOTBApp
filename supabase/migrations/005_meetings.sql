-- Initial agreement only. Revisions/cancellation are Phase 6; date/past policy
-- remains an explicit Phase 5 entrance decision before exposing customer UI.
create table public.meetings (
 id uuid primary key default gen_random_uuid(),
 sequence bigint generated always as identity unique,
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 proposer_id uuid not null references public.profiles(id) on delete cascade,
 recipient_id uuid not null references public.profiles(id) on delete cascade,
 request_id uuid not null,
 status text not null default 'pending' check(status in ('pending','confirmed','declined')),
 version integer not null default 1 check(version > 0),
 created_at timestamptz not null default clock_timestamp(),
 updated_at timestamptz not null default clock_timestamp(),
 check(proposer_id <> recipient_id),
 unique(conversation_id,proposer_id,request_id)
);
create index participant_meetings_proposer on public.meetings(proposer_id,sequence desc);
create index participant_meetings_recipient on public.meetings(recipient_id,sequence desc);
create table public.meeting_revisions (
 id uuid primary key default gen_random_uuid(),
 meeting_id uuid not null unique references public.meetings(id) on delete cascade,
 starts_at timestamptz not null check(isfinite(starts_at)),
 time_zone text not null,
 location text not null check(char_length(location) between 1 and 500 and location ~ '[^[:space:]]'),
 note text not null default '' check(char_length(note) <= 2000)
);
create table public.meeting_responses (
 meeting_id uuid not null references public.meetings(id) on delete cascade,
 actor_id uuid not null references public.profiles(id) on delete cascade,
 request_id uuid not null,
 expected_version integer not null,
 decision text not null check(decision in ('confirmed','declined')),
 result jsonb not null,
 primary key(meeting_id,actor_id,request_id)
);
alter table public.meetings enable row level security;
alter table public.meeting_revisions enable row level security;
alter table public.meeting_responses enable row level security;
revoke all on public.meetings,public.meeting_revisions,public.meeting_responses from public,anon,authenticated;
revoke all on sequence public.meetings_sequence_seq from public,anon,authenticated;

alter table public.messages add column meeting_id uuid references public.meetings(id) on delete cascade;
alter table public.messages add column meeting_version integer;
alter table public.messages add column event_kind text not null default 'text';
alter table public.messages add constraint message_event_shape check(
 (event_kind='text' and meeting_id is null and meeting_version is null) or
 (event_kind in ('proposal','confirmed','declined') and meeting_id is not null and meeting_version > 0)
);
create unique index meeting_event_version on public.messages(meeting_id,meeting_version) where meeting_id is not null;

create function public.meeting_document(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(m) || jsonb_build_object('revision',to_jsonb(r),
 'proposer_name',a.display_name,'recipient_name',b.display_name)
 from public.meetings m join public.meeting_revisions r on r.meeting_id=m.id
 join public.profiles a on a.id=m.proposer_id join public.profiles b on b.id=m.recipient_id
 where m.id=p_id;
$$;
revoke all on function public.meeting_document(uuid) from public,anon,authenticated;

create function public.get_meeting(p_meeting_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare thread uuid;
begin
 select conversation_id into thread from public.meetings where id=p_meeting_id;
 perform public.require_conversation(thread);
 return public.meeting_document(p_meeting_id);
end; $$;

create function public.create_meeting(p_conversation_id uuid,p_request_id uuid,p_starts_at timestamptz,
 p_time_zone text,p_location text,p_note text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.require_conversation(p_conversation_id); peer uuid;
 existing public.meetings; revision public.meeting_revisions; saved_id uuid;
 place text:=btrim(p_location,E' \t\n\r'); note text:=btrim(coalesce(p_note,''),E' \t\n\r');
begin
 if p_request_id is null or p_starts_at is null or not isfinite(p_starts_at)
 or p_time_zone is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_time_zone)
 or place is null or char_length(place) not between 1 and 500 or place !~ '[^[:space:]]'
 or char_length(note)>2000 then raise exception using errcode='22023',message='Invalid proposal'; end if;
 -- Match send_message lock order: all thread events serialize before sequence allocation.
 select case when first_profile=actor then second_profile else first_profile end into peer
 from public.conversations where id=p_conversation_id for update;
 select * into existing from public.meetings where conversation_id=p_conversation_id and proposer_id=actor and request_id=p_request_id;
 if found then
  select * into revision from public.meeting_revisions where meeting_id=existing.id;
  if revision.starts_at<>p_starts_at or revision.time_zone<>p_time_zone or revision.location<>place or revision.note<>note
  then raise exception using errcode='22023',message='Request ID already used'; end if;
  return public.meeting_document(existing.id);
 end if;
 insert into public.meetings(conversation_id,proposer_id,recipient_id,request_id)
 values(p_conversation_id,actor,peer,p_request_id) returning id into saved_id;
 insert into public.meeting_revisions(meeting_id,starts_at,time_zone,location,note)
 values(saved_id,p_starts_at,p_time_zone,place,note);
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(p_conversation_id,actor,gen_random_uuid(),'Game proposed. Awaiting recipient agreement.',saved_id,1,'proposal');
 return public.meeting_document(saved_id);
end; $$;

create function public.respond_to_meeting(p_meeting_id uuid,p_request_id uuid,p_expected_version integer,p_decision text) returns jsonb
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
  if previous.expected_version<>p_expected_version or previous.decision<>p_decision
  then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 if saved.version<>p_expected_version or saved.status<>'pending'
 then raise exception using errcode='PT409',message='Proposal changed; refresh before responding'; end if;
 update public.meetings set status=p_decision,version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),case when p_decision='confirmed' then 'Proposal accepted. Meeting confirmed.' else 'Proposal declined.' end,
 p_meeting_id,saved.version+1,p_decision);
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_responses values(p_meeting_id,actor,p_request_id,p_expected_version,p_decision,result);
 return result;
end; $$;

create function public.list_meetings(p_before bigint default null,p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 select id into actor from public.profiles where owner_id=auth.uid();
 if actor is null then raise insufficient_privilege using message='Profile required'; end if;
 if p_limit is null or p_limit not between 1 and 100 or p_before<=0
 then raise exception using errcode='22023',message='Invalid page'; end if;
 with page as(select id,sequence from public.meetings where actor in(proposer_id,recipient_id)
  and (p_before is null or sequence<p_before) order by sequence desc limit p_limit+1),
 shown as(select * from page order by sequence desc limit p_limit)
 select jsonb_build_object('meetings',coalesce((select jsonb_agg(public.meeting_document(s.id) order by s.sequence desc) from shown s),'[]'::jsonb),
 'next_cursor',case when (select count(*) from page)>p_limit then (select min(sequence) from shown) else null end) into result;
 return result;
end; $$;

revoke all on function public.get_meeting(uuid),public.create_meeting(uuid,uuid,timestamptz,text,text,text),public.respond_to_meeting(uuid,uuid,integer,text),public.list_meetings(bigint,integer) from public,anon;
grant execute on function public.get_meeting(uuid),public.create_meeting(uuid,uuid,timestamptz,text,text,text),public.respond_to_meeting(uuid,uuid,integer,text),public.list_meetings(bigint,integer) to authenticated;
