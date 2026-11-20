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

-- ---------- Audit trail ----------
reset role;
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';

-- App users cannot read or write the audit log.
do $$ begin
    begin
        perform 1 from public.audit_log;
        raise exception 'audit log readable by users';
    exception when insufficient_privilege then null;
    end;
    begin
        insert into public.audit_log (table_name, row_id, action, actor_role)
        values ('x', 'x', 'insert', 'x');
        raise exception 'audit log writable by users';
    exception when insufficient_privilege then null;
    end;
end $$;

reset role;

-- The booking made above was logged, with the user as actor and no
-- contact details.
do $$ begin
    if not exists (
        select 1 from public.audit_log
        where table_name = 'consultation_requests' and action = 'insert'
          and actor_id = '11111111-1111-1111-1111-111111111111'
          and changes ->> 'phone' = 'changed'
          and changes::text not like '%555%'
    ) then
        raise exception 'booking insert not audited';
    end if;
end $$;

-- A payment update by the service role is logged with old and new status.
set request.jwt.claims = '{"role":"service_role"}';
set request.jwt.claim.sub = '';
update public.consultation_requests
set status = 'paid', amount_paid = 3500, paid_at = now()
where id = (select id from public.consultation_requests order by created_at limit 1);
do $$ begin
    if not exists (
        select 1 from public.audit_log
        where action = 'update' and actor_role = 'service_role'
          and changes -> 'status' ->> 1 = 'paid'
          and changes -> 'amount_paid' ->> 1 = '3500'
    ) then
        raise exception 'payment update not audited';
    end if;
end $$;
reset request.jwt.claims;

-- ---------- Vastu plan sync ----------
insert into auth.users values ('33333333-3333-3333-3333-333333333333', true);
reset request.jwt.claims;
set role authenticated;

-- An email account saves a plan and its picture in its own folder.
set request.jwt.claim.sub = '11111111-1111-1111-1111-111111111111';
insert into public.vastu_layouts (id, layout) values ('p1', '{"name":"Home"}');
insert into storage.objects (bucket_id, name)
values ('vastu-plans', '11111111-1111-1111-1111-111111111111/p1_1.jpg');

-- It cannot put a picture in someone else's folder.
do $$ begin
    begin
        insert into storage.objects (bucket_id, name)
        values ('vastu-plans', '22222222-2222-2222-2222-222222222222/x.jpg');
        raise exception 'wrote into another folder';
    exception when insufficient_privilege then null;
    end;
end $$;

-- Another account sees neither the plan nor the picture.
set request.jwt.claim.sub = '22222222-2222-2222-2222-222222222222';
do $$ begin
    if exists (select 1 from public.vastu_layouts)
       or exists (select 1 from storage.objects where bucket_id = 'vastu-plans') then
        raise exception 'plan visible to another account';
    end if;
end $$;

-- A guest cannot store plans in the cloud.
set request.jwt.claim.sub = '33333333-3333-3333-3333-333333333333';
do $$ begin
    begin
        insert into public.vastu_layouts (id, layout) values ('g1', '{}');
        raise exception 'guest stored a plan';
    exception when insufficient_privilege then null;
    end;
end $$;

-- Anonymous visitors have no access at all.
reset role;
set role anon;
do $$ begin
    begin
        perform 1 from public.vastu_layouts;
        raise exception 'anon read plans';
    exception when insufficient_privilege then null;
    end;
end $$;
reset role;
