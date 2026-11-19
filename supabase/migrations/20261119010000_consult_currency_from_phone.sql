-- ============================================
-- CONSULTATION CURRENCY FROM THE PHONE NUMBER
-- ============================================
--
-- The price used to follow the phone's time zone, which anyone can change.
-- The server now sets the currency from the booking's phone number:
-- Indian numbers (+91) pay in rupees, all others in dollars. The checkout
-- function charges by this column, so the app can't choose the currency.

create or replace function public.check_consultation_request()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    open_count integer;
begin
    -- Rupees for Indian (+91 / 0091) numbers, dollars for everyone else,
    -- whatever currency the app sent.
    new.currency := case
        when regexp_replace(new.phone, '[\s().-]', '', 'g') ~ '^(\+|00)91'
            then 'inr'
        else 'usd'
    end;

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
