# Phase 3 — Full Chat Feature (design/spec)

**Date:** 2026-07-05
**Goal:** Replace MineLink's basic comms hub with the full CPS-style messaging surface described in the design's chat kit — 1:1 DMs, group rooms, replies, @mentions, presence, delivered/read receipts — re-scoped to MineLink's company rules, wired to the live Supabase project `yftazblpmicqtamyiwyb`.

## Sources
- **Design intent:** `docs/new system design/minelink-new-design-v0.1/ui_kits/chat/` (README + chat-kit.jsx + app.jsx).
- **Reference impl (UI/UX to adapt):** `.../uploads/FULL CHAT FEATURE/` (CPS Smart Central, 65 files — models, repos, services, widgets). Uses ChangeNotifier + a `public.users` identity model.
- **Current MineLink chat:** `lib/features/chat/` (chat_rooms + chat_messages, Riverpod). Identity = `auth.uid()` (participant_ids are auth uids; profiles.id = auth uid).

## Architecture decision
**Extend MineLink's existing `chat_rooms`/`chat_messages` schema + Riverpod providers** (not swap in the CPS `conversations`/`messages`/`users` model). Reasons: already integrated, RLS already `auth.uid()`-based, lower risk. The CPS Dart is a **pattern reference** for the premium UI (bubbles, mention picker, presence, typing, receipts), re-implemented in Riverpod against MineLink's schema.

## MineLink company-scoping rules (from chat kit README)
A regular user's **Contacts** are grouped:
1. **MY COMPANY** — everyone in their own org (auto).
2. **MINE-LINK** — both Super Global Admins (auto).
3. **CONNECTED · {Company}** — users of another org a Super Admin connected them to. Revoked → still listed, marked **BLOCKED** (history kept, sending disabled, banner shown).

**Super Global Admin** sees: **MINE-LINK** (other admin) + one **ORGANIZATION · {Company}** group per org.

Connected orgs can also create **org-to-org group chats**; each org manages only its **own** members.

## DB migration (NEW — needs approval before applying to live DB)
New migration `supabase/migrations/2026070510XXXX_full_chat.sql`:

1. **`org_connections`** — undirected org-to-org registry:
   `id, company_low_id, company_high_id (ordered pair, unique), status text CHECK in ('granted','revoked'), granted_by uuid, granted_at, revoked_by uuid, revoked_at, created_at, updated_at`.
   RLS: super admins (profiles.platform_role) full manage; members of either company SELECT their own connections. Realtime enabled.
2. **Extend `chat_rooms`**: add `type text default 'dm' CHECK in ('dm','group','org_group')`, `company_a_id uuid`, `company_b_id uuid` (org_group scope), `created_by uuid`. Membership stays `participant_ids[]` (auth uids); a participant's company is derived from employees/companies.
3. **Extend `chat_messages`**: add `mentions jsonb default '[]'`, `delivered_at timestamptz`, `read_at timestamptz`. Keep `is_read`.
4. **`chat_message_reads`** — per-recipient receipts for group rooms: `message_id, user_id, delivered_at, read_at`, PK(message_id,user_id). RLS: room participants.
5. **RPC `get_chat_contacts(p_user_id)`** — returns the grouped contact list (my company / mine-link / connected / blocked) applying the scoping rules server-side.
6. **Send-guard**: RLS/trigger blocks inserting a message into an org_group / cross-company DM when the underlying org_connection is `revoked` (history preserved, new sends denied) — mirrors the BLOCKED banner.
7. Indexes; add new tables to `supabase_realtime`; `REPLICA IDENTITY FULL`.

All migration SQL will be shown for approval and applied via the Management API (or `supabase db push`) — nothing runs against the live DB without an explicit go-ahead.

## Dart implementation (Riverpod, against MineLink schema)
- **Models:** extend `chat_room_model` (type, company scope, members-with-company), `chat_message_model` (mentions, delivered_at, read_at), add `chat_contact_model`, `chat_mention`, `org_connection`.
- **Repositories/services:** `chat_repository` (rooms/messages CRUD + get-or-create DM), `chat_contacts_service` (calls `get_chat_contacts`), `presence_service` (Supabase Realtime presence), `typing_service` (broadcast), `message_delivery_service` (delivered/read), `mention_search_service`, `org_connections_service` (super-admin grant/revoke).
- **Providers:** rooms list, active room messages (realtime), contacts (grouped), presence, typing, unread counts, org-connections.
- **UI (ml-styled):** rebuild `chat_screen` as the messaging surface — contacts sidebar (grouped, presence dots, blocked state), conversation view (date separators, unread separator, message bubbles with sender+reply-quote+mono time+delivered/read ticks), composer with @mention picker, blocked banner + "Message Mine-Link", group creation + members panel (per-company manage). Super-admin **Connections** panel (grant/revoke). All using `ml_*` components + tokens.
- Keep the existing floating/nav entry points; replace `communications_hub_screen` content with the new Messages surface.

## Build order (one task at a time, verify each)
1. Write + **get approval for** the migration SQL; apply to live DB; verify with introspection.
2. Models + repositories + `get_chat_contacts` wiring.
3. Contacts list (grouped, scoped) + rooms list.
4. Conversation view + message bubbles + composer (send/receive realtime).
5. @mentions, replies, delivered/read receipts, presence, typing.
6. Org-to-org groups + members panel; super-admin Connections panel; blocked banner + send-guard.
7. Reskin pass + full QA on second monitor across roles (buyer/mine/transporter/super-admin).

## Verification
Per step: `flutter analyze lib` clean + Windows build; live DB introspection for schema; drive the app on monitor 2 to exercise send/receive between two test accounts (e.g. buyer.owner ↔ minesupplier.owner once connected). Honest reporting of what's live-verified vs code-verified.

## Out of scope (this phase)
CPS support-ticket sub-feature (MineLink replaces it with company-scoping). Voice/video. Message edit/delete (messages immutable, per design).
