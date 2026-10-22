-- ============================================
-- AI ASTROLOGER QUESTION PACKS
-- ============================================
--
-- Free users who use up their monthly questions can buy a pack
-- (RevenueCat consumable rv_ai_questions_10). The edge function counts
-- packs bought from RevenueCat and marks each answer it takes from a pack,
-- so pack questions never expire and are never counted twice.

alter table public.ai_questions
    add column if not exists from_pack boolean not null default false;

create index if not exists ai_questions_user_pack
    on public.ai_questions (user_id)
    where from_pack;
