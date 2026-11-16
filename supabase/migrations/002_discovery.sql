-- Private approximate named centers. No device GPS or home-address fields.
create table public.profile_areas (
 profile_id uuid primary key references public.profiles(id) on delete cascade,
 name text not null check (char_length(name) between 1 and 120 and name = btrim(name) and name !~ '[[:cntrl:]]'),
 latitude numeric(5,2) not null check (latitude between -90 and 90),
 longitude numeric(6,2) not null check (longitude between -180 and 180),
 country_code text not null check (country_code = 'US')
);
create index profile_areas_latitude on public.profile_areas(latitude);
create table public.discovery_settings (
 owner_id uuid primary key references auth.users(id) on delete cascade,
 name text not null,
 latitude numeric(5,2) not null,
 longitude numeric(6,2) not null,
 country_code text not null check (country_code = 'US'),
 radius_miles integer not null check (radius_miles in (3,5,10))
);
alter table public.profile_areas enable row level security;
alter table public.discovery_settings enable row level security;
revoke all on public.profile_areas, public.discovery_settings from public, anon, authenticated;

create function public.validate_area(p_name text, p_latitude double precision, p_longitude double precision, p_country_code text, p_radius_miles integer)
returns void language plpgsql immutable set search_path = '' as $$
begin
 if p_country_code is distinct from 'US' then raise exception using errcode='22023', message='US areas only'; end if;
 if p_name is null or char_length(btrim(p_name)) not between 1 and 120 or p_name ~ '[[:cntrl:]]'
 or p_latitude is null or not (p_latitude between -90 and 90)
 or p_longitude is null or not (p_longitude between -180 and 180)
 or p_radius_miles is null or p_radius_miles not in (3,5,10)
 then raise exception using errcode='22023', message='Invalid area'; end if;
end; $$;
revoke all on function public.validate_area(text,double precision,double precision,text,integer) from public, anon, authenticated;

-- Replace projections without changing any existing identities or names.
drop function public.get_own_profile();
drop function public.save_own_profile(text);
drop function public.get_player_profile(uuid);
create function public.get_own_profile() returns table(id uuid, display_name text, area_name text)
language sql stable security definer set search_path='' as $$
 select p.id,p.display_name,a.name from public.profiles p left join public.profile_areas a on a.profile_id=p.id where p.owner_id=(select auth.uid()); $$;
create function public.get_player_profile(p_profile_id uuid) returns table(id uuid, display_name text, area_name text)
language sql stable security definer set search_path='' as $$
 select p.id,p.display_name,a.name from public.profiles p left join public.profile_areas a on a.profile_id=p.id where p.id=p_profile_id and (select auth.uid()) is not null; $$;
create function public.save_own_profile(p_display_name text) returns table(id uuid, display_name text, area_name text)
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); normalized text:=btrim(p_display_name,E' \t\n\r');
begin
 if actor is null then raise insufficient_privilege using message='Authentication required'; end if;
 if normalized is null or char_length(normalized) not between 1 and 60 or normalized ~ '[[:cntrl:]]' then raise exception using errcode='22023',message='Invalid display name'; end if;
 insert into public.profiles as p(owner_id,display_name) values(actor,normalized) on conflict(owner_id) do update set display_name=excluded.display_name;
 return query select * from public.get_own_profile();
end; $$;

create function public.get_discovery_settings() returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('area',jsonb_build_object('name',s.name,'latitude',s.latitude,'longitude',s.longitude,'country_code',s.country_code),'radius',s.radius_miles)
 from public.discovery_settings s where s.owner_id=(select auth.uid()); $$;
create function public.get_own_profile_area() returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('name',a.name,'latitude',a.latitude,'longitude',a.longitude,'country_code',a.country_code)
 from public.profile_areas a join public.profiles p on p.id=a.profile_id where p.owner_id=(select auth.uid()); $$;
create function public.save_search_area(p_name text,p_latitude double precision,p_longitude double precision,p_country_code text,p_radius_miles integer default 5)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();
begin
 if actor is null then raise insufficient_privilege using message='Authentication required'; end if;
 perform public.validate_area(p_name,p_latitude,p_longitude,p_country_code,p_radius_miles);
 insert into public.discovery_settings values(actor,btrim(p_name),round(p_latitude::numeric,2),round(p_longitude::numeric,2),p_country_code,p_radius_miles)
 on conflict(owner_id) do update set name=excluded.name,latitude=excluded.latitude,longitude=excluded.longitude,country_code=excluded.country_code,radius_miles=excluded.radius_miles;
 return public.get_discovery_settings();
end; $$;
create function public.save_own_profile_area(p_name text,p_latitude double precision,p_longitude double precision,p_country_code text,p_radius_miles integer default 5)
returns table(id uuid,display_name text,area_name text) language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); profile uuid;
begin
 if actor is null then raise insufficient_privilege using message='Authentication required'; end if;
 perform public.validate_area(p_name,p_latitude,p_longitude,p_country_code,p_radius_miles);
 select p.id into profile from public.profiles p where p.owner_id=actor;
 if profile is null then raise exception using errcode='22023',message='Create a profile first'; end if;
 insert into public.profile_areas values(profile,btrim(p_name),round(p_latitude::numeric,2),round(p_longitude::numeric,2),p_country_code)
 on conflict(profile_id) do update set name=excluded.name,latitude=excluded.latitude,longitude=excluded.longitude,country_code=excluded.country_code;
 insert into public.discovery_settings values(actor,btrim(p_name),round(p_latitude::numeric,2),round(p_longitude::numeric,2),p_country_code,p_radius_miles) on conflict(owner_id) do nothing;
 return query select * from public.get_own_profile();
end; $$;

create function public.area_distance_miles(a double precision,b double precision,c double precision,d double precision)
returns double precision language sql immutable set search_path='' as $$
 select 7917.5226 * asin(least(1.0,sqrt(power(sin(radians(c-a)/2),2)+cos(radians(a))*cos(radians(c))*power(sin(radians(d-b)/2),2)))); $$;
revoke all on function public.area_distance_miles(double precision,double precision,double precision,double precision) from public,anon,authenticated;

create function public.search_players(p_latitude double precision,p_longitude double precision,p_radius_miles integer,p_cursor text default null,p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare after_band integer; after_id uuid; result jsonb;
begin
 if auth.uid() is null then raise insufficient_privilege using message='Authentication required'; end if;
 if p_latitude is null or not(p_latitude between -90 and 90) or p_longitude is null or not(p_longitude between -180 and 180)
 or p_radius_miles is null or p_radius_miles not in (3,5,10) or p_limit is null or p_limit not between 1 and 50
 then raise exception using errcode='22023',message='Invalid search'; end if;
 if p_cursor is not null then
  begin
   if p_cursor !~ '^[0-9]{1,2}:[0-9a-fA-F-]{36}$' then raise invalid_text_representation; end if;
   after_band:=split_part(p_cursor,':',1)::integer; after_id:=split_part(p_cursor,':',2)::uuid;
  exception when invalid_text_representation then raise exception using errcode='22023',message='Invalid cursor'; end;
 end if;
 with distances as (
  select p.id,p.display_name,a.name as area_name,
   public.area_distance_miles(round(p_latitude::numeric,2)::double precision,round(p_longitude::numeric,2)::double precision,a.latitude::double precision,a.longitude::double precision) as miles
  from public.profiles p join public.profile_areas a on a.profile_id=p.id
  where p.owner_id <> (select auth.uid()) and a.latitude between p_latitude-(p_radius_miles/68.0)-0.02 and p_latitude+(p_radius_miles/68.0)+0.02
 ), bands as (
  select id,display_name,area_name,case when miles<1 then 0 else greatest(1,round(miles)::integer) end as distance_miles from distances where miles<=p_radius_miles
 ), page as (
  select * from bands where p_cursor is null or (distance_miles,id)>(after_band,after_id) order by distance_miles,id limit p_limit+1
 ), shown as (select * from page order by distance_miles,id limit p_limit)
 select jsonb_build_object('players',coalesce((select jsonb_agg(to_jsonb(s) order by s.distance_miles,s.id) from shown s),'[]'::jsonb),
 'next_cursor',case when (select count(*) from page)>p_limit then (select distance_miles::text||':'||id::text from shown order by distance_miles desc,id desc limit 1) else null end) into result;
 return result;
end; $$;

revoke all on function public.get_own_profile(),public.save_own_profile(text),public.get_player_profile(uuid),public.get_discovery_settings(),public.get_own_profile_area(),public.save_search_area(text,double precision,double precision,text,integer),public.save_own_profile_area(text,double precision,double precision,text,integer),public.search_players(double precision,double precision,integer,text,integer) from public,anon;
grant execute on function public.get_own_profile(),public.save_own_profile(text),public.get_player_profile(uuid),public.get_discovery_settings(),public.get_own_profile_area(),public.save_search_area(text,double precision,double precision,text,integer),public.save_own_profile_area(text,double precision,double precision,text,integer),public.search_players(double precision,double precision,integer,text,integer) to authenticated;
