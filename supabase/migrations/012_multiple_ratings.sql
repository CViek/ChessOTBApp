-- Preserve existing entries while allowing one rating per source and format.
alter table public.profile_ratings drop constraint profile_ratings_pkey;
alter table public.profile_ratings add primary key(profile_id,kind);

drop function public.save_rated_profile(text,text,integer);
drop function public.save_own_profile(text);
drop function public.save_own_profile_area(text,double precision,double precision,text,integer);
drop function public.get_own_profile();
drop function public.get_player_profile(uuid);

create function public.get_own_profile() returns table(id uuid,display_name text,area_name text,rating jsonb,ratings jsonb)
language sql stable security definer set search_path='' as $$
 select p.id,p.display_name,a.name,(coalesce((select jsonb_agg(jsonb_build_object('kind',r.kind,'value',r.value) order by r.kind) from public.profile_ratings r where r.profile_id=p.id),'[]'::jsonb))->0,coalesce((select jsonb_agg(jsonb_build_object('kind',r.kind,'value',r.value) order by r.kind) from public.profile_ratings r where r.profile_id=p.id),'[]'::jsonb)
 from public.profiles p left join public.profile_areas a on a.profile_id=p.id where p.owner_id=(select auth.uid()); $$;
create function public.get_player_profile(p_profile_id uuid) returns table(id uuid,display_name text,area_name text,rating jsonb,ratings jsonb)
language sql stable security definer set search_path='' as $$
 select p.id,p.display_name,a.name,(coalesce((select jsonb_agg(jsonb_build_object('kind',r.kind,'value',r.value) order by r.kind) from public.profile_ratings r where r.profile_id=p.id),'[]'::jsonb))->0,coalesce((select jsonb_agg(jsonb_build_object('kind',r.kind,'value',r.value) order by r.kind) from public.profile_ratings r where r.profile_id=p.id),'[]'::jsonb)
 from public.profiles p left join public.profile_areas a on a.profile_id=p.id where p.id=p_profile_id and (select auth.uid()) is not null; $$;


create function public.save_own_profile(p_display_name text) returns table(id uuid, display_name text, area_name text, rating jsonb,ratings jsonb)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); normalized text:=btrim(p_display_name,E' \t\n\r');
begin
 if actor is null then raise insufficient_privilege using message='Authentication required'; end if;
 if normalized is null or char_length(normalized) not between 1 and 60 or normalized ~ '[[:cntrl:]]' then raise exception using errcode='22023',message='Invalid display name'; end if;
 insert into public.profiles as p(owner_id,display_name) values(actor,normalized) on conflict(owner_id) do update set display_name=excluded.display_name;
 return query select * from public.get_own_profile();
end; $$;



create function public.save_own_profile_area(p_name text,p_latitude double precision,p_longitude double precision,p_country_code text,p_radius_miles integer default 5)
returns table(id uuid,display_name text,area_name text,rating jsonb,ratings jsonb) language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); profile uuid;
begin
 if actor is null then raise insufficient_privilege using message='Authentication required'; end if;
 perform public.validate_area(p_name,p_latitude,p_longitude,p_country_code,p_radius_miles);
 select p.id into profile from public.profiles p where p.owner_id=actor;
 if profile is null then raise exception using errcode='22023',message='Create a profile first'; end if;
 insert into public.profile_areas values(profile,btrim(p_name),round(p_latitude::numeric,2),round(p_longitude::numeric,2),p_country_code)
 on conflict(profile_id) do update set name=excluded.name,latitude=excluded.latitude,longitude=excluded.longitude,country_code=excluded.country_code;
 insert into public.discovery_settings(owner_id,name,latitude,longitude,country_code,radius_miles) values(actor,btrim(p_name),round(p_latitude::numeric,2),round(p_longitude::numeric,2),p_country_code,p_radius_miles) on conflict(owner_id) do nothing;
 return query select * from public.get_own_profile();
end; $$;


create function public.save_rated_profile(p_display_name text,p_rating_kind text default null,p_rating_value integer default null)
returns table(id uuid,display_name text,area_name text,rating jsonb,ratings jsonb)
language plpgsql security definer set search_path='' as $$
declare profile uuid;
begin
 if (p_rating_kind is null)<>(p_rating_value is null) or (p_rating_kind is not null and
 (p_rating_kind not in ('chess_com_rapid','chess_com_blitz','chess_com_bullet','lichess_rapid','lichess_blitz','lichess_bullet','lichess_classical','us_chess_regular','us_chess_quick','us_chess_blitz') or p_rating_value not between 1 and 4000)) then raise exception using errcode='22023',message='Invalid rating'; end if;
 perform public.save_own_profile(p_display_name);
 select p.id into profile from public.profiles p where p.owner_id=auth.uid();
 -- Older clients can represent only one rating. Reject edits that would discard unseen entries.
 if (select count(*) from public.profile_ratings where profile_id=profile)>1 then
  raise exception using errcode='22023',message='Update the app to edit a profile with multiple ratings';
 end if;
 delete from public.profile_ratings where profile_id=profile;
 if p_rating_kind is not null then insert into public.profile_ratings values(profile,p_rating_kind,p_rating_value); end if;
 return query select * from public.get_own_profile();
end; $$;
-- Replace the complete rating list in the same transaction as the display name.
create function public.save_profile_ratings(p_display_name text,p_ratings jsonb)
returns table(id uuid,display_name text,area_name text,rating jsonb,ratings jsonb)
language plpgsql security definer set search_path='' as $$
declare profile uuid; entry jsonb;
begin
 if auth.uid() is null then raise insufficient_privilege using message='Authentication required'; end if;
 if p_ratings is null or jsonb_typeof(p_ratings)<>'array' then
  raise exception using errcode='22023',message='Invalid ratings';
 end if;
 if jsonb_array_length(p_ratings)>10 then raise exception using errcode='22023',message='Invalid ratings'; end if;
 for entry in select value from jsonb_array_elements(p_ratings) loop
  if jsonb_typeof(entry)<>'object' or not(entry ? 'kind' and entry ? 'value')
   or jsonb_typeof(entry->'kind')<>'string' or jsonb_typeof(entry->'value')<>'number'
   or (entry->>'kind') not in ('chess_com_rapid','chess_com_blitz','chess_com_bullet','lichess_rapid','lichess_blitz','lichess_bullet','lichess_classical','us_chess_regular','us_chess_quick','us_chess_blitz')
   or (entry->>'value')::numeric not between 1 and 4000
   or (entry->>'value')::numeric<>trunc((entry->>'value')::numeric) then
   raise exception using errcode='22023',message='Invalid rating';
  end if;
 end loop;
 if (select count(distinct value->>'kind') from jsonb_array_elements(p_ratings))<>jsonb_array_length(p_ratings) then
  raise exception using errcode='22023',message='Duplicate rating source and format';
 end if;
 -- The profile upsert serializes concurrent saves for the same owner.
 perform public.save_own_profile(p_display_name);
 select p.id into profile from public.profiles p where p.owner_id=auth.uid();
 delete from public.profile_ratings where profile_id=profile;
 insert into public.profile_ratings(profile_id,kind,value)
 select profile,value->>'kind',(value->>'value')::numeric::integer from jsonb_array_elements(p_ratings);
 return query select * from public.get_own_profile();
end; $$;

create or replace function public.search_players(p_latitude double precision,p_longitude double precision,p_radius_miles integer,p_cursor text default null,p_limit integer default 20,p_rating_kind text default null,p_rating_min integer default null,p_rating_max integer default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare after_band integer; after_id uuid; result jsonb;
begin
 if auth.uid() is null then raise insufficient_privilege using message='Authentication required'; end if;
 if p_latitude is null or not(p_latitude between -90 and 90) or p_longitude is null or not(p_longitude between -180 and 180)
 or p_radius_miles is null or p_radius_miles not between 1 and 100 or p_limit is null or p_limit not between 1 and 50
 then raise exception using errcode='22023',message='Invalid search'; end if;
 if (p_rating_kind is null and (p_rating_min is not null or p_rating_max is not null)) or
 (p_rating_kind is not null and (p_rating_kind not in ('chess_com_rapid','chess_com_blitz','chess_com_bullet','lichess_rapid','lichess_blitz','lichess_bullet','lichess_classical','us_chess_regular','us_chess_quick','us_chess_blitz') or
 (p_rating_min is not null and p_rating_min not between 1 and 4000) or (p_rating_max is not null and p_rating_max not between 1 and 4000) or coalesce(p_rating_min,1)>coalesce(p_rating_max,4000)))
 then raise exception using errcode='22023',message='Invalid rating filter'; end if;
 if p_cursor is not null then
  begin
   if p_cursor !~ '^[0-9]{1,3}:[0-9a-fA-F-]{36}$' then raise invalid_text_representation; end if;
   after_band:=split_part(p_cursor,':',1)::integer; after_id:=split_part(p_cursor,':',2)::uuid;
  exception when invalid_text_representation then raise exception using errcode='22023',message='Invalid cursor'; end;
 end if;
 with distances as (
  select p.id,p.display_name,a.name as area_name,(coalesce((select jsonb_agg(jsonb_build_object('kind',r.kind,'value',r.value) order by r.kind) from public.profile_ratings r where r.profile_id=p.id),'[]'::jsonb))->0 as rating,coalesce((select jsonb_agg(jsonb_build_object('kind',r.kind,'value',r.value) order by r.kind) from public.profile_ratings r where r.profile_id=p.id),'[]'::jsonb) as ratings,
   public.area_distance_miles(round(p_latitude::numeric,2)::double precision,round(p_longitude::numeric,2)::double precision,a.latitude::double precision,a.longitude::double precision) as miles
  from public.profiles p join public.profile_areas a on a.profile_id=p.id
  where (p_rating_kind is null or (exists (select 1 from public.profile_ratings r where r.profile_id=p.id and r.kind=p_rating_kind and r.value>=coalesce(p_rating_min,1) and r.value<=coalesce(p_rating_max,4000)))) and p.owner_id <> (select auth.uid()) and a.latitude between p_latitude-(p_radius_miles/68.0)-0.02 and p_latitude+(p_radius_miles/68.0)+0.02
 ), bands as (
  select id,display_name,area_name,rating,ratings,case when miles<1 then 0 else greatest(1,round(miles)::integer) end as distance_miles from distances where miles<=p_radius_miles
 ), page as (
  select * from bands where p_cursor is null or (distance_miles,id)>(after_band,after_id) order by distance_miles,id limit p_limit+1
 ), shown as (select * from page order by distance_miles,id limit p_limit)
 select jsonb_build_object('players',coalesce((select jsonb_agg(to_jsonb(s) order by s.distance_miles,s.id) from shown s),'[]'::jsonb),
 'next_cursor',case when (select count(*) from page)>p_limit then (select distance_miles::text||':'||id::text from shown order by distance_miles desc,id desc limit 1) else null end) into result;
 return result;
end; $$;

revoke all on function public.get_own_profile(),public.get_player_profile(uuid),public.save_own_profile(text),public.save_own_profile_area(text,double precision,double precision,text,integer),public.save_rated_profile(text,text,integer),public.save_profile_ratings(text,jsonb) from public,anon;
grant execute on function public.get_own_profile(),public.get_player_profile(uuid),public.save_own_profile(text),public.save_own_profile_area(text,double precision,double precision,text,integer),public.save_rated_profile(text,text,integer),public.save_profile_ratings(text,jsonb) to authenticated;
