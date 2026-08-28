#!/usr/bin/env bash
#
# Orphan cleanup, in phases.
#
#   1. SECURITY  — the keys contain full JWTs. Decodes each token's own exp
#                  claim to report whether they are still valid.
#   2. BACKUP    — writes all records to a local JSON file before anything moves.
#   3. RESTORE   — moves ONLY party_guests, the single record holding real data
#                  that exists nowhere else.
#
# Deliberately does NOT restore ai_import_count, ai_import_reset_month,
# tracker_reset_date or water_glasses. Those are counters: "absent" means full
# quota / clean slate, so writing a stale value would take AI imports away from
# a user or trigger a spurious tracker reset. Restoring them is worse than
# leaving them.
#
# Usage:
#   bash ~/Downloads/recover-orphans.sh /Users/riteshvyas/PlanBhai/PlanBhai
#   bash ~/Downloads/recover-orphans.sh /Users/riteshvyas/PlanBhai/PlanBhai --purge
#
set -uo pipefail

# Temp scripts are written into backend/ so node can resolve node_modules.
# They are removed on exit, including on failure.
cleanup() { rm -f ./.planbhai_recover.js ./.planbhai_purge.js 2>/dev/null; }
trap cleanup EXIT

ROOT="${1:-$(pwd)}"
MODE="${2:-}"
cd "$ROOT/backend" 2>/dev/null || { echo "ERROR: no backend/ under $ROOT"; exit 1; }

# ---------------------------------------------------------------------------
if [ "$MODE" = "--purge" ]; then
  BACKUP=$(ls -t orphan-backup-*.json 2>/dev/null | head -1)
  if [ -z "$BACKUP" ]; then
    echo "No orphan-backup-*.json in backend/."
    echo "Run without --purge first — that writes the backup."
    exit 1
  fi
  echo "Backup: $BACKUP ($(wc -c < "$BACKUP" | tr -d ' ') bytes)"
  echo
  read -r -p "Delete all guest-* records? Cannot be undone. [type DELETE]: " CONFIRM
  if [ "$CONFIRM" != "DELETE" ]; then
    echo "Cancelled — nothing deleted."
    exit 0
  fi
  TMPJS="./.planbhai_purge.js"
  cat > "$TMPJS" << 'PURGE_EOF'
require("dotenv").config();
const mongoose = require("mongoose");
(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  const AppData = require("./models/AppData");
  const r = await AppData.deleteMany({ userId: /^guest-/ });
  console.log("deleted " + r.deletedCount + " orphan record(s)");
  console.log("remaining: " + (await AppData.countDocuments({ userId: /^guest-/ })));
  await mongoose.disconnect();
})().catch(e => { console.error("FAILED:", e.message); process.exit(1); });
PURGE_EOF
  node "$TMPJS"
  rm -f "$TMPJS"
  exit 0
fi

# ---------------------------------------------------------------------------
TMPJS="./.planbhai_recover.js"
cat > "$TMPJS" << 'RECOVER_EOF'
require("dotenv").config();
const mongoose = require("mongoose");
const fs = require("fs");

function payloadOf(jwt) {
  try {
    const part = jwt.split(".")[1];
    if (!part) return null;
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
    return JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
  } catch { return null; }
}

const isEmpty = (d) =>
  d === null || d === undefined ||
  (Array.isArray(d) && d.length === 0) ||
  (typeof d === "object" && !Array.isArray(d) && Object.keys(d).length === 0);

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  const AppData = require("./models/AppData");
  const orphans = await AppData.find({ userId: /^guest-/ }).lean();

  // ---- 1. security ------------------------------------------------------
  console.log("=== 1. Are these tokens still valid? ===");
  const now = Math.floor(Date.now() / 1000);
  let alive = 0, expired = 0, noExp = 0, soonest = null;
  const seen = new Set();

  for (const o of orphans) {
    const tok = o.userId.slice("guest-".length);
    if (seen.has(tok)) continue;
    seen.add(tok);
    const p = payloadOf(tok);
    if (!p || !p.exp) { noExp++; continue; }
    if (p.exp > now) {
      alive++;
      if (soonest === null || p.exp < soonest) soonest = p.exp;
    } else expired++;
  }

  console.log("   distinct tokens: " + seen.size);
  console.log("   still valid    : " + alive);
  console.log("   expired        : " + expired);
  if (noExp) console.log("   no exp claim   : " + noExp);
  if (alive > 0) {
    console.log();
    console.log("   *** " + alive + " VALID auth token(s) stored in plaintext as database");
    console.log("   *** keys. Anything with read access to this collection can");
    console.log("   *** authenticate as those users until they expire.");
    console.log("   *** earliest expiry: " +
      new Date(soonest * 1000).toISOString().slice(0, 16).replace("T", " "));
  } else {
    console.log("   All expired — no credential exposure remains.");
  }
  console.log();

  // ---- 2. backup --------------------------------------------------------
  console.log("=== 2. Backup ===");
  const stamp = new Date().toISOString().slice(0, 19).replace(/[:T]/g, "-");
  const file = "orphan-backup-" + stamp + ".json";
  fs.writeFileSync(file, JSON.stringify(orphans, null, 2));
  console.log("   wrote " + orphans.length + " record(s) -> backend/" + file);
  console.log("   (contains JWTs — do not commit this file)");
  console.log();

  // ---- 3. restore -------------------------------------------------------
  console.log("=== 3. Restoring party_guests only ===");
  const candidates = orphans
    .filter(o => o.type === "party_guests" && !isEmpty(o.data))
    .map(o => {
      const p = payloadOf(o.userId.slice("guest-".length));
      return { uid: p && (p.id || p._id || p.userId || p.sub), data: o.data, updatedAt: o.updatedAt };
    })
    .filter(c => c.uid);

  if (!candidates.length) console.log("   none found");

  const best = new Map();
  for (const c of candidates) {
    const cur = best.get(c.uid);
    if (!cur || new Date(c.updatedAt) > new Date(cur.updatedAt)) best.set(c.uid, c);
  }

  let restored = 0, skipped = 0;
  for (const [uid, c] of best) {
    const existing = await AppData.findOne({ userId: uid, type: "party_guests" }).lean();
    if (existing && !isEmpty(existing.data)) {
      console.log("   SKIP " + uid + " — live already holds " +
        (Array.isArray(existing.data) ? existing.data.length : "?") + " item(s)");
      skipped++;
      continue;
    }
    await AppData.findOneAndUpdate(
      { userId: uid, type: "party_guests" },
      { userId: uid, type: "party_guests", data: c.data },
      { upsert: true }
    );
    console.log("   RESTORED " + uid + " — " +
      (Array.isArray(c.data) ? c.data.length : "?") + " guest(s) from " +
      new Date(c.updatedAt).toISOString().slice(0, 10));
    restored++;
  }
  console.log();
  console.log("   restored: " + restored + "   skipped: " + skipped);
  console.log();

  console.log("=== 4. Deliberately NOT restored ===");
  console.log("   ai_import_count / ai_import_reset_month — quota counters. Absent");
  console.log("      means full quota; a stale count takes imports AWAY from a user.");
  console.log("   tracker_reset_date — a stale date can trigger a spurious reset.");
  console.log("   water_glasses      — resets daily; a July 28 count is meaningless.");
  console.log("   saved_plans, calorie_entries, party_menu_items, party_event —");
  console.log("      the live record is newer and holds the same or more data.");
  console.log();

  console.log("=== 5. Purge ===");
  console.log("   " + orphans.length + " orphan record(s) remain — unreachable by the app, and");
  console.log("   holding auth tokens. Once you have checked the backup:");
  console.log();
  console.log("      bash ~/Downloads/recover-orphans.sh <repo-root> --purge");

  await mongoose.disconnect();
})().catch(e => { console.error("FAILED:", e.message); process.exit(1); });
RECOVER_EOF

node "$TMPJS"
rm -f "$TMPJS"
