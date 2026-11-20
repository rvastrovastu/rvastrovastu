-- ============================================
-- VASTU PLAN SYNC
-- ============================================
--
-- Saved house plans follow an email account to a new phone. Each plan is a
-- row (the layout as JSON, plus which bought report it uses) and, when it
-- has one, a picture in the private "vastu-plans" storage bucket under the
-- owner's id. Guests keep plans on the phone, as before.
--
-- A deleted plan stays as a small "deleted" row with no layout or picture,
-- so a second phone removes its copy instead of uploading it again. Rows go
-- with the account (on delete cascade); the app removes the pictures first.

create table if not exists public.vastu_layouts (
    user_id uuid not null default auth.uid()
        references auth.users (id) on delete cascade,
    id text not null check (char_length(id) between 1 and 64),
    layout jsonb not null default '{}'::jsonb
        check (pg_column_size(layout) < 65536),
    image_path text check (image_path is null or char_length(image_path) <= 200),
    report_txn text check (report_txn is null or char_length(report_txn) <= 200),
    updated_at timestamptz not null default now(),
    deleted boolean not null default false,
    primary key (user_id, id)
);

alter table public.vastu_layouts enable row level security;
revoke all on public.vastu_layouts from anon;
grant select, insert, update, delete on public.vastu_layouts to authenticated;

-- Email accounts only: a guest's rows could never be reached again.
create or replace function public.is_full_account()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1 from auth.users
        where id = auth.uid() and not coalesce(is_anonymous, false)
    );
$$;

revoke all on function public.is_full_account() from public, anon;
grant execute on function public.is_full_account() to authenticated;

drop policy if exists "Owners read their Vastu plans" on public.vastu_layouts;
create policy "Owners read their Vastu plans"
    on public.vastu_layouts for select to authenticated
    using ((select auth.uid()) = user_id);

drop policy if exists "Owners add Vastu plans" on public.vastu_layouts;
create policy "Owners add Vastu plans"
    on public.vastu_layouts for insert to authenticated
    with check ((select auth.uid()) = user_id and public.is_full_account());

drop policy if exists "Owners change Vastu plans" on public.vastu_layouts;
create policy "Owners change Vastu plans"
    on public.vastu_layouts for update to authenticated
    using ((select auth.uid()) = user_id)
    with check ((select auth.uid()) = user_id and public.is_full_account());

drop policy if exists "Owners remove Vastu plans" on public.vastu_layouts;
create policy "Owners remove Vastu plans"
    on public.vastu_layouts for delete to authenticated
    using ((select auth.uid()) = user_id);

-- ---------- Pictures ----------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('vastu-plans', 'vastu-plans', false, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Each account reads and writes only its own folder: vastu-plans/<user id>/…
drop policy if exists "Owners read their plan pictures" on storage.objects;
create policy "Owners read their plan pictures"
    on storage.objects for select to authenticated
    using (bucket_id = 'vastu-plans'
           and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "Owners upload plan pictures" on storage.objects;
create policy "Owners upload plan pictures"
    on storage.objects for insert to authenticated
    with check (bucket_id = 'vastu-plans'
                and (storage.foldername(name))[1] = (select auth.uid())::text
                and public.is_full_account());

drop policy if exists "Owners replace plan pictures" on storage.objects;
create policy "Owners replace plan pictures"
    on storage.objects for update to authenticated
    using (bucket_id = 'vastu-plans'
           and (storage.foldername(name))[1] = (select auth.uid())::text)
    with check (bucket_id = 'vastu-plans'
                and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "Owners remove plan pictures" on storage.objects;
create policy "Owners remove plan pictures"
    on storage.objects for delete to authenticated
    using (bucket_id = 'vastu-plans'
           and (storage.foldername(name))[1] = (select auth.uid())::text);
