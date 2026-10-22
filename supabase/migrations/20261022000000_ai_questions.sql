-- ============================================
-- AI ASTROLOGER USAGE
-- ============================================
--
-- One row per answered question, written only by the ask-astrologer edge
-- function (service role). Used to enforce the free monthly allowance and
-- a fair-use daily cap for Premium. Rows go when the account is deleted.
--
-- Only lengths and the model are stored, never the question or the answer.

create table if not exists public.ai_questions (
    id bigint generated always as identity primary key,
    user_id uuid not null references auth.users (id) on delete cascade,
    created_at timestamptz not null default now(),
    model text,
    question_length integer
);

create index if not exists ai_questions_user_time
    on public.ai_questions (user_id, created_at desc);

alter table public.ai_questions enable row level security;

drop policy if exists "Users read their own AI usage" on public.ai_questions;
create policy "Users read their own AI usage"
    on public.ai_questions for select
    to authenticated
    using ((select auth.uid()) = user_id);

grant select on public.ai_questions to authenticated;
grant select, insert on public.ai_questions to service_role;
