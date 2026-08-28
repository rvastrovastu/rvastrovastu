#!/usr/bin/env bash
#
# READ-ONLY analysis of the guest-<jwt> orphaned AppData records.
#
# Each orphan key is "guest-" + a JWT. The JWT's payload decodes to the real user
# id, so every orphan IS identifiable. This maps them, compares each against that
# user's live record, and classifies what would be safe to restore.
#
# CHANGES NOTHING. Run it as often as you like.
#
# Usage:
#   bash ~/Downloads/analyze-orphans.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/backend" 2>/dev/null || { echo "ERROR: no backend/ under $ROOT"; exit 1; }

node -e '
require("dotenv").config();
const mongoose = require("mongoose");

// Decode a JWT payload WITHOUT verifying. We are identifying ownership, not
// authenticating, and these tokens are long expired anyway.
function userIdFromJwt(jwt) {
  try {
    const part = jwt.split(".")[1];
    if (!part) return null;
    const b64 = part.replace(/-/g, "+").replace(/_/g, "/");
    const json = JSON.parse(Buffer.from(b64, "base64").toString("utf8"));
    return json.id || json._id || json.userId || json.sub || null;
  } catch { return null; }
}

const size = (d) =>
  Array.isArray(d) ? d.length
  : d && typeof d === "object" ? Object.keys(d).length
  : d === null || d === undefined ? 0 : 1;

const isEmpty = (d) =>
  d === null || d === undefined ||
  (Array.isArray(d) && d.length === 0) ||
  (typeof d === "object" && !Array.isArray(d) && Object.keys(d).length === 0);

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  const AppData = require("./models/AppData");
  const User = require("./models/User");

  const orphans = await AppData.find({ userId: /^guest-/ }).lean();
  console.log("=== 1. Overview ===");
  console.log("   orphaned records: " + orphans.length);

  // ---- decode ownership --------------------------------------------------
  const rows = [];
  let undecodable = 0;
  for (const o of orphans) {
    const uid = userIdFromJwt(o.userId.slice("guest-".length));
    if (!uid) { undecodable++; continue; }
    rows.push({ uid, type: o.type, data: o.data, updatedAt: o.updatedAt, key: o.userId });
  }
  console.log("   decoded to a user: " + rows.length);
  console.log("   undecodable:       " + undecodable);
  console.log();

  // ---- who ---------------------------------------------------------------
  const byUser = new Map();
  for (const r of rows) {
    if (!byUser.has(r.uid)) byUser.set(r.uid, []);
    byUser.get(r.uid).push(r);
  }

  console.log("=== 2. Affected users ===");
  for (const [uid, list] of byUser) {
    let u = null;
    try { u = await User.findById(uid).select("name email").lean(); } catch {}
    console.log("   " + uid + "  " + (u ? `${u.name} <${u.email}>` : "(user not found)"));
    console.log("      " + list.length + " orphaned record(s), " +
      new Set(list.map(r => r.type)).size + " distinct type(s)");
  }
  console.log();

  // ---- per record, compared against what is live now ----------------------
  console.log("=== 3. Every orphan vs the live record ===");
  console.log("   " + "type".padEnd(22) + "orphan".padEnd(14) + "live".padEnd(14) + "verdict");
  console.log("   " + "-".repeat(74));

  const verdicts = { SAFE: [], CONFLICT: [], SKIP: [] };

  for (const [uid, list] of byUser) {
    // Group this user'"'"'s orphans by type — multiple sessions can leave several.
    const byType = new Map();
    for (const r of list) {
      if (!byType.has(r.type)) byType.set(r.type, []);
      byType.get(r.type).push(r);
    }

    for (const [type, versions] of byType) {
      versions.sort((a, b) => new Date(b.updatedAt) - new Date(a.updatedAt));
      const newest = versions[0];
      const live = await AppData.findOne({ userId: uid, type }).lean();

      const oDesc = size(newest.data) + " items" + (versions.length > 1 ? ` (${versions.length}v)` : "");
      const lDesc = live ? size(live.data) + " items" : "none";

      let verdict;
      if (isEmpty(newest.data)) {
        verdict = "SKIP - orphan is empty";
        verdicts.SKIP.push({ uid, type });
      } else if (!live) {
        verdict = "SAFE - nothing live to lose";
        verdicts.SAFE.push({ uid, type, versions: versions.length });
      } else if (isEmpty(live.data)) {
        verdict = "SAFE - live record is empty";
        verdicts.SAFE.push({ uid, type, versions: versions.length });
      } else if (new Date(live.updatedAt) > new Date(newest.updatedAt)) {
        verdict = "CONFLICT - live is newer";
        verdicts.CONFLICT.push({ uid, type });
      } else {
        verdict = "CONFLICT - orphan is newer";
        verdicts.CONFLICT.push({ uid, type });
      }

      console.log("   " + type.padEnd(22) + oDesc.padEnd(14) + lDesc.padEnd(14) + verdict);
    }
  }
  console.log();

  // ---- summary -----------------------------------------------------------
  console.log("=== 4. Summary ===");
  console.log("   SAFE to restore : " + verdicts.SAFE.length +
    "  (no live data, or live is empty)");
  console.log("   CONFLICT        : " + verdicts.CONFLICT.length +
    "  (both hold data — needs a human decision)");
  console.log("   SKIP            : " + verdicts.SKIP.length +
    "  (orphan is empty, nothing to recover)");
  console.log();

  if (verdicts.SAFE.length) {
    console.log("   Safe candidates:");
    verdicts.SAFE.forEach(v =>
      console.log("      " + v.type + (v.versions > 1 ? `  (${v.versions} versions, newest wins)` : "")));
  }
  if (verdicts.CONFLICT.length) {
    console.log();
    console.log("   Conflicts — do NOT restore these blind:");
    verdicts.CONFLICT.forEach(v => console.log("      " + v.type));
  }
  console.log();
  console.log("   Nothing was changed. This was a read-only report.");

  await mongoose.disconnect();
})().catch(e => { console.error("FAILED:", e.message); process.exit(1); });
'
