// Stripe webhook: marks a consultation booking 'paid' when its Checkout
// session completes.
//
// Deploy without JWT checks (Stripe signs the request instead):
//   supabase functions deploy stripe-webhook --no-verify-jwt
// Secrets: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET (whsec_…, from the
// webhook endpoint in the Stripe dashboard).

import { createClient } from "jsr:@supabase/supabase-js@2";
import Stripe from "npm:stripe@17.7.0";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") ?? "", {
  httpClient: Stripe.createFetchHttpClient(),
});
const crypto = Stripe.createSubtleCryptoProvider();
const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";

Deno.serve(async (req) => {
  const signature = req.headers.get("Stripe-Signature");
  if (!signature || !WEBHOOK_SECRET) {
    return new Response("missing signature", { status: 400 });
  }

  const body = await req.text();
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
      body,
      signature,
      WEBHOOK_SECRET,
      undefined,
      crypto,
    );
  } catch (error) {
    console.error("[STRIPE] bad signature", error);
    return new Response("bad signature", { status: 400 });
  }

  if (
    event.type === "checkout.session.completed" ||
    event.type === "checkout.session.async_payment_succeeded"
  ) {
    const session = event.data.object as Stripe.Checkout.Session;
    const requestId = session.metadata?.request_id;
    if (requestId && session.payment_status === "paid") {
      const admin = createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      );
      const { data, error } = await admin
        .from("consultation_requests")
        .update({
          status: "paid",
          paid_at: new Date().toISOString(),
          amount_paid: session.amount_total,
          stripe_session_id: session.id,
        })
        .eq("id", requestId)
        .in("status", ["confirmed", "requested"])
        .select("id");
      if (error) return new Response("update failed", { status: 500 });
      if (!data?.length) {
        // Paid, but the booking was already cancelled or paid (e.g. the
        // slot expired first). Refund or rebook this payment in Stripe.
        console.error(
          "[STRIPE] payment not applied: refund or rebook",
          session.id,
          requestId,
        );
      }
    }
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
