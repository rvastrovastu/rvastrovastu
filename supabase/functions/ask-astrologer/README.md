# AI astrologer: one-time setup

The app never holds an AI key. It calls this Supabase edge function, which
holds the keys, checks the allowance and asks Groq (or Gemini as backup).

1. **Groq key (free):** sign in at https://console.groq.com, then
   API Keys > Create API Key. Copy it.
2. **Optional backup, Gemini (free tier):** https://aistudio.google.com >
   Get API key. Note: on the free tier Google may use prompts to improve
   its products outside the EU/UK, so it is only a fallback here.
3. **RevenueCat secret key** (so Premium users get unlimited questions):
   RevenueCat > Project settings > API keys > Secret API keys > + New.
4. Install the Supabase CLI (`brew install supabase/tap/supabase`), then
   from the project folder:

   ```
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   supabase secrets set GROQ_API_KEY=gsk_... REVENUECAT_SECRET_KEY=sk_...
   supabase secrets set GEMINI_API_KEY=AIza...
   supabase functions deploy ask-astrologer
   ```

   `YOUR_PROJECT_REF` is the id in your Supabase dashboard URL.
   `db push` creates the `ai_questions` usage table.

Optional settings (also with `supabase secrets set`):

| Secret | Default | Meaning |
| --- | --- | --- |
| `AI_FREE_PER_MONTH` | 3 | Free questions per calendar month |
| `AI_PREMIUM_PER_DAY` | 30 | Fair-use cap for Premium per day |
| `GROQ_MODEL` | llama-3.3-70b-versatile | Groq model |
| `GEMINI_MODEL` | gemini-2.5-flash | Gemini model |

What is sent to the AI: the chart summary the app computes (Lagna,
planets, dasha, current transits) and the question, never the user's
name, birthplace or birth time. The usage table stores only the time,
the model and the question's length.
