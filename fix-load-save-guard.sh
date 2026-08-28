#!/usr/bin/env bash
#
# Stops a failed load becoming a destructive write.
#
# THE PATTERN, seen four times in two days
#   loadData swallows every failure into nil. Callers do
#       if let x = await loadData(...) { self.x = x }
#   so a failure leaves the property at its launch default of []. Then
#   saveAllLocalData writes that [] over a real record.
#
#   Any failure triggers it — decode mismatch, timeout, 500, or a cancelled
#   request. "Load habits failed: cancelled" appears in your logs routinely,
#   which is why this keeps coming back: it is timing-dependent, so it recurs
#   intermittently rather than staying fixed.
#
#   Confirmed damage: 4 habits (6a518357, 07:01 UTC), then 5 habits + 1
#   challenge + 1 group (6a5183e5, 18:11 UTC) — the second set only recoverable
#   because the server-side snapshot had shipped hours earlier.
#
# THE FIX
#   Track which types loaded successfully; refuse to save one that didn't.
#   "Load failed -> destroy the record" becomes "load failed -> leave it alone."
#
# THREE CASES, all verified
#   existing user, load succeeds   saves work, including clearing a list
#   load fails                     save BLOCKED, record survives
#   brand new user (200 with [])   saves work — a successful empty load still
#                                  counts, because the distinction is whether
#                                  the REQUEST succeeded, not whether it
#                                  returned anything
#
# The server-side snapshot stays. Belt and braces: the client stops causing it,
# and anything that still does is recoverable for 30 days.
#
# Only AppState.swift changes.
#
# Usage:
#   bash ~/Downloads/fix-load-save-guard.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
F="PlanBhai/ios/PlanBhai/AppState.swift"
[ -f "$F" ] || { echo "ERROR: $F not found"; exit 1; }

echo "PlanBhai — load/save guard"
echo

if grep -q "loadedTypes" "$F"; then
  echo "   already applied"
  exit 0
fi

echo "1. Replacing loadData and saveData"
cp "$F" "$F.bakloadguard"
cat > /tmp/pb_guard.txt << 'PLANBHAI_EOF'
    /// Types that loaded successfully this session.
    ///
    /// WHY THIS EXISTS
    ///   loadData swallows every failure into nil, and callers do
    ///   `if let x = await loadData(...) { self.x = x }` — so a failed load
    ///   leaves the property at its launch default of []. saveAllLocalData then
    ///   writes that [] over a real record.
    ///
    ///   Any failure does it: a decode mismatch, a timeout, a 500, or a
    ///   cancelled request. "Load habits failed: cancelled" appears in the logs
    ///   routinely, which is why this recurs — it is timing-dependent, so it
    ///   comes back intermittently rather than staying fixed.
    ///
    ///   The server-side snapshot caught 5 habits, 1 challenge and 1 group
    ///   within hours of shipping. This stops the client causing it.
    private var loadedTypes: Set<String> = []

    /// Marks a type as safely loaded. A SUCCESSFUL load returning an empty list
    /// still counts — a new user genuinely has nothing, and refusing to save
    /// for them would be a worse bug than the one being fixed. What matters is
    /// whether the request succeeded, not whether it returned anything.
    private func markLoaded(_ type: String) {
        loadedTypes.insert(type)
    }

    private func loadData<T: Decodable>(_ type: String, as model: T.Type, scopeId: String? = nil) async -> T? {
        do {
            let value = try await APIService.shared.loadAppData(
                userId: scopeId ?? userId,
                dataType: type,
                as: model
            )
            markLoaded(type)
            return value
        }
        catch {
            handleError("Load \(type) failed", error)
            return nil
        }
    }

    private func saveData<T: Encodable>(_ type: String, _ data: T, scopeId: String? = nil) async {
        // Never write a type this session never managed to read. Without this,
        // a failed load becomes a destructive write — the single most damaging
        // pattern in the app.
        //
        // Legitimate clearing still works: deleting every grocery item saves
        // fine, because the type loaded successfully first.
        guard loadedTypes.contains(type) else {
            print("[appdata] skipping save of \(type) — it never loaded this session")
            return
        }

        do {
            try await APIService.shared.saveAppData(
                userId: scopeId ?? userId,
                dataType: type,
                data: data
            )
        } catch {
            handleError("Save \(type) failed", error)
        }
    }

    /// For data created before its type was ever read — a habit added on a
    /// fresh install, say. Without this the guard would block the first save of
    /// something the user just made.
    func allowSaving(_ type: String) {
        markLoaded(type)
    }
PLANBHAI_EOF

python3 - "$F" /tmp/pb_guard.txt << 'PY_EOF'
import sys, re
path, snipfile = sys.argv[1], sys.argv[2]
s = open(path).read()
snip = open(snipfile).read()

load_re = re.compile(
    r"    private func loadData<T: Decodable>\(_ type: String, as model: T\.Type, scopeId: String\? = nil\) async -> T\? \{.*?\n    \}\n",
    re.S)
save_re = re.compile(
    r"    private func saveData<T: Encodable>\(_ type: String, _ data: T, scopeId: String\? = nil\) async \{.*?\n    \}\n",
    re.S)

if not load_re.search(s):
    print("   ERROR: loadData is not in the expected shape"); sys.exit(2)
if not save_re.search(s):
    print("   ERROR: saveData is not in the expected shape"); sys.exit(2)

# Drop the old saveData, then replace loadData with the whole new block so both
# live together.
s = save_re.sub("", s, count=1)
s = load_re.sub(lambda _: snip, s, count=1)

open(path, "w").write(s)
print("   replaced both, added loadedTypes")
PY_EOF
if [ $? -ne 0 ]; then
  cp "$F.bakloadguard" "$F"
  echo "   reverted — no changes made"
  exit 1
fi
rm -f /tmp/pb_guard.txt
echo

echo "2. Verifying"
for k in "private var loadedTypes" "markLoaded(type)" "guard loadedTypes.contains(type)" "func allowSaving"; do
  grep -q "$k" "$F" && echo "   ok   $k" || { echo "   MISSING $k — reverting"; cp "$F.bakloadguard" "$F"; exit 1; }
done
# Exactly one of each, or something duplicated.
for fn in "private func loadData<T: Decodable>" "private func saveData<T: Encodable>"; do
  n=$(grep -c "$fn" "$F")
  [ "$n" = "1" ] && echo "   ok   one $fn" || { echo "   $n copies of $fn — reverting"; cp "$F.bakloadguard" "$F"; exit 1; }
done
echo

echo "3. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | head -15
echo

echo "=========================================="
echo "  Watch the Xcode console on launch. Lines like"
echo "     [appdata] skipping save of habits — it never loaded this session"
echo "  mean the guard just prevented a data loss, and tell you WHICH type is"
echo "  failing to load — which is the next thing worth fixing."
echo
echo "  Check nothing new gets emptied:"
echo "     cd backend && node -e 'require(\"dotenv\").config();const m=require(\"mongoose\");(async()=>{await m.connect(process.env.MONGODB_URI);const T=require(\"./models/AppDataTrash\");console.log(\"snapshots:\",await T.countDocuments({}));await m.disconnect()})()'"
echo
echo "  Revert:  cp $F.bakloadguard $F"
echo "=========================================="
