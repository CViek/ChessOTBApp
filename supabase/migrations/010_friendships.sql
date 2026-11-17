-- Canonical pairs persist through decline/removal; versions prevent stale actions.
create table public.friendships (
 first_profile uuid not null references public.profiles(id) on delete cascade,
 second_profile uuid not null references public.profiles(id) on delete cascade,
 sequence bigint generated always as identity unique,
 state text not null default 'none' check(state in ('none','pending','accepted')),
 requester_id uuid references public.profiles(id) on delete cascade,
 version integer not null default 0,
 primary key(first_profile,second_profile), check(first_profile<second_profile),
 check(requester_id is null or requester_id in(first_profile,second_profile))
);
create table public.friendship_receipts (
 actor_id uuid not null references public.profiles(id) on delete cascade,
 request_id uuid not null, payload jsonb not null, result jsonb not null,
 primary key(actor_id,request_id)
);
alter table public.friendships enable row level security;
alter table public.friendship_receipts enable row level security;
revoke all on public.friendships,public.friendship_receipts from public,anon,authenticated;
revoke all on sequence public.friendships_sequence_seq from public,anon,authenticated;

create function public.friendship_document(p_actor uuid,p_peer uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('peer_id',p.id,'display_name',p.display_name,'area_name',a.name,
 'state',coalesce(f.state,'none'),'requester_id',f.requester_id,'version',coalesce(f.version,0),'sequence',coalesce(f.sequence,0))
 from public.profiles p left join public.profile_areas a on a.profile_id=p.id
 left join public.friendships f on f.first_profile=least(p_actor,p_peer) and f.second_profile=greatest(p_actor,p_peer)
 where p.id=p_peer;
$$;
revoke all on function public.friendship_document(uuid,uuid) from public,anon,authenticated;

create function public.get_friendship(p_peer_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid;
begin
 select id into actor from public.profiles where owner_id=auth.uid();
 if actor is null then raise insufficient_privilege using message='Profile required'; end if;
 if p_peer_id is null or p_peer_id=actor or not exists(select 1 from public.profiles where id=p_peer_id)
 then raise exception using errcode='22023',message='Invalid peer'; end if;
 return public.friendship_document(actor,p_peer_id);
end; $$;

create function public.mutate_friendship(p_peer_id uuid,p_action text,p_request_id uuid,p_expected_version integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; saved public.friendships; previous public.friendship_receipts; payload jsonb; result jsonb;
begin
 select id into actor from public.profiles where owner_id=auth.uid();
 if actor is null then raise insufficient_privilege using message='Profile required'; end if;
 if p_peer_id is null or p_peer_id=actor or not exists(select 1 from public.profiles where id=p_peer_id)
 or p_request_id is null or p_expected_version is null or p_expected_version<0
 or p_action is null or p_action not in ('send','accept','decline','remove')
 then raise exception using errcode='22023',message='Invalid friendship action'; end if;
 -- Serialize this actor's retries, including accidental reuse against another peer.
 perform 1 from public.profiles where id=actor for no key update;
 payload:=jsonb_build_object('peer',p_peer_id,'action',p_action,'version',p_expected_version);
 select * into previous from public.friendship_receipts where actor_id=actor and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 insert into public.friendships(first_profile,second_profile) values(least(actor,p_peer_id),greatest(actor,p_peer_id)) on conflict do nothing;
 select * into saved from public.friendships where first_profile=least(actor,p_peer_id) and second_profile=greatest(actor,p_peer_id) for update;
 if p_action='send' and saved.state in ('pending','accepted') then
  -- A crossed request never implies explicit acceptance.
  result:=public.friendship_document(actor,p_peer_id);
 else
  if saved.version<>p_expected_version then raise exception using errcode='PT409',message='Friendship changed; refresh and retry'; end if;
  if p_action='send' and saved.state='none' then
   update public.friendships set state='pending',requester_id=actor,version=version+1 where first_profile=saved.first_profile and second_profile=saved.second_profile;
  elsif p_action in ('accept','decline') and saved.state='pending' then
   if saved.requester_id=actor then raise insufficient_privilege using message='Only the recipient may respond'; end if;
   update public.friendships set state=case when p_action='accept' then 'accepted' else 'none' end,version=version+1 where first_profile=saved.first_profile and second_profile=saved.second_profile;
  elsif p_action='remove' and saved.state='accepted' then
   update public.friendships set state='none',version=version+1 where first_profile=saved.first_profile and second_profile=saved.second_profile;
  else raise exception using errcode='PT409',message='This action is no longer available'; end if;
  result:=public.friendship_document(actor,p_peer_id);
 end if;
 insert into public.friendship_receipts values(actor,p_request_id,payload,result);
 return result;
end; $$;

create function public.list_friendships(p_before bigint default null,p_limit integer default 50) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 select id into actor from public.profiles where owner_id=auth.uid();
 if actor is null then raise insufficient_privilege using message='Profile required'; end if;
 if p_limit is null or p_limit not between 1 and 100 or p_before<=0 then raise exception using errcode='22023',message='Invalid page'; end if;
 with page as(select sequence,case when first_profile=actor then second_profile else first_profile end peer
 from public.friendships where actor in(first_profile,second_profile) and state<>'none' and (p_before is null or sequence<p_before) order by sequence desc limit p_limit+1),
 shown as(select * from page order by sequence desc limit p_limit)
 select jsonb_build_object('relationships',coalesce((select jsonb_agg(public.friendship_document(actor,peer) order by sequence desc) from shown),'[]'::jsonb),
 'next_cursor',case when (select count(*) from page)>p_limit then (select min(sequence) from shown) else null end) into result;
 return result;
end; $$;
revoke all on function public.get_friendship(uuid),public.mutate_friendship(uuid,text,uuid,integer),public.list_friendships(bigint,integer) from public,anon;
grant execute on function public.get_friendship(uuid),public.mutate_friendship(uuid,text,uuid,integer),public.list_friendships(bigint,integer) to authenticated;
