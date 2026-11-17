-- Verified operator listings only. No client writes or production sample data.
create schema group_private;
revoke all on schema group_private from public,anon,authenticated,service_role;
create table public.group_listings (
 id uuid primary key,
 name text not null check (char_length(name) between 1 and 120 and name=btrim(name) and name !~ '[[:cntrl:]]'),
 area_name text not null check (char_length(area_name) between 1 and 120 and area_name=btrim(area_name) and area_name !~ '[[:cntrl:]]'),
 latitude numeric(5,2) not null check (latitude between -90 and 90),
 longitude numeric(6,2) not null check (longitude between -180 and 180),
 description text not null check (char_length(description) between 1 and 2000 and description !~ '[[:cntrl:]]'),
 contact_id uuid references public.profiles(id) on delete set null,
 introduction_text text check (char_length(introduction_text) between 1 and 1000 and introduction_text !~ '[[:cntrl:]]'),
 introduction_profile_id uuid references public.profiles(id) on delete set null,
 updated_at timestamptz not null default now()
);
alter table public.group_listings enable row level security;
revoke all on public.group_listings from public,anon,authenticated,service_role;
create function group_private.import_listing(p_listing jsonb) returns void
language plpgsql set search_path='' as $$
begin
 if p_listing->>'contact_id' is null or not exists (
  select 1 from public.profiles p join auth.users u on u.id=p.owner_id
  where p.id=(p_listing->>'contact_id')::uuid and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())
 ) then raise exception using errcode='22023',message='A live consenting contact is required'; end if;
 if (p_listing->>'introduction_text' is null) <> (p_listing->>'introduction_profile_id' is null)
 or (p_listing->>'introduction_profile_id' is not null and not exists (
  select 1 from public.profiles p join auth.users u on u.id=p.owner_id where p.id=(p_listing->>'introduction_profile_id')::uuid
   and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())
 )) then raise exception using errcode='22023',message='Introduction requires an approved live profile and text'; end if;
 perform public.validate_area(p_listing->>'area_name',(p_listing->>'latitude')::double precision,(p_listing->>'longitude')::double precision,'US',5);
 insert into public.group_listings(id,name,area_name,latitude,longitude,description,contact_id,introduction_text,introduction_profile_id)
 values ((p_listing->>'id')::uuid,btrim(p_listing->>'name'),btrim(p_listing->>'area_name'),round((p_listing->>'latitude')::numeric,2),round((p_listing->>'longitude')::numeric,2),btrim(p_listing->>'description'),(p_listing->>'contact_id')::uuid,btrim(p_listing->>'introduction_text'),(p_listing->>'introduction_profile_id')::uuid)
 on conflict(id) do update set name=excluded.name,area_name=excluded.area_name,latitude=excluded.latitude,longitude=excluded.longitude,
 description=excluded.description,contact_id=excluded.contact_id,introduction_text=excluded.introduction_text,introduction_profile_id=excluded.introduction_profile_id,updated_at=now();
end; $$;
create function group_private.remove_listing(p_id uuid) returns void language sql set search_path='' as $$ delete from public.group_listings where id=p_id; $$;
create function group_private.live_player(p_id uuid) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('id',p.id,'display_name',p.display_name) from public.profiles p join auth.users u on u.id=p.owner_id
 where p.id=p_id and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now()); $$;
create function public.get_group_listing(p_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if auth.uid() is null then raise insufficient_privilege using message='Authentication required'; end if;
 select jsonb_build_object('id',g.id,'name',g.name,'area_name',g.area_name,'description',g.description,
 'contact',group_private.live_player(g.contact_id),
 'introduction',case when g.introduction_text is not null and group_private.live_player(g.introduction_profile_id) is not null then
 jsonb_build_object('text',g.introduction_text,'player',group_private.live_player(g.introduction_profile_id)) else null end)
 into result from public.group_listings g where g.id=p_id;
 return result;
end; $$;
create function public.search_groups(p_latitude double precision,p_longitude double precision,p_radius_miles integer,p_cursor text default null,p_limit integer default 20)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare after_band integer; after_id uuid; result jsonb;
begin
 if auth.uid() is null then raise insufficient_privilege using message='Authentication required'; end if;
 perform public.validate_area('Search',p_latitude,p_longitude,'US',p_radius_miles);
 if p_limit is null or p_limit not between 1 and 50 then raise exception using errcode='22023',message='Invalid limit'; end if;
 if p_cursor is not null then
  begin
   if p_cursor !~ '^[0-9]{1,3}:[0-9a-fA-F-]{36}$' then raise invalid_text_representation; end if;
   after_band:=split_part(p_cursor,':',1)::integer; after_id:=split_part(p_cursor,':',2)::uuid;
  exception when invalid_text_representation then raise exception using errcode='22023',message='Invalid cursor'; end;
 end if;
 with distances as (
  select g.id,public.area_distance_miles(round(p_latitude::numeric,2)::double precision,round(p_longitude::numeric,2)::double precision,g.latitude::double precision,g.longitude::double precision) as miles
  from public.group_listings g
 ), bands as (
  select id,case when miles<1 then 0 else greatest(1,round(miles)::integer) end as distance_miles from distances where miles<=p_radius_miles
 ), page as (
  select * from bands where p_cursor is null or (distance_miles,id)>(after_band,after_id) order by distance_miles,id limit p_limit+1
 ), shown as (select * from page order by distance_miles,id limit p_limit)
 select jsonb_build_object('groups',coalesce((select jsonb_agg(public.get_group_listing(s.id)||jsonb_build_object('distance_miles',s.distance_miles) order by s.distance_miles,s.id) from shown s),'[]'::jsonb),
 'next_cursor',case when (select count(*) from page)>p_limit then (select distance_miles::text||':'||id::text from shown order by distance_miles desc,id desc limit 1) else null end) into result;
 return result;
end; $$;
revoke all on all functions in schema group_private from public,anon,authenticated,service_role;
revoke all on function public.get_group_listing(uuid),public.search_groups(double precision,double precision,integer,text,integer) from public,anon;
grant execute on function public.get_group_listing(uuid),public.search_groups(double precision,double precision,integer,text,integer) to authenticated;
