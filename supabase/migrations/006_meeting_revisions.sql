-- Participant cancellation, serialized with all conversation events.
alter table public.meetings drop constraint meetings_status_check;
alter table public.meetings add constraint meetings_status_check check(status in ('pending','confirmed','declined','cancelled'));
alter table public.messages drop constraint message_event_shape;
alter table public.messages add constraint message_event_shape check(
 (event_kind='text' and meeting_id is null and meeting_version is null) or
 (event_kind in ('proposal','confirmed','declined','cancelled') and meeting_id is not null and meeting_version > 0)
);
create table public.meeting_mutations (
 meeting_id uuid not null references public.meetings(id) on delete cascade,
 actor_id uuid not null references public.profiles(id) on delete cascade,
 request_id uuid not null,
 payload jsonb not null,
 result jsonb not null,
 primary key(meeting_id,actor_id,request_id)
);
alter table public.meeting_mutations enable row level security;
revoke all on public.meeting_mutations from public,anon,authenticated;

create function public.cancel_meeting(p_meeting_id uuid,p_request_id uuid,p_expected_version integer) returns jsonb
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
 update public.meetings set status='cancelled',version=version+1,updated_at=clock_timestamp() where id=p_meeting_id;
 insert into public.messages(conversation_id,sender_id,client_id,body,meeting_id,meeting_version,event_kind)
 values(thread,actor,gen_random_uuid(),'Meeting cancelled.',p_meeting_id,saved.version+1,'cancelled');
 result:=public.meeting_document(p_meeting_id);
 insert into public.meeting_mutations values(p_meeting_id,actor,p_request_id,payload,result);
 return result;
end; $$;
revoke all on function public.cancel_meeting(uuid,uuid,integer) from public,anon;
grant execute on function public.cancel_meeting(uuid,uuid,integer) to authenticated;
