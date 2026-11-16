// Sends a WhatsApp message when a consultation is paid:
//   - the astrologer gets the full details (template WA_TEMPLATE_NAME)
//   - the customer gets a confirmation (template WA_CUSTOMER_TEMPLATE)
// Called by a Supabase Database Webhook on UPDATE of consultation_requests,
// filtered to status = 'paid'.
//
// Deploy without JWT checks; the webhook must send the shared secret:
//   supabase functions deploy notify-consultation-paid --no-verify-jwt
// Secrets (supabase secrets set …):
//   WA_ACCESS_TOKEN       permanent WhatsApp Cloud API token
//   WA_PHONE_NUMBER_ID    the sending number's ID in Meta
//   ASTROLOGER_WHATSAPP   astrologer's number with country code, digits only (e.g. 15551234567)
//   NOTIFY_SECRET         random string; the webhook sends it in x-notify-secret
// Optional:
//   WA_TEMPLATE_NAME           default consult_paid_astrologer
//   WA_CUSTOMER_TEMPLATE       default consult_paid_customer
//   WA_API_VERSION             default v21.0

const TOKEN = Deno.env.get("WA_ACCESS_TOKEN") ?? "";
const PHONE_ID = Deno.env.get("WA_PHONE_NUMBER_ID") ?? "";
const ASTROLOGER = (Deno.env.get("ASTROLOGER_WHATSAPP") ?? "").replace(/\D/g, "");
const SECRET = Deno.env.get("NOTIFY_SECRET") ?? "";
const TEMPLATE = Deno.env.get("WA_TEMPLATE_NAME") ?? "consult_paid_astrologer";
const CUSTOMER_TEMPLATE = Deno.env.get("WA_CUSTOMER_TEMPLATE") ?? "consult_paid_customer";
const API_VERSION = Deno.env.get("WA_API_VERSION") ?? "v21.0";

const TOPICS: Record<string, string> = {
  kundli: "Kundli reading",
  marriage: "Marriage & compatibility",
  career: "Career & finance",
  vastu: "Vastu for your home",
};
const MODES: Record<string, string> = {
  phone: "Phone call",
  whatsapp: "WhatsApp",
  video: "Video call",
};

// WhatsApp template parameters can't contain newlines or runs of spaces.
function clean(value: unknown, max = 300): string {
  const text = String(value ?? "-").replace(/[\r\n\t]+/g, " ").replace(/ {2,}/g, " ").trim();
  return (text || "-").slice(0, max);
}

// Digits only, with country code. Returns null if the number can't be used.
function toWhatsAppNumber(raw: unknown): string | null {
  const digits = String(raw ?? "").replace(/\D/g, "");
  return digits.length >= 10 && digits.length <= 15 ? digits : null;
}

function when(iso: string): string {
  return new Date(iso).toLocaleString("en-US", {
    timeZone: "America/Chicago",
    weekday: "short",
    day: "numeric",
    month: "short",
    year: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
  });
}

async function sendTemplate(to: string, template: string, params: string[]): Promise<Response> {
  return await fetch(`https://graph.facebook.com/${API_VERSION}/${PHONE_ID}/messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      to,
      type: "template",
      template: {
        name: template,
        language: { code: "en" },
        components: [
          {
            type: "body",
            parameters: params.map((text) => ({ type: "text", text })),
          },
        ],
      },
    }),
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  if (!SECRET || req.headers.get("x-notify-secret") !== SECRET) {
    return new Response("unauthorized", { status: 401 });
  }
  if (!TOKEN || !PHONE_ID || !ASTROLOGER) {
    return new Response("not configured", { status: 503 });
  }

  let payload: { type?: string; record?: Record<string, unknown>; old_record?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch (_) {
    return new Response("bad request", { status: 400 });
  }

  const booking = payload.record ?? {};
  // Only act on the change to 'paid', never on other updates.
  if (booking.status !== "paid" || payload.old_record?.status === "paid") {
    return new Response(JSON.stringify({ skipped: true }), {
      headers: { "Content-Type": "application/json" },
    });
  }

  const minutes = clean(booking.duration_minutes, 10);
  const slot = clean(when(String(booking.slot_start)), 120);
  const mode = clean(MODES[String(booking.mode)] ?? booking.mode, 30);

  // 1. Astrologer: full details. If this fails, nothing else is sent,
  //    and the 502 makes the webhook retry, so the customer isn't messaged twice.
  const astrologerRes = await sendTemplate(ASTROLOGER, TEMPLATE, [
    clean(booking.name, 120),                                   // {{1}} customer name
    clean(booking.phone, 32),                                   // {{2}} customer phone
    slot,                                                       // {{3}} slot time (Chicago)
    clean(`${minutes} min`, 20),                                // {{4}} length
    mode,                                                       // {{5}} how to talk
    clean(TOPICS[String(booking.topic)] ?? booking.topic, 60),  // {{6}} topic
    clean(booking.question || "None", 300),                     // {{7}} their question
  ]);

  if (!astrologerRes.ok) {
    const detail = await astrologerRes.text();
    console.error("[NOTIFY] astrologer send failed", astrologerRes.status, detail);
    return new Response("send failed", { status: 502 });
  }

  // 2. Customer: confirmation. A failure here is logged but doesn't retry
  //    the astrologer message, which has already gone out.
  let customerSent = false;
  const customerTo = toWhatsAppNumber(booking.phone);
  if (!customerTo) {
    console.error("[NOTIFY] customer phone not usable", booking.phone);
  } else {
    const customerRes = await sendTemplate(customerTo, CUSTOMER_TEMPLATE, [
      clean(booking.name, 120),  // {{1}} customer name
      slot,                      // {{2}} slot time
      clean(`${minutes} min`, 20), // {{3}} length
      mode,                      // {{4}} how it will happen
    ]);
    if (customerRes.ok) {
      customerSent = true;
    } else {
      console.error("[NOTIFY] customer send failed", customerRes.status, await customerRes.text());
    }
  }

  return new Response(JSON.stringify({ sent: true, customerSent }), {
    headers: { "Content-Type": "application/json" },
  });
});
