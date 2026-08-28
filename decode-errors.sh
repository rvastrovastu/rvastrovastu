#!/usr/bin/env bash
#
# Decode failures name the field that broke.
#
# WHY THIS RATHER THAN ANOTHER STRUCT FIX
#   APIError.decodingError was a bare case. Every decode failure in the app said
#   only "Couldn't decode server response" — which names nothing, and turns each
#   one into a guessing game.
#
#   FIVE structs broke this way in a single day: Habit, PartyGuest,
#   PartyMenuItem, TemplatePreview, and now the meal plan. Each cost a round of
#   speculation that the field name would have ended immediately.
#
#   Fixing the sixth struct fixes one bug. Fixing the error fixes the next five
#   too.
#
#     before   Couldn't decode server response
#     after    Missing ingredients at meals → 3 → lunch
#
# Both throw sites now describe what failed. Every call through APIService gets
# this, not only the meal plan.
#
# EXPECT BUILD ERRORS at any `catch APIError.decodingError` that matched the
# bare case — each is a one-line change to `.decodingError(let detail)`.
#
# Usage:
#   bash ~/Downloads/decode-errors.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
A="PlanBhai/ios/PlanBhai/APIService.swift"
[ -f "$A" ] || { echo "ERROR: $A not found"; exit 1; }

echo "PlanBhai — decode errors that name the field"
echo

echo "1. Patching"
cp "$A" "$A.bakdec"
cat > /tmp/pb_de.py << 'PLANBHAI_EOF'
import sys
p = 'PlanBhai/ios/PlanBhai/APIService.swift'
s = open(p).read()

if 'case decodingError(String)' in s:
    print("   already carries its cause"); sys.exit(3)

# The case gains a payload.
old_case = "    case decodingError"
if old_case not in s:
    print("   ERROR: the enum case is not in the expected shape"); sys.exit(2)
s = s.replace(old_case, """    /// Carries the field and path that failed.
    ///
    /// It used to be a bare case, so every decode failure said only
    /// "Couldn't decode server response" — which named nothing and turned each
    /// one into a guessing game. Five separate structs broke this way in a
    /// single day: Habit, PartyGuest, PartyMenuItem, TemplatePreview and the
    /// meal plan. Each cost a round of speculation that the field name would
    /// have ended immediately.
    case decodingError(String)""", 1)

s = s.replace('        case .decodingError: return "Couldn\'t decode server response"',
              '        case .decodingError(let detail):\n            return detail.isEmpty ? "Couldn\'t decode server response" : detail', 1)

# Both throw sites describe what failed.
old_throw = """        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }"""
new_throw = """        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(describeDecodingFailure(error, type: T.self))
        }"""
n = s.count(old_throw)
if n != 2:
    print(f"   ERROR: expected 2 throw sites, found {n}"); sys.exit(2)
s = s.replace(old_throw, new_throw)

# The describer.
anchor = "    // MARK: - Generic authenticated GET"
helper = """    /// Turns a DecodingError into something that names the problem.
    ///
    /// "Missing ingredients at meals → 3 → lunch" ends a debugging session that
    /// "Couldn't decode server response" would have started.
    private func describeDecodingFailure<T>(_ error: Error, type: T.Type) -> String {
        func path(_ ctx: DecodingError.Context) -> String {
            let parts = ctx.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }
            return parts.isEmpty ? "the top level" : parts.joined(separator: " → ")
        }

        switch error {
        case let DecodingError.keyNotFound(key, ctx):
            return "Missing \\(key.stringValue) at \\(path(ctx))"
        case let DecodingError.typeMismatch(expected, ctx):
            return "Expected \\(expected) at \\(path(ctx))"
        case let DecodingError.valueNotFound(expected, ctx):
            return "Null \\(expected) at \\(path(ctx))"
        case let DecodingError.dataCorrupted(ctx):
            return "Malformed at \\(path(ctx)): \\(ctx.debugDescription)"
        default:
            return "Couldn't read \\(T.self): \\(error.localizedDescription)"
        }
    }

""" + anchor
if anchor not in s:
    print("   ERROR: could not find where to add the describer"); sys.exit(2)
s = s.replace(anchor, helper, 1)

open(p, "w").write(s)
print("   decodingError now names the field and path")
PLANBHAI_EOF
python3 /tmp/pb_de.py
RC=$?
rm -f /tmp/pb_de.py
if [ "$RC" = "3" ]; then
  echo "   nothing to do"
elif [ "$RC" != "0" ]; then
  cp "$A.bakdec" "$A"; echo "   reverted"; exit 1
fi
echo

echo "2. Other places that match the bare case"
grep -rn "APIError.decodingError" PlanBhai/ios/PlanBhai/ --include="*.swift" \
  | grep -v "\.bak" | grep -v "APIService.swift" | head -5
echo "   (any listed above need .decodingError(let detail) — the build will say)"
echo

echo "3. Building"
SIM=$(xcodebuild -scheme PlanBhai -showdestinations 2>/dev/null \
  | grep -oE "name:iPhone [^}]*" | sed 's/name://' | sed 's/ *$//' | head -1)
[ -z "$SIM" ] && SIM="iPhone 17"
echo "   simulator: $SIM"
xcodebuild -scheme PlanBhai -destination "platform=iOS Simulator,name=$SIM" build 2>&1 \
  | grep -E "error:|failures\)|BUILD (SUCCEEDED|FAILED)" | head -12
echo

echo "=========================================="
echo "  Generate a meal plan again. The error will now name the field, and"
echo "  the fix after that is one line rather than another guess."
echo
echo "  Revert:  cp $A.bakdec $A"
echo "=========================================="
