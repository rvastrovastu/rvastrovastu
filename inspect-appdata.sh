#!/usr/bin/env bash
#
# Inspects your AppData documents so the dashboard adapter can be written against
# your real field names instead of guesses.
#
# READ-ONLY. Prints structure and small samples, not full personal content.
#
# Usage:
#   bash ~/Downloads/inspect-appdata.sh /Users/riteshvyas/PlanBhai/PlanBhai
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
  const Household = require('./models/Household');

  // ---- 1. what types exist -------------------------------------------------
  console.log('=== 1. AppData types in use ===');
  const types = await AppData.distinct('type');
  for (const t of types.sort()) {
    const n = await AppData.countDocuments({ type: t });
    console.log('   ' + t.padEnd(28) + n + ' doc(s)');
  }
  console.log();

  // ---- 2. structure of each type -------------------------------------------
  // Field names only exist in the documents, since \`data\` is Mixed.
  console.log('=== 2. shape of each type ===');
  const describe = (v, depth = 0) => {
    if (v === null || v === undefined) return 'null';
    if (Array.isArray(v)) {
      if (v.length === 0) return '[] (empty)';
      return 'array[' + v.length + '] of ' + describe(v[0], depth + 1);
    }
    if (typeof v === 'object') {
      const keys = Object.keys(v);
      if (depth >= 2) return '{' + keys.slice(0, 8).join(', ') + '}';
      return '{\n' + keys.slice(0, 14).map(k =>
        '        ' + '  '.repeat(depth) + k + ': ' + describe(v[k], depth + 1)
      ).join('\n') + '\n      ' + '  '.repeat(depth) + '}';
    }
    if (typeof v === 'string') return 'string \"' + v.slice(0, 40) + '\"';
    return typeof v;
  };

  for (const t of types.sort()) {
    const doc = await AppData.findOne({ type: t }).lean();
    console.log('   --- ' + t + ' ---');
    console.log('      ' + describe(doc.data));
    console.log('      updated: ' + doc.updatedAt);
    console.log();
  }

  // ---- 3. is this data per-user or shared? ---------------------------------
  console.log('=== 3. how many users hold each type ===');
  console.log('   (this decides whether a household brief can read one user or must merge)');
  for (const t of types.sort()) {
    const users = await AppData.distinct('userId', { type: t });
    console.log('   ' + t.padEnd(28) + users.length + ' user(s)');
  }
  console.log();

  // ---- 4. household shape --------------------------------------------------
  console.log('=== 4. households ===');
  const hs = await Household.find({}).limit(5).lean();
  for (const h of hs) {
    console.log('   ' + h._id + '  \"' + (h.name || '(unnamed)') + '\"');
    console.log('      members: ' + (h.members || []).length +
                '  ' + JSON.stringify((h.members || []).map(String)));
    const ownerKeys = Object.keys(h).filter(k =>
      /owner|creator|createdBy|admin/i.test(k));
    console.log('      owner-ish fields: ' +
      (ownerKeys.length ? JSON.stringify(ownerKeys.map(k => k + '=' + h[k])) : 'NONE'));
    console.log('      other fields: ' + Object.keys(h).filter(k =>
      !['_id','__v','members','name','createdAt','updatedAt'].includes(k)).join(', '));
  }
  console.log();

  // ---- 5. do household members actually hold data? -------------------------
  console.log('=== 5. which members hold AppData ===');
  for (const h of hs.slice(0, 2)) {
    console.log('   household ' + h._id);
    for (const m of (h.members || [])) {
      const ts = await AppData.distinct('type', { userId: String(m) });
      console.log('      user ' + m + ' -> ' +
        (ts.length ? ts.join(', ') : '(no AppData)'));
    }
  }

  await mongoose.disconnect();
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
"
