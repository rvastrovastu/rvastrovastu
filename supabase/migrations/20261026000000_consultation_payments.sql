-- ============================================
-- CONSULTATION PAYMENTS (Stripe)
-- ============================================
--
-- After the astrologer sets a request to 'confirmed', the user pays from
-- My bookings. The create-consultation-checkout function opens a Stripe
-- Checkout page; the stripe-webhook function marks the booking 'paid'.
-- Users can never set 'paid' themselves (they may only cancel).

alter table public.consultation_requests
    add column if not exists currency text not null default 'usd'
        check (currency in ('inr', 'usd')),
    add column if not exists stripe_session_id text,
    add column if not exists amount_paid integer,
    add column if not exists paid_at timestamptz;

alter table public.consultation_requests
    drop constraint if exists consultation_requests_status_check;
alter table public.consultation_requests
    add constraint consultation_requests_status_check
    check (status in ('requested', 'confirmed', 'paid', 'completed', 'cancelled'));

-- A paid booking keeps its slot too.
drop index if exists public.consultation_requests_open_slot;
create unique index if not exists consultation_requests_open_slot
    on public.consultation_requests (slot_start)
    where status in ('requested', 'confirmed', 'paid');

-- Only a request still waiting for confirmation can be cancelled in the
-- app; a confirmed or paid one is cancelled by the astrologer (refunds
-- happen in Stripe).
drop policy if exists "Users cancel their own consultation requests"
    on public.consultation_requests;
create policy "Users cancel their own consultation requests"
    on public.consultation_requests for update
    to authenticated
    using ((select auth.uid()) = user_id and status = 'requested')
    with check ((select auth.uid()) = user_id and status = 'cancelled');

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
    where r.status in ('requested', 'confirmed', 'paid')
      and r.slot_start >= from_time
      and r.slot_start < to_time;
$$;
