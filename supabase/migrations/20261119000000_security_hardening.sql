-- ============================================
-- SECURITY HARDENING (review of 18 Nov 2026)
-- ============================================
--
-- 1. Table privileges: Supabase gives anon and authenticated full rights
--    on new public tables by default, and RLS policies are then the only
--    guard. Replace those defaults with exactly what the app needs, so a
--    user can't write payment columns (stripe_session_id, amount_paid,
--    paid_at), the astrologer's note or the status when booking.
-- 2. Bookings must be real slots: on the half hour, in the future, within
--    the booking window, and never overlapping another open booking (a
--    60-minute booking also holds the next half hour).
-- 3. One user can hold at most 2 unpaid bookings at a time, so nobody can
--    block the whole calendar.

-- ---------- 1. Privileges ----------

revoke all on public.consultation_requests from anon, authenticated;
grant select on public.consultation_requests to authenticated;
grant insert (
    topic, duration_minutes, slot_start, mode, name, phone, email,
    question, language, price_label, currency, birth_details
) on public.consultation_requests to authenticated;
-- Cancelling is the only change a user can make (see the update policy).
grant update (status) on public.consultation_requests to authenticated;
grant all on public.consultation_requests to service_role;

revoke all on public.ai_questions from anon, authenticated;
grant select on public.ai_questions to authenticated;
grant select, insert, update, delete on public.ai_questions to service_role;

revoke all on public.birth_profiles from anon;
revoke all on public.kundalis from anon;
revoke all on public.planet_positions from anon;
revoke all on public.rashi_houses from anon;

-- ---------- 2. Valid, non-overlapping slots ----------

create or replace function public.check_consultation_request()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    open_count integer;
begin
    if new.slot_start <> date_trunc('minute', new.slot_start)
        or extract(minute from new.slot_start)::int % 30 <> 0 then
        raise exception 'Slot must start on the hour or half hour'
            using errcode = '22023';
    end if;

    if new.slot_start < now() + interval '1 hour'
        or new.slot_start > now() + interval '15 days' then
        raise exception 'Slot is outside the booking window'
            using errcode = '22023';
    end if;

    select count(*) into open_count
    from public.consultation_requests r
    where r.user_id = new.user_id
      and r.status = 'requested';
    if open_count >= 2 then
        raise exception 'Too many unpaid bookings; pay or cancel one first'
            using errcode = '53400';
    end if;

    return new;
end;
$$;

drop trigger if exists consultation_request_checks
    on public.consultation_requests;
create trigger consultation_request_checks
    before insert on public.consultation_requests
    for each row execute function public.check_consultation_request();

-- The time a booking occupies. Adding whole minutes doesn't depend on the
-- time zone, so this is safe to mark immutable for the constraint below.
create or replace function public.consultation_span(
    slot_start timestamptz,
    duration_minutes integer
)
returns tstzrange
language sql
immutable
set search_path = ''
as $$
    select tstzrange(slot_start, slot_start + make_interval(mins => duration_minutes));
$$;

-- No two open bookings may overlap in time. If this statement fails, two
-- existing open bookings overlap: cancel one in the dashboard and re-run.
alter table public.consultation_requests
    drop constraint if exists consultation_requests_no_overlap;
alter table public.consultation_requests
    add constraint consultation_requests_no_overlap
    exclude using gist (
        public.consultation_span(slot_start, duration_minutes) with &&
    )
    where (status in ('requested', 'confirmed', 'paid'));

-- Taken start times now include the half hours held by 60-minute bookings,
-- so the app greys them out.
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
    select s.slot_start
    from public.consultation_requests r
    cross join lateral generate_series(
        r.slot_start,
        r.slot_start + make_interval(mins => r.duration_minutes - 30),
        interval '30 minutes'
    ) as s(slot_start)
    where r.status in ('requested', 'confirmed', 'paid')
      and s.slot_start >= from_time
      and s.slot_start < to_time;
$$;

revoke all on function public.consultation_taken_slots(timestamptz, timestamptz)
    from public, anon;
grant execute on function public.consultation_taken_slots(timestamptz, timestamptz)
    to authenticated;
