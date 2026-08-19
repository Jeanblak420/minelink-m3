# Release hardening — account deactivation, push, crash sink, pubspec

**Date:** 2026-08-19
**Status:** approved (Jean, 2026-08-19); **R-1 re-scoped from deletion to
deactivation by Jean's ruling the same day — see §1.1, which supersedes §1's
conclusion.**
**Scope:** four store-blocking / release-blocking items, tracked here as R-1 … R-4.

| id | item | why it blocks |
|---|---|---|
| R-1 | In-app account **deactivation** | See the ruling below. Originally scoped as deletion; Jean ruled on 2026-08-19 that nothing on this platform is ever deleted. |
| R-2 | Push notifications | `POST_NOTIFICATIONS` is declared with nothing behind it. Notifications reach a user only while the app is open — for driver dispatch on a logistics platform that is a product hole, and Play will ask why the permission is declared but unused. |
| R-3 | Crash reports leaving the device | `crash_reporter.dart` is a correct seam with no destination. On a shipped release there is still no way to see a crash. |
| R-4 | pubspec / SDK hygiene | `mockito` ships in the production binary; the description is Flutter's stub; the SDK constraint and CI are pinned to **beta**. |

---

## 1. The finding that shapes R-1

Read this before touching the deletion code. It is the reason the design is not
what "delete my account" usually means.

Every foreign key into `public.profiles` and `auth.users` was pulled from
production on 2026-08-19. Two clusters matter:

**Deleting the row destroys a company.**

| referencing | column | on delete |
|---|---|---|
| `companies` | `user_id` | **CASCADE** |
| `employees` | `user_id` | CASCADE |
| `notifications` | `user_id` | CASCADE |
| `chat_messages` | `sender_id` | CASCADE |

`auth.users → profiles` is itself CASCADE. So `auth.admin.deleteUser()` on a
company owner deletes their **entire company** and everything hanging off it.

**And it would not get that far, because these block it.**

`audit_logs.actor_user_id` · `companies.created_by` ·
`companies.last_token_generated_by` · `companies.company_admin_user_id` ·
`chat_room_companies.invited_by` · `chat_rooms.ended_by` ·
`organization_seats.occupied_by_user_id` · `platform_admin_settings.main_super_admin_user_id` ·
`seat_reassignment_log` (×3) · `serial_tokens` (×2) · `token_requests` (×2)
— all **NO ACTION**. Any one of them raises a foreign-key violation and the
delete fails.

So a naive hard delete either throws or detonates a company. There is no third
outcome.

**The rejected alternative, and why.** The delete could be made to work by
converting all eleven NO ACTION references to `SET NULL`. That buys a row
deletion at the price of `audit_logs.actor_user_id` going NULL — the
accountability trail on a platform whose whole job is establishing who weighed,
sealed, dispatched and received a load. POPIA does not ask for that; §14 expects
records required for commercial and legal purposes to be **retained**. Trading
the audit trail for a `DELETE` is worse under the same statute that motivates
the feature.

### 1.1 THE RULING THAT SUPERSEDES THIS — nothing is deleted (Jean, 2026-08-19)

Read this before §2. The FK analysis above still stands and is still the
reason the obvious thing is impossible — but the conclusion has changed.

> *"Accounts (company profiles) shouldn't be deletable really, only deactivate
> it, make it inactive."* — Jean, 2026-08-19

Asked whether that extended from companies to individual people, Jean chose
**deactivate-only for both**, with the store consequence stated in the question
he answered. So:

| | delete | deactivate |
|---|---|---|
| **A company** | never. No code path exists or will be built. | `super_admin_set_company_status(id, 'suspended')` — **already exists**, platform-admin gated, writes an audit log. Nothing new needed. |
| **A person** | never. | `deactivate_account` — sessions revoked, sign-in refused, `employees.status = 'inactive'`. **Fully reversible** by `reactivate_account`. |

**Nothing is scrubbed. No PII is destroyed. No credential is scrambled.** The
account becomes unusable and stays recoverable.

⚠️ **THIS DOES NOT SATISFY THE STORES, AND R-1 MUST NOT BE REPORTED AS CLOSING
THAT GAP.** Google Play's User Data policy is explicit that offering only
account deactivation does not meet the account-deletion requirement, and App
Store §5.1.1(v) reads the same way. This was the item's original justification.
Jean was shown that trade-off in the question and chose deactivation anyway,
which is his call to make — but the checklist must say the submission blocker
is still open, because a green marker here would be a false claim in the
document agents trust most.

**What this ruling removes from the build.** Deactivation destroys nothing, so:

- the **anonymisation scrub is not built** — no `finalise_account_deletion`, no
  writes to `auth.users` beyond the ban flag, no `auth.identities` delete;
- the **storage purge is not built**, and with it the entire
  `account-deletion` edge function. It existed for exactly one reason —
  `storage.protect_delete()` refuses `DELETE FROM storage.objects` in SQL — and
  with nothing to purge, that reason is gone;
- the **cron backstop becomes plain SQL**: it calls the RPC directly instead of
  a `pg_net` round trip to a function that no longer exists.

The §1 FK graph is kept in this document deliberately. If Play rejects the
submission and real deletion becomes necessary, that analysis is the expensive
part and it is already done — including the three production-verified schema
facts in §2.3 that a first draft got wrong.

---

## 2. R-1 — Account deactivation

### 2.1 Flow

Jean chose **request → super-admin review** over immediate self-service.

```
user taps Deactivate my account
  -> re-auth (password) + types DEACTIVATE
  -> request_account_deactivation(reason)      status = pending
  -> platform admins notified
       |
       |-- user changes mind: cancel_account_deactivation_request() -> cancelled
       |
       |-- admin: review_account_deactivation_request(id, true|false, note)
       |        approve -> approved            reject -> rejected (user told why)
       |
       `-- nobody acts for 30 days -> auto_apply_at passes
                                              |
  apply_due_account_deactivations_job()  (pg_cron, daily)
      picks up everything `approved`, and everything `pending` past auto_apply_at
        -> deactivate_account(user_id)     [plain SQL. no edge function.]
                                              status = deactivated

  ... and, at any later time, an admin can undo it:
  reactivate_account(user_id)                  status = reactivated
```

**Every step is reversible**, which is the whole point of the ruling in §1.1 and
the reason this flow is safe to automate at all.

**The 30-day auto-apply backstop.** A queue an admin can simply never action
leaves a user unable to leave. The backstop bounds it: review is an opportunity
to intervene, not a condition of the request being honoured. Under the
deletion design this mattered because it bounded an irreversible act; under
deactivation it is *safer still*, since anything auto-applied can be undone by
`reactivate_account` with no data lost. Approved by Jean, 2026-08-19.

### 2.2 Schema — `public.account_deactivation_requests`

| column | type | note |
|---|---|---|
| `id` | uuid pk | `gen_random_uuid()` |
| `user_id` | uuid | → `profiles(id) on delete cascade` |
| `requested_at` | timestamptz | `timezone('utc', now())` |
| `reason` | text | free text, optional, shown to the reviewer |
| `status` | text | check in `('pending','approved','rejected','cancelled','deactivated','reactivated')` |
| `reviewed_by` | uuid | → `profiles(id) on delete set null` |
| `reviewed_at` | timestamptz | |
| `review_note` | text | mandatory on reject — the user is told why |
| `auto_apply_at` | timestamptz | `requested_at + interval '30 days'` |
| `deactivated_at` | timestamptz | |
| `reactivated_at` | timestamptz | |
| `reactivated_by` | uuid | → `profiles(id) on delete set null` |

```sql
create unique index account_deactivation_requests_one_open
  on public.account_deactivation_requests (user_id)
  where status in ('pending', 'approved');
```

One open request per user, enforced in Postgres rather than by a client check.
Note `deactivated` is **not** in that index — a reactivated user must be able to
ask again later, and a permanently-occupied slot would prevent it.

`reactivated_at` / `reactivated_by` exist because the reversal is a first-class
event, not an absence. *Who* restored an account and *when* is exactly what an
audit asks about, and a status flipped back with no trace cannot answer it.

`auto_apply_at` is a TTL, not a business day — so it uses `now()`, not
`ml_today()`, and is exempt under §7.1 of CLAUDE.md. `tool/one_clock_check.py`
must agree; if it flags the column, the exemption goes in the tool, not a
`current_date` in the migration.

**RLS.** Table carries a SELECT grant only, no write grant and no write policy —
the same shape as `monthly_targets`. Every write goes through an RPC.
SELECT policy: `user_id = auth.uid() or public.is_platform_admin()`.

### 2.3 RPCs

All `security definer`, `set search_path = public, extensions, pg_temp`,
`revoke execute from public`, granted to `authenticated`.

> **On the `search_path`:** `extensions` is included as house style even though
> deactivation needs no `pgcrypto`. This repo has already shipped a bug from a
> narrow path — `20260516220000_fix_create_serial_token_pgcrypto.sql` exists
> because `create_serial_token` called `gen_random_bytes` unqualified and raised
> `42883`. Anything added to these functions later inherits the safe path.

**`request_account_deactivation(p_reason text) returns uuid`**

Guards, in order:

1. **Sole company owner → refuse, SQLSTATE `MLD01`.** If
   `exists (select 1 from companies where user_id = auth.uid())`, raise with
   *"You own {company}. Its account must be suspended by a platform admin, or
   ownership transferred, before yours can be deactivated."*

   The refusal now **names two routes instead of being a dead end**, which is
   the practical consequence of §1.1: a company is never deleted, but it *can*
   be suspended, and that path already exists.
2. **Open request already exists → refuse, `MLD02`.** Belt and braces with the
   unique index; the index is the real guarantee, the raise is the readable
   error.
3. Otherwise insert `pending`, and `create_notification_internal(...)` to every
   platform admin, `importance = 'high'`, `metadata = {'deactivation_request_id': …}`.

**Active trips do not block the request.** A driver mid-load who wants out
should not be told to finish the trip first — the request is harmless, and the
review step exists to catch this. The reviewer sees it as a blocker chip.

**`cancel_account_deactivation_request() returns void`** — own `pending`
request only; `approved` cannot be cancelled by the user (an admin has acted).

**`review_account_deactivation_request(p_id uuid, p_approve boolean, p_note text)`**
— `is_platform_admin()` only, else `42501`. Rejects require a non-empty
`p_note`. Notifies the requester either way. Writes an audit log row.

**`my_account_deactivation_request() returns jsonb`** — what the user's card
renders.

**`list_account_deactivation_requests(p_status text)`** — the console queue,
with `is_company_owner` and `active_trips` computed per row as blocker chips.

#### `deactivate_account(p_user_id uuid) returns jsonb`

The whole act. Callable by `is_platform_admin()` or the service role (the cron
backstop). **Everything it does is reversible, and nothing it does destroys
data.**

```sql
-- Revoke the live session so the change takes effect now, not at next token
-- expiry. NOTE the ::text cast: auth.refresh_tokens.user_id is `character
-- varying`, NOT uuid -- alone among the auth tables touched here, verified
-- against production 2026-08-19. `= v_uid` raises 42883.
delete from auth.refresh_tokens where user_id = v_uid::text;
delete from auth.sessions        where user_id = v_uid;

-- The sign-in refusal. GoTrue's own switch, and a single column to undo.
-- auth.identities is NOT touched, the password is NOT scrambled, and
-- deleted_at is NOT set -- those are deletion mechanics and this is not a
-- deletion (§1.1).
update auth.users set banned_until = 'infinity' where id = v_uid;

update public.employees set
  status     = 'inactive',
  updated_at = timezone('utc', now())
where user_id = v_uid;
```

**`profiles` is not modified at all.** Under the deletion design it was where
the PII scrub landed; with nothing scrubbed there is nothing to write, and the
`display_name` every historical trip, chat message and audit row renders
through must keep resolving to the real person. An account being inactive is a
fact about *access*, not about who the person was.

The active/inactive state is therefore derived from two places and one of them
is authoritative: `auth.users.banned_until` decides whether sign-in works, and
`employees.status` is what the company screens read. `deactivate_account`
writes both in one transaction so they cannot disagree.

#### `reactivate_account(p_user_id uuid) returns jsonb`

The exact inverse, `is_platform_admin()` only — never the service role, because
nothing should ever restore access automatically:

```sql
update auth.users set banned_until = null where id = v_uid;
update public.employees set status = 'active', updated_at = timezone('utc', now())
 where user_id = v_uid;
update public.account_deactivation_requests
   set status = 'reactivated', reactivated_at = timezone('utc', now()),
       reactivated_by = auth.uid()
 where user_id = p_user_id and status = 'deactivated';
```

**`banned_until = null`, not a past timestamp.** A past timestamp also permits
sign-in, but null is the value a never-banned account carries, so a reactivated
account becomes indistinguishable from one that was never touched. Anything
else leaves a residue that a future query filtering on `banned_until is not
null` would misread.

**Reactivation restores `employees.status` to `'active'` unconditionally.** It
does not attempt to restore a prior value, because the only status this flow
ever writes is `'inactive'` — and guessing at a pre-existing state nobody
recorded would be worse than a stated rule.

### 2.4 No edge function

The deletion design needed one for exactly one reason: Supabase's
`storage.protect_delete()` refuses `DELETE FROM storage.objects` in SQL
(`42501`, recorded in CLAUDE.md §6), so identity documents and the signature
PNG could not be purged from an RPC.

**Deactivation purges nothing, so that reason is gone and the function is not
built.** The `account-deletion` edge function is struck from the plan entirely.

### 2.5 The cron backstop

`apply_due_account_deactivations_job()` + a pg_cron entry, following the
`*_job()` shape already used by nine jobs on this project.

It selects requests that are `approved`, or `pending` with `auto_apply_at <=
now()`, and calls `deactivate_account(user_id)` **directly in SQL**. No
`pg_net`, no HTTP, no edge function, no service-role key to source — all of
which the deletion design needed and none of which survives §1.1. This also
removes the open question about whether `app.settings.service_role_key` is
configured on this project.

Each iteration is wrapped so an exception is logged as a `raise warning` and the
loop continues, and the run is bounded. Both are the same lessons already
recorded in CLAUDE.md: one stuck row must not freeze the nightly run for every
other (the `close_due_target_cycles_job` fault), and an unbounded nightly write
on this free-plan instance is the shape that took Postgres down for two hours on
2026-08-16.

### 2.6 UI

**User side** — a `DeactivateAccountCard`, added to both
`lib/features/profile/screens/account_security_screen.dart` and the portal
profile screen, so every role reaches it.

States: *none* (danger-toned card, "Deactivate my account") → confirm dialog
(what deactivation means, that it is reversible by an admin, the 30-day
disclosure, type `DEACTIVATE`, re-enter password) → *pending* (status,
requested date, "Cancel request") → *approved* (scheduled, no cancel) →
*rejected* (the admin's note).

**The copy must not say "delete".** A user who reads "delete" and gets
deactivation has been misled about what happened to their data, and that is a
worse disclosure failure than the one this feature set out to fix. The dialog
states plainly: sign-in is disabled, the account can be restored by an
administrator, and records of loads the user was part of are retained either
way.

Owner refusal (`MLD01`) is caught by SQLSTATE, not message text — the
`getErrorCode` precedent in `company-user-admin/index.ts` exists because
matching on wording breaks the moment the wording is edited.

**Admin side** — `/super-admin/account-deactivations`, mirroring
`token_requests_screen.dart`: same list/detail shape, same sidebar registration.
Each row shows requester, company, role, reason, days until auto-apply, and
blocker chips (company owner / active trip). Actions: Approve, Reject with a
note, and — on an already-`deactivated` row — **Reactivate**, which is the
control that makes the whole design honest.

All styling via `MlTokens` / `MlSemantic` / `MlTone`; the danger surface is
`MlTone.error`, the reactivate action `MlTone.done`.

## 3. R-2 — Push notifications

### 3.1 Schema — `public.device_tokens`

`id` · `user_id → profiles on delete cascade` · `token text not null unique` ·
`platform text check in ('android','ios','web')` · `app_version text` ·
`created_at` · `last_seen_at` · `disabled_at timestamptz`.

RLS: a user sees and manages only their own rows. Writes go through
`register_device_token(p_token, p_platform, p_app_version)` (upsert on `token`,
re-pointing `user_id` if the device changed hands — a shared depot tablet is a
real case, and a stale row would send one driver's dispatch to another) and
`unregister_device_token(p_token)`, called on sign-out.

Index on `(user_id) where disabled_at is null`.

**Retention.** Per CLAUDE.md §10.2 — *"when adding any high-frequency write path,
ship its retention job in the same migration"*. Tokens not seen in 180 days are
deleted by the same job that prunes crash reports (R-3), to avoid a tenth cron
entry for two `delete` statements.

### 3.2 Delivery

`AFTER INSERT` trigger on `public.notifications` → `pg_net` POST to the
`push-fanout` edge function, carrying the notification id.

**Trigger + `pg_net`, not an outbox drained by cron.** Cron's minimum useful
period is one minute, and the case this feature exists for is telling a driver a
load is ready. A minute of latency on dispatch is the difference between the
feature working and the feature being a slower version of the bell they already
have. `pg_net` is async and fire-and-forget, so the trigger cannot slow down or
fail a notification insert — which is the property that makes it safe to hang
off the write path at all.

`push-fanout`:

1. service-role read of the notification + the recipient's live tokens,
2. FCM **HTTP v1** send (`FCM_SERVICE_ACCOUNT` secret, OAuth2 from the service
   account — the legacy server key is retired and must not be used),
3. deep link carried as `data.route` / `data.nav_tab`, reusing the existing
   `metadata.nav_tab` convention the in-app notifications already use,
4. tokens FCM answers `UNREGISTERED` or `INVALID_ARGUMENT` are marked
   `disabled_at` — an unpruned token list degrades quietly until sends start
   failing in bulk.

### 3.3 Flutter

`firebase_core` + `firebase_messaging`. `lib/core/push/push_service.dart`:
permission request (Android 13+ `POST_NOTIFICATIONS`, iOS provisional→full),
token fetch, `onTokenRefresh` re-registration, foreground handler, background
handler (top-level entry point, as the plugin requires), and tap handling routed
through `go_router`.

**It must degrade, not crash, with no Firebase configured.** That is the state
of this repo today, of CI, and of Jean's machine until he creates the project.
`PushService.initialise()` catches and logs, exactly as `PlaceIndexConfig`
degrades when the extras project is paused (CLAUDE.md §6). The app must start
and behave identically without it.

**No placeholder `google-services.json` is committed.** A fake one does not
degrade — it breaks the Gradle plugin with an error that reads like a build bug,
and a placeholder that looks like a credential is exactly the class of thing
that once shipped a live ArcGIS token (pubspec.yaml, `config/` comment).
Instead the Gradle `apply` is conditional on the file existing.

### 3.4 What Jean must supply

Documented step-by-step in `docs/push-setup.md`:

| artifact | from | goes |
|---|---|---|
| `google-services.json` | Firebase console → Android app | `android/app/` (gitignored) |
| `GoogleService-Info.plist` | Firebase console → iOS app | `ios/Runner/` (gitignored) |
| APNs auth key `.p8` | Apple Developer → Keys | uploaded into Firebase, not into this repo |
| `FCM_SERVICE_ACCOUNT` | Firebase → service accounts → generate key | `supabase secrets set` |
| `FCM_VAPID_KEY` | Firebase → Cloud Messaging → Web Push certs | `--dart-define`, web only |

Web push is wired but skipped when `FCM_VAPID_KEY` is absent.

---

## 4. R-3 — Crash reports

### 4.1 Schema — `public.crash_reports`

`id` · `user_id → profiles on delete set null` · `at timestamptz` ·
`platform text` · `app_version text` · `error text` · `stack text` ·
`context text` · `fatal boolean` · `created_at`.

`user_id` is **SET NULL**, not CASCADE: an account deletion (R-1) should
de-identify a crash report, not destroy the engineering record of the crash.
This is the one place the two features touch.

RLS: INSERT `with check (user_id = auth.uid() or user_id is null)` for
`authenticated` — a crash during bootstrap has no session yet, and losing
precisely the crashes that happen before sign-in would be the worst possible
gap. SELECT `is_platform_admin()` only. No UPDATE, no DELETE policy.

`stack` is truncated to 16 kB and `error` to 4 kB at the sink, before it leaves
the device. Main is a 500 MB free-plan project (CLAUDE.md §10.2) and an error
loop can generate reports faster than anyone reads them.

**Retention: 90 days**, in the same migration, via
`prune_telemetry_job()` (also handling `device_tokens`, §3.1).

### 4.2 `SupabaseReportingSink`

Implements the existing `ReportingSink`. Behaviour:

- keeps the in-memory ring buffer (it is what a support conversation reads
  today, and nothing about adding a destination makes it less useful),
- enqueues and posts asynchronously; a crash report must never block a frame,
- **buffers when offline and drains on the next successful report** — the
  crashes worth seeing are disproportionately the ones on a truck with no
  signal,
- **never reports its own failures.** A sink that reports a sink failure is an
  unbounded loop that will take the app down harder than the original bug. Sink
  errors go to `debugPrint` and nowhere else. This mirrors the deliberate empty
  catch already documented in `CrashReporter.recordError`.
- caps the pending queue (50) and drops oldest-first — an error storm must
  degrade, not exhaust memory.

`app_version` from `package_info_plus` (new dependency); `platform` from
`defaultTargetPlatform` + `kIsWeb`.

Wired in `main()` as one line, after Supabase init, replacing the default sink.
`installCrashHandlers()` still runs first — telemetry that needs a database to
be up cannot be the thing that catches the database failing to come up, so the
`LoggingReportingSink` remains the boot-time sink and is swapped, not replaced.

### 4.3 Reader

`/super-admin/crash-reports` — list by recency, fatal-first filter, expandable
stack, platform/version facets. Console shell registration as for
`/super-admin/account-deletions`.

---

## 5. R-4 — pubspec and SDK

```diff
-description: "A new Flutter project."
+description: "MineLink — mineral logistics and bulk-commodity haulage operations platform."

 environment:
-  sdk: ^3.8.0-278.1.beta
+  sdk: ^3.8.0

 dependencies:
-  mockito: ^5.4.4
+  firebase_core: ^3.8.0
+  firebase_messaging: ^15.1.5
+  package_info_plus: ^8.1.1

 dev_dependencies:
+  mockito: ^5.4.4
```

```diff
# .github/workflows/release-guards.yml
       - uses: subosito/flutter-action@v2
         with:
-          channel: beta
+          channel: stable
```

`mockito` moving is not cosmetic: a mocking library in `dependencies` is
tree-shaken only by luck and is a supply-chain surface in a consumer binary.

The SDK change **records reality rather than altering it** — Jean's machine is
on stable 3.44.8 / Dart 3.12.2, which already satisfies both the old and new
constraints. Dropping the `-278.1.beta` prerelease marker means a 3.8.0 *beta*
SDK no longer satisfies the constraint, while every stable ≥ 3.8.0 still does.

Package versions above are the intent; the actual resolved versions come from
`flutter pub get` against the current stable and are pinned to whatever resolves.

**Two new guards** in `tool/release_guards.dart`, each with the planted
violation `--selftest` requires:

| id | pattern over | catches |
|---|---|---|
| `mockito-not-in-dependencies` | `pubspec.yaml` | `mockito` reappearing above `dev_dependencies` |
| `no-prerelease-sdk-constraint` | `pubspec.yaml` | an `sdk:` constraint containing `-` (any prerelease marker) |

Both `Mode.block`. Neither pattern contains `\s`, so neither needs `spanLines`
(see the 2026-08-16 note in that file on why that question must be asked).

---

## 6. Verification, and what is explicitly not proven

Nothing here is reported as done on the strength of it compiling.

| what | how |
|---|---|
| Guards still bite | `dart run tool/release_guards.dart --selftest`, then the real scan |
| Analyzer | `flutter analyze` clean |
| Suite | `flutter test` — full, not a subset; current baseline 1125 |
| Layout | New cards and both console screens rendered with **real fonts** (`_loadRealFonts()`) across width × textScale 0.85–1.3, asserting geometry, not just absence of overflow (CLAUDE.md §7, §10.4, §10.5) |
| Migrations vs ledger | `python tool/migration_ledger_check.py` — exit 2 is *not* a pass |
| Cold replay | `python tool/cold_replay.py` — the new migrations must apply into an empty project. §6 is emphatic that this is the only thing that tests them |
| One clock | `python tool/one_clock_check.py` |
| RLS | Each new policy exercised as a real signed-in user of the wrong role, not asserted from the policy text |
| Deactivation cycle | Driven end-to-end against a **purpose-made throwaway account** inside a rolled-back transaction: request → approve → deactivate → **reactivate**, asserting `banned_until` and `employees.status` at each step and that reactivate returns `banned_until` to **null**, not a past timestamp |

**Not proven, and to be reported as such:**

- **Push end-to-end.** No Firebase project exists. The DB half, the trigger, the
  edge function and the Dart half are testable; an actual FCM delivery to a
  handset is not, until the credentials in §3.4 exist. Reported as 🟡.
- **iOS anything.** No Apple Developer account is reachable from here.
- `lock`-style irreversible admin actions are not clicked on production for the
  sake of a screenshot — the precedent set by `lock_target_cycle` in CLAUDE.md.

### Follow-ups this creates (not in scope, but owed)

1. 🚨 **The store blocker is still open.** R-1 as built is deactivation, and
   Play's User Data policy does not accept deactivation in place of deletion
   (§1.1). Before a Play or App Store submission, either the scrub is built —
   §1 and §2.3's verified schema facts are the expensive half and are already
   done — or the submission is expected to be rejected on this point. **Do not
   let a later reader infer from a green R-1 that this is handled.**
2. **The privacy policy must describe deactivation accurately.** The three
   documents in `assets/legal/` are still `*.placeholder.md` with draft banners.
   They must not promise deletion, because the product does not do it.
3. **`employees.status = 'inactive'`** — confirm no existing query treats
   anything other than `'active'` as dismissed-and-gone, and check
   `tool/notification_vocabulary_check.py`.
4. **Ownership transfer has no UI.** `MLD01` now names two routes — company
   suspension (which exists, admin-gated) or ownership transfer (which does
   not). Acceptable for v1 because the first route is real, but the second is
   still a gap.
5. **Nothing reactivates automatically, by design.** `reactivate_account` is
   `is_platform_admin()` only and the cron job never calls it. If a
   self-service "come back" flow is ever wanted, it needs its own decision —
   restoring access is not the inverse risk of removing it.

---

## 7. Migration inventory

Per CLAUDE.md §6 rule 1 — one file per applied migration, named for what it did,
stamp repointed in its own call after apply, then verified.

| stamp | file | contents |
|---|---|---|
| `20260819090000` | `device_tokens.sql` | table, RLS, register/unregister, notifications trigger + `pg_net` fan-out |
| `20260819100000` | `account_deactivation_requests.sql` | table, index, RLS, request/cancel/read RPCs, `MLD01`/`MLD02` |
| `20260819110000` | `account_deactivation_apply.sql` | review, `deactivate_account`, `reactivate_account`, console list RPC |
| `20260819120000` | `account_deactivation_apply_job.sql` | `apply_due_account_deactivations_job()` + pg_cron entry |
| `20260819140000` | `crash_reports.sql` | table, RLS |
| `20260819150000` | `prune_telemetry_job.sql` | crash-report + device-token retention, pg_cron entry |

**`device_tokens` is stamped `090000`, ahead of the account-deactivation set.**
`deactivate_account` does not touch it — deactivation deletes nothing — but the
push fan-out trigger and the deactivation flow both read `profiles`, and keeping
the stamp order equal to the apply order removes a class of cold-replay
ordering surprise for nothing. There is no `130000`; the gap is deliberate and
marks where the struck `account-deletion` work would have sat.

Each must survive `cold_replay.py`. `pg_cron` and `pg_net` are created by the
canonical reset as of the 2026-08-17 fix, and `pgcrypto` has been created there
`with schema extensions` since the reset was written (line 3) — so the cron and
`extensions.gen_salt` calls have their extensions on a cold build. The replay is
what proves that, not this sentence.
