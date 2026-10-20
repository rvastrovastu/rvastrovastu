#!/usr/bin/env bash
#
# Guards against destructive AppData writes.
#
# WHAT HAPPENED
#   Three times in one day a failed read became a destructive write:
#     - habits loaded empty, then saveAllLocalData wrote [] over four real ones
#       (userId 6a518357, 07:01 UTC today — that is how the habits vanished)
#     - water_glasses failed to decode, then reset to 0
#     - userId fell back to "guest-<jwt>", orphaning 57 records
#
#   Always the same shape: a load fails silently, the in-memory value stays at
#   its launch default, and the next save persists that default over real data.
#   All ~24 AppData types share that path, so patching clients one at a time
#   will keep losing this race.
#
# WHAT THIS DOES
#   Catches it at the write. When an incoming value would empty a previously
#   non-empty record, the old value is snapshotted to AppDataTrash with a 30-day
#   TTL, and a warning is logged.
#
#   Nothing is blocked and no behaviour changes — a user deleting their own data
#   still works. Only "something became nothing" is captured; shrinking a list
#   from 10 to 3 is a user's business, and a water count going 4 -> 0 is the
#   daily reset.
#
# Usage:
#   bash ~/Downloads/install-appdata-guard.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/services ] || { echo "ERROR: backend/services not found"; exit 1; }

echo "PlanBhai — AppData write guard"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakguard"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Model and guard"
write 'backend/models/AppDataTrash.js' << 'PLANBHAI_EOF'
const mongoose = require('mongoose');

/**
 * Snapshots of AppData records that were emptied by a write.
 *
 * WHY THIS EXISTS
 *   Three times in one day, a failed read became a destructive write:
 *     - habits loaded empty, then saveAllLocalData wrote [] over four real ones
 *     - water_glasses failed to decode, then reset to 0
 *     - userId fell back to "guest-<jwt>", orphaning 57 records
 *
 *   The shape is always the same: a load fails silently, the in-memory value
 *   stays at its launch default, and the next save persists that default over
 *   real data. Every one of the ~24 AppData types shares that path.
 *
 *   Rather than patch each client, this catches the write. Nothing is blocked
 *   and no behaviour changes — but an overwrite that empties a record leaves a
 *   copy behind for 30 days.
 */
const AppDataTrashSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, index: true },
    type: { type: String, required: true },
    data: { type: mongoose.Schema.Types.Mixed, required: true },
    /** How many items were lost — makes triage readable without opening `data`. */
    itemCount: { type: Number, default: 0 },
    emptiedAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true },
  },
  { timestamps: false }
);

AppDataTrashSchema.index({ userId: 1, type: 1, emptiedAt: -1 });
AppDataTrashSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('AppDataTrash', AppDataTrashSchema);
PLANBHAI_EOF
write 'backend/services/appDataGuard.js' << 'PLANBHAI_EOF'
const AppDataTrash = require('../models/AppDataTrash');

const RETENTION_DAYS = 30;

/** How many items a value holds — arrays by length, objects by key count. */
function sizeOf(v) {
  if (Array.isArray(v)) return v.length;
  if (v && typeof v === 'object') return Object.keys(v).length;
  return v === null || v === undefined ? 0 : 1;
}

/**
 * Is this write destroying data?
 *
 * Only counts the case that keeps happening: something became nothing. A write
 * that shrinks a list from 10 to 3 is a user deleting things and is none of our
 * business. A write that takes 4 habits to zero is almost always a failed load
 * persisting its default.
 */
function isDestructive(existing, incoming) {
  return sizeOf(existing) > 0 && sizeOf(incoming) === 0;
}

/**
 * Snapshots the old value when a write empties it. Never throws — a backup
 * failing must not stop a user's save from going through.
 *
 * @returns {boolean} whether a snapshot was taken
 */
async function guardWrite({ userId, type, existingData, incomingData }) {
  if (!isDestructive(existingData, incomingData)) return false;

  try {
    const count = sizeOf(existingData);
    await AppDataTrash.create({
      userId,
      type,
      data: existingData,
      itemCount: count,
      emptiedAt: new Date(),
      expiresAt: new Date(Date.now() + RETENTION_DAYS * 24 * 3600 * 1000),
    });

    // Logged loudly. An emptied record is nearly always a client bug, and the
    // whole reason these went unnoticed is that nothing ever said so.
    console.warn(
      `[appdata] "${type}" emptied for ${userId} — ${count} item(s) snapshotted, ` +
        `recoverable for ${RETENTION_DAYS} days`
    );
    return true;
  } catch (err) {
    console.error('[appdata] snapshot failed:', err.message);
    return false;
  }
}

module.exports = { guardWrite, isDestructive, sizeOf, RETENTION_DAYS };
PLANBHAI_EOF

node --check backend/models/AppDataTrash.js || exit 1
node --check backend/services/appDataGuard.js || exit 1
echo "   both parse"
echo

echo "2. Hooking the save handler"
R=backend/routes/appDataRoutes.js
if grep -q "guardWrite" "$R"; then
  echo "   already hooked"
else
  cp "$R" "$R.bakguard"
  python3 - "$R" << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()

if 'require("../services/appDataGuard")' not in s:
    anchor = 'const AppData = require("../models/AppData");'
    if anchor not in s:
        m = re.search(r'const AppData = require\([^)]+\);', s)
        if not m:
            print("   ERROR: could not find the AppData import"); sys.exit(2)
        anchor = m.group(0)
    s = s.replace(anchor, anchor + '\nconst { guardWrite } = require("../services/appDataGuard");', 1)

old = """        const updated = await AppData.findOneAndUpdate(
            { userId, type },
            { userId, type, data },
            { new: true, upsert: true }
        );"""
new = """        // A load that failed silently on the client shows up here as an empty
        // write over real data. Snapshot before overwriting; never block.
        const existing = await AppData.findOne({ userId, type }).lean();
        await guardWrite({
            userId,
            type,
            existingData: existing ? existing.data : undefined,
            incomingData: data,
        });

        const updated = await AppData.findOneAndUpdate(
            { userId, type },
            { userId, type, data },
            { new: true, upsert: true }
        );"""

if old not in s:
    print("   ERROR: the save handler is not in the expected shape")
    sys.exit(2)
s = s.replace(old, new, 1)
open(p, "w").write(s)
print("   guard wired into POST /:userId/:type")
PY_EOF
  if [ $? -ne 0 ]; then
    cp "$R.bakguard" "$R"
    echo "   reverted — no changes made"
    exit 1
  fi
  node --check "$R" && echo "   route parses"
fi
echo

echo "3. Indexes"
cd backend
cat > ./.pb_idx.js << 'IDX_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  await require("./models/AppDataTrash").syncIndexes();
  console.log("   AppDataTrash indexed (TTL on expiresAt)");
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
IDX_EOF
node ./.pb_idx.js
rm -f ./.pb_idx.js
cd ..
echo

echo "=========================================="
echo "  Deploy:"
echo "     git add -A && git commit -m 'Guard against destructive AppData writes' && git push"
echo "  then Manual Deploy on Render."
echo
echo "  To see what has been caught:"
echo "     cd backend && node -e 'require(\"dotenv\").config();const m=require(\"mongoose\");(async()=>{await m.connect(process.env.MONGODB_URI);const T=require(\"./models/AppDataTrash\");(await T.find({}).sort({emptiedAt:-1}).limit(20).lean()).forEach(r=>console.log(r.emptiedAt.toISOString().slice(0,16),r.type.padEnd(20),r.itemCount+\" items\",r.userId.slice(-6)));await m.disconnect()})()'"
echo "=========================================="
