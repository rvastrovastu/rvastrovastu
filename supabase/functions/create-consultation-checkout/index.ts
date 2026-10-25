// Creates a Stripe Checkout page for a confirmed consultation booking.
//
// The app calls this from My bookings once the astrologer has set the
// request to 'confirmed'. The price comes from the table below (or the
// CONSULT_PRICES secret), never from the app, so it can't be tampered
// with. Payment is recorded by the stripe-webhook function.
//
// Secrets (supabase secrets set …): STRIPE_SECRET_KEY; optional
// CONSULT_PRICES (JSON like the default below, in the smallest unit:
// paise / cents) and CONSULT_RETURN_URL (page shown after paying).
//
// Body: { request_id }  →  { url }

import { createClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.7.0";

const STRIPE_KEY = Deno.env.get("STRIPE_SECRET_KEY");
const RETURN_URL =
  Deno.env.get("CONSULT_RETURN_URL") ??
  "https://rvastrovastu.github.io/rvastrovastu/";

// Keep in step with ConsultationConfig in the app.
const DEFAULT_PRICES: Record<string, Record<string, number>> = {
  inr: { "30": 110000, "60": 210000 },
  usd: { "30": 1900, "60": 3500 },
};
const PRICES: Record<string, Record<string, number>> = (() => {
  try {
    return JSON.parse(Deno.env.get("CONSULT_PRICES") ?? "") ?? DEFAULT_PRICES;
  } catch (_) {
    return DEFAULT_PRICES;
  }
})();

const TOPICS: Record<string, string> = {
  kundli: "Kundli reading",
  marriage: "Marriage & compatibility",
  career: "Career & finance",
  vastu: "Vastu for your home",
};

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!STRIPE_KEY) return json({ error: "payments_not_configured" }, 503);

  const url = Deno.env.get("SUPABASE_URL")!;
  const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const userClient = createClient(url, anon, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: auth } = await userClient.auth.getUser();
  const user = auth?.user;
  if (!user) return json({ error: "unauthorized" }, 401);

  let requestId: unknown;
  try {
    requestId = (await req.json())?.request_id;
  } catch (_) {
    return json({ error: "bad_request" }, 400);
  }
  if (typeof requestId !== "string") return json({ error: "bad_request" }, 400);

  const admin = createClient(url, service);
  const { data: booking, error } = await admin
    .from("consultation_requests")
    .select("*")
    .eq("id", requestId)
    .eq("user_id", user.id)
    .maybeSingle();
  if (error) return json({ error: "lookup_failed" }, 500);
  // Not 404: the app reads 404 as "function not deployed".
  if (!booking) return json({ error: "not_found" }, 403);
  if (booking.status !== "confirmed") {
    return json({ error: "not_payable", status: booking.status }, 409);
  }

  const currency = String(booking.currency ?? "usd");
  const amount = PRICES[currency]?.[String(booking.duration_minutes)];
  if (!amount) return json({ error: "no_price" }, 500);

  const stripe = new Stripe(STRIPE_KEY, {
    httpClient: Stripe.createFetchHttpClient(),
  });
  const slot = new Date(booking.slot_start).toUTCString();
  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    line_items: [
      {
        quantity: 1,
        price_data: {
          currency,
          unit_amount: amount,
          product_data: {
            name: `${TOPICS[booking.topic] ?? "Consultation"} · ${booking.duration_minutes} min`,
            description: `RV Astro Vastu consultation on ${slot}`,
          },
        },
      },
    ],
    customer_email: booking.email ?? undefined,
    client_reference_id: booking.id,
    metadata: { request_id: booking.id, user_id: user.id },
    payment_intent_data: { metadata: { request_id: booking.id } },
    success_url: `${RETURN_URL}?paid=1`,
    cancel_url: `${RETURN_URL}?paid=0`,
  });

  await admin
    .from("consultation_requests")
    .update({ stripe_session_id: session.id })
    .eq("id", booking.id);

  return json({ url: session.url });
});
