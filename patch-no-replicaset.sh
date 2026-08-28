#!/usr/bin/env bash
#
# Removes the replica-set requirement from Phase 0.
#
# The calendar sync now detects transaction support at runtime: transactional on
# a replica set (Render/Atlas, i.e. production), sequential on a standalone
# (your laptop). No Mongo reconfiguration needed to develop locally.
#
# Usage:
#   bash ~/Downloads/patch-no-replicaset.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -euo pipefail

ROOT="${1:-$(pwd)}"
[ -d "$ROOT/backend" ] || { echo "ERROR: no backend/ under $ROOT"; exit 1; }
cd "$ROOT"
mkdir -p backend/services

write() {
  local dest="$1"
  [ -f "$dest" ] && { cp "$dest" "$dest.bak"; echo "  backed up $dest"; }
  cat > "$dest"
  echo "  wrote $dest"
}

write 'backend/services/mongo.util.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');

/**
 * MongoDB transactions require a replica set or a sharded cluster. Atlas and
 * Render's managed Mongo both give you one; a plain local mongod does not.
 *
 * Rather than making local development depend on reconfiguring Mongo, we detect
 * the capability once and degrade to sequential writes when it's absent. In
 * production this is a no-op — you get real atomicity. Locally you get a working
 * dev loop and one honest warning at startup.
 */

let cached = null;

async function supportsTransactions() {
  if (cached !== null) return cached;

  try {
    const info = await mongoose.connection.db.admin().command({ hello: 1 });
    // setName => replica set member. isdbgrid => mongos in front of a sharded cluster.
    cached = Boolean(info.setName || info.msg === 'isdbgrid');
  } catch (err) {
    cached = false;
  }

  if (!cached) {
    console.warn(
      '[mongo] Standalone server detected — writes will run without transactions.\n' +
        '        Fine for local development. Production MUST run a replica set, or a\n' +
        '        sync that dies halfway will leave a household with a partially\n' +
        '        deleted calendar.'
    );
  }

  return cached;
}

/**
 * Runs `fn(session)` inside a transaction when the deployment supports one, and
 * plainly otherwise. `fn` must accept a session that may be null — mongoose treats
 * `{ session: null }` as "no session", so call sites need no branching.
 */
async function runAtomic(fn) {
  if (await supportsTransactions()) {
    const session = await mongoose.startSession();
    try {
      let result;
      await session.withTransaction(async () => {
        result = await fn(session);
      });
      return result;
    } finally {
      session.endSession();
    }
  }

  return fn(null);
}

/** Test hook — forces re-detection. */
function _reset() {
  cached = null;
}

module.exports = { runAtomic, supportsTransactions, _reset };

PLANBHAI_EOF

write 'backend/routes/calendar.routes.js' << 'PLANBHAI_EOF'
const express = require('express');
const ExternalEvent = require('../models/ExternalEvent');
const DayBrief = require('../models/DayBrief');
const { runAtomic } = require('../services/mongo.util');

const router = express.Router();

// Replace these two with your existing middleware.
const requireAuth = require('../middleware/requireAuth');
const requireHouseholdMember = require('../middleware/requireHouseholdMember');

const MAX_EVENTS = 1000;
const MAX_WINDOW_DAYS = 45;

/**
 * POST /api/calendar/sync
 *
 * The device sends its FULL window every time, not a delta. Anything in the window
 * that isn't in the payload is treated as deleted. This is the only reliable way to
 * handle recurring-event edits and deletions without tracking tombstones on device.
 *
 * Body: { windowStart, windowEnd, syncedAt?, events: [...] }
 */
router.post('/sync', requireAuth, requireHouseholdMember, async (req, res) => {
  const { scopeId } = req; // set by requireHouseholdMember — never trust the raw query
  const userId = req.user._id;
  const { windowStart, windowEnd, events } = req.body || {};

  if (!windowStart || !windowEnd || !Array.isArray(events)) {
    return res.status(400).json({ error: 'windowStart, windowEnd and events[] are required' });
  }

  const start = new Date(windowStart);
  const end = new Date(windowEnd);
  if (isNaN(start) || isNaN(end) || end <= start) {
    return res.status(400).json({ error: 'Invalid sync window' });
  }
  if ((end - start) / 86400000 > MAX_WINDOW_DAYS) {
    return res.status(422).json({ error: `Window may not exceed ${MAX_WINDOW_DAYS} days` });
  }
  if (events.length > MAX_EVENTS) {
    return res.status(413).json({ error: `Too many events (max ${MAX_EVENTS})` });
  }

  // Strip anything we didn't ask for. Defence in depth: even if a future client
  // build starts sending notes or attendees, they never reach the database.
  const sanitized = [];
  for (const e of events) {
    if (!e.externalId || !e.occurrenceDate || !e.startUtc || !e.endUtc) continue;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(e.occurrenceDate)) continue;

    const s = new Date(e.startUtc);
    const en = new Date(e.endUtc);
    if (isNaN(s) || isNaN(en) || en < s) continue;

    sanitized.push({
      externalId: String(e.externalId).slice(0, 256),
      occurrenceDate: e.occurrenceDate,
      title: String(e.title || 'Busy').slice(0, 200),
      startUtc: s,
      endUtc: en,
      sourceTz: e.sourceTz ? String(e.sourceTz).slice(0, 64) : null,
      allDay: Boolean(e.allDay),
      calendarName: e.calendarName ? String(e.calendarName).slice(0, 100) : null,
    });
  }

  let upserted = 0;
  let removed = 0;

  try {
    // Transactional on a replica set (production), sequential on a standalone
    // (local dev). See services/mongo.util.js.
    await runAtomic(async (session) => {
      if (sanitized.length) {
        const ops = sanitized.map((e) => ({
          updateOne: {
            filter: {
              scopeId,
              provider: 'eventkit',
              externalId: e.externalId,
              occurrenceDate: e.occurrenceDate,
            },
            update: { $set: { ...e, scopeId, ownerUserId: userId, provider: 'eventkit' } },
            upsert: true,
          },
        }));
        const result = await ExternalEvent.bulkWrite(ops, { session, ordered: false });
        upserted = (result.upsertedCount || 0) + (result.modifiedCount || 0);
      }

      // Delete-by-omission, scoped to this owner's events inside this window only.
      const keep = sanitized.map((e) => `${e.externalId}::${e.occurrenceDate}`);
      const stale = await ExternalEvent.find(
        {
          scopeId,
          ownerUserId: userId,
          provider: 'eventkit',
          startUtc: { $gte: start, $lt: end },
        },
        { externalId: 1, occurrenceDate: 1 }
      ).session(session);

      const toDelete = stale
        .filter((d) => !keep.includes(`${d.externalId}::${d.occurrenceDate}`))
        .map((d) => d._id);

      if (toDelete.length) {
        const r = await ExternalEvent.deleteMany({ _id: { $in: toDelete } }, { session });
        removed = r.deletedCount || 0;
      }
    });
  } catch (err) {
    console.error('[calendar/sync] failed', err);
    return res.status(500).json({ error: 'Sync failed' });
  }

  // The timeline just changed — drop today-and-forward briefs for this household.
  const today = new Date().toISOString().slice(0, 10);
  await DayBrief.deleteMany({ scopeId, localDate: { $gte: today } });

  res.json({ upserted, removed, received: events.length, syncedAt: new Date().toISOString() });
});

/**
 * DELETE /api/calendar/disconnect
 * Required for the App Store privacy commitment: turning calendar access off must
 * actually remove the data, not just stop syncing.
 */
router.delete('/disconnect', requireAuth, requireHouseholdMember, async (req, res) => {
  const { scopeId } = req;
  const r = await ExternalEvent.deleteMany({
    scopeId,
    ownerUserId: req.user._id,
    provider: 'eventkit',
  });
  const today = new Date().toISOString().slice(0, 10);
  await DayBrief.deleteMany({ scopeId, localDate: { $gte: today } });
  res.json({ removed: r.deletedCount || 0 });
});

module.exports = router;

PLANBHAI_EOF


echo
node --check backend/routes/calendar.routes.js && echo "  calendar.routes.js parses"
node --check backend/services/mongo.util.js    && echo "  mongo.util.js parses"
echo
echo "Done. Local standalone MongoDB is now fine for development."
echo "You will see one warning line on first sync -- that is expected."
