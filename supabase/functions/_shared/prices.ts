// Consultation prices, in the smallest unit (paise / cents), by currency
// and session length. The one source of truth: the checkout charges these
// and the consult-prices function shows them in the app.
//
// Override without a deploy: supabase secrets set CONSULT_PRICES='{"inr":
// {"30":110000,"60":210000},"usd":{"30":1900,"60":3500}}'

const DEFAULT_PRICES: Record<string, Record<string, number>> = {
  inr: { "30": 110000, "60": 210000 },
  usd: { "30": 1900, "60": 3500 },
};

export const PRICES: Record<string, Record<string, number>> = (() => {
  try {
    return JSON.parse(Deno.env.get("CONSULT_PRICES") ?? "") ?? DEFAULT_PRICES;
  } catch (_) {
    return DEFAULT_PRICES;
  }
})();
