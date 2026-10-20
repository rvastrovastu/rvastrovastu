#!/usr/bin/env bash
#
# Reads the actual VALUES of the handful of fields the dashboard depends on.
# Structure alone isn't enough: a date stored as a number is meaningless until we
# know its epoch, and "day" in a meal plan could be "Monday" or "Day 1".
#
# READ-ONLY.
#
# Usage:
#   bash ~/Downloads/inspect-values.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/backend" 2>/dev/null || { echo "ERROR: no backend/ under $ROOT"; exit 1; }

node -e "
require('dotenv').config();
const mongoose = require('mongoose');

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  const AppData = require('./models/AppData');

  const HH = '6a5186af77659b8762bfb01c';
  const Household = require('./models/Household');
  const hh = await Household.findById(HH).lean();
  const members = (hh.members || []).map(String);

  const get = async (type) => {
    const docs = await AppData.find({ type, userId: { \$in: members } }).lean();
    return docs.map(d => ({ userId: d.userId, data: d.data }));
  };

  // ---- events[].date : which epoch? ---------------------------------------
  console.log('=== A. events[].date — decoding the number ===');
  const evs = await get('events');
  let shown = 0;
  for (const { userId, data } of evs) {
    for (const e of (data || []).slice(0, 3)) {
      if (shown++ > 5) break;
      const n = e.date;
      console.log('   \"' + e.name + '\"  raw=' + n);
      console.log('      as unix seconds : ' + new Date(n * 1000).toISOString());
      console.log('      as unix millis  : ' + new Date(n).toISOString());
      console.log('      as Swift (2001) : ' + new Date((n + 978307200) * 1000).toISOString());
    }
  }
  if (!evs.length) console.log('   (none)');
  console.log();

  // ---- calendar_events ----------------------------------------------------
  console.log('=== B. calendar_events (full) ===');
  for (const { data } of await get('calendar_events')) {
    console.log('   ' + JSON.stringify(data, null, 2).split('\n').join('\n   '));
  }
  console.log();

  // ---- party_events -------------------------------------------------------
  console.log('=== C. party_events — dates only ===');
  for (const { data } of await get('party_events')) {
    for (const p of (data || []).slice(0, 6)) {
      console.log('   ' + (p.name || '?').padEnd(18) + 'date=' + JSON.stringify(p.date) +
                  '  dateText=' + JSON.stringify(p.dateText));
    }
  }
  console.log();

  // ---- meal_plan ----------------------------------------------------------
  console.log('=== D. meal_plan — how are days keyed? ===');
  for (const { userId, data } of await get('meal_plan')) {
    console.log('   owned by user: ' + userId);
    console.log('   day values: ' + JSON.stringify((data.meals || []).map(m => m.day)));
    console.log('   first entry:');
    console.log('   ' + JSON.stringify((data.meals || [])[0], null, 2).split('\n').join('\n   '));
    console.log('   groceryList[0]: ' + JSON.stringify((data.groceryList || [])[0]));
  }
  console.log();

  // ---- groceries: is there ANY completion field? --------------------------
  console.log('=== E. groceries — every key that appears ===');
  for (const { userId, data } of await get('groceries')) {
    const keys = new Set();
    (data || []).forEach(i => Object.keys(i).forEach(k => keys.add(k)));
    console.log('   user ' + userId + '  items=' + (data || []).length +
                '  keys=' + JSON.stringify([...keys]));
    console.log('      sample: ' + JSON.stringify((data || [])[0]));
  }
  console.log();

  // ---- family_members -----------------------------------------------------
  console.log('=== F. family_members (full) ===');
  for (const { userId, data } of await get('family_members')) {
    console.log('   user ' + userId + ': ' + JSON.stringify(data));
  }
  console.log();

  // ---- who holds what, for the merge -------------------------------------
  console.log('=== G. per-member counts for the types that matter ===');
  for (const t of ['events','calendar_events','party_events','meal_plan','groceries','family_members','chores','habits','pantry']) {
    const rows = await AppData.find({ type: t, userId: { \$in: members } }).lean();
    const summary = rows.map(r => {
      const d = r.data;
      const n = Array.isArray(d) ? d.length : (d && typeof d === 'object' ? 'obj' : typeof d);
      return r.userId.slice(-6) + '=' + n;
    });
    console.log('   ' + t.padEnd(18) + (summary.length ? summary.join('  ') : '(none)'));
  }

  await mongoose.disconnect();
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
"
