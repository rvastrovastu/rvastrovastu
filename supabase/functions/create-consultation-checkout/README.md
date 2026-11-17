# Consultations and payments: one-time setup

Booking flow: the user requests a slot in the app → you confirm it →
the user taps **Pay** in My bookings → Stripe Checkout → the booking
shows **Paid**.

## 1. Database

From the project folder (Supabase CLI: `brew install supabase/tap/supabase`):

```
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

This creates `consultation_requests` and adds the payment columns.
(Without the CLI: open each file in `supabase/migrations/` dated
20261025 and 20261026 and run it in the dashboard's SQL Editor.)

**Guest bookings:** the app books with the user's account, or with a
guest account if *Authentication → Sign In / Providers → Anonymous
sign-ins* is turned on. If it is off, the app asks the user to sign in
with their email first.

## 2. Stripe

1. Create an account at https://dashboard.stripe.com (test mode first).
2. Developers → API keys → copy the **secret key** (`sk_test_…`).
3. Deploy the functions and set the key:

   ```
   supabase secrets set STRIPE_SECRET_KEY=sk_test_...
   supabase functions deploy create-consultation-checkout
   supabase functions deploy stripe-webhook --no-verify-jwt
   ```

4. Developers → Webhooks → **Add endpoint**:
   - URL: `https://YOUR_PROJECT_REF.supabase.co/functions/v1/stripe-webhook`
   - Events: `checkout.session.completed` and
     `checkout.session.async_payment_succeeded`
   - Copy the **signing secret** (`whsec_…`), then:

   ```
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
   ```

5. When you go live, repeat steps 2–4 with live keys.

Optional secrets:

| Secret | Default | Meaning |
| --- | --- | --- |
| `CONSULT_PRICES` | `{"inr":{"30":110000,"60":210000},"usd":{"30":1900,"60":3500}}` | Prices in paise / cents. Keep in step with `ConsultationConfig` in the app. |
| `CONSULT_RETURN_URL` | `https://rvastrovastu.github.io/rvastrovastu/` | Page shown after paying (`?paid=1`) or cancelling (`?paid=0`). |

## 3. Running consultations

- **New requests:** Table Editor → `consultation_requests`, status
  `requested`. Tip: Database → Webhooks → on INSERT, send yourself an
  email or Slack message.
- **Confirm:** set `status` to `confirmed`. The user sees a **Pay**
  button in My bookings.
- **Paid:** Stripe sets `status` to `paid` automatically. Call the user
  at the booked time (`slot_start` is in UTC; the app shows it in their
  own time zone).
- **Done / cancelled:** set `status` to `completed` or `cancelled`
  (refund paid bookings in the Stripe dashboard).

Payments are for a live one-to-one session with a person, which Apple
(App Review Guideline 3.1.3(d)) and Google Play generally allow outside
in-app purchase. Check the current store rules before release.
