-- ============================================
-- BIRTH PROFILE SYNC FIX + UNKNOWN BIRTH TIME
-- ============================================
--
-- The app gives each profile a text id (a timestamp such as
-- "1731840000000000"), but birth_profiles.id was a uuid, so every cloud
-- save failed and profiles never reached the cloud. The id becomes text.
-- New: birth_time_known, false when the user picked a rough part of the
-- day instead of an exact time.

do $$
begin
    -- The old kundali tables point at birth_profiles.id; drop that link
    -- first if they still exist (they are removed when empty elsewhere).
    if to_regclass('public.kundalis') is not null then
        alter table public.kundalis
            drop constraint if exists kundalis_birth_profile_id_fkey;
        alter table public.kundalis
            alter column birth_profile_id type text using birth_profile_id::text;
    end if;
end;
$$;

alter table public.birth_profiles alter column id drop default;
alter table public.birth_profiles
    alter column id type text using id::text;
alter table public.birth_profiles
    alter column id set default gen_random_uuid()::text;
alter table public.birth_profiles
    add constraint birth_profiles_id_length
    check (char_length(id) between 1 and 64);

do $$
begin
    if to_regclass('public.kundalis') is not null then
        alter table public.kundalis
            add constraint kundalis_birth_profile_id_fkey
            foreign key (birth_profile_id)
            references public.birth_profiles (id) on delete cascade;
    end if;
end;
$$;

alter table public.birth_profiles
    add column if not exists birth_time_known boolean not null default true;
