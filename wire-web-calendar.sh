#!/usr/bin/env bash
#
# Switches the web Calendar onto the merged range endpoint.
#
# WHAT IT WAS DOING
#   Three direct AppData fetches, each with .catch(() => null) — so a failure
#   looked identical to an empty calendar. One of them fetched `meal_plans`,
#   a key with ZERO documents (the real one is `meal_plan`), so meals never
#   appeared and nothing ever said so.
#
#   It also never read `events` or EventKit, so the device calendar the whole
#   iOS sync exists for has never reached this page.
#
# WHAT IT DOES NOW
#   One call to /api/schedule/range, merged server-side. The page gains
#   schedule blocks, device calendar events, PlanBhai events, and meals mapped
#   by weekday — and errors surface instead of rendering as an empty month.
#
#   calendar_events is still fetched separately, because addEvent and
#   removeEvent write that array back; they need the raw list, not merged rows.
#
#   The range is padded a week either side of the month so the grid's leading
#   and trailing cells — which belong to adjacent months — aren't blank.
#
# Only web/src/pages/Calendar.jsx changes.
#
# Usage:
#   bash ~/Downloads/wire-web-calendar.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT/web" 2>/dev/null || { echo "ERROR: no web/ under $ROOT"; exit 1; }
F="src/pages/Calendar.jsx"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — web calendar onto the range endpoint"
echo

echo "1. Prerequisite"
grep -q "fetchScheduleRange" src/api.js \
  && echo "   ok   api.fetchScheduleRange exists" \
  || { echo "   MISSING — run install-calendar-range.sh first"; exit 1; }
echo

if grep -q "fetchScheduleRange" "$F"; then
  echo "2. Already switched"
  exit 0
fi

echo "2. Patching"
cp "$F" "$F.bakwire"
cat > /tmp/pb_cal_load.jsx << 'PLANBHAI_EOF'
  const [rangeDays, setRangeDays] = useState([]);
  const [rangeError, setRangeError] = useState('');

  // The month being viewed, as the range the endpoint needs. Padded a week
  // either side so the leading and trailing cells of the grid — which belong to
  // adjacent months — aren't blank.
  const rangeFrom = toDateStr(new Date(viewMonth.getFullYear(), viewMonth.getMonth(), -6));
  const rangeTo = toDateStr(new Date(viewMonth.getFullYear(), viewMonth.getMonth() + 1, 7));

  useEffect(() => {
    if (!scopeId) return;
    let cancelled = false;

    async function load() {
      setLoading(true);
      setRangeError('');
      try {
        const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;

        // One merged call for display, plus the raw calendar_events because
        // addEvent/removeEvent write that array back.
        //
        // The merged endpoint replaces three direct AppData fetches. Those were
        // reading `meal_plans` — a key with zero documents — so meals never
        // appeared here, and they ignored EventKit and `events` entirely.
        const [range, customRes] = await Promise.all([
          api.fetchScheduleRange(scopeId, rangeFrom, rangeTo, tz),
          api.fetchAppData('calendar_events', scopeId).catch(() => null),
        ]);

        if (cancelled) return;
        setRangeDays(range?.days || []);
        setCustomEvents(customRes?.data || []);
      } catch (err) {
        // Surfaced rather than swallowed. The old version caught each fetch to
        // null, so a failure looked identical to an empty calendar.
        if (!cancelled) setRangeError(err.message || 'Could not load your calendar');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => { cancelled = true; };
  }, [scopeId, rangeFrom, rangeTo]);
PLANBHAI_EOF
cat > /tmp/pb_cal_merge.jsx << 'PLANBHAI_EOF'
  // Merged server-side now — schedule blocks, EventKit events, PlanBhai events,
  // parties and meals mapped by weekday. The old client-side merge dated meals
  // as createdAt + index, which put Monday's dinner on whatever weekday the plan
  // happened to be generated.
  const merged = rangeDays.flatMap((day) => day.rows);

  const eventsByDate = {};
  rangeDays.forEach((day) => {
    if (day.rows.length) eventsByDate[day.localDate] = day.rows;
  });
PLANBHAI_EOF
cat > /tmp/pb_cal_patch.py << 'PLANBHAI_EOF'
import sys, re
path, loadfile, mergefile = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
load = open(loadfile).read()
merge = open(mergefile).read()

# 1. Replace the loader (three AppData fetches -> one merged call).
m = re.search(
    r"  useEffect\(\(\) => \{\n    if \(!scopeId\) return;\n    let cancelled = false;\n    async function load\(\) \{.*?\n  \}, \[scopeId\]\);\n",
    s, re.S)
if not m:
    print("   ERROR: the loader is not in the expected shape")
    sys.exit(2)
s = s[:m.start()] + load + s[m.end():]

# 2. Replace the client-side merge with the server's rows.
m2 = re.search(
    r"\n  const merged = \[\];\n\n  customEvents\.forEach.*?\n  const eventsByDate = \{\};\n  merged\.forEach\(\(e\) => \{\n    if \(!e\.date\) return;\n    \(eventsByDate\[e\.date\] = eventsByDate\[e\.date\] \|\| \[\]\)\.push\(e\);\n  \}\);\n",
    s, re.S)
if not m2:
    print("   ERROR: the merge block is not in the expected shape")
    sys.exit(2)
s = s[:m2.start()] + "\n" + merge + s[m2.end():]

# 3. partyEvents / mealPlans state is now unused.
s = s.replace("  const [partyEvents, setPartyEvents] = useState([]);\n", "")
s = s.replace("  const [mealPlans, setMealPlans] = useState([]);\n", "")

open(path, "w").write(s)

leftover = []
for name in ["setPartyEvents", "setMealPlans", "partyEvents", "mealPlans"]:
    n = len(re.findall(r"\b" + name + r"\b", s))
    if n: leftover.append(f"{name}×{n}")
print("   loader and merge replaced")
if leftover:
    print("   NOTE still referenced: " + ", ".join(leftover))
PLANBHAI_EOF

python3 /tmp/pb_cal_patch.py "$F" /tmp/pb_cal_load.jsx /tmp/pb_cal_merge.jsx
RC=$?
rm -f /tmp/pb_cal_patch.py /tmp/pb_cal_load.jsx /tmp/pb_cal_merge.jsx
if [ "$RC" != "0" ]; then
  cp "$F.bakwire" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
echo

echo "3. Building"
if [ -d node_modules ]; then
  npm run build 2>&1 | grep -E "error|✓ built" | head -8
else
  echo "   node_modules missing"
fi
echo

echo "=========================================="
echo "  If the build complains about partyEvents or mealPlans, those were"
echo "  removed as unused — the reference is somewhere I could not see. Paste"
echo "  the error and I will handle it."
echo
echo "  Then: npm run dev, open /calendar, and meals should appear on every"
echo "  day for the first time."
echo
echo "  Revert:  cp web/$F.bakwire web/$F"
echo "=========================================="
