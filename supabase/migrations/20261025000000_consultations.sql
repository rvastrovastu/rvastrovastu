-- ============================================
-- PERSONAL CONSULTATIONS
-- ============================================
--
-- Booking requests from the app. A user (guest or signed in) picks a
-- topic, length, time and how to talk; the astrologer confirms by
-- WhatsApp or email and sends a payment link. Nothing is charged in the
-- app.
--
-- Users can create requests, read their own, and cancel their own. Only
-- the astrologer (dashboard / service role) confirms or completes them.
-- To be told about new requests, add a Database Webhook on INSERT to
-- this table (Supabase dashboard → Database → Webhooks), e.g. to an
-- email or Slack automation.

create table if not exists public.consultation_requests (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid()
        references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    topic text not null
        check (topic in ('kundli', 'marriage', 'career', 'vastu')),
    duration_minutes integer not null check (duration_minutes in (30, 60)),
    slot_start timestamptz not null,
    mode text not null check (mode in ('phone', 'whatsapp', 'video')),
    name text not null check (char_length(name) between 1 and 120),
    phone text not null check (char_length(phone) between 6 and 32),
    email text check (email is null or char_length(email) <= 254),
    question text check (question is null or char_length(question) <= 1000),
    language text not null default 'en',
    price_label text,
    birth_details jsonb,
    status text not null default 'requested'
        check (status in ('requested', 'confirmed', 'completed', 'cancelled')),
    astrologer_note text
);

-- One open booking per start time.
create unique index if not exists consultation_requests_open_slot
    on public.consultation_requests (slot_start)
    where status in ('requested', 'confirmed');

create index if not exists consultation_requests_user
    on public.consultation_requests (user_id, slot_start desc);

alter table public.consultation_requests enable row level security;

drop policy if exists "Users create their own consultation requests"
    on public.consultation_requests;
create policy "Users create their own consultation requests"
    on public.consultation_requests for insert
    to authenticated
    with check (
        (select auth.uid()) = user_id
        and status = 'requested'
        and astrologer_note is null
        and slot_start > now()
    );

drop policy if exists "Users read their own consultation requests"
    on public.consultation_requests;
create policy "Users read their own consultation requests"
    on public.consultation_requests for select
    to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists "Users cancel their own consultation requests"
    on public.consultation_requests;
create policy "Users cancel their own consultation requests"
    on public.consultation_requests for update
    to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id and status = 'cancelled');

grant select, insert on public.consultation_requests to authenticated;
-- Users may only change the status column (and only to cancelled, above).
grant update (status) on public.consultation_requests to authenticated;
grant all on public.consultation_requests to service_role;

-- Start times already held, without revealing who holds them.
create or replace function public.consultation_taken_slots(
    from_time timestamptz,
    to_time timestamptz
)
returns table (slot_start timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
    select r.slot_start
    from public.consultation_requests r
    where r.status in ('requested', 'confirmed')
      and r.slot_start >= from_time
      and r.slot_start < to_time;
$$;

revoke all on function public.consultation_taken_slots(timestamptz, timestamptz)
    from public, anon;
grant execute on function public.consultation_taken_slots(timestamptz, timestamptz)
    to authenticated;
