-- ============================================
-- DATA INTEGRITY AND RETENTION (audit of 19 Nov 2026)
-- ============================================
--
-- D1/D2  Birth profiles keep the family relationship and a correct
--        updated_at, so the newest copy wins when two phones sync.
-- D3     Guest (anonymous) sessions no longer upload profiles; their old
--        cloud copies could never be read again, so they are removed.
-- D8     Deleting an account keeps its payment records, with the personal
--        details cleared, as the privacy policy promises. Unpaid holds are
--        cancelled.
-- D6     Retention: Ask AI usage rows go after 13 months; cancelled
--        bookings lose their personal details after 2 years.
-- D7     The kundali tables the app never used are dropped, only if empty.

-- ---------- D1/D2: birth profiles ----------

alter table public.birth_profiles
    add column if not exists relationship text
        check (relationship is null or char_length(relationship) <= 40);

-- The app sends the time of the user's own edit. When an update doesn't
-- change updated_at (an older app version, a dashboard edit), stamp it now.
create or replace function public.touch_birth_profile()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.updated_at is not distinct from old.updated_at then
        new.updated_at := now();
    end if;
    return new;
end;
$$;

drop trigger if exists birth_profiles_touch on public.birth_profiles;
create trigger birth_profiles_touch
    before update on public.birth_profiles
    for each row execute function public.touch_birth_profile();

-- ---------- D3: guests' unreachable cloud profiles ----------

delete from public.birth_profiles bp
using auth.users u
where u.id = bp.user_id
  and u.is_anonymous;

-- ---------- D8: keep payment records when an account is deleted ----------

alter table public.consultation_requests
    alter column user_id drop not null;
alter table public.consultation_requests
    drop constraint if exists consultation_requests_user_id_fkey;
alter table public.consultation_requests
    add constraint consultation_requests_user_id_fkey
    foreign key (user_id) references auth.users (id) on delete set null;

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    uid uuid := auth.uid();
begin
    if uid is null then
        raise exception 'Not signed in' using errcode = '42501';
    end if;

    -- Holds that were never paid are released.
    update public.consultation_requests
    set status = 'cancelled'
    where user_id = uid and status = 'requested';

    -- Every booking keeps its dates, length and payment; the personal
    -- details go.
    update public.consultation_requests
    set name = 'Deleted account',
        phone = 'deleted',
        email = null,
        question = null,
        birth_details = null
    where user_id = uid;

    delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
revoke all on function public.delete_my_account() from anon;
grant execute on function public.delete_my_account() to authenticated;

-- ---------- D6: retention ----------

create or replace function public.apply_retention()
returns void
language sql
security definer
set search_path = ''
as $$
    delete from public.ai_questions
    where created_at < now() - interval '13 months';

    update public.consultation_requests
    set name = 'Removed after 2 years',
        phone = 'removed',
        email = null,
        question = null,
        birth_details = null
    where status = 'cancelled'
      and created_at < now() - interval '2 years'
      and phone <> 'removed';
$$;

revoke all on function public.apply_retention() from public, anon, authenticated;

-- Daily at 03:17 UTC.
select cron.schedule(
    'apply-retention',
    '17 3 * * *',
    $$ select public.apply_retention(); $$
);

-- ---------- D7: unused tables (only if they hold no rows) ----------

do $$
begin
    if not exists (select 1 from public.planet_positions)
        and not exists (select 1 from public.rashi_houses)
        and not exists (select 1 from public.kundalis) then
        drop table public.planet_positions;
        drop table public.rashi_houses;
        drop table public.kundalis;
    end if;
end;
$$;
