-- Keep the initial creation revision immutable for safe original-send retries.
-- Pending invitations can point at a newer offered revision until the recipient agrees.
alter table public.meetings add column offered_revision_id uuid references public.meeting_revisions(id);

create or replace function public.meeting_document(p_id uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select to_jsonb(m) || jsonb_build_object('revision',to_jsonb(r),
 'pending_revision',(select to_jsonb(p) from public.meeting_revisions p where p.id=m.pending_revision_id),
 'revisions',(select coalesce(jsonb_agg(to_jsonb(h) order by h.starts_at,h.id),'[]'::jsonb) from public.meeting_revisions h where h.meeting_id=m.id),
 'proposer_name',a.display_name,'recipient_name',b.display_name)
 from public.meetings m join public.meeting_revisions r on r.id=coalesce(m.accepted_revision_id,m.offered_revision_id,m.initial_revision_id)
 join public.profiles a on a.id=m.proposer_id join public.profiles b on b.id=m.recipient_id where m.id=p_id;
$$;

create function public.edit_meeting_invitation_with_place(p_meeting_id uuid,p_request_id uuid,p_expected_version integer,
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
 payload:=jsonb_build_object('action','edit_invitation','version',p_expected_version,'starts_at',p_starts_at,'time_zone',p_time_zone,'location',place,'note',note,'place',p_place);
 select * into previous from public.meeting_mutations where meeting_id=p_meeting_id and actor_id=actor and request_id=p_request_id;
 if found then
  if previous.payload<>payload then raise exception using errcode='22023',message='Request ID already used'; end if;
  return previous.result;
 end if;
 if saved.proposer_id is distinct from actor then raise insufficient_privilege using message='Only the sender may edit this invitation'; end if;
 if saved.version<>p_expected_version or saved.status<>'pending'
 then raise exception using errcode='PT409',message='Meeting changed; reload before editing'; end if;
 if p_starts_at<=clock_timestamp() then raise exception using errcode='22023',message='Choose a future meeting time'; end if;
 insert into public.meeting_revisions(meeting_id,starts_at,time_zone,location,note,proposed_by,place)
 values(p_meeting_id,p_starts_at,p_time_zone,place,note,actor,p_place) returning id into revision_id;
 update public.meetings set offered_revision_id=revision_id,version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),'Invitation updated. Review the latest details before responding.',p_meeting_id,saved.version+1,'proposal');
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_mutations values(p_meeting_id,actor,p_request_id,payload,result);
 return result;
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
 if p_decision='confirmed' and (select starts_at from public.meeting_revisions where id=coalesce(saved.offered_revision_id,saved.initial_revision_id))<=clock_timestamp()
 then raise exception using errcode='PT409',message='This proposal is in the past; arrange another game'; end if;
 update public.meetings set status=p_decision,accepted_revision_id=case when p_decision='confirmed' then coalesce(offered_revision_id,initial_revision_id) else null end,
 version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),case when p_decision='confirmed' then 'Proposal accepted. Meeting confirmed.' else 'Proposal declined.' end,p_meeting_id,saved.version+1,p_decision);
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_responses values(p_meeting_id,actor,p_request_id,p_expected_version,p_decision,result);
 return result;
end; $$;


revoke all on function public.edit_meeting_invitation_with_place(uuid,uuid,integer,timestamptz,text,text,jsonb,text) from public,anon;
grant execute on function public.edit_meeting_invitation_with_place(uuid,uuid,integer,timestamptz,text,text,jsonb,text) to authenticated;
