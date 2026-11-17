-- ============================================
-- DIRECT BOOKING: book and pay in one step
-- ============================================
--
-- The app now creates the booking as 'requested' and opens Stripe Checkout
-- straight away. The stripe-webhook function sets it to 'paid' when the
-- payment completes. Unpaid bookings hold their slot for 40 minutes, then
-- are cancelled so the slot is free again (Stripe's checkout session
-- expires after 31 minutes, so a late payment cannot arrive after that).

-- Keep the scheduled job available (Supabase: Database → Extensions).
create extension if not exists pg_cron with schema pg_catalog;

-- Free slots held by unpaid bookings. Runs every 5 minutes.
select cron.schedule(
    'expire-unpaid-consultations',
    '*/5 * * * *',
    $$
    update public.consultation_requests
    set status = 'cancelled'
    where status = 'requested'
      and created_at < now() - interval '40 minutes';
    $$
);

-- Notify the astrologer when a booking is paid: add a Database Webhook on
-- UPDATE of this table (Supabase dashboard → Database → Webhooks) and
-- filter for status = 'paid'. Stripe also emails the payment receipt.
