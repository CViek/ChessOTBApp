-- No auth identifiers or email addresses appear in the public profile projection.
create table public.profiles (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null unique references auth.users(id) on delete cascade,
    display_name text not null check (
        char_length(display_name) between 1 and 60
        and display_name !~ '[[:cntrl:]]'
        and display_name = btrim(display_name)
    )
);
alter table public.profiles enable row level security;
revoke all on public.profiles from public, anon, authenticated;
-- Defense in depth for future explicitly granted access.
create policy own_profile_read on public.profiles for select to authenticated using ((select auth.uid()) = owner_id);
create policy own_profile_insert on public.profiles for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy own_profile_update on public.profiles for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);

create function public.get_own_profile()
returns table(id uuid, display_name text)
language sql stable security definer set search_path = ''
as $$ select p.id, p.display_name from public.profiles p where p.owner_id = (select auth.uid()); $$;

create function public.save_own_profile(p_display_name text)
returns table(id uuid, display_name text)
language plpgsql security definer set search_path = ''
as $$
declare
    actor uuid := auth.uid();
    normalized text := btrim(p_display_name, E' \t\n\r');
begin
    if actor is null then raise insufficient_privilege using message = 'Authentication required'; end if;
    if normalized is null or char_length(normalized) not between 1 and 60 or normalized ~ '[[:cntrl:]]' then
        raise exception using errcode = '22023', message = 'Invalid display name';
    end if;
    return query insert into public.profiles as p(owner_id, display_name)
        values(actor, normalized)
        on conflict(owner_id) do update set display_name = excluded.display_name
        returning p.id, p.display_name;
end;
$$;

create function public.get_player_profile(p_profile_id uuid)
returns table(id uuid, display_name text)
language sql stable security definer set search_path = ''
as $$ select p.id, p.display_name from public.profiles p where p.id = p_profile_id and (select auth.uid()) is not null; $$;

revoke all on function public.get_own_profile() from public, anon;
revoke all on function public.save_own_profile(text) from public, anon;
revoke all on function public.get_player_profile(uuid) from public, anon;
grant execute on function public.get_own_profile() to authenticated;
grant execute on function public.save_own_profile(text) to authenticated;
grant execute on function public.get_player_profile(uuid) to authenticated;
