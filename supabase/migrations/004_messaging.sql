-- Profile IDs are public identities; auth owner IDs never leave these functions.
create table public.conversations (
 id uuid primary key default gen_random_uuid(),
 first_profile uuid not null references public.profiles(id) on delete cascade,
 second_profile uuid not null references public.profiles(id) on delete cascade,
 created_at timestamptz not null default clock_timestamp(),
 check(first_profile < second_profile),
 unique(first_profile,second_profile)
);
create table public.messages (
 id uuid primary key default gen_random_uuid(),
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 sender_id uuid not null references public.profiles(id) on delete cascade,
 client_id uuid not null,
 sequence bigint generated always as identity unique,
 body text not null check(char_length(body) between 1 and 4000 and body ~ '[^[:space:]]'),
 created_at timestamptz not null default clock_timestamp(),
 unique(conversation_id,sender_id,client_id)
);
create index message_history_order on public.messages(conversation_id,sequence desc);
create table public.conversation_reads (
 conversation_id uuid not null references public.conversations(id) on delete cascade,
 profile_id uuid not null references public.profiles(id) on delete cascade,
 through_sequence bigint not null default 0,
 primary key(conversation_id,profile_id)
);
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.conversation_reads enable row level security;
revoke all on public.conversations,public.messages,public.conversation_reads from public,anon,authenticated;
revoke all on sequence public.messages_sequence_seq from public,anon,authenticated;

create function public.require_conversation(p_id uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare profile uuid;
begin
 select p.id into profile from public.profiles p join public.conversations c
 on p.id in(c.first_profile,c.second_profile) where p.owner_id=auth.uid() and c.id=p_id;
 if profile is null then raise insufficient_privilege using message='Conversation access denied'; end if;
 return profile;
end; $$;
revoke all on function public.require_conversation(uuid) from public,anon,authenticated;

create function public.open_conversation(p_peer_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid; thread uuid;
begin
 select id into actor from public.profiles where owner_id=auth.uid();
 if actor is null then raise insufficient_privilege using message='Profile required'; end if;
 if p_peer_id is null or actor=p_peer_id or not exists(select 1 from public.profiles where id=p_peer_id)
 then raise exception using errcode='22023',message='Invalid participant'; end if;
 insert into public.conversations(first_profile,second_profile) values(least(actor,p_peer_id),greatest(actor,p_peer_id))
 on conflict(first_profile,second_profile) do update set first_profile=excluded.first_profile returning id into thread;
 return thread;
end; $$;

create function public.send_message(p_conversation_id uuid,p_client_id uuid,p_body text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.require_conversation(p_conversation_id); existing public.messages; saved public.messages;
 normalized text:=btrim(p_body,E' \t\n\r');
begin
 if p_client_id is null or normalized is null or char_length(normalized) not between 1 and 4000 or normalized !~ '[^[:space:]]'
 then raise exception using errcode='22023',message='Invalid message'; end if;
 -- Serialize within the thread before assigning a sequence, including retries.
 perform 1 from public.conversations where id=p_conversation_id for update;
 select * into existing from public.messages where conversation_id=p_conversation_id and sender_id=actor and client_id=p_client_id;
 if found then
  if existing.body<>normalized then raise exception using errcode='22023',message='Client ID already used'; end if;
  return to_jsonb(existing);
 end if;
 insert into public.messages(conversation_id,sender_id,client_id,body) values(p_conversation_id,actor,p_client_id,normalized) returning * into saved;
 return to_jsonb(saved);
end; $$;

create function public.message_history(p_conversation_id uuid,p_before bigint default null,p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.require_conversation(p_conversation_id);
 if p_limit is null or p_limit not between 1 and 100 or p_before<=0 then raise exception using errcode='22023',message='Invalid page'; end if;
 with page as (select * from public.messages where conversation_id=p_conversation_id and (p_before is null or sequence<p_before) order by sequence desc limit p_limit+1),
 shown as(select * from page order by sequence desc limit p_limit)
 select jsonb_build_object('messages',coalesce((select jsonb_agg(to_jsonb(s) order by s.sequence) from shown s),'[]'::jsonb),
 'next_cursor',case when (select count(*) from page)>p_limit then (select min(sequence) from shown) else null end) into result;
 return result;
end; $$;

create function public.mark_conversation_read(p_conversation_id uuid,p_through bigint) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=public.require_conversation(p_conversation_id);
begin
 if p_through is null or not exists(select 1 from public.messages where conversation_id=p_conversation_id and sequence=p_through)
 then raise exception using errcode='22023',message='Invalid read position'; end if;
 insert into public.conversation_reads values(p_conversation_id,actor,p_through)
 on conflict(conversation_id,profile_id) do update set through_sequence=greatest(public.conversation_reads.through_sequence,excluded.through_sequence);
end; $$;

create function public.list_conversations() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 select id into actor from public.profiles where owner_id=auth.uid();
 if actor is null then raise insufficient_privilege using message='Profile required'; end if;
 select coalesce(jsonb_agg(to_jsonb(rows) order by rows.updated_at desc,rows.id),'[]'::jsonb) into result from (
  select c.id,p.id as peer_id,p.display_name,last_message.body as preview,
  coalesce(last_message.created_at,c.created_at) as updated_at,
  (select count(*) from public.messages m where m.conversation_id=c.id and m.sender_id<>actor and m.sequence>coalesce(r.through_sequence,0)) as unread_count
  from public.conversations c join public.profiles p on p.id=case when c.first_profile=actor then c.second_profile else c.first_profile end
  left join public.conversation_reads r on r.conversation_id=c.id and r.profile_id=actor
  left join lateral(select m.body,m.created_at from public.messages m where m.conversation_id=c.id order by m.sequence desc limit 1) last_message on true
  where actor in(c.first_profile,c.second_profile)
 ) rows;
 return result;
end; $$;

revoke all on function public.open_conversation(uuid),public.send_message(uuid,uuid,text),public.message_history(uuid,bigint,integer),public.mark_conversation_read(uuid,bigint),public.list_conversations() from public,anon;
grant execute on function public.open_conversation(uuid),public.send_message(uuid,uuid,text),public.message_history(uuid,bigint,integer),public.mark_conversation_read(uuid,bigint),public.list_conversations() to authenticated;
