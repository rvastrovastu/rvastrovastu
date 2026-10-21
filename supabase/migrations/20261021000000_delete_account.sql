-- ============================================
-- ACCOUNT DELETION
-- ============================================
--
-- Lets a signed-in user (email or guest) delete their own account from
-- inside the app, as the App Store and Google Play require.
--
-- Deleting the auth.users row cascades to birth_profiles, kundalis,
-- planet_positions and rashi_houses (all reference it with
-- "on delete cascade").
--
-- Store subscriptions are not touched: they are billed by Apple or
-- Google and must be cancelled by the user in their store account.

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

    delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
revoke all on function public.delete_my_account() from anon;
grant execute on function public.delete_my_account() to authenticated;
