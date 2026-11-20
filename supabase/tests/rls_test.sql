-- Permission checks run in CI after all migrations. Every block must
-- behave as its comment says, or the script stops with an error.
\set ON_ERROR_STOP 1

insert into auth.users values
    ('11111111-1111-1111-1111-111111111111', false),
    ('22222222-2222-2222-2222-222222222222', false);

set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

insert into public.consultation_requests
    (topic, duration_minutes, slot_start, mode, name, phone)
values
    ('kundli', 60, date_trunc('hour', now()) + interval '2 days',
     'phone', 'A', '+1 214 555 0182');

-- Currency follows the phone number, not the app.
do $$ begin
    if (select currency from public.consultation_requests limit 1) <> 'usd' then
        raise exception 'currency rule broken';
    end if;
end $$;

-- A user cannot write payment fields.
do $$ begin
    begin
        insert into public.consultation_requests
            (topic, duration_minutes, slot_start, mode, name, phone, amount_paid)
        values ('kundli', 30, date_trunc('hour', now()) + interval '3 days',
                'phone', 'A', '+1 214 555 0182', 1900);
        raise exception 'payment field write allowed';
    exception when insufficient_privilege then null;
    end;
end $$;

-- An overlapping booking is refused.
do $$ begin
    begin
        insert into public.consultation_requests
            (topic, duration_minutes, slot_start, mode, name, phone)
        values ('kundli', 30, date_trunc('hour', now()) + interval '2 days 30 minutes',
                'phone', 'A', '+1 214 555 0182');
        raise exception 'overlap allowed';
    exception when exclusion_violation then null;
    end;
end $$;

-- User B sees nothing of user A's.
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$ begin
    if (select count(*) from public.consultation_requests) <> 0 then
        raise exception 'user B can read user A bookings';
    end if;
end $$;

-- Logged-out visitors read nothing.
reset role;
set role anon;
do $$ begin
    begin
        perform 1 from public.consultation_requests;
        raise exception 'anon can read bookings';
    exception when insufficient_privilege then null;
    end;
end $$;

reset role;
\echo 'RLS checks passed'
