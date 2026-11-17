create function public.inbox_page(p_before_time timestamptz default null,p_before_id uuid default null,p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid; result jsonb;
begin
 select id into actor from public.profiles where owner_id=auth.uid();
 if actor is null then raise insufficient_privilege using message='Profile required'; end if;
 if p_limit is null or p_limit not between 1 and 100 or (p_before_time is null)<>(p_before_id is null)
 or (p_before_time is not null and not isfinite(p_before_time))
 then raise exception using errcode='22023',message='Invalid inbox page'; end if;
 with rows as (
  select c.id,p.id as peer_id,p.display_name,last_message.body as preview,
   coalesce(last_message.created_at,c.created_at) as updated_at,
   (select count(*) from public.messages m where m.conversation_id=c.id and m.sender_id<>actor and m.sequence>coalesce(r.through_sequence,0)) as unread_count
  from public.conversations c join public.profiles p on p.id=case when c.first_profile=actor then c.second_profile else c.first_profile end
  left join public.conversation_reads r on r.conversation_id=c.id and r.profile_id=actor
  left join lateral(select m.body,m.created_at from public.messages m where m.conversation_id=c.id order by m.sequence desc limit 1) last_message on true
  where actor in(c.first_profile,c.second_profile)
 ), page as (
  select * from rows where p_before_time is null or (updated_at,id)<(p_before_time,p_before_id)
  order by updated_at desc,id desc limit p_limit+1
 ), shown as (select * from page order by updated_at desc,id desc limit p_limit)
 select jsonb_build_object('conversations',coalesce((select jsonb_agg(to_jsonb(s) order by s.updated_at desc,s.id desc) from shown s),'[]'::jsonb),
 'next_cursor',case when (select count(*) from page)>p_limit then (select jsonb_build_object('updated_at',updated_at,'id',id) from shown order by updated_at,id limit 1) else null end) into result;
 return result;
end; $$;
revoke all on function public.inbox_page(timestamptz,uuid,integer) from public,anon;
grant execute on function public.inbox_page(timestamptz,uuid,integer) to authenticated;
