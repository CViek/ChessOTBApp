-- One optional self-reported rating. Comparisons require the identical source/format key.
create table public.profile_ratings (
 profile_id uuid primary key references public.profiles(id) on delete cascade,
 kind text not null check(kind in ('chess_com_rapid','chess_com_blitz','chess_com_bullet','lichess_rapid','lichess_blitz','lichess_bullet','lichess_classical','us_chess_regular','us_chess_quick','us_chess_blitz')),
 value integer not null check(value between 1 and 4000)
);
alter table public.profile_ratings enable row level security;
revoke all on public.profile_ratings from public,anon,authenticated;
alter table public.discovery_settings add column rating_kind text;
alter table public.discovery_settings add column rating_min integer;
alter table public.discovery_settings add column rating_max integer;
alter table public.discovery_settings add constraint rating_filter_shape check(
 (rating_kind is null and rating_min is null and rating_max is null) or
 (rating_kind is not null and rating_kind in ('chess_com_rapid','chess_com_blitz','chess_com_bullet','lichess_rapid','lichess_blitz','lichess_bullet','lichess_classical','us_chess_regular','us_chess_quick','us_chess_blitz') and
 (rating_min is null or rating_min between 1 and 4000) and (rating_max is null or rating_max between 1 and 4000) and coalesce(rating_min,1)<=coalesce(rating_max,4000))
);
drop function public.get_own_profile();
drop function public.get_player_profile(uuid);
create function public.get_own_profile() returns table(id uuid,display_name text,area_name text,rating jsonb)
language sql stable security definer set search_path='' as $$
 select p.id,p.display_name,a.name,case when r.profile_id is null then null else jsonb_build_object('kind',r.kind,'value',r.value) end
 from public.profiles p left join public.profile_areas a on a.profile_id=p.id left join public.profile_ratings r on r.profile_id=p.id where p.owner_id=(select auth.uid()); $$;
create function public.get_player_profile(p_profile_id uuid) returns table(id uuid,display_name text,area_name text,rating jsonb)
language sql stable security definer set search_path='' as $$
 select p.id,p.display_name,a.name,case when r.profile_id is null then null else jsonb_build_object('kind',r.kind,'value',r.value) end
 from public.profiles p left join public.profile_areas a on a.profile_id=p.id left join public.profile_ratings r on r.profile_id=p.id where p.id=p_profile_id and (select auth.uid()) is not null; $$;

drop function public.save_own_profile(text);
create function public.save_own_profile(p_display_name text) returns table(id uuid, display_name text, area_name text, rating jsonb)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); normalized text:=btrim(p_display_name,E' \t\n\r');
begin
 if actor is null then raise insufficient_privilege using message='Authentication required'; end if;
 if normalized is null or char_length(normalized) not between 1 and 60 or normalized ~ '[[:cntrl:]]' then raise exception using errcode='22023',message='Invalid display name'; end if;
 insert into public.profiles as p(owner_id,display_name) values(actor,normalized) on conflict(owner_id) do update set display_name=excluded.display_name;
 return query select * from public.get_own_profile();
end; $$;


drop function public.save_own_profile_area(text,double precision,double precision,text,integer);
create function public.save_own_profile_area(p_name text,p_latitude double precision,p_longitude double precision,p_country_code text,p_radius_miles integer default 5)
returns table(id uuid,display_name text,area_name text,rating jsonb) language plpgsql security definer set search_path='' as $$
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
returns table(id uuid,display_name text,area_name text,rating jsonb)
language plpgsql security definer set search_path='' as $$
declare profile uuid;
begin
 if (p_rating_kind is null)<>(p_rating_value is null) or (p_rating_kind is not null and
 (p_rating_kind not in ('chess_com_rapid','chess_com_blitz','chess_com_bullet','lichess_rapid','lichess_blitz','lichess_bullet','lichess_classical','us_chess_regular','us_chess_quick','us_chess_blitz') or p_rating_value not between 1 and 4000)) then raise exception using errcode='22023',message='Invalid rating'; end if;
 perform public.save_own_profile(p_display_name);
 select p.id into profile from public.profiles p where p.owner_id=auth.uid();
 if p_rating_kind is null then delete from public.profile_ratings where profile_id=profile;
 else insert into public.profile_ratings values(profile,p_rating_kind,p_rating_value) on conflict(profile_id) do update set kind=excluded.kind,value=excluded.value; end if;
 return query select * from public.get_own_profile();
end; $$;
create or replace function public.get_discovery_settings() returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('area',jsonb_build_object('name',s.name,'latitude',s.latitude,'longitude',s.longitude,'country_code',s.country_code),'radius',s.radius_miles,
 'rating',case when s.rating_kind is null then null else jsonb_build_object('kind',s.rating_kind,'minimum',s.rating_min,'maximum',s.rating_max) end)
 from public.discovery_settings s where s.owner_id=(select auth.uid()); $$;
create function public.save_search_filters(p_radius_miles integer,p_rating_kind text default null,p_rating_min integer default null,p_rating_max integer default null) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise insufficient_privilege using message='Authentication required'; end if;
 if p_radius_miles is null or p_radius_miles not between 1 and 100 or
 (p_rating_kind is null and (p_rating_min is not null or p_rating_max is not null)) or
 (p_rating_kind is not null and (p_rating_kind not in ('chess_com_rapid','chess_com_blitz','chess_com_bullet','lichess_rapid','lichess_blitz','lichess_bullet','lichess_classical','us_chess_regular','us_chess_quick','us_chess_blitz') or
 (p_rating_min is not null and p_rating_min not between 1 and 4000) or (p_rating_max is not null and p_rating_max not between 1 and 4000) or coalesce(p_rating_min,1)>coalesce(p_rating_max,4000)))
 then raise exception using errcode='22023',message='Invalid rating filter'; end if;
 update public.discovery_settings set radius_miles=p_radius_miles,rating_kind=p_rating_kind,rating_min=p_rating_min,rating_max=p_rating_max where owner_id=auth.uid();
 if not found then raise exception using errcode='22023',message='Save a search area first'; end if;
 return public.get_discovery_settings();
end; $$;
drop function public.search_players(double precision,double precision,integer,text,integer);
create function public.search_players(p_latitude double precision,p_longitude double precision,p_radius_miles integer,p_cursor text default null,p_limit integer default 20,p_rating_kind text default null,p_rating_min integer default null,p_rating_max integer default null)
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
  select p.id,p.display_name,a.name as area_name,case when r.profile_id is null then null else jsonb_build_object('kind',r.kind,'value',r.value) end as rating,
   public.area_distance_miles(round(p_latitude::numeric,2)::double precision,round(p_longitude::numeric,2)::double precision,a.latitude::double precision,a.longitude::double precision) as miles
  from public.profiles p join public.profile_areas a on a.profile_id=p.id left join public.profile_ratings r on r.profile_id=p.id
  where (p_rating_kind is null or (r.kind=p_rating_kind and r.value>=coalesce(p_rating_min,1) and r.value<=coalesce(p_rating_max,4000))) and p.owner_id <> (select auth.uid()) and a.latitude between p_latitude-(p_radius_miles/68.0)-0.02 and p_latitude+(p_radius_miles/68.0)+0.02
 ), bands as (
  select id,display_name,area_name,rating,case when miles<1 then 0 else greatest(1,round(miles)::integer) end as distance_miles from distances where miles<=p_radius_miles
 ), page as (
  select * from bands where p_cursor is null or (distance_miles,id)>(after_band,after_id) order by distance_miles,id limit p_limit+1
 ), shown as (select * from page order by distance_miles,id limit p_limit)
 select jsonb_build_object('players',coalesce((select jsonb_agg(to_jsonb(s) order by s.distance_miles,s.id) from shown s),'[]'::jsonb),
 'next_cursor',case when (select count(*) from page)>p_limit then (select distance_miles::text||':'||id::text from shown order by distance_miles desc,id desc limit 1) else null end) into result;
 return result;
end; $$;


revoke all on function public.get_own_profile(),public.get_player_profile(uuid),public.save_own_profile(text),public.save_own_profile_area(text,double precision,double precision,text,integer),public.save_rated_profile(text,text,integer),public.save_search_filters(integer,text,integer,integer),public.search_players(double precision,double precision,integer,text,integer,text,integer,integer) from public,anon;
grant execute on function public.get_own_profile(),public.get_player_profile(uuid),public.save_own_profile(text),public.save_own_profile_area(text,double precision,double precision,text,integer),public.save_rated_profile(text,text,integer),public.save_search_filters(integer,text,integer,integer),public.search_players(double precision,double precision,integer,text,integer,text,integer,integer) to authenticated;
