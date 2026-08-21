-- ============================================
-- RV ASTRO VASTU
-- ASTROLOGY DATABASE SCHEMA
-- ============================================

create extension if not exists "pgcrypto";

-- ============================================
-- BIRTH PROFILES
-- ============================================

create table if not exists public.birth_profiles (
    id uuid primary key default gen_random_uuid(),

    user_id uuid references auth.users(id) on delete cascade,

    name text not null,
    gender text not null,

    date_of_birth date not null,
    birth_time text not null,

    birth_city text not null,
    birth_state text,
    birth_country text,

    latitude double precision not null,
    longitude double precision not null,
    timezone text not null,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- ============================================
-- KUNDALIS
-- ============================================

create table if not exists public.kundalis (
    id uuid primary key default gen_random_uuid(),

    user_id uuid references auth.users(id) on delete cascade,

    birth_profile_id uuid
        references public.birth_profiles(id)
        on delete cascade,

    ascendant text not null,
    ascendant_degree double precision not null,

    sun_sign text not null,
    moon_sign text not null,

    nakshatra text not null,
    nakshatra_pada integer not null,

    ayanamsa text,
    house_system text,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- ============================================
-- PLANET POSITIONS
-- ============================================

create table if not exists public.planet_positions (
    id uuid primary key default gen_random_uuid(),

    kundali_id uuid not null
        references public.kundalis(id)
        on delete cascade,

    planet text not null,
    sign text not null,

    house integer not null,
    degree double precision not null,

    retrograde boolean not null default false,

    nakshatra text,
    nakshatra_pada integer,

    created_at timestamptz not null default now()
);

-- ============================================
-- RASHI CHART
-- ============================================

create table if not exists public.rashi_houses (
    id uuid primary key default gen_random_uuid(),

    kundali_id uuid not null
        references public.kundalis(id)
        on delete cascade,

    house integer not null,
    sign text not null,

    planets text[] not null default '{}',

    created_at timestamptz not null default now(),

    unique(kundali_id, house)
);

-- ============================================
-- INDEXES
-- ============================================

create index if not exists idx_birth_profiles_user
on public.birth_profiles(user_id);

create index if not exists idx_kundalis_user
on public.kundalis(user_id);

create index if not exists idx_kundalis_birth_profile
on public.kundalis(birth_profile_id);

create index if not exists idx_planet_positions_kundali
on public.planet_positions(kundali_id);

create index if not exists idx_rashi_houses_kundali
on public.rashi_houses(kundali_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================

alter table public.birth_profiles enable row level security;
alter table public.kundalis enable row level security;
alter table public.planet_positions enable row level security;
alter table public.rashi_houses enable row level security;

-- ============================================
-- BIRTH PROFILE POLICIES
-- ============================================

create policy "Users can view their birth profiles"
on public.birth_profiles
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can create their birth profiles"
on public.birth_profiles
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update their birth profiles"
on public.birth_profiles
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete their birth profiles"
on public.birth_profiles
for delete
to authenticated
using (auth.uid() = user_id);

-- ============================================
-- KUNDALI POLICIES
-- ============================================

create policy "Users can view their kundalis"
on public.kundalis
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can create their kundalis"
on public.kundalis
for insert
to authenticated
with check (auth.uid() = user_id);

-- ============================================
-- PLANET POSITION POLICIES
-- ============================================

create policy "Users can view their planet positions"
on public.planet_positions
for select
to authenticated
using (
    exists (
        select 1
        from public.kundalis k
        where k.id = planet_positions.kundali_id
        and k.user_id = auth.uid()
    )
);

-- ============================================
-- RASHI HOUSE POLICIES
-- ============================================

create policy "Users can view their rashi houses"
on public.rashi_houses
for select
to authenticated
using (
    exists (
        select 1
        from public.kundalis k
        where k.id = rashi_houses.kundali_id
        and k.user_id = auth.uid()
    )
);
