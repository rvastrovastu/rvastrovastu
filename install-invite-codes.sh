#!/usr/bin/env bash
#
# Invitations, reworked: shareable codes, no email.
#
# WHY NO EMAIL
#   Sharing is already solved by the phone in your hand — people invite family
#   over WhatsApp, Messages, or by reading a code aloud. A mail pipeline is
#   maintenance for a job a six-character string does, and it fails in ways a
#   string cannot: app passwords get revoked, personal Gmail sending to
#   strangers gets rate limited, invitations land in spam.
#
#   The first version proved the point. Email failed, the code came back, and
#   the invitation was completely usable.
#
# WHAT THE RECORD IS STILL FOR
#   The household already has a shared code, so a code alone needs no model.
#   This tracks WHO was invited — which is what lets a family-member label link
#   to the account that accepts it.
#
#     before  { id, name: "Jim", role: "Parent" }        a label
#     after   { id, name: "Jim", ..., linkedUserId }     a person
#
#   Without it, someone joining by code is a new member with no connection to
#   the "Jim" that chores are assigned to.
#
# CODES: six characters, no vowels (no accidental words), no 0/O/1/I/L (no
# misreads when read aloud). 481 million combinations, single-use when tied to a
# person, 14-day expiry.
#
#   POST /api/invites/create   { householdId, inviteeName?, familyMemberId? }
#   GET  /api/invites/:id      live invitations
#   POST /api/invites/revoke   { inviteId }
#
# /join now accepts a personal code OR the household's shared one, and links the
# label when the code was made for one.
#
# Usage:
#   bash ~/Downloads/install-invite-codes.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/routes ] || { echo "ERROR: backend/routes not found"; exit 1; }

echo "PlanBhai — invite codes"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakcode"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "1. Files"
write 'backend/models/HouseholdInvite.js' << 'PLANBHAI_EOF'
const mongoose = require("mongoose");
const crypto = require("crypto");

/**
 * An invitation to join a household, as a shareable code.
 *
 * NO EMAIL. Sharing is already solved — people invite family over WhatsApp,
 * Messages, or by reading a code aloud. An email pipeline would be maintenance
 * for a job a six-character string does, and it fails in ways a string cannot:
 * app passwords get revoked, personal Gmail sending to strangers gets rate
 * limited, and mail lands in spam.
 *
 * WHAT THE RECORD IS FOR
 *   The household already has a shared inviteCode, so a code alone needs no
 *   model. This exists to track WHO was invited — which is what lets a
 *   family-member label link to the account that accepts it.
 *
 *     before  { id, name: "Jim", role: "Parent" }        a label
 *     after   { id, name: "Jim", ..., linkedUserId }     a person
 *
 *   Without it, someone joining by code is a new member with no connection to
 *   the "Jim" that chores are assigned to.
 */

/** Six characters, no vowels, no 0/O/1/I/L. Unambiguous read aloud. */
const ALPHABET = "BCDFGHJKMNPQRSTVWXYZ23456789";
function makeCode() {
    const bytes = crypto.randomBytes(6);
    let out = "";
    for (let i = 0; i < 6; i++) out += ALPHABET[bytes[i] % ALPHABET.length];
    return out;
}

const HouseholdInviteSchema = new mongoose.Schema({
    householdId: { type: mongoose.Schema.Types.ObjectId, ref: "Household", required: true, index: true },

    /// Per-invite, not the household's shared code.
    ///
    /// A code tied to one person must be single-use — otherwise "Jim's invite"
    /// forwarded to three people links all three to Jim.
    code: { type: String, required: true, unique: true, uppercase: true, index: true },

    /// Who this is for. Free text, because they have no account yet — the whole
    /// point is that this is the step before one exists.
    inviteeName: { type: String, default: "" },

    /// Which family-member label to link on acceptance, if any.
    familyMemberId: { type: String, default: null },

    invitedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    invitedByName: { type: String, default: "" },

    status: { type: String, enum: ["pending", "accepted", "revoked"], default: "pending", index: true },
    acceptedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    acceptedAt: { type: Date, default: null },

    /// Codes expire. One that works forever works for whoever finds the old
    /// message in two years.
    expiresAt: {
        type: Date,
        default: () => new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
        index: true,
    },
}, { timestamps: true });

HouseholdInviteSchema.statics.makeCode = makeCode;

/** A code nobody else holds. Retries because collisions are possible, if rare. */
HouseholdInviteSchema.statics.freshCode = async function () {
    for (let i = 0; i < 8; i++) {
        const code = makeCode();
        if (!(await this.exists({ code }))) return code;
    }
    throw new Error("Could not generate an unused invite code");
};

HouseholdInviteSchema.methods.isLive = function () {
    return this.status === "pending" && this.expiresAt > new Date();
};

module.exports = mongoose.model("HouseholdInvite", HouseholdInviteSchema);
PLANBHAI_EOF
write 'backend/routes/invite.routes.js' << 'PLANBHAI_EOF'
const express = require("express");
const jwt = require("jsonwebtoken");
const Household = require("../models/Household");
const HouseholdInvite = require("../models/HouseholdInvite");
const AppData = require("../models/AppData");
const UserModel = require("../models/User");

const router = express.Router();

/**
 * Household invitations, as shareable codes.
 *
 * Family members were names — Jim could be assigned chores but never notified,
 * because there was nowhere to send anything. These routes turn a label into a
 * person: create a code for Jim, share it however you already talk to him, and
 * when he joins, his label links to his account.
 *
 * No email. Sharing is solved by the phone in your hand, and a mail pipeline
 * would be maintenance for a job a six-character string does.
 */

// requireUser is a LOCAL function inside householdRoutes, not a middleware
// file. Defined here rather than imported to avoid a circular require.
async function requireUser(req, res) {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.slice(7) : null;
    if (!token) { res.status(401).json({ success: false, message: "Not signed in" }); return null; }
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await UserModel.findById(decoded.id || decoded.userId);
        if (!user) { res.status(401).json({ success: false, message: "Not signed in" }); return null; }
        return user;
    } catch {
        res.status(401).json({ success: false, message: "Not signed in" }); return null;
    }
}

/**
 * POST /api/invites/create   { householdId, inviteeName?, familyMemberId? }
 *
 * Admin only. Anyone being able to bring strangers into a household with
 * everyone's meals, chores and calendar is not a small thing.
 */
router.post("/create", async (req, res) => {
    const user = await requireUser(req, res);
    if (!user) return;

    const { householdId, inviteeName, familyMemberId } = req.body || {};

    try {
        const household = await Household.findById(householdId);
        if (!household) {
            return res.status(404).json({ success: false, message: "Household not found" });
        }
        if (!household.isAdmin(user._id)) {
            return res.status(403).json({ success: false, message: "Only the household owner can invite people" });
        }

        // One live invite per family member — a second code for Jim would mean
        // two people could each claim to be him.
        if (familyMemberId) {
            const existing = await HouseholdInvite.findOne({
                householdId, familyMemberId, status: "pending",
            });
            if (existing && existing.isLive()) {
                return res.json({
                    success: true,
                    invite: shape(existing),
                    reused: true,
                });
            }
        }

        const invite = await HouseholdInvite.create({
            householdId,
            code: await HouseholdInvite.freshCode(),
            inviteeName: (inviteeName || "").trim(),
            familyMemberId: familyMemberId || null,
            invitedBy: user._id,
            invitedByName: user.name || "",
        });

        res.json({ success: true, invite: shape(invite) });
    } catch (err) {
        console.error("[invites/create]", err);
        res.status(500).json({ success: false, message: "Could not create that invitation" });
    }
});

/** GET /api/invites/:householdId — live invitations. Admin only. */
router.get("/:householdId", async (req, res) => {
    const user = await requireUser(req, res);
    if (!user) return;

    try {
        const household = await Household.findById(req.params.householdId);
        if (!household) {
            return res.status(404).json({ success: false, message: "Household not found" });
        }
        if (!household.isAdmin(user._id)) {
            return res.status(403).json({ success: false, message: "Only the household owner can see invitations" });
        }

        const invites = await HouseholdInvite
            .find({ householdId: req.params.householdId, status: "pending" })
            .sort({ createdAt: -1 })
            .lean();

        res.json({
            success: true,
            invites: invites.map((i) => ({
                id: String(i._id),
                code: i.code,
                inviteeName: i.inviteeName,
                familyMemberId: i.familyMemberId,
                invitedByName: i.invitedByName,
                expired: new Date(i.expiresAt) <= new Date(),
                createdAt: i.createdAt,
            })),
        });
    } catch (err) {
        console.error("[invites/list]", err);
        res.status(500).json({ success: false, message: "Could not load invitations" });
    }
});

/** POST /api/invites/revoke   { inviteId } */
router.post("/revoke", async (req, res) => {
    const user = await requireUser(req, res);
    if (!user) return;

    try {
        const invite = await HouseholdInvite.findById(req.body.inviteId);
        if (!invite) {
            return res.status(404).json({ success: false, message: "Invitation not found" });
        }
        const household = await Household.findById(invite.householdId);
        if (!household || !household.isAdmin(user._id)) {
            return res.status(403).json({ success: false, message: "Only the household owner can revoke invitations" });
        }

        invite.status = "revoked";
        await invite.save();
        res.json({ success: true });
    } catch (err) {
        console.error("[invites/revoke]", err);
        res.status(500).json({ success: false, message: "Could not revoke that invitation" });
    }
});

function shape(i) {
    return {
        id: String(i._id),
        code: i.code,
        inviteeName: i.inviteeName,
        familyMemberId: i.familyMemberId,
        expiresAt: i.expiresAt,
    };
}

/**
 * Called from /join. Marks an invite accepted and links the family-member label
 * to the account that used it.
 *
 * @param code  the code they joined with — matched against invite codes as well
 *              as the household's shared one.
 */
async function claimInviteOnJoin({ household, user, code }) {
    if (!code) return null;

    const invite = await HouseholdInvite.findOne({
        householdId: household._id,
        code: String(code).toUpperCase(),
        status: "pending",
    });
    if (!invite || !invite.isLive()) return null;

    invite.status = "accepted";
    invite.acceptedBy = user._id;
    invite.acceptedAt = new Date();
    await invite.save();

    // The point of the whole exercise: chores assigned to "Jim" now belong to
    // Jim rather than to a string that happens to match.
    if (invite.familyMemberId) {
        const scope = household._id.toString();
        const row = await AppData.findOne({ userId: scope, type: "family_members" });
        if (row && Array.isArray(row.data)) {
            const idx = row.data.findIndex((m) => String(m.id) === String(invite.familyMemberId));
            if (idx >= 0) {
                row.data[idx] = { ...row.data[idx], linkedUserId: user._id.toString() };
                row.markModified("data");
                await row.save();
            }
        }
    }

    return invite;
}

/** Finds the household for a code — either an invite code or the shared one. */
async function householdForCode(code) {
    const clean = String(code || "").toUpperCase().trim();
    if (!clean) return null;

    const invite = await HouseholdInvite.findOne({ code: clean, status: "pending" });
    if (invite && invite.isLive()) {
        return Household.findById(invite.householdId);
    }
    return Household.findOne({ inviteCode: clean });
}

module.exports = { router, claimInviteOnJoin, householdForCode };
PLANBHAI_EOF

rm -f backend/services/invite.mailer.js && echo "   removed the mailer"
for f in backend/models/HouseholdInvite.js backend/routes/invite.routes.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   both parse"
echo

echo "2. Rewiring /join"
cp backend/routes/householdRoutes.js backend/routes/householdRoutes.js.bakcode
cat > /tmp/pb_join2.py << 'PLANBHAI_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

# Remove the old email-based hook if present.
old_hook = """        // If they were invited, mark it accepted and link their family-member
        // label to this account — so chores assigned to "Jim" now belong to
        // Jim rather than to a string that happens to match.
        //
        // Failure here must not break the join. Being in the household is the
        // important part; the link is an improvement on top of it.
        try {
            const { claimInviteOnJoin } = require("./invite.routes");
            await claimInviteOnJoin({ household, user });
        } catch (e) {
            console.error("[join] invite claim failed:", e.message);
        }

"""
if old_hook in s:
    s = s.replace(old_hook, "", 1)
    print("   removed the email-era hook")

# /join must accept per-invite codes, not only the household's shared one.
old_find = """        const household = await Household.findOne({ inviteCode: inviteCode.toUpperCase() });
        if (!household) {
            return res.status(404).json({ success: false, message: "No household found with that invite code" });
        }"""
new_find = """        // Matches a per-invite code OR the household's shared one. Personal
        // codes are what let a join link back to the family member it was
        // created for.
        const { householdForCode } = require("./invite.routes");
        const household = await householdForCode(inviteCode);
        if (!household) {
            return res.status(404).json({ success: false, message: "No household found with that invite code" });
        }"""
if old_find not in s:
    print("   ERROR: the lookup in /join is not in the expected shape"); sys.exit(2)
s = s.replace(old_find, new_find, 1)

old_after = """        await household.populate("members", "name email");
        res.json({ success: true, household });"""
new_after = """        // Link the family-member label to this account, if the code was made
        // for one. Failure must not break the join — being in the household is
        // the important part; the link is an improvement on top.
        try {
            const { claimInviteOnJoin } = require("./invite.routes");
            await claimInviteOnJoin({ household, user, code: inviteCode });
        } catch (e) {
            console.error("[join] invite claim failed:", e.message);
        }

        await household.populate("members", "name email");
        res.json({ success: true, household });"""
if old_after not in s:
    print("   ERROR: could not find the join response"); sys.exit(2)
s = s.replace(old_after, new_after, 1)

open(p, "w").write(s)
print("   /join accepts personal codes and links on accept")
PLANBHAI_EOF
python3 /tmp/pb_join2.py backend/routes/householdRoutes.js
RC=$?
rm -f /tmp/pb_join2.py
if [ "$RC" != "0" ]; then
  cp backend/routes/householdRoutes.js.bakcode backend/routes/householdRoutes.js
  echo "   reverted"; exit 1
fi
node --check backend/routes/householdRoutes.js || {
  cp backend/routes/householdRoutes.js.bakcode backend/routes/householdRoutes.js
  echo "   PARSE FAILED — reverted"; exit 1; }
echo

echo "3. Clearing the email-era invite"
cd backend
cat > ./.pb_ci.js << 'CI_EOF'
require("dotenv").config();
const m = require("mongoose");
(async () => {
  await m.connect(process.env.MONGODB_URI);
  // The old records have no `code`, which is now required — they would fail
  // validation on any future save.
  const r = await m.connection.collection("householdinvites").deleteMany({ code: { $exists: false } });
  console.log("   removed " + r.deletedCount + " invite(s) from the email version");
  await m.disconnect();
})().catch(e => { console.error("   " + e.message); process.exit(0); });
CI_EOF
node ./.pb_ci.js
rm -f ./.pb_ci.js
cd ..
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Invitations as shareable codes' && git push"
echo "           then Manual Deploy on Render."
echo
echo "  EMAIL_USER / EMAIL_PASS are no longer needed for invites — password"
echo "  reset still uses them, so leave them be."
echo
echo "  Test:"
echo "     curl -X POST .../api/invites/create -H \"Authorization: Bearer \$TOK\" \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"householdId\":\"6a5186af77659b8762bfb01c\",\"inviteeName\":\"Jim\"}'"
echo
echo "  Returns a code. Share it however you already talk to Jim."
echo "=========================================="
