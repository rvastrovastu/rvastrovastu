// Returns consultation prices for the app to show, in whole rupees and
// dollars: { inr: { "30": 1100, "60": 2100 }, usd: { "30": 19, "60": 35 } }.
// Same table the checkout charges (../_shared/prices.ts), so the price on
// screen always matches the price paid.

import { PRICES } from "../_shared/prices.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve((req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  const whole: Record<string, Record<string, number>> = {};
  for (const [currency, byLength] of Object.entries(PRICES)) {
    whole[currency] = {};
    for (const [minutes, amount] of Object.entries(byLength)) {
      whole[currency][minutes] = Math.round(amount / 100);
    }
  }
  return new Response(JSON.stringify(whole), {
    headers: {
      ...cors,
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=300",
    },
  });
});
