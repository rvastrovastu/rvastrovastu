#!/usr/bin/env bash
#
# Samples the first NON-EMPTY document of each type.
#
# The earlier inspection used findOne({type}), which returned whichever document
# happened to come first — often an empty array. That made habits look unused when
# a household member actually has five. This scans for content instead.
#
# READ-ONLY.
#
# Usage:
#   bash ~/Downloads/inspect-shapes.sh /Users/riteshvyas/PlanBhai/PlanBhai
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

  const TYPES = ['habits','chores','groceries','events','calendar_events',
                 'party_events','pantry','budget_items','household_notes','settlements'];

  const firstNonEmpty = async (type) => {
    const docs = await AppData.find({ type }).lean();
    return docs.find(d => Array.isArray(d.data) ? d.data.length > 0
                        : d.data && typeof d.data === 'object' ? Object.keys(d.data).length > 0
                        : d.data != null);
  };

  for (const t of TYPES) {
    const doc = await firstNonEmpty(t);
    console.log('=== ' + t + ' ===');
    if (!doc) {
      console.log('   EMPTY in every document — this feature has no data anywhere');
      console.log();
      continue;
    }
    const arr = Array.isArray(doc.data) ? doc.data : [doc.data];
    console.log('   user ' + doc.userId + '   count=' + arr.length);

    // Union of keys across items, so optional fields aren't missed.
    const keys = new Set();
    arr.forEach(i => i && typeof i === 'object' && Object.keys(i).forEach(k => keys.add(k)));
    console.log('   all keys: ' + JSON.stringify([...keys]));

    console.log('   sample:');
    console.log('   ' + JSON.stringify(arr[0], null, 2).split('\n').join('\n   '));
    if (arr.length > 1) {
      console.log('   second:');
      console.log('   ' + JSON.stringify(arr[1], null, 2).split('\n').join('\n   '));
    }
    console.log();
  }

  // ---- settle the date epoch, wherever events exist -----------------------
  console.log('=== events[].date — epoch check ===');
  const ev = await firstNonEmpty('events');
  if (ev) {
    for (const e of ev.data.slice(0, 3)) {
      const n = e.date;
      if (typeof n !== 'number') { console.log('   date is not a number: ' + JSON.stringify(n)); continue; }
      console.log('   \"' + (e.name || '?') + '\"  raw=' + n);
      console.log('      unix seconds : ' + new Date(n * 1000).toISOString());
      console.log('      unix millis  : ' + new Date(n).toISOString());
      console.log('      Swift (2001) : ' + new Date((n + 978307200) * 1000).toISOString());
    }
  } else {
    console.log('   no events anywhere');
  }
  console.log();

  // ---- what the target household actually holds ---------------------------
  console.log('=== household 6a5186af — real content per member ===');
  const Household = require('./models/Household');
  const hh = await Household.findById('6a5186af77659b8762bfb01c').lean();
  for (const m of (hh.members || []).map(String)) {
    const docs = await AppData.find({ userId: m }).lean();
    const withData = docs.filter(d => Array.isArray(d.data) ? d.data.length > 0
                                    : d.data && typeof d.data === 'object' ? Object.keys(d.data).length > 0
                                    : false);
    console.log('   ' + m + ':');
    if (!withData.length) { console.log('      (nothing)'); continue; }
    withData.forEach(d => {
      const n = Array.isArray(d.data) ? d.data.length + ' items' : 'object';
      console.log('      ' + d.type.padEnd(22) + n);
    });
  }

  await mongoose.disconnect();
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
"
