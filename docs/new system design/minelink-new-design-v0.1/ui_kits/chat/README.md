# Messages / Chat — UI kit

**Replaces the old Comms hub.** A MineLink-branded messaging surface modelled on
the CPS Smart Central chat feature (1:1 DMs, group rooms, replies, @mentions,
presence, delivered/read receipts) — re-skinned to MineLink's cyan/navy/slate
palette and re-scoped to MineLink's company rules.

## Files
- `index.html` — interactive. A **"View as"** switcher demonstrates every role.
- `data.js` — orgs, users, super admins, seeded conversations, and the **org-to-org connection registry** (`grant` / `revoke`, undirected pairs) with the contact-grouping logic.
- `chat-kit.jsx` — components: `ChatAvatar` (presence dot), `MessageBubble` (sender name + divider, reply quote, mono timestamp, delivered/read ticks), `ConversationRow`, `GroupHeader`, `ContactRow`, `Composer` (@mention hint), `ConvHeader`, `BlockedBanner`, `DateSeparator`.
- `app.jsx` — `OrgUserChat`, `AdminChat`, `ConnectionsPanel`.

## Company-scoping rules (the MineLink-specific model)
A regular user's **Contacts** are grouped and separated:
1. **MY COMPANY** — every user in their own org (internal), auto-added.
2. **MINE-LINK** — both Super Global Admins, always auto-added.
3. **CONNECTED · {Company}** — users of any *other* org that a Super Admin has connected them to. A revoked connection still appears but is marked **BLOCKED**.

The **Super Global Admin** sees a different grouping: **MINE-LINK** (the other admin) plus one group per organization (`ORGANIZATION · {Company}`) containing that org's users — so admin↔org and admin↔user chats are clearly segregated by company.

## Grant / revoke mechanics (super admin)
The **Connections** panel (hub icon) lists every org-to-org pair and lets the admin **grant** a new connection or **revoke**/re-grant an existing one. Revoking:
- **keeps all conversation history**,
- **blocks** new send/receive between the two orgs,
- shows both sides a banner: *"You can no longer send or receive messages with {Company}. Contact Mine-Link to request permission to chat with {Company} again."* with a **Message Mine-Link** button.

Once two orgs are connected they can also create **org-to-org group chats** and add/remove members from their own company. This is fully built:
- **Groups tab** — lists the viewer's org-to-org rooms; **New org-to-org group** creates one with any *connected* company (disabled with a hint when the org has no connections).
- **Group room** — cross-company message bubbles labelled `Name · Company`, @mentions, composer.
- **Members panel** — grouped by company; the viewer's own company shows **"You manage"** with Add/Remove per user, the other company is view-only (**"managed by them"**). Each org controls only its own members.
- If the underlying org-to-org connection is later **revoked**, the group room shows the same blocked banner and preserves history.

Source of truth: `uploads/FULL CHAT FEATURE/` (CPS Smart Central chat), adapted.
