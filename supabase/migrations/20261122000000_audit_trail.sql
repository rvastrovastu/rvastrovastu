-- ============================================
-- AUDIT TRAIL FOR CONSULTATION BOOKINGS
-- ============================================
--
-- Every insert, change and delete of a consultation booking is recorded:
-- when, by whom (the signed-in user, the service role used by the edge
-- functions and Stripe webhook, or someone working directly in the
-- database such as the dashboard or a scheduled job) and what changed.
--
-- The log holds no contact details. Name, phone, email, question and
-- birth details are recorded only as "changed", never their values, so
-- deleting or anonymising a booking really removes the personal data.
-- Only the service role and the dashboard can read it. Rows are kept for
-- seven years, for payment disputes and accounts.

create table if not exists public.audit_log (
    id bigint generated always as identity primary key,
    at timestamptz not null default now(),
    table_name text not null,
    row_id text not null,
    action text not null check (action in ('insert', 'update', 'delete')),
    actor_role text not null,
    actor_id uuid,
    changes jsonb not null default '{}'::jsonb
);

create index if not exists audit_log_row on public.audit_log (table_name, row_id, at);
create index if not exists audit_log_at on public.audit_log (at);

alter table public.audit_log enable row level security;
-- No policies: app users can neither read nor write it.
revoke all on public.audit_log from anon, authenticated;

-- Who made the change, from the request's JWT when there is one.
create or replace function public.audit_actor_role()
returns text
language sql
stable
set search_path = ''
as $$
    select coalesce(
        nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role',
        case when auth.uid() is not null then 'authenticated' end,
        'database'
    );
$$;

create or replace function public.audit_consultation_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    -- Recorded with old and new values.
    tracked constant text[] := array[
        'status', 'slot_start', 'duration_minutes', 'topic', 'mode',
        'currency', 'price_label', 'amount_paid', 'paid_at',
        'stripe_session_id', 'user_id'];
    -- Recorded only as changed: personal data or free text.
    private constant text[] := array[
        'name', 'phone', 'email', 'question', 'birth_details',
        'astrologer_note', 'language'];
    old_row jsonb := case when tg_op = 'INSERT' then '{}'::jsonb else to_jsonb(old) end;
    new_row jsonb := case when tg_op = 'DELETE' then '{}'::jsonb else to_jsonb(new) end;
    diff jsonb := '{}'::jsonb;
    col text;
begin
    -- A JSON null and a missing value count as the same (nothing).
    foreach col in array tracked loop
        if nullif(old_row -> col, 'null') is distinct from nullif(new_row -> col, 'null') then
            diff := diff || jsonb_build_object(
                col, jsonb_build_array(old_row -> col, new_row -> col));
        end if;
    end loop;
    foreach col in array private loop
        if nullif(old_row -> col, 'null') is distinct from nullif(new_row -> col, 'null') then
            diff := diff || jsonb_build_object(col, 'changed');
        end if;
    end loop;

    -- An update that touched nothing worth noting leaves no row.
    if tg_op = 'UPDATE' and diff = '{}'::jsonb then
        return null;
    end if;

    insert into public.audit_log (table_name, row_id, action, actor_role, actor_id, changes)
    values (
        tg_table_name,
        coalesce(new_row ->> 'id', old_row ->> 'id'),
        lower(tg_op),
        public.audit_actor_role(),
        auth.uid(),
        diff
    );
    return null;
end;
$$;

revoke all on function public.audit_consultation_change() from public, anon, authenticated;

drop trigger if exists audit_consultation_requests on public.consultation_requests;
create trigger audit_consultation_requests
    after insert or update or delete on public.consultation_requests
    for each row execute function public.audit_consultation_change();

-- Keep the log for seven years; the rest of retention is unchanged.
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

    delete from public.audit_log
    where at < now() - interval '7 years';
$$;

revoke all on function public.apply_retention() from public, anon, authenticated;
