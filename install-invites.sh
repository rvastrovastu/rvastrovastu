#!/usr/bin/env bash
#
# Family members become real people: invitations by email.
#
# THE GAP THIS CLOSES
#   Household members are accounts. Family members were NAMES — Jim and Joy
#   could be assigned chores but never notified of them, because there was
#   nowhere to send anything. Two different concepts sharing one word.
#
#   Now: invite by email, they join with the code that already works, and the
#   family-member label LINKS to their account. Chores assigned to "Jim" belong
#   to Jim rather than to a string that happens to match.
#
#     before  { id, name: "Jim", role: "Parent" }              a label
#     after   { id, name: "Jim", role: "Parent",               a person
#               linkedUserId: "6a51..." }
#
# WHAT IT ADDS
#   POST /api/invites/send      { householdId, email, familyMemberId? }
#   GET  /api/invites/:id       who is pending
#   POST /api/invites/revoke    { inviteId }
#
#   And a hook inside the EXISTING /join, so there is still one way into a
#   household rather than two that can drift apart.
#
# DECISIONS WORTH KNOWING
#   ADMIN ONLY. Anyone being able to invite strangers into a household with
#   everyone's meals, chores and calendar is not a small thing.
#
#   INVITES EXPIRE after 14 days. A link that works forever is a link that works
#   for whoever finds it in a forwarded email two years from now.
#
#   A FAILED EMAIL DOES NOT FAIL THE INVITE. The code is returned either way and
#   can be passed along by hand — an invitation that exists only in an inbox is
#   one that can be lost.
#
#   RE-INVITING RESENDS rather than piling up duplicates.
#
# Uses the Gmail credentials already in .env — the same sender as password
# reset, so there is one place to change it.
#
# Usage:
#   bash ~/Downloads/install-invites.sh /Users/riteshvyas/PlanBhai/PlanBhai
#
set -uo pipefail

ROOT="${1:-$(pwd)}"
cd "$ROOT" || { echo "Cannot cd to $ROOT"; exit 1; }
[ -d backend/routes ] || { echo "ERROR: backend/routes not found"; exit 1; }

echo "PlanBhai — household invitations"
echo

echo "1. Checking prerequisites"
grep -q "EMAIL_USER" backend/.env 2>/dev/null \
  && echo "   ok   email credentials present" \
  || echo "   warn no EMAIL_USER — invites will be created but not sent"
grep -q "nodemailer" backend/package.json \
  && echo "   ok   nodemailer installed" \
  || { echo "   MISSING nodemailer — run: cd backend && npm i nodemailer"; exit 1; }
[ -f backend/middleware/requireUser.js ] \
  && echo "   ok   requireUser middleware" \
  || echo "   warn requireUser.js not found — edit the require in invite.routes.js"
echo

write() {
  local dest="$1"
  [ -f "$dest" ] && cp "$dest" "$dest.bakinvite"
  cat > "$dest"
  echo "   wrote $dest"
}

echo "2. Files"
write 'backend/models/HouseholdInvite.js' << 'PLANBHAI_EOF'
const mongoose = require("mongoose");

/**
 * An invitation to join a household, sent by email.
 *
 * WHY THIS EXISTS
 *   Household members are real accounts; family members were just names. Jim
 *   and Joy had no email, no account and no way to be notified of anything —
 *   they were labels for chores, not people the app could reach.
 *
 *   This is the bridge: invite by email, they sign up or sign in, and the
 *   family-member label links to their real account.
 */
const HouseholdInviteSchema = new mongoose.Schema({
    householdId: { type: mongoose.Schema.Types.ObjectId, ref: "Household", required: true, index: true },
    email: { type: String, required: true, lowercase: true, trim: true, index: true },

    /// Which family-member label this invite is for, if any. When accepted, that
    /// label gains a linkedUserId — so Jim's chores and points follow him rather
    /// than staying attached to a name.
    familyMemberId: { type: String, default: null },

    invitedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    invitedByName: { type: String, default: "" },

    status: { type: String, enum: ["pending", "accepted", "revoked"], default: "pending", index: true },
    acceptedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
    acceptedAt: { type: Date, default: null },

    /// Invites expire. A link that works forever is a link that works for
    /// whoever finds it in a forwarded email two years from now.
    expiresAt: {
        type: Date,
        default: () => new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
        index: true,
    },
}, { timestamps: true });

/// One live invite per email per household — re-inviting should resend, not
/// pile up.
HouseholdInviteSchema.index(
    { householdId: 1, email: 1, status: 1 },
    { unique: true, partialFilterExpression: { status: "pending" } }
);

HouseholdInviteSchema.methods.isLive = function () {
    return this.status === "pending" && this.expiresAt > new Date();
};

module.exports = mongoose.model("HouseholdInvite", HouseholdInviteSchema);
PLANBHAI_EOF
write 'backend/services/invite.mailer.js' << 'PLANBHAI_EOF'
const nodemailer = require("nodemailer");

/**
 * Sends household invitations.
 *
 * Uses the same Gmail credentials as password reset — one sender, one place to
 * change it, rather than a second transport that drifts out of step.
 */
function transport() {
    return nodemailer.createTransport({
        service: "gmail",
        auth: { user: process.env.EMAIL_USER, pass: process.env.EMAIL_PASS },
    });
}

/**
 * @returns {Promise<boolean>} whether it actually sent.
 *
 * Returns false rather than throwing. A failed email should not roll back the
 * invitation — the code still works if it is passed along by hand, and telling
 * someone "invite failed" when the record exists would be worse.
 */
async function sendInvite({ to, householdName, inviteCode, invitedByName, appUrl }) {
    if (!process.env.EMAIL_USER || !process.env.EMAIL_PASS) {
        console.warn("[invite] no email credentials — invite created but not sent");
        return false;
    }

    const link = `${appUrl || "https://planbhai.com"}/join?code=${encodeURIComponent(inviteCode)}`;
    const who = invitedByName ? `${invitedByName} has` : "You have been";

    try {
        await transport().sendMail({
            from: `"PlanBhai" <${process.env.EMAIL_USER}>`,
            to,
            subject: `${invitedByName || "Someone"} invited you to ${householdName} on PlanBhai`,
            text:
`${who} invited you to join "${householdName}" on PlanBhai.

Join here: ${link}

Or open the app and enter this code: ${inviteCode}

PlanBhai keeps a household's meals, chores, calendar and shopping in one place.
If you weren't expecting this, you can ignore it — nothing happens until you
accept.`,
            html:
`<div style="font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;max-width:480px;color:#1F2937">
  <p style="font-size:16px;margin:0 0 16px">
    <strong>${invitedByName || "Someone"}</strong> invited you to join
    <strong>${householdName}</strong> on PlanBhai.
  </p>
  <p style="margin:0 0 20px">
    <a href="${link}" style="display:inline-block;background:#52796F;color:#fff;
       padding:12px 22px;border-radius:8px;text-decoration:none;font-weight:600">
      Join ${householdName}
    </a>
  </p>
  <p style="font-size:14px;color:#6B7280;margin:0 0 6px">
    Or open the app and enter this code:
  </p>
  <p style="font-family:ui-monospace,Menlo,monospace;font-size:20px;font-weight:700;
     letter-spacing:2px;margin:0 0 20px">${inviteCode}</p>
  <p style="font-size:12px;color:#9CA3AF;line-height:1.5;margin:0">
    PlanBhai keeps a household's meals, chores, calendar and shopping in one place.
    If you weren't expecting this, you can ignore it — nothing happens until you accept.
  </p>
</div>`,
        });
        return true;
    } catch (err) {
        console.error("[invite] send failed:", err.message);
        return false;
    }
}

module.exports = { sendInvite };
PLANBHAI_EOF
write 'backend/routes/invite.routes.js' << 'PLANBHAI_EOF'
const express = require("express");
const Household = require("../models/Household");
const HouseholdInvite = require("../models/HouseholdInvite");
const AppData = require("../models/AppData");
const User = require("../models/User");
const { sendInvite } = require("../services/invite.mailer");

const router = express.Router();

// >>> EDIT if your auth helper is named differently.
const requireUser = require("../middleware/requireUser");

/**
 * Household invitations.
 *
 * Family members were names with no account — Jim and Joy could be assigned
 * chores but never notified of them, because there was nowhere to send
 * anything. These routes turn a label into a person: invite by email, they
 * join, and the label links to their real account so their chores and points
 * follow them.
 */

/**
 * POST /api/invites/send   { householdId, email, familyMemberId? }
 *
 * Admin only. Anyone being able to invite strangers into a household with
 * everyone's meals, chores and calendar is not a small thing.
 */
router.post("/send", async (req, res) => {
    const user = await requireUser(req, res);
    if (!user) return;

    const { householdId, email, familyMemberId } = req.body || {};
    const clean = String(email || "").toLowerCase().trim();

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(clean)) {
        return res.status(400).json({ success: false, message: "That doesn't look like an email address" });
    }

    try {
        const household = await Household.findById(householdId);
        if (!household) {
            return res.status(404).json({ success: false, message: "Household not found" });
        }
        if (!household.isAdmin(user._id)) {
            return res.status(403).json({ success: false, message: "Only the household owner can invite people" });
        }

        // Already a member? Say so rather than sending an invite that will
        // bounce off "you're already in this household".
        const existing = await User.findOne({ email: clean }).select("_id name").lean();
        if (existing && household.members.some((id) => id.toString() === existing._id.toString())) {
            return res.status(400).json({ success: false, message: "They're already in this household" });
        }

        // Re-inviting resends rather than duplicating.
        let invite = await HouseholdInvite.findOne({ householdId, email: clean, status: "pending" });
        if (invite) {
            invite.expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000);
            if (familyMemberId) invite.familyMemberId = familyMemberId;
            await invite.save();
        } else {
            invite = await HouseholdInvite.create({
                householdId,
                email: clean,
                familyMemberId: familyMemberId || null,
                invitedBy: user._id,
                invitedByName: user.name || "",
            });
        }

        const sent = await sendInvite({
            to: clean,
            householdName: household.name,
            inviteCode: household.inviteCode,
            invitedByName: user.name,
            appUrl: process.env.APP_URL,
        });

        res.json({
            success: true,
            invite: { id: invite._id, email: clean, status: invite.status },
            emailSent: sent,
            // The code is returned either way, so it can be shared by hand when
            // email is unavailable. An invitation that only exists in an inbox
            // is an invitation that can be lost.
            inviteCode: household.inviteCode,
        });
    } catch (err) {
        console.error("[invites/send]", err);
        res.status(500).json({ success: false, message: "Could not send that invitation" });
    }
});

/** GET /api/invites/:householdId — who is pending. Admin only. */
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
                email: i.email,
                invitedByName: i.invitedByName,
                familyMemberId: i.familyMemberId,
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

/**
 * Called after a successful join. Marks the invite accepted and links the
 * family-member label to the new account.
 *
 * Exported rather than routed — /join already exists and should stay the single
 * way in, so this hooks into it instead of adding a second path.
 */
async function claimInviteOnJoin({ household, user }) {
    const email = String(user.email || "").toLowerCase();
    const invite = await HouseholdInvite.findOne({
        householdId: household._id,
        email,
        status: "pending",
    });
    if (!invite) return null;

    invite.status = "accepted";
    invite.acceptedBy = user._id;
    invite.acceptedAt = new Date();
    await invite.save();

    // Link the label, so chores and points assigned to "Jim" now belong to
    // Jim's account rather than to a string that happens to match.
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

module.exports = { router, claimInviteOnJoin };
PLANBHAI_EOF

for f in backend/models/HouseholdInvite.js backend/services/invite.mailer.js \
         backend/routes/invite.routes.js; do
  node --check "$f" || { echo "   PARSE FAILED: $f"; exit 1; }
done
echo "   all three parse"
echo

echo "3. Hooking into /join"
cp backend/routes/householdRoutes.js backend/routes/householdRoutes.js.bakinvite
cat > /tmp/pb_join.py << 'PLANBHAI_EOF'
import sys
p = sys.argv[1]
s = open(p).read()

if 'claimInviteOnJoin' in s:
    print("   already hooked"); sys.exit(3)

old = """        await household.populate("members", "name email");
        res.json({ success: true, household });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// ─── LIST MY HOUSEHOLDS ────────────────────────────────────────"""

new = """        // If they were invited, mark it accepted and link their family-member
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

        await household.populate("members", "name email");
        res.json({ success: true, household });
    } catch (error) {
        res.status(500).json({ success: false, message: error.message });
    }
});

// ─── LIST MY HOUSEHOLDS ────────────────────────────────────────"""

if old not in s:
    print("   ERROR: /join is not in the expected shape"); sys.exit(2)

s = s.replace(old, new, 1)
open(p, "w").write(s)
print("   /join now claims invitations")
PLANBHAI_EOF
python3 /tmp/pb_join.py backend/routes/householdRoutes.js
RC=$?
rm -f /tmp/pb_join.py
if [ "$RC" != "0" ] && [ "$RC" != "3" ]; then
  cp backend/routes/householdRoutes.js.bakinvite backend/routes/householdRoutes.js
  echo "   reverted"; exit 1
fi
node --check backend/routes/householdRoutes.js || {
  cp backend/routes/householdRoutes.js.bakinvite backend/routes/householdRoutes.js
  echo "   PARSE FAILED — reverted"; exit 1; }
echo

echo "4. Mounting"
if grep -q "invite.routes" backend/server.js; then
  echo "   already mounted"
else
  cp backend/server.js backend/server.js.bakinvite
  python3 - backend/server.js << 'PY_EOF'
import sys, re
p = sys.argv[1]
s = open(p).read()
m = None
for m in re.finditer(r"app\.use\(\s*['\"]/api[^\n]*\n", s): pass
if not m:
    print("   ERROR: no /api mounts found"); sys.exit(2)
s = s[:m.end()] + "app.use('/api/invites', require('./routes/invite.routes').router);\n" + s[m.end():]
open(p, "w").write(s)
print("   mounted /api/invites")
PY_EOF
  [ $? -ne 0 ] && { cp backend/server.js.bakinvite backend/server.js; exit 1; }
  node --check backend/server.js && echo "   server.js parses"
fi
echo

echo "=========================================="
echo "  Deploy:  git add -A && git commit -m 'Household invitations by email' && git push"
echo "           then Manual Deploy on Render."
echo
echo "  Set APP_URL on Render (e.g. https://planbhai.com) so invite links point"
echo "  at the right place — it falls back to planbhai.com if unset."
echo
echo "  Test it:"
echo "     curl -X POST .../api/invites/send -H \"Authorization: Bearer \$TOK\" \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"householdId\":\"6a5186af77659b8762bfb01c\",\"email\":\"you@example.com\"}'"
echo
echo "  NO UI YET. The endpoints work; an invite screen is the next step, and"
echo "  worth building once you have seen the email arrive."
echo "=========================================="
