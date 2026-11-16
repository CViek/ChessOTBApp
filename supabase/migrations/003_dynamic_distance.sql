-- Expand the radius without changing identities, saved areas or public projections.
alter table public.discovery_settings drop constraint discovery_settings_radius_miles_check;
alter table public.discovery_settings add constraint discovery_settings_radius_miles_check check (radius_miles between 1 and 100);

create or replace function public.validate_area(p_name text, p_latitude double precision, p_longitude double precision, p_country_code text, p_radius_miles integer)
returns void language plpgsql immutable set search_path = '' as $$
begin
 if p_country_code is distinct from 'US' then raise exception using errcode='22023', message='US areas only'; end if;
 if p_name is null or char_length(btrim(p_name)) not between 1 and 120 or p_name ~ '[[:cntrl:]]'
 or p_latitude is null or not (p_latitude between -90 and 90)
 or p_longitude is null or not (p_longitude between -180 and 180)
 or p_radius_miles is null or p_radius_miles not between 1 and 100
 then raise exception using errcode='22023', message='Invalid area'; end if;
end; $$;

create or replace function public.search_players(p_latitude double precision,p_longitude double precision,p_radius_miles integer,p_cursor text default null,p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare after_band integer; after_id uuid; result jsonb;
begin
 if auth.uid() is null then raise insufficient_privilege using message='Authentication required'; end if;
 if p_latitude is null or not(p_latitude between -90 and 90) or p_longitude is null or not(p_longitude between -180 and 180)
 or p_radius_miles is null or p_radius_miles not between 1 and 100 or p_limit is null or p_limit not between 1 and 50
 then raise exception using errcode='22023',message='Invalid search'; end if;
 if p_cursor is not null then
  begin
   if p_cursor !~ '^[0-9]{1,3}:[0-9a-fA-F-]{36}$' then raise invalid_text_representation; end if;
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

