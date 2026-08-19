# Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close three of the four release blockers — in-app account **deactivation**, push notifications, and a crash-report destination — plus pubspec/SDK hygiene. R-1 no longer closes the store gap; see the banner below.

**Architecture:** Account deactivation is a *request → super-admin review → apply* pipeline that **destroys nothing**: sessions are revoked, `auth.users.banned_until` refuses sign-in, `employees.status` goes `inactive`, and `reactivate_account` undoes all of it. Push is a trigger on `notifications` firing `pg_net` at an edge function that talks FCM HTTP v1, built code-complete but inert until Firebase credentials exist. The crash sink is one new implementation of the existing `ReportingSink` seam writing to a `crash_reports` table.

**Tech Stack:** Flutter 3.44 stable / Dart 3.12, Riverpod, go_router, Supabase (Postgres 17.6 + RLS + `pg_cron` + `pg_net` + Deno edge functions), FCM HTTP v1.

**Spec:** `docs/superpowers/specs/2026-08-19-release-hardening-design.md` — read it before Task 1. **Read §1.1 first — it supersedes §1's conclusion.** §1 explains why a hard delete is impossible here; §1.1 is Jean's ruling that nothing is deleted at all. Both are load-bearing and neither is repeated in full here.

---

## Global Constraints

Every task's requirements implicitly include this section.

- **Package name is `flutter_application_1`.** All imports are `package:flutter_application_1/...`. Never rename.
- **Design tokens are law.** No raw `Color(0x...)` or magic numbers in feature code — `MlTokens`, `MlSemantic`, `MlTone` only. Danger surfaces use `MlTone.error`.
- **All DB access goes through a feature `service` or a `core` repository.** Screens and providers never call `SupabaseConfig.client` directly.
- **`SupabaseConfig.client` is the MAIN project** (`yftazblpmicqtamyiwyb`). Nothing in this plan touches the extras project. The Supabase MCP tools only ever reach main — which is what we want here.
- **There is no staging.** Every migration lands on live data. Apply small, verify, and never overlap bulk work.
- **Migrations: one file per applied migration** (CLAUDE.md §6 rule 1). After `apply_migration`, repoint the ledger stamp **in its own separate call** — never in a batch containing a self-rolling-back probe (rule 5) — then verify with the two commands in rule 5.
- **`pgcrypto` lives in the `extensions` schema.** Always schema-qualify: `extensions.crypt`, `extensions.gen_salt`. Precedent: `20260516220000_fix_create_serial_token_pgcrypto.sql`.
- **`auth.refresh_tokens.user_id` is `character varying`,** not uuid. Cast: `where user_id = v_uid::text`.
- **One clock:** `public.ml_today()` / `ml_day()` for anything a user reads as a business day. Never `current_date`. Row-stamping timestamps and TTLs are exempt (`timezone('utc', now())` is correct for those).
- **Bitwise operators are unsigned 32-bit under dart2js.** Use arithmetic (`+ * % ~/`) wherever a value can be negative or exceed 32 bits.
- **Layout tests must call `loadRealFonts()`** from `test/test_helpers/real_fonts.dart` before asserting geometry, and sweep textScale 0.85–1.3.
- 🚨 **A sweep that only renders an EMPTY state proves nothing, and `takeException() == null` passes on a screen that rendered nothing at all.** Found in Task 4's review, and the fault was in this plan's own test template. Every UI task here must, in addition to the empty case:
  - render a **populated** fixture across the same width × textScale matrix;
  - make the fixture **hostile** — an unbroken 300-character token with no spaces is what actually overflows a `Row`, where a long sentence just wraps; include null-valued optional fields and the longest realistic enum/label text;
  - **assert content is present** (`find.text`, `find.byType`) so the test cannot pass on a blank screen;
  - **assert geometry, not just absence of overflow**, wherever alignment or containment is the property that matters. `expect(tester.getRect(find.byX).right, closeTo(width, 1))` is what caught two real bugs in this repo that an overflow sweep never would (CLAUDE.md §10.4).
- **Logging is `LoggerFactory.getLogger('Scope')`,** never `print`.
- **Commit after every task.** Multiple agent sessions write this worktree (CLAUDE.md §10.1) — never `git stash`, `git checkout -- .`, `git clean`, or switch branches. Work stays on `chore/release-v1-hardening`.

### Exact identifiers this plan defines

Later tasks depend on these names being exactly right.

| kind | identifier |
|---|---|
| table | `public.account_deactivation_requests`, `public.device_tokens`, `public.crash_reports` |
| rpc | `request_account_deactivation(p_reason text) returns uuid` |
| rpc | `cancel_account_deactivation_request() returns void` |
| rpc | `my_account_deactivation_request() returns jsonb` |
| rpc | `review_account_deactivation_request(p_id uuid, p_approve boolean, p_note text) returns void` |
| rpc | `deactivate_account(p_user_id uuid) returns jsonb` |
| rpc | `reactivate_account(p_user_id uuid) returns jsonb` |
| rpc | `list_account_deactivation_requests(p_status text) returns table(...)` |
| rpc | `register_device_token(p_token text, p_platform text, p_app_version text) returns uuid` |
| rpc | `unregister_device_token(p_token text) returns void` |
| job | `apply_due_account_deactivations_job() returns int` |
| job | `prune_telemetry_job(p_crash_keep_days int default 90, p_token_idle_days int default 180) returns int` |
| sqlstate | `MLD01` sole company owner · `MLD02` open request exists |
| edge fn | `push-fanout` — **only one.** The `account-deletion` function is struck (spec §2.4) |
| dart | `AccountDeactivationService`, `DeactivateAccountCard`, `SupabaseReportingSink`, `PushService`, `DeviceTokenRepository` |
| route | `/super-admin/account-deactivations`, `/super-admin/crash-reports` |

### 🚨 R-1 is deactivation, not deletion

Jean ruled on 2026-08-19, mid-planning, that **nothing on this platform is ever
deleted** — companies or people. Spec §1.1 is the authority and supersedes §1's
conclusion.

- **Nothing is scrubbed.** No PII is nulled, no credential scrambled, no
  `auth.identities` row deleted, and `public.profiles` is not modified at all.
  If a task has you writing an `UPDATE` that nulls a personal-data column, that
  is the struck design — stop and re-read §1.1.
- **Everything is reversible** via `reactivate_account`.
- **This does not satisfy Google Play**, and Task 13 requires that be recorded
  honestly rather than papered over.

---

## File Structure

**Created**

```
supabase/migrations/
  20260819090000_device_tokens.sql                    table, RLS, register/unregister, fan-out trigger
  20260819100000_account_deactivation_requests.sql    table, RLS, request/cancel/read RPCs
  20260819110000_account_deactivation_apply.sql       review + deactivate + reactivate + list
  20260819120000_account_deactivation_apply_job.sql   cron backstop (plain SQL, no pg_net)
  20260819140000_crash_reports.sql                    table, RLS
  20260819150000_prune_telemetry_job.sql              retention for the two above
supabase/functions/push-fanout/index.ts               FCM HTTP v1 send
lib/core/telemetry/supabase_reporting_sink.dart       ReportingSink -> crash_reports
lib/core/push/push_service.dart                       permission, token, handlers, deep link
lib/core/push/device_token_repository.dart            register/unregister
lib/features/profile/services/account_deactivation_service.dart
lib/features/profile/models/account_deactivation_request.dart
lib/features/profile/widgets/deactivate_account_card.dart
lib/features/super_admin/screens/account_deactivations_screen.dart
lib/features/super_admin/screens/crash_reports_screen.dart
docs/push-setup.md                                    what Jean must supply
test/... (per task)
```

There is no `20260819130000`. The gap is deliberate and marks where the struck
`account-deletion` edge function and its migration would have sat (spec §2.4).
`device_tokens` moves to `090000` so stamp order equals apply order.

**Modified**

```
pubspec.yaml                                  deps, description, sdk
.github/workflows/release-guards.yml          channel: stable
tool/release_guards.dart                      two new guards
lib/main.dart                                 sink swap, PushService.initialise()
lib/features/profile/screens/account_security_screen.dart   + DeactivateAccountCard
lib/features/profile/screens/profile_screen.dart            + DeactivateAccountCard
lib/core/routing/app_router.dart                            two routes
lib/features/super_admin/widgets/sidebar/console_sidebar_bridge.dart
lib/features/super_admin/widgets/super_admin_shell_layout.dart
android/app/build.gradle.kts                  conditional google-services apply
android/app/src/main/AndroidManifest.xml      FCM default channel meta-data
ios/Runner/AppDelegate.swift, ios/Runner/Info.plist
.gitignore                                    google-services.json, GoogleService-Info.plist
```

---

## Task 1: pubspec and SDK hygiene, with guards

Smallest task, done first: it changes the dependency set every later task builds against.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `.github/workflows/release-guards.yml`
- Modify: `tool/release_guards.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `firebase_core`, `firebase_messaging`, `package_info_plus` available to Tasks 6, 10, 11. `mockito` available to tests only.

- [ ] **Step 1: Add the two guards, so they fail before the fix**

In `tool/release_guards.dart`, append to the `guards` list (before its closing `];`):

```dart
  Guard(
    id: 'mockito-not-in-dependencies',
    why: 'mockito in `dependencies` ships a mocking library inside the '
        'consumer binary. It is tree-shaken only by luck, and it is a '
        'supply-chain surface in a released app. It belongs in '
        '`dev_dependencies` (R-4).',
    mode: Mode.block,
    roots: ['pubspec.yaml'],
    // Anchored to column 2 so it matches a top-level `dependencies:` entry.
    // `dev_dependencies` entries sit at the same indent, so the scanner alone
    // cannot tell them apart — see the selftest note below.
    pattern: RegExp(r'^  mockito:'),
    plantFile: 'pubspec.yaml',
    plantLine: '  mockito: ^5.4.4',
  ),
  Guard(
    id: 'no-prerelease-sdk-constraint',
    why: 'An sdk constraint carrying a prerelease marker (-beta, -dev) means '
        'the app is built against a non-stable Dart. Shipping a consumer '
        'release off the beta channel is a real risk (R-4).',
    mode: Mode.block,
    roots: ['pubspec.yaml'],
    pattern: RegExp(r'^\s*sdk:\s*\^?[0-9.]+-'),
    plantFile: 'pubspec.yaml',
    plantLine: '  sdk: ^3.8.0-278.1.beta',
  ),
```

> **Note on `mockito-not-in-dependencies`:** the pattern matches `  mockito:` anywhere in the file, including under `dev_dependencies`. That is intentional and is why Step 3 moves mockito to a **three-space-deep block or a different anchor** — see Step 3. Do not "fix" this by making the pattern smarter with `\s`; the 2026-08-16 note in that file explains why a pattern containing `\s` that can meet a newline is how a guard goes blind.

- [ ] **Step 2: Run the guard to verify it fails on the current tree**

```bash
dart run tool/release_guards.dart
```

Expected: **FAIL** — both `mockito-not-in-dependencies` and `no-prerelease-sdk-constraint` report a hit in `pubspec.yaml`.

- [ ] **Step 3: Apply the pubspec fix**

In `pubspec.yaml`:

```yaml
description: "MineLink — mineral logistics and bulk-commodity haulage operations platform."
```

```yaml
environment:
  sdk: ^3.8.0
```

Delete the `  mockito: ^5.4.4` line from `dependencies`. Add to `dependencies`, after `flutter_map_marker_cluster`:

```yaml
  # Push notifications (R-2). Inert until android/app/google-services.json and
  # ios/Runner/GoogleService-Info.plist exist — PushService degrades to a
  # logged no-op, exactly as PlaceIndexConfig does for a paused extras project.
  firebase_core: ^3.8.0
  firebase_messaging: ^15.1.5
  # app_version on a crash report (R-3). Without it a stack trace cannot be
  # tied to a build, which is most of what makes one actionable.
  package_info_plus: ^8.1.1
```

Add to `dev_dependencies`, indented **four** spaces under a comment so the guard's two-space anchor does not match it:

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  build_runner: ^2.4.8
  # Test-only. It was in `dependencies` until R-4 and shipped in the release
  # binary. The `mockito-not-in-dependencies` guard anchors on a two-space
  # indent, so this entry is nested under `mockito:` deliberately — see
  # tool/release_guards.dart.
  mockito:
    version: ^5.4.4
```

> If `mockito:` with a nested `version:` key fails `flutter pub get`, fall back to a plain `  mockito: ^5.4.4` here and instead narrow the guard to match only within the `dependencies:` block by setting `spanLines: true` with a pattern of `RegExp(r'^dependencies:[\s\S]*?^  mockito:', multiLine: true)` — **and add the required `plantWrapped`**, because `spanLines` without it makes the selftest prove nothing (the 2026-08-16 lesson in that file).

- [ ] **Step 4: Set CI to stable**

In `.github/workflows/release-guards.yml`:

```yaml
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
```

- [ ] **Step 5: Resolve and verify**

```bash
flutter pub get
dart run tool/release_guards.dart --selftest
dart run tool/release_guards.dart
flutter analyze
flutter test
```

Expected: `pub get` resolves (record the actual resolved firebase versions and pin them if they differ from the caret ranges above); selftest reports **BITES** for both new guards; the real scan is **PASS**; analyze clean; the full suite green at its current baseline. If any test breaks, it is a real regression from the SDK constraint change — fix it, do not skip it.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock .github/workflows/release-guards.yml tool/release_guards.dart
git commit -m "chore(deps): mockito out of the release binary, off the beta channel

mockito was in `dependencies`, so a mocking library shipped inside the
consumer app. The SDK constraint carried a prerelease marker and CI
pinned channel: beta, while Jean's own machine has been on stable
3.44.8 / Dart 3.12.2 all along — so the beta pin recorded nothing real
and only widened what could land.

Both are now held by guards with planted violations, because a hygiene
fix nobody enforces is a hygiene fix that regresses.

Adds firebase_core/firebase_messaging (R-2) and package_info_plus (R-3)."
```

---

## Task 2: `crash_reports` table

**Files:**
- Create: `supabase/migrations/20260819140000_crash_reports.sql`

**Interfaces:**
- Consumes: nothing.
- Produces: table `public.crash_reports` with columns `id, user_id, at, platform, app_version, error, stack, context, fatal, created_at`. Task 3 inserts into it; Task 4 reads it; Task 12 prunes it.

- [ ] **Step 1: Probe that the table does not exist**

Run via Supabase MCP `execute_sql`:

```sql
select to_regclass('public.crash_reports') as exists_yet;
```

Expected: `null`.

- [ ] **Step 2: Write the migration file**

Create `supabase/migrations/20260819140000_crash_reports.sql`:

```sql
-- Crash reports had nowhere to go.
--
-- `lib/core/telemetry/crash_reporter.dart` has been a correct seam since S9-1:
-- FlutterError.onError, PlatformDispatcher.onError, runZonedGuarded and
-- ErrorWidget.builder all route into a ReportingSink. But the only sink kept
-- 50 reports in memory on the device, so on a shipped release there was still
-- no way for anyone to see a crash. Picking the destination was the open ASK;
-- Jean chose a table on this project over a third-party vendor (2026-08-19).
--
-- WHY user_id IS `on delete set null`, NOT CASCADE
-- ------------------------------------------------
-- Account deletion (R-1) must de-identify a crash report, not destroy the
-- engineering record of the crash. This is the one column where the two
-- features touch, and getting it wrong means every bug report from a user who
-- later leaves disappears with them.

create table if not exists public.crash_reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles(id) on delete set null,
  at          timestamptz not null,
  platform    text,
  app_version text,
  error       text not null,
  stack       text,
  context     text,
  fatal       boolean not null default false,
  created_at  timestamptz not null default timezone('utc', now())
);

comment on table public.crash_reports is
  'Uncaught and handled errors shipped off-device by SupabaseReportingSink. '
  'user_id is SET NULL rather than CASCADE so an account deletion (R-1) '
  'de-identifies a report instead of destroying it. Pruned at 90 days by '
  'prune_telemetry_job(). error/stack are truncated client-side (4 kB / 16 kB) '
  'because this is a 500 MB free-plan project and an error loop can generate '
  'reports faster than anyone reads them.';

create index if not exists crash_reports_recent_idx
  on public.crash_reports (created_at desc);
create index if not exists crash_reports_fatal_idx
  on public.crash_reports (created_at desc) where fatal;

alter table public.crash_reports enable row level security;

-- INSERT allows user_id IS NULL on purpose. A crash during bootstrap happens
-- before there is a session, and losing precisely the crashes that occur
-- before sign-in would be the worst possible gap in a crash reporter.
drop policy if exists crash_reports_insert_own on public.crash_reports;
create policy crash_reports_insert_own on public.crash_reports
  for insert to authenticated
  with check (user_id = auth.uid() or user_id is null);

drop policy if exists crash_reports_select_platform_admin on public.crash_reports;
create policy crash_reports_select_platform_admin on public.crash_reports
  for select to authenticated
  using (public.is_platform_admin());

-- No UPDATE and no DELETE policy: a crash report is not editable, and it is
-- removed only by prune_telemetry_job(), which is SECURITY DEFINER.
grant select, insert on public.crash_reports to authenticated;
```

- [ ] **Step 3: Apply it**

Apply via Supabase MCP `apply_migration` with name `crash_reports`.

- [ ] **Step 4: Repoint the ledger stamp — IN ITS OWN CALL**

A separate `execute_sql` call. **Nothing else may be in this batch** (CLAUDE.md §6 rule 5 — a self-rolling-back probe in the same batch silently undoes the repoint):

```sql
update supabase_migrations.schema_migrations
set version = '20260819140000' where name = 'crash_reports';
```

- [ ] **Step 5: Verify the stamp and the RLS**

```sql
select version, name from supabase_migrations.schema_migrations
 where version >= '20260819100000' order by version;
```

Expected: one row, `20260819140000 | crash_reports`.

Then prove the read boundary holds for a non-admin. Run as a role that is not a platform admin:

```sql
-- Expect 0 rows for a non-admin even with a row present.
set local role authenticated;
select count(*) from public.crash_reports;
reset role;
```

- [ ] **Step 6: Run the ledger check**

```bash
python tool/migration_ledger_check.py
```

Expected: exit 0. **Exit 2 is "could not check", not a pass** — if you get it, supply `ML_LEDGER_PASSWORD` and re-run.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/20260819140000_crash_reports.sql
git commit -m "feat(telemetry): crash_reports table, so a crash can leave the device

The ReportingSink seam has been correct since S9-1 and had no
destination. user_id is ON DELETE SET NULL, not CASCADE: an account
deletion must de-identify a crash report, not destroy the engineering
record of the crash.

INSERT permits user_id IS NULL because a bootstrap crash has no session
yet, and those are the ones worth having."
```

---

## Task 3: `SupabaseReportingSink`

**Files:**
- Create: `lib/core/telemetry/supabase_reporting_sink.dart`
- Modify: `lib/main.dart`
- Test: `test/core/supabase_reporting_sink_test.dart`

**Interfaces:**
- Consumes: `public.crash_reports` (Task 2); `ReportingSink`, `CrashReport`, `crashReporter` from `lib/core/telemetry/crash_reporter.dart`.
- Produces: `class SupabaseReportingSink implements ReportingSink` with constructor `SupabaseReportingSink({required Future<void> Function(List<Map<String, dynamic>>) postBatch, int queueLimit = 50})` and methods `void report(CrashReport)`, `Future<void> flush()`, `int get pendingCount`.

The `postBatch` injection point is what makes this testable without a live database — the test supplies a function that records or throws.

- [ ] **Step 1: Write the failing test**

Create `test/core/supabase_reporting_sink_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';
import 'package:flutter_application_1/core/telemetry/supabase_reporting_sink.dart';

CrashReport _r(String message, {bool fatal = false}) => CrashReport(
      error: message,
      stack: StackTrace.current,
      at: DateTime.utc(2026, 8, 19, 12),
      fatal: fatal,
    );

void main() {
  test('posts a reported crash', () async {
    final sent = <Map<String, dynamic>>[];
    final sink = SupabaseReportingSink(
      postBatch: (rows) async => sent.addAll(rows),
    );

    sink.report(_r('boom', fatal: true));
    await sink.flush();

    expect(sent, hasLength(1));
    expect(sent.single['error'], 'boom');
    expect(sent.single['fatal'], isTrue);
    expect(sent.single['at'], '2026-08-19T12:00:00.000Z');
  });

  test('a failing destination does not throw into the caller', () async {
    final sink = SupabaseReportingSink(
      postBatch: (_) async => throw StateError('offline'),
    );

    // report() is what a crash handler calls. If it can throw, it converts a
    // handled error into an uncaught one inside the handler meant to contain
    // it — the exact failure CrashReporter.recordError already guards against.
    expect(() => sink.report(_r('boom')), returnsNormally);
    await expectLater(sink.flush(), completes);
  });

  test('buffers while the destination is down and drains when it recovers',
      () async {
    var fail = true;
    final sent = <Map<String, dynamic>>[];
    final sink = SupabaseReportingSink(postBatch: (rows) async {
      if (fail) throw StateError('offline');
      sent.addAll(rows);
    });

    sink.report(_r('first'));
    sink.report(_r('second'));
    await sink.flush();
    expect(sent, isEmpty, reason: 'destination was down');
    expect(sink.pendingCount, 2, reason: 'nothing may be dropped while down');

    fail = false;
    await sink.flush();
    expect(sent.map((r) => r['error']), ['first', 'second']);
    expect(sink.pendingCount, 0);
  });

  test('an error storm drops oldest-first rather than exhausting memory',
      () async {
    final sink = SupabaseReportingSink(
      postBatch: (_) async => throw StateError('offline'),
      queueLimit: 3,
    );

    for (var i = 0; i < 10; i++) {
      sink.report(_r('e$i'));
    }
    await sink.flush();

    expect(sink.pendingCount, 3);
    expect(sink.pending.map((r) => r['error']), ['e7', 'e8', 'e9']);
  });

  // ── Required by controller Ruling 8 (2026-08-19) ──────────────────────────
  // crash_reports' INSERT policy is `to authenticated`. A genuine pre-auth
  // crash (splash, /login, before any session) runs as the `anon` Postgres
  // role and is REFUSED by RLS. An anon INSERT policy was considered and
  // deliberately rejected: the publishable key ships in every web bundle and
  // APK, so that would be an unauthenticated unmetered write endpoint into a
  // 500 MB free-plan database with a documented outage history.
  //
  // The sink is therefore what covers bootstrap crashes: it must HOLD them
  // and deliver them once the user signs in. That is not a happy accident of
  // the offline buffer -- it is the mitigation, so it gets its own test.
  test('holds a pre-auth crash and delivers it after sign-in', () async {
    var signedIn = false;
    final sent = <Map<String, dynamic>>[];
    final sink = SupabaseReportingSink(postBatch: (rows) async {
      // Stand-in for the RLS refusal an unauthenticated insert really gets.
      if (!signedIn) throw StateError('42501: new row violates row-level security');
      sent.addAll(rows);
    });

    sink.report(_r('crashed on the splash screen'));
    await sink.flush();
    expect(sent, isEmpty);
    expect(sink.pendingCount, 1, reason: 'a bootstrap crash must not be dropped');

    signedIn = true;
    await sink.flush();
    expect(sent.single['error'], 'crashed on the splash screen');
    expect(sink.pendingCount, 0);
  });

  test('truncates oversized payloads before they leave the device', () async {
    final sent = <Map<String, dynamic>>[];
    final sink = SupabaseReportingSink(postBatch: (rows) async => sent.addAll(rows));

    sink.report(CrashReport(
      error: 'x' * 10000,
      stack: StackTrace.fromString('y' * 40000),
      at: DateTime.utc(2026, 8, 19),
    ));
    await sink.flush();

    expect((sent.single['error'] as String).length, lessThanOrEqualTo(4096));
    expect((sent.single['stack'] as String).length, lessThanOrEqualTo(16384));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/core/supabase_reporting_sink_test.dart
```

Expected: FAIL — `supabase_reporting_sink.dart` does not exist.

- [ ] **Step 3: Implement the sink**

Create `lib/core/telemetry/supabase_reporting_sink.dart`:

```dart
/// Ships crash reports to `public.crash_reports` on the main Supabase project.
///
/// This is the one file that names a destination. [ReportingSink] is the whole
/// vendor surface (see `crash_reporter.dart`), and adopting a different one
/// means writing another implementation of it and changing one line in
/// `main()`. Nothing else in the app refers to a destination.
///
/// ## The three properties that matter more than delivery
///
/// 1. **[report] cannot throw.** It is called from inside crash handlers. A
///    sink that throws converts a handled error into an uncaught one inside
///    the handler meant to contain it.
/// 2. **A sink failure is never itself reported.** That is an unbounded loop
///    which takes the app down harder than the bug that started it. Sink
///    errors go to `debugPrint` and nowhere else — the same deliberate silence
///    as `CrashReporter.recordError`.
/// 3. **It buffers offline and drains on recovery.** The crashes worth seeing
///    are disproportionately the ones on a truck with no signal.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';

/// Caps, applied before anything leaves the device.
///
/// Main is a 500 MB free-plan project and an error loop can generate reports
/// faster than anyone reads them. A truncated stack is still actionable; an
/// exhausted database is not.
const int _maxErrorChars = 4096;
const int _maxStackChars = 16384;

String _clip(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 3)}...';

class SupabaseReportingSink implements ReportingSink {
  SupabaseReportingSink({
    Future<void> Function(List<Map<String, dynamic>> rows)? postBatch,
    this.queueLimit = 50,
    String? appVersion,
  })  : _postBatch = postBatch ?? _defaultPost,
        _appVersion = appVersion;

  /// Injected so the queueing and truncation rules can be tested without a
  /// live database — which is the half most likely to be wrong.
  final Future<void> Function(List<Map<String, dynamic>> rows) _postBatch;

  final int queueLimit;
  final String? _appVersion;

  final Queue<Map<String, dynamic>> _pending = Queue<Map<String, dynamic>>();
  bool _draining = false;

  int get pendingCount => _pending.length;
  List<Map<String, dynamic>> get pending => List.unmodifiable(_pending);

  static Future<void> _defaultPost(List<Map<String, dynamic>> rows) =>
      SupabaseConfig.client.from('crash_reports').insert(rows);

  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  @override
  void report(CrashReport r) {
    try {
      _pending.addLast(<String, dynamic>{
        'user_id': SupabaseConfig.client.auth.currentUser?.id,
        'at': r.at.toUtc().toIso8601String(),
        'platform': _platform,
        'app_version': _appVersion,
        'error': _clip(r.error.toString(), _maxErrorChars),
        'stack': r.stack == null ? null : _clip(r.stack.toString(), _maxStackChars),
        'context': r.context,
        'fatal': r.fatal,
      });
      // Oldest-first: during a storm the newest reports are the ones still
      // describing the live state of the app.
      while (_pending.length > queueLimit) {
        _pending.removeFirst();
      }
      unawaited(flush());
    } catch (e) {
      // See property 2 above. Never report this.
      debugPrint('SupabaseReportingSink.report failed: $e');
    }
  }

  /// Attempts to send everything queued. Never throws.
  Future<void> flush() async {
    if (_draining || _pending.isEmpty) return;
    _draining = true;
    final batch = _pending.toList(growable: false);
    try {
      await _postBatch(batch);
      // Only remove what was actually accepted. Reports added while the post
      // was in flight stay queued.
      for (var i = 0; i < batch.length && _pending.isNotEmpty; i++) {
        _pending.removeFirst();
      }
    } catch (e) {
      debugPrint('SupabaseReportingSink.flush failed, ${_pending.length} held: $e');
    } finally {
      _draining = false;
    }
  }
}
```

Note `_platform` uses `defaultTargetPlatform.name` — no bitwise arithmetic anywhere in this file, so the dart2js hazard does not apply.

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/core/supabase_reporting_sink_test.dart
```

Expected: PASS, 6 tests.

> **Controller Ruling 8 (2026-08-19) — why the sixth test exists and must not be deleted.**
> `crash_reports` INSERT is granted `to authenticated`. A crash before sign-in
> runs as the `anon` Postgres role and is refused by RLS. An `anon` INSERT
> policy was considered and **deliberately rejected**: the publishable key ships
> in every web bundle and APK, so it would be an unauthenticated, unmetered
> write endpoint into a 500 MB free-plan database whose documented history
> (CLAUDE.md §10.2) includes a two-hour outage from write and disk pressure.
>
> The sink's hold-and-drain behaviour is therefore **the mitigation**, not a
> convenience. It must retain a refused report and deliver it once a session
> exists. The residual gap — a crash on a session that never signs in at all —
> is accepted and is written into the table comment rather than left untrue.

- [ ] **Step 5: Wire it into `main()`**

In `lib/main.dart`, inside `_initializeApplication()`, immediately after `await SupabaseConfig.initialize();`:

```dart
    // Swap the boot-time sink now that there is a database to talk to.
    //
    // installCrashHandlers() ran first, on the in-memory LoggingReportingSink,
    // and that ordering is deliberate: telemetry that needs Supabase to be up
    // cannot be the thing that catches Supabase failing to come up. The
    // in-memory history is swapped, not lost — the reports that arrived during
    // bootstrap were already logged.
    crashReporter.useSink(SupabaseReportingSink(
      appVersion: (await PackageInfo.fromPlatform()).version,
    ));
```

Add the imports:

```dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_application_1/core/telemetry/supabase_reporting_sink.dart';
```

- [ ] **Step 6: Verify and commit**

```bash
flutter analyze
flutter test
```

```bash
git add lib/core/telemetry/supabase_reporting_sink.dart lib/main.dart test/core/supabase_reporting_sink_test.dart
git commit -m "feat(telemetry): crash reports actually leave the device

One implementation of the existing ReportingSink seam, one line in
main(). The three properties tested are the ones that matter more than
delivery: report() cannot throw (it runs inside crash handlers), a sink
failure is never itself reported (that loop takes the app down harder
than the original bug), and reports buffer offline and drain on
recovery — the crashes worth seeing are disproportionately the ones on
a truck with no signal.

The boot-time LoggingReportingSink is swapped, not replaced: telemetry
needing Supabase cannot be what catches Supabase failing to start."
```

---

## Task 4: `/super-admin/crash-reports` reader

**Files:**
- Create: `lib/features/super_admin/screens/crash_reports_screen.dart`
- Modify: `lib/core/routing/app_router.dart`
- Modify: `lib/features/super_admin/widgets/sidebar/console_sidebar_bridge.dart`
- Modify: `lib/features/super_admin/widgets/super_admin_shell_layout.dart`
- Test: `test/features/crash_reports_screen_test.dart`

**Interfaces:**
- Consumes: `public.crash_reports` (Task 2).
- Produces: route `/super-admin/crash-reports`.

- [ ] **Step 1: Read the pattern before writing anything**

Open `lib/features/super_admin/screens/token_requests_screen.dart` and follow its structure — list/detail, providers, empty state, `MlSemantic.of(context)` for surfaces. Match it. Do not invent a new console screen shape.

- [ ] **Step 2: Write the failing layout test**

Create `test/features/crash_reports_screen_test.dart`. It must call `loadRealFonts()` and sweep text scale, because a console screen inherits `ConsolePrefs.textScale` (0.85–1.3):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/super_admin/screens/crash_reports_screen.dart';
import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  for (final width in <double>[360, 800, 1440]) {
    for (final scale in <double>[0.85, 1.0, 1.3]) {
      testWidgets('renders without overflow at ${width}px / scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(body: CrashReportsScreen(reports: [])),
          ),
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // An empty store must say so, not render a blank panel that reads as
        // a broken screen.
        expect(find.textContaining('No crash reports'), findsOneWidget);
      });
    }
  }
}
```

- [ ] **Step 3: Run it to verify it fails**

```bash
flutter test test/features/crash_reports_screen_test.dart
```

Expected: FAIL — `crash_reports_screen.dart` does not exist.

- [ ] **Step 4: Implement the screen**

Create `CrashReportsScreen` taking an optional injected `List<CrashReportRow> reports` (so the test above needs no database) and otherwise reading a Riverpod provider backed by a service method. Requirements:

- Newest first; a "Fatal only" filter toggle; facet chips for platform and app_version.
- Each row: timestamp (`MlTime.sast`), fatal pill via `MlTone.error` / handled via `MlTone.neutral`, context, first line of `error`.
- Expanding a row reveals the full `stack` in `MlTokens.fontMono`, inside its own `overflow-x: auto` equivalent — a horizontally scrollable box. A stack trace is the widest text in the app and must not push the page sideways.
- Empty state text: `No crash reports in the last 90 days.` — naming the retention window, so an empty screen reads as "nothing broke", not "this is broken".
- Wrap every text cell in `Flexible` inside any `Row` (CLAUDE.md §10.4 — a non-flex child in a Row gets unbounded width and `ellipsis` never engages).

- [ ] **Step 5: Register the route and sidebar entry**

In `app_router.dart`, beside the other `/super-admin/*` routes:

```dart
          GoRoute(
            path: '/super-admin/crash-reports',
            builder: (context, state) => const CrashReportsScreen(),
          ),
```

In `console_sidebar_bridge.dart`, add to both maps, matching the existing dotted-key style (`'tokens.requests': '/super-admin/token-requests'`):

```dart
  'platform.crashReports': '/super-admin/crash-reports',
```
```dart
  '/super-admin/crash-reports': 'platform.crashReports',
```

In `super_admin_shell_layout.dart`, add a nav entry under the same group as the other platform-health items, following the `_active(...)` / `_go(...)` pattern used for `/super-admin/token-requests`.

- [ ] **Step 6: Verify route reachability**

```bash
flutter test test/features/crash_reports_screen_test.dart
python tool/route_reachability.py
flutter analyze
```

`route_reachability.py` exists to catch exactly the failure this repo already had — a screen sitting at a route with no nav entry pointing at it. Expected: the new route reachable.

- [ ] **Step 7: Commit**

```bash
git add lib/features/super_admin/screens/crash_reports_screen.dart lib/core/routing/app_router.dart lib/features/super_admin/widgets/sidebar/console_sidebar_bridge.dart lib/features/super_admin/widgets/super_admin_shell_layout.dart test/features/crash_reports_screen_test.dart
git commit -m "feat(super-admin): a screen to read crash reports

Registered in the sidebar, not just the router — route_reachability.py
exists because this repo has shipped a screen no nav entry pointed at.

Empty state names the 90-day window so it reads as 'nothing broke'
rather than 'this is broken'. Rendered with real fonts across three
widths x textScale 0.85-1.3."
```

---

## Task 5: `device_tokens`, the fan-out trigger, and `push-fanout`

**Files:**
- Create: `supabase/migrations/20260819090000_device_tokens.sql`
- Create: `supabase/functions/push-fanout/index.ts`

**Interfaces:**
- Consumes: `public.notifications`.
- Produces: table `public.device_tokens`; `register_device_token(p_token text, p_platform text, p_app_version text) returns uuid`; `unregister_device_token(p_token text) returns void`; trigger `notifications_push_fanout`; edge function `push-fanout`.

- [ ] **Step 1: Write the migration**

```sql
-- POST_NOTIFICATIONS was declared in AndroidManifest.xml with nothing behind
-- it. Notifications reached a user only while the app was open, which on a
-- logistics platform means a driver learns a load is ready when they next
-- happen to look -- and Play asks why a permission is declared but unused.

create table if not exists public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  token       text not null unique,
  platform    text not null check (platform in ('android','ios','web')),
  app_version text,
  created_at  timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),
  disabled_at timestamptz
);

comment on table public.device_tokens is
  'FCM registration tokens. UNIQUE on token, and register_device_token '
  're-points user_id on conflict: a shared depot tablet really does change '
  'hands, and a stale row would send one driver''s dispatch to another. '
  'Idle tokens are removed at 180 days by prune_telemetry_job().';

create index if not exists device_tokens_live_idx
  on public.device_tokens (user_id) where disabled_at is null;

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_select_own on public.device_tokens;
create policy device_tokens_select_own on public.device_tokens
  for select to authenticated using (user_id = auth.uid());

grant select on public.device_tokens to authenticated;

create or replace function public.register_device_token(
  p_token text, p_platform text, p_app_version text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_token,'')),'') is null then
    raise exception 'A device token is required' using errcode = '22023';
  end if;

  insert into public.device_tokens (user_id, token, platform, app_version)
  values (auth.uid(), p_token, p_platform, p_app_version)
  on conflict (token) do update
    set user_id      = auth.uid(),   -- the device changed hands
        platform     = excluded.platform,
        app_version  = excluded.app_version,
        last_seen_at = timezone('utc', now()),
        disabled_at  = null          -- it is demonstrably alive again
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  delete from public.device_tokens
   where token = p_token and user_id = auth.uid();
end;
$$;

revoke execute on function public.register_device_token(text, text, text) from public, anon;
revoke execute on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text, text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Fan-out: trigger + pg_net, NOT an outbox drained by cron.
--
-- Cron's minimum useful period is a minute, and the case this feature exists
-- for is telling a driver a load is ready. A minute of latency on dispatch is
-- the difference between the feature working and it being a slower version of
-- the bell they already have.
--
-- pg_net is async and fire-and-forget, which is the property that makes it
-- safe to hang off the write path at all: the trigger cannot slow down or fail
-- a notification insert.
-- ---------------------------------------------------------------------------
create or replace function public.notifications_push_fanout()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  begin
    perform net.http_post(
      url     => coalesce(current_setting('app.settings.supabase_url', true),
                          'https://yftazblpmicqtamyiwyb.supabase.co')
                 || '/functions/v1/push-fanout',
      body    => jsonb_build_object('notification_id', new.id),
      headers => jsonb_build_object(
                   'Content-Type', 'application/json',
                   'Authorization', 'Bearer ' ||
                     current_setting('app.settings.service_role_key', true)
                 ),
      timeout_milliseconds => 10000
    );
  exception when others then
    -- A push that cannot be dispatched must never cost the in-app
    -- notification that is already written. Warn and carry on.
    raise warning 'push fanout failed for notification %: %', new.id, sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists notifications_push_fanout on public.notifications;
create trigger notifications_push_fanout
  after insert on public.notifications
  for each row execute function public.notifications_push_fanout();
```

- [ ] **Step 2: Apply, repoint the stamp in its own call, verify**

```sql
update supabase_migrations.schema_migrations
set version = '20260819090000' where name = 'device_tokens';
```

Then confirm an insert into `notifications` still succeeds with the edge function absent — this is the property that matters most:

```sql
begin;
insert into public.notifications (user_id, title, message, type)
values ((select id from public.profiles limit 1), 'probe', 'probe', 'system')
returning id;
rollback;
```

Expected: the insert succeeds (possibly with a `WARNING`). **If it raises, stop** — the trigger is not adequately isolated and would break every notification in the product.

- [ ] **Step 3: Write `push-fanout`**

`supabase/functions/push-fanout/index.ts`: service-role client; read the notification; read live tokens for `user_id`; mint an OAuth2 access token from the `FCM_SERVICE_ACCOUNT` service-account JSON (JWT grant against `https://oauth2.googleapis.com/token`, scope `https://www.googleapis.com/auth/firebase.messaging`); POST each token to `https://fcm.googleapis.com/v1/projects/<project_id>/messages:send`.

Required behaviours, each with a comment saying why:

- **HTTP v1 only.** The legacy server key is retired; do not use it.
- Payload carries `notification: {title, body}` plus `data: {route, nav_tab, notification_id}` from `notifications.metadata`, reusing the existing `metadata.nav_tab` convention.
- On `UNREGISTERED` or `INVALID_ARGUMENT`, set `disabled_at` on that token — an unpruned list degrades quietly until sends fail in bulk.
- If `FCM_SERVICE_ACCOUNT` is unset, return `{"ok": true, "skipped": "no FCM credentials"}` with HTTP 200 rather than erroring. This is the normal state until Jean creates the project, and a trigger that logs a warning on every notification is noise that trains people to ignore warnings.

- [ ] **Step 4: Deploy and verify the no-credentials path**

Deploy as `push-fanout`. Then:

```bash
curl -s -X POST "https://yftazblpmicqtamyiwyb.supabase.co/functions/v1/push-fanout" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" -H "Content-Type: application/json" \
  -H "User-Agent: MineLink-ops/1.0" -d '{"notification_id":"00000000-0000-0000-0000-000000000000"}'
```

Expected: HTTP 200 with `skipped: "no FCM credentials"`.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260819090000_device_tokens.sql supabase/functions/push-fanout/index.ts
git commit -m "feat(push): device tokens and the notifications fan-out

Trigger + pg_net rather than an outbox drained by cron: cron's minimum
useful period is a minute, and the case this exists for is telling a
driver a load is ready. pg_net being async is what makes it safe to hang
off the write path -- the trigger cannot slow or fail a notification
insert, and it swallows its own errors so a push that cannot be
dispatched never costs the in-app notification already written.

register_device_token re-points user_id on token conflict: a shared
depot tablet changes hands, and a stale row sends one driver's dispatch
to another.

push-fanout returns 200 'skipped' with no FCM credentials, which is the
normal state until the Firebase project exists. A warning on every
notification is noise that trains people to ignore warnings."
```

---

## Task 6: `account_deactivation_requests` — table and the user-facing RPCs

**Files:**
- Create: `supabase/migrations/20260819100000_account_deactivation_requests.sql`

**Interfaces:**
- Consumes: `public.is_platform_admin()`, `public.create_notification_internal(...)` (12 args).
- Produces: table `public.account_deactivation_requests`; `request_account_deactivation(p_reason text) returns uuid`; `cancel_account_deactivation_request() returns void`; `my_account_deactivation_request() returns jsonb`. SQLSTATEs `MLD01`, `MLD02`.

> **Read spec §1.1 first.** R-1 was re-scoped from deletion to deactivation by Jean on 2026-08-19. **Nothing is deleted and nothing is scrubbed.** If you find yourself writing an `UPDATE` that nulls a personal-data column, stop — that is the struck design.

- [ ] **Step 1: Probe the preconditions**

```sql
select to_regclass('public.account_deactivation_requests') as exists_yet,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'create_notification_internal') as notif_fn,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'is_platform_admin') as admin_fn,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname = 'super_admin_set_company_status') as company_status_fn;
```

Expected: `null | 1 | 1 | 1`. The last one matters: `MLD01`'s message promises a company-suspension route, and that route must actually exist.

- [ ] **Step 2: Write the migration**

Create `supabase/migrations/20260819100000_account_deactivation_requests.sql`:

```sql
-- In-app account DEACTIVATION.
--
-- Originally scoped as deletion, because Play's User Data policy and App Store
-- 5.1.1(v) require it. Jean ruled on 2026-08-19 that nothing on this platform
-- is ever deleted -- companies or people -- so this is deactivation, and the
-- store gap stays open and recorded. See the spec s1.1.
--
--   "Accounts (company profiles) shouldn't be deletable really, only
--    deactivate it, make it inactive."  -- Jean, 2026-08-19
--
-- NOTHING HERE DESTROYS DATA. No PII is scrubbed, no credential is scrambled,
-- no auth.identities row is deleted. The account becomes unusable and stays
-- fully recoverable through reactivate_account (20260819110000).
--
-- The spec's s1 foreign-key analysis is kept even though nothing deletes: it
-- is why a delete is impossible here (companies.user_id -> profiles is ON
-- DELETE CASCADE, plus eleven NO ACTION references), and it is the expensive
-- half of the work if the stores ever force the issue.

create table if not exists public.account_deactivation_requests (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.profiles(id) on delete cascade,
  requested_at    timestamptz not null default timezone('utc', now()),
  reason          text,
  status          text not null default 'pending'
                    check (status in ('pending','approved','rejected',
                                      'cancelled','deactivated','reactivated')),
  reviewed_by     uuid references public.profiles(id) on delete set null,
  reviewed_at     timestamptz,
  review_note     text,
  -- A TTL, not a business day: now() is correct and ml_today() is not
  -- (CLAUDE.md s7.1 exempts timestamps that stamp a row rather than decide a day).
  auto_apply_at   timestamptz not null
                    default timezone('utc', now()) + interval '30 days',
  deactivated_at  timestamptz,
  -- The reversal is a first-class event, not an absence. Who restored an
  -- account and when is exactly what an audit asks, and a status flipped back
  -- with no trace cannot answer it.
  reactivated_at  timestamptz,
  reactivated_by  uuid references public.profiles(id) on delete set null
);

comment on table public.account_deactivation_requests is
  'User-initiated account deactivation, reviewed by a platform admin. Nothing '
  'is deleted or scrubbed -- see the spec s1.1 (Jean, 2026-08-19). Anything '
  'still pending at auto_apply_at is applied by '
  'apply_due_account_deactivations_job(), and every deactivation is reversible '
  'by reactivate_account(). NOTE: this does NOT satisfy Google Play''s '
  'account-DELETION requirement; that gap is open and recorded.';

-- One open request per user. `deactivated` is deliberately NOT in this list:
-- a reactivated user must be able to ask again later, and a permanently
-- occupied slot would prevent it.
create unique index if not exists account_deactivation_requests_one_open
  on public.account_deactivation_requests (user_id)
  where status in ('pending', 'approved');

create index if not exists account_deactivation_requests_due_idx
  on public.account_deactivation_requests (auto_apply_at)
  where status = 'pending';

alter table public.account_deactivation_requests enable row level security;

-- SELECT grant only. No write grant and no write policy: every write goes
-- through an RPC, the same shape as monthly_targets.
drop policy if exists account_deactivation_requests_select
  on public.account_deactivation_requests;
create policy account_deactivation_requests_select
  on public.account_deactivation_requests
  for select to authenticated
  using (user_id = auth.uid() or public.is_platform_admin());

grant select on public.account_deactivation_requests to authenticated;

-- ---------------------------------------------------------------------------
-- request_account_deactivation
-- ---------------------------------------------------------------------------
create or replace function public.request_account_deactivation(
  p_reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid     uuid := auth.uid();
  v_company text;
  v_id      uuid;
  v_name    text;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  -- MLD01 -- sole company owner.
  --
  -- Refused at REQUEST time, not review time, because it is actionable by the
  -- user. The message names TWO real routes rather than being a dead end:
  -- super_admin_set_company_status(id,'suspended') already exists and is how a
  -- company goes inactive, and ownership transfer is the other way out.
  select c.company_name into v_company
    from public.companies c
   where c.user_id = v_uid
   limit 1;

  if v_company is not null then
    raise exception
      'You own %. Its account must be suspended by a platform admin, or ownership transferred, before yours can be deactivated.',
      v_company
      using errcode = 'MLD01';
  end if;

  -- MLD02 -- belt and braces with the unique index. The index is the real
  -- guarantee; this raise is the readable error.
  if exists (
    select 1 from public.account_deactivation_requests
     where user_id = v_uid and status in ('pending','approved')
  ) then
    raise exception 'You already have a deactivation request in progress.'
      using errcode = 'MLD02';
  end if;

  insert into public.account_deactivation_requests (user_id, reason)
  values (v_uid, nullif(btrim(coalesce(p_reason, '')), ''))
  returning id into v_id;

  select coalesce(nullif(btrim(p.display_name), ''), p.email)
    into v_name from public.profiles p where p.id = v_uid;

  perform public.create_notification_internal(
    pr.id, null, null,
    'Account deactivation requested',
    coalesce(v_name, 'A user') || ' has asked for their account to be deactivated.',
    'account_deactivation', v_name, v_uid, null, null, 'high',
    jsonb_build_object('deactivation_request_id', v_id)
  )
  from public.profiles pr
  -- MEASURED 2026-08-19: profiles.platform_role is NOT NULL and DEFAULTS to
  -- 'normalUser', so `is not null` matches 114 of 117 profiles -- every user
  -- on the platform, not the 3 admins. is_platform_admin() -> is_super_admin()
  -- tests this exact value, so match the column, not the null-ness. The
  -- function itself cannot be used here: it asks whether the CALLER is an
  -- admin, and this needs to ask it of each candidate ROW.
  where pr.platform_role = 'superGlobalSerialAdminMain';

  return v_id;
end;
$$;

comment on function public.request_account_deactivation(text) is
  'Opens a deactivation request. Refuses a company owner with SQLSTATE MLD01 '
  '(a company is never deleted and its owner cannot leave it ownerless -- the '
  'message names the suspension and transfer routes) and a duplicate with '
  'MLD02. Active trips do NOT block: the request is harmless and the review '
  'step exists to catch that.';

-- ---------------------------------------------------------------------------
-- cancel_account_deactivation_request
-- ---------------------------------------------------------------------------
create or replace function public.cancel_account_deactivation_request()
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
  v_n   int;
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  -- 'pending' only. Once an admin has approved, the user cannot unilaterally
  -- withdraw -- a decision has been taken on it.
  update public.account_deactivation_requests
     set status = 'cancelled'
   where user_id = v_uid and status = 'pending';

  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'No pending deactivation request to cancel.'
      using errcode = 'MLD02';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- my_account_deactivation_request -- what the card renders
-- ---------------------------------------------------------------------------
create or replace function public.my_account_deactivation_request()
returns jsonb
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select to_jsonb(r)
    from public.account_deactivation_requests r
   where r.user_id = auth.uid()
     and r.status in ('pending','approved','rejected')
   order by r.requested_at desc
   limit 1;
$$;

revoke execute on function public.request_account_deactivation(text) from public, anon;
revoke execute on function public.cancel_account_deactivation_request() from public, anon;
revoke execute on function public.my_account_deactivation_request() from public, anon;
grant execute on function public.request_account_deactivation(text) to authenticated;
grant execute on function public.cancel_account_deactivation_request() to authenticated;
grant execute on function public.my_account_deactivation_request() to authenticated;
```

- [ ] **Step 3: Apply, then repoint the stamp in a separate call**

Apply via `apply_migration`, name `account_deactivation_requests`. Then, alone in its own `execute_sql` (CLAUDE.md §6 rule 5 — a self-rolling-back probe in the same batch silently undoes it):

```sql
update supabase_migrations.schema_migrations
set version = '20260819100000' where name = 'account_deactivation_requests';
```

- [ ] **Step 4: Prove MLD01 fires, then roll back**

Production database — every probe rolls back.

```sql
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', (select user_id::text from public.companies
                             where user_id is not null limit 1),
                    'role', 'authenticated')::text, true);
set local role authenticated;
do $$
begin
  perform public.request_account_deactivation('probe');
  raise exception 'PROBE FAILED: owner was allowed to request deactivation';
exception when sqlstate 'MLD01' then
  raise notice 'PROBE OK: MLD01 raised for a company owner';
end $$;
rollback;
```

Expected: `PROBE OK: MLD01 raised for a company owner`.

- [ ] **Step 5: Prove the happy path and MLD02, then roll back**

```sql
begin;
select set_config('request.jwt.claims',
  json_build_object('sub', (select p.id::text from public.profiles p
                             where not exists (select 1 from public.companies c
                                                where c.user_id = p.id)
                             limit 1),
                    'role', 'authenticated')::text, true);
set local role authenticated;
select public.request_account_deactivation('probe reason') as first_id;
do $$
begin
  perform public.request_account_deactivation('again');
  raise exception 'PROBE FAILED: duplicate request was allowed';
exception when sqlstate 'MLD02' then
  raise notice 'PROBE OK: MLD02 raised on duplicate';
end $$;
select status, auto_apply_at - requested_at as window
  from public.account_deactivation_requests order by requested_at desc limit 1;
rollback;
```

Expected: a uuid, `PROBE OK: MLD02 raised on duplicate`, `pending | 30 days`.

- [ ] **Step 6: Confirm nothing persisted, then check the ledger**

```sql
select count(*) as must_be_zero from public.account_deactivation_requests;
```
```bash
python tool/migration_ledger_check.py
python tool/one_clock_check.py
```

Exit 2 from the ledger check is "could not check", **not** a pass.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/20260819100000_account_deactivation_requests.sql
git commit -m "feat(account): deactivation request table and the user's RPCs

Re-scoped from deletion to deactivation on Jean's ruling (spec s1.1):
nothing on this platform is ever deleted, companies or people. Nothing
here scrubs PII or touches a credential.

MLD01 refuses a company owner at REQUEST time and names two real routes
instead of dead-ending -- super_admin_set_company_status already exists
and is how a company goes inactive. Active trips deliberately do not
block; review exists to catch that.

'deactivated' is deliberately absent from the one-open-request index: a
reactivated user must be able to ask again."
```

---

## Task 7: review, deactivate, and reactivate

**Files:**
- Create: `supabase/migrations/20260819110000_account_deactivation_apply.sql`

**Interfaces:**
- Consumes: Task 6's table.
- Produces: `review_account_deactivation_request(p_id uuid, p_approve boolean, p_note text) returns void`; `deactivate_account(p_user_id uuid) returns jsonb`; `reactivate_account(p_user_id uuid) returns jsonb`; `list_account_deactivation_requests(p_status text)`.

- [ ] **Step 1: Confirm the two schema facts this depends on**

Do not skip. The first was wrong in the design's first draft.

```sql
select table_name, column_name, data_type
  from information_schema.columns
 where table_schema = 'auth'
   and (table_name, column_name) in
       (('refresh_tokens','user_id'), ('sessions','user_id'), ('users','banned_until'))
 order by table_name;
select count(*) as banned_not_null_today from auth.users where banned_until is not null;
```

Expected: `refresh_tokens.user_id` is **character varying** while `sessions.user_id` is uuid; `users.banned_until` is `timestamp with time zone`; and `banned_not_null_today` tells you whether any account is currently banned by other means — if it is non-zero, reactivation must not be assumed to be this feature's business.

- [ ] **Step 2: Write the migration**

Create `supabase/migrations/20260819110000_account_deactivation_apply.sql`:

```sql
-- Review, apply, and undo. See 20260819100000 and the spec s2.3.
--
-- NOTHING HERE DELETES OR SCRUBS. The only destructive statements are the two
-- session revocations, and a session is not data -- it is an access grant, and
-- revoking it is the point.
--
-- auth.refresh_tokens.user_id is `character varying`, NOT uuid -- alone among
-- the auth tables touched here, verified against production 2026-08-19.
-- `= v_uid` raises 42883 (operator does not exist: character varying = uuid).

create or replace function public.review_account_deactivation_request(
  p_id      uuid,
  p_approve boolean,
  p_note    text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_req   public.account_deactivation_requests;
  v_admin text;
begin
  if not public.is_platform_admin() then
    raise exception 'Only a platform admin may review deactivation requests.'
      using errcode = '42501';
  end if;

  select * into v_req from public.account_deactivation_requests where id = p_id;
  if not found then
    raise exception 'No such deactivation request.' using errcode = 'MLD02';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'That request is already %.', v_req.status using errcode = 'MLD02';
  end if;

  -- A rejection the user cannot understand is a rejection they will re-submit.
  if not p_approve and nullif(btrim(coalesce(p_note, '')), '') is null then
    raise exception 'A reason is required when rejecting a deactivation request.'
      using errcode = 'MLD02';
  end if;

  update public.account_deactivation_requests
     set status      = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = auth.uid(),
         reviewed_at = timezone('utc', now()),
         review_note = nullif(btrim(coalesce(p_note, '')), '')
   where id = p_id;

  select coalesce(nullif(btrim(display_name), ''), email)
    into v_admin from public.profiles where id = auth.uid();

  perform public.create_notification_internal(
    v_req.user_id, null, null,
    case when p_approve then 'Account deactivation approved'
                        else 'Deactivation request declined' end,
    case when p_approve
         then 'Your account will be deactivated shortly. You will not be able to sign in, and an administrator can restore it if you change your mind.'
         else 'Your deactivation request was declined: ' || coalesce(p_note, '') end,
    'account_deactivation', v_admin, auth.uid(), null, null, 'high',
    jsonb_build_object('deactivation_request_id', p_id)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- deactivate_account -- the act. Reversible, destroys nothing.
-- ---------------------------------------------------------------------------
create or replace function public.deactivate_account(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid        uuid := p_user_id;
  v_req        uuid;
  v_name       text;
  v_company_id uuid;
begin
  -- Platform admin (console) or the service role (the cron backstop).
  if not (public.is_platform_admin() or auth.role() = 'service_role') then
    raise exception 'Not permitted.' using errcode = '42501';
  end if;

  if not exists (select 1 from public.profiles where id = v_uid) then
    raise exception 'No such user.' using errcode = 'MLD02';
  end if;

  select coalesce(nullif(btrim(p.display_name), ''), p.email),
         (select e.company_id from public.employees e where e.user_id = v_uid limit 1)
    into v_name, v_company_id
    from public.profiles p where p.id = v_uid;

  -- A company owner must never end up deactivated: companies.user_id is NOT
  -- NULL-able in practice and an ownerless company has nobody who can act for
  -- it. request_account_deactivation refuses this at the front door; this is
  -- the same rule at the back door, because the cron job also calls here.
  if exists (select 1 from public.companies where user_id = v_uid) then
    raise exception 'That user owns a company and cannot be deactivated.'
      using errcode = 'MLD01';
  end if;

  -- Revoke the live session so the change takes effect now, not at next token
  -- expiry. NOTE the ::text cast -- see the file header.
  delete from auth.refresh_tokens where user_id = v_uid::text;
  delete from auth.sessions        where user_id = v_uid;

  -- The sign-in refusal. GoTrue's own switch, and ONE column to undo.
  -- auth.identities is NOT touched, the password is NOT scrambled, and
  -- deleted_at is NOT set: those are deletion mechanics, and this is not a
  -- deletion.
  update auth.users set banned_until = 'infinity' where id = v_uid;

  update public.employees set
    status     = 'inactive',
    updated_at = timezone('utc', now())
  where user_id = v_uid;

  -- public.profiles is deliberately NOT modified. display_name is what every
  -- historical trip, chat message and audit row renders through, and an
  -- account being inactive is a fact about access, not about who the person
  -- was.

  update public.account_deactivation_requests
     set status = 'deactivated', deactivated_at = timezone('utc', now())
   where user_id = v_uid and status in ('pending','approved')
  returning id into v_req;

  -- insert_audit_log's REAL signature, verified against production 2026-08-19:
  --   (p_action_type, p_target_type, p_target_id, p_target_name,
  --    p_organization_id, p_description, p_before_data, p_after_data)
  -- Eight parameters, the last two defaulted -- super_admin_set_company_status
  -- calls it with six, which is why six is known to work. p_organization_id is
  -- the COMPANY, not the user: passing a user id there would file every
  -- deactivation under an organisation that does not exist.
  perform public.insert_audit_log(
    'ACCOUNT_DEACTIVATED', 'profiles', v_uid, v_name, v_company_id,
    'Account deactivated (request ' || coalesce(v_req::text, 'n/a') || ')'
  );

  return jsonb_build_object('user_id', v_uid, 'request_id', v_req,
                            'status', 'deactivated');
end;
$$;

-- ---------------------------------------------------------------------------
-- reactivate_account -- the exact inverse
-- ---------------------------------------------------------------------------
create or replace function public.reactivate_account(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_uid        uuid := p_user_id;
  v_name       text;
  v_company_id uuid;
begin
  -- Platform admin ONLY -- never the service role, and the cron job never
  -- calls this. Nothing should ever restore access automatically; removing
  -- access and granting it back are not symmetric risks.
  if not public.is_platform_admin() then
    raise exception 'Only a platform admin may reactivate an account.'
      using errcode = '42501';
  end if;

  select coalesce(nullif(btrim(p.display_name), ''), p.email),
         (select e.company_id from public.employees e where e.user_id = v_uid limit 1)
    into v_name, v_company_id
    from public.profiles p where p.id = v_uid;

  -- null, not a past timestamp. A past timestamp also permits sign-in, but
  -- null is what a never-banned account carries, so a reactivated account
  -- becomes indistinguishable from one that was never touched. Anything else
  -- leaves residue that a query filtering `banned_until is not null` misreads.
  update auth.users set banned_until = null where id = v_uid;

  -- Unconditionally 'active'. The only status this flow ever writes is
  -- 'inactive', and guessing at a prior state nobody recorded would be worse
  -- than a stated rule.
  update public.employees set status = 'active', updated_at = timezone('utc', now())
   where user_id = v_uid;

  update public.account_deactivation_requests
     set status = 'reactivated',
         reactivated_at = timezone('utc', now()),
         reactivated_by = auth.uid()
   where user_id = v_uid and status = 'deactivated';

  perform public.insert_audit_log(
    'ACCOUNT_REACTIVATED', 'profiles', v_uid, v_name, v_company_id,
    'Account reactivated'
  );

  return jsonb_build_object('user_id', v_uid, 'status', 'reactivated');
end;
$$;

-- ---------------------------------------------------------------------------
-- list_account_deactivation_requests -- the console queue
-- ---------------------------------------------------------------------------
create or replace function public.list_account_deactivation_requests(
  p_status text default 'pending'
)
returns table (
  id               uuid,
  user_id          uuid,
  display_name     text,
  email            text,
  company_name     text,
  role             text,
  reason           text,
  status           text,
  requested_at     timestamptz,
  auto_apply_at    timestamptz,
  review_note      text,
  deactivated_at   timestamptz,
  is_company_owner boolean,
  active_trips     int
)
language sql
stable
security definer
set search_path = public, extensions, pg_temp
as $$
  select r.id, r.user_id, p.display_name, p.email, c.company_name, e.role,
         r.reason, r.status, r.requested_at, r.auto_apply_at, r.review_note,
         r.deactivated_at,
         exists (select 1 from public.companies co where co.user_id = r.user_id),
         -- Active trips, counted down BOTH driver paths.
         --
         -- driver_assignments is the authoritative one (CLAUDE.md §4: driver
         -- screens resolve the truck through it precisely because 2nd+ drivers
         -- were invisible otherwise), and it keys on
         -- driver_assignments.driver_employee_id -> employees.id, NOT on a
         -- user id -- hence the join through employees.
         -- fleet_vehicles.driver_user_id is the legacy single-driver column and
         -- is still populated, so it is unioned in.
         --
         -- This chip is informational for a human reviewer. Over-reporting a
         -- blocker costs a glance; under-reporting one hides a driver who is
         -- mid-load, which is the entire reason the chip exists.
         (select count(distinct t.id)::int
            from public.trips t
           where t.status not in ('completed','cancelled')
             and (exists (select 1
                            from public.driver_assignments da
                            join public.employees e on e.id = da.driver_employee_id
                           where da.vehicle_id = t.vehicle_id
                             and e.user_id = r.user_id)
               or exists (select 1
                            from public.fleet_vehicles fv
                           where fv.id = t.vehicle_id
                             and fv.driver_user_id = r.user_id)))
    from public.account_deactivation_requests r
    join public.profiles p on p.id = r.user_id
    left join public.employees e on e.user_id = r.user_id
    left join public.companies c on c.id = e.company_id
   where public.is_platform_admin()
     and (p_status is null or r.status = p_status)
   order by r.requested_at;
$$;

revoke execute on function public.review_account_deactivation_request(uuid, boolean, text) from public, anon;
revoke execute on function public.deactivate_account(uuid) from public, anon, authenticated;
revoke execute on function public.reactivate_account(uuid) from public, anon;
revoke execute on function public.list_account_deactivation_requests(text) from public, anon;
grant execute on function public.review_account_deactivation_request(uuid, boolean, text) to authenticated;
grant execute on function public.reactivate_account(uuid) to authenticated;
grant execute on function public.list_account_deactivation_requests(text) to authenticated;
-- deactivate_account is NOT granted to authenticated: it is reached by a
-- platform admin through review, or by the cron job as service_role.
```

> **Before applying**, verify these three names exist with these signatures, and adjust rather than assume:
> ```sql
> select p.proname, pg_get_function_identity_arguments(p.oid)
>   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
>  where n.nspname='public' and p.proname in ('insert_audit_log','is_platform_admin');
> select column_name from information_schema.columns
>  where table_schema='public' and table_name='trips' and column_name like '%vehicle%';
> ```
> **Already resolved by the controller on 2026-08-19 — do not re-derive, but DO re-run the query to confirm it still holds:**
> - `insert_audit_log(p_action_type text, p_target_type text, p_target_id uuid, p_target_name text, p_organization_id uuid, p_description text, p_before_data jsonb, p_after_data jsonb)` — **eight** parameters, last two defaulted (six-argument calls are proven by `super_admin_set_company_status`). The plan's SQL above already uses the correct order.
> - `trips.vehicle_id` and `trips.status` both exist. `trips` has **no** driver column — drivers reach a trip through `driver_assignments.driver_employee_id -> employees.id`, or through the legacy `fleet_vehicles.driver_user_id`. The `active_trips` subquery above already covers both paths; do not simplify it to one.

- [ ] **Step 3: Apply, repoint the stamp in its own call**

```sql
update supabase_migrations.schema_migrations
set version = '20260819110000' where name = 'account_deactivation_apply';
```

- [ ] **Step 4: Drive the full cycle against a throwaway account, then roll back**

The most important verification in this plan. Request → approve → deactivate → **reactivate**, asserting at every step, all inside a transaction that rolls back.

```sql
begin;

do $$
declare
  v_uid uuid := gen_random_uuid();
  v_req uuid;
  v_banned timestamptz;
  v_status text;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (v_uid, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'probe-deact@example.test',
          extensions.crypt('probe', extensions.gen_salt('bf')),
          now(), now(), now());

  insert into public.profiles (id, email, display_name, user_type)
  values (v_uid, 'probe-deact@example.test', 'Probe User', 'buyer')
  on conflict (id) do nothing;

  insert into public.account_deactivation_requests (user_id, reason, status)
  values (v_uid, 'probe', 'approved') returning id into v_req;

  -- DEACTIVATE
  perform public.deactivate_account(v_uid);

  select banned_until into v_banned from auth.users where id = v_uid;
  if v_banned is null then
    raise exception 'PROBE FAILED: banned_until not set';
  end if;
  raise notice 'PROBE OK: banned_until = %', v_banned;

  select display_name into v_status from public.profiles where id = v_uid;
  if v_status <> 'Probe User' then
    raise exception 'PROBE FAILED: profiles was modified -- nothing may be scrubbed';
  end if;
  raise notice 'PROBE OK: profiles untouched (display_name still %)', v_status;

  select status into v_status from public.account_deactivation_requests where id = v_req;
  raise notice 'PROBE OK: request status = %', v_status;

  -- REACTIVATE
  perform public.reactivate_account(v_uid);

  select banned_until into v_banned from auth.users where id = v_uid;
  if v_banned is not null then
    raise exception 'PROBE FAILED: banned_until is % , must be NULL', v_banned;
  end if;
  raise notice 'PROBE OK: banned_until back to NULL, not a past timestamp';

  select status into v_status from public.account_deactivation_requests where id = v_req;
  if v_status <> 'reactivated' then
    raise exception 'PROBE FAILED: request status is %', v_status;
  end if;
  raise notice 'PROBE OK: full cycle deactivate -> reactivate';
end $$;

rollback;
```

Expected: six `PROBE OK` notices, no exception. The `profiles` assertion is the one that guards the ruling — if a future edit reintroduces a scrub, this probe fails.

- [ ] **Step 5: Confirm nothing persisted, and probe health**

```sql
select count(*) as must_be_zero from public.account_deactivation_requests;
select count(*) as must_be_zero from auth.users where email like 'probe-deact%';
```
```bash
python tool/health_probe.py
```

This task wrote to `auth.*`. CLAUDE.md §1's standing rule: probe every service — db, rest, auth, storage, realtime — do not read a status field. Not optional, not deferrable.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260819110000_account_deactivation_apply.sql
git commit -m "feat(account): deactivate and reactivate, both reversible

deactivate_account revokes the sessions and sets banned_until. It does
NOT touch auth.identities, does NOT scramble the password, does NOT set
deleted_at and does NOT modify public.profiles -- those are deletion
mechanics and this is not a deletion (spec s1.1). display_name is what
every historical trip and audit row renders through.

reactivate_account sets banned_until back to NULL rather than a past
timestamp: both permit sign-in, but only NULL leaves an account
indistinguishable from one never touched, so a later query filtering on
`banned_until is not null` cannot misread it. Platform-admin only, and
the cron job never calls it -- removing access and granting it back are
not symmetric risks.

Full cycle driven against a throwaway account and rolled back. The probe
asserts profiles was NOT modified, so a reintroduced scrub fails it."
```

---

## Task 8: the 30-day auto-apply backstop

**Files:**
- Create: `supabase/migrations/20260819120000_account_deactivation_apply_job.sql`

**Interfaces:**
- Consumes: Tasks 6–7.
- Produces: `apply_due_account_deactivations_job() returns int`; cron job `apply-due-account-deactivations`.

> Under the struck deletion design this job needed `pg_net`, an edge function and a service-role key. Deactivation is plain SQL, so it calls `deactivate_account` directly. **There is no HTTP here and no `app.settings.service_role_key` to source.**

- [ ] **Step 1: Write the migration**

```sql
-- The backstop. A queue an admin never actions leaves a user unable to leave;
-- this bounds it at 30 days. Under the deletion design the bound mattered
-- because it bounded an irreversible act -- under deactivation it is safer
-- still, since anything applied here can be undone by reactivate_account with
-- nothing lost.

create or replace function public.apply_due_account_deactivations_job()
returns int
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_row   record;
  v_count int := 0;
begin
  for v_row in
    select user_id from public.account_deactivation_requests
     where status = 'approved'
        or (status = 'pending' and auto_apply_at <= timezone('utc', now()))
     order by requested_at
     -- Bounded. An unbounded nightly loop is the shape that took this instance
     -- down on 2026-08-16; there will never be 200 of these in a night, and if
     -- there are, something is wrong and slower is correct.
     limit 200
  loop
    -- One bad row must not stop the rest. This is the close_due_target_cycles_job
    -- lesson: an exception propagating out of the loop freezes the nightly run
    -- for every other scope. A company owner reaching here raises MLD01 by
    -- design and is skipped with a warning, not a crash.
    begin
      perform public.deactivate_account(v_row.user_id);
      v_count := v_count + 1;
    exception when others then
      raise warning 'apply_due_account_deactivations_job: user % skipped: %',
        v_row.user_id, sqlerrm;
    end;
  end loop;

  return v_count;
end;
$$;

comment on function public.apply_due_account_deactivations_job() is
  'Applies approved deactivation requests, and pending ones 30 days old. Plain '
  'SQL -- no pg_net and no edge function, because deactivation destroys '
  'nothing and needs no storage purge. Never reactivates: that is '
  'platform-admin only, deliberately.';

revoke execute on function public.apply_due_account_deactivations_job()
  from public, anon, authenticated;

select cron.unschedule('apply-due-account-deactivations')
 where exists (select 1 from cron.job where jobname = 'apply-due-account-deactivations');

-- 03:50 UTC, offset from the eight existing nightly jobs so they do not
-- contend on a shared-CPU free-plan instance.
select cron.schedule(
  'apply-due-account-deactivations',
  '50 3 * * *',
  'select public.apply_due_account_deactivations_job()'
);
```

- [ ] **Step 2: Apply, repoint in its own call, verify**

```sql
update supabase_migrations.schema_migrations
set version = '20260819120000' where name = 'account_deactivation_apply_job';
```
```sql
select jobname, schedule from cron.job where jobname = 'apply-due-account-deactivations';
select public.apply_due_account_deactivations_job() as applied;
```

Expected: the schedule row, and `applied = 0` — nothing is due, because there are no real requests yet. **A non-zero result means a real request exists and was just actioned: stop and investigate before continuing.**

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260819120000_account_deactivation_apply_job.sql
git commit -m "feat(account): 30-day auto-apply backstop, in plain SQL

Review is an opportunity to intervene, not a condition of the request
being honoured -- without this, an admin who never actions the queue
leaves a user unable to leave.

No pg_net, no edge function, no service-role key: deactivation destroys
nothing, so there is no storage purge and nothing to reach over HTTP for.
That also removes the open question about whether
app.settings.service_role_key is configured on this project.

Bounded at 200 a night and each iteration wrapped -- a company owner
reaching here raises MLD01 by design and is skipped with a warning
rather than freezing the run for everyone else."
```

---

## Task 9: user-facing `DeactivateAccountCard`

**Files:**
- Create: `lib/features/profile/models/account_deactivation_request.dart`
- Create: `lib/features/profile/services/account_deactivation_service.dart`
- Create: `lib/features/profile/widgets/deactivate_account_card.dart`
- Modify: `lib/features/profile/screens/account_security_screen.dart`
- Modify: `lib/features/profile/screens/profile_screen.dart`
- Test: `test/features/deactivate_account_card_test.dart`

**Interfaces:**
- Consumes: `request_account_deactivation`, `cancel_account_deactivation_request`, `my_account_deactivation_request`.
- Produces: `AccountDeactivationService` with `Future<AccountDeactivationRequest?> current()`, `Future<void> request(String? reason)`, `Future<void> cancel()`; `AccountDeactivationRequest` with `status`, `requestedAt`, `autoApplyAt`, `reviewNote`; `DeactivateAccountCard({AccountDeactivationService? service})`.

> **The copy must never say "delete".** A user who reads "delete" and gets deactivation has been misled about what happened to their data — a worse disclosure failure than the one this set out to fix.

- [ ] **Step 1: Write the failing test**

Create `test/features/deactivate_account_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/profile/models/account_deactivation_request.dart';
import 'package:flutter_application_1/features/profile/services/account_deactivation_service.dart';
import 'package:flutter_application_1/features/profile/widgets/deactivate_account_card.dart';
import '../test_helpers/real_fonts.dart';

class _FakeService implements AccountDeactivationService {
  _FakeService({this.existing, this.throwCode});
  AccountDeactivationRequest? existing;
  final String? throwCode;
  String? requestedReason;
  bool cancelled = false;

  @override
  Future<AccountDeactivationRequest?> current() async => existing;

  @override
  Future<void> request(String? reason) async {
    if (throwCode != null) {
      throw AccountDeactivationException(throwCode!, 'nope');
    }
    requestedReason = reason;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

Widget _host(Widget child, {double scale = 1.0}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

AccountDeactivationRequest _req(String status, {String? note}) =>
    AccountDeactivationRequest(
      status: status,
      requestedAt: DateTime.utc(2026, 8, 19),
      autoApplyAt: DateTime.utc(2026, 9, 18),
      reviewNote: note,
    );

void main() {
  setUpAll(loadRealFonts);

  testWidgets('offers deactivation when there is no open request',
      (tester) async {
    await tester.pumpWidget(_host(DeactivateAccountCard(service: _FakeService())));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate my account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('never uses the word delete anywhere on the card',
      (tester) async {
    await tester.pumpWidget(_host(DeactivateAccountCard(service: _FakeService())));
    await tester.pumpAndSettle();
    // The product does not delete. Copy that says otherwise misleads the user
    // about what happened to their data.
    expect(find.textContaining(RegExp(r'delet', caseSensitive: false)),
        findsNothing);
  });

  testWidgets('a pending request shows status and a way out', (tester) async {
    final svc = _FakeService(existing: _req('pending'));
    await tester.pumpWidget(_host(DeactivateAccountCard(service: svc)));
    await tester.pumpAndSettle();
    expect(find.textContaining('being reviewed'), findsOneWidget);
    await tester.tap(find.text('Cancel request'));
    await tester.pumpAndSettle();
    expect(svc.cancelled, isTrue);
  });

  testWidgets('an approved request cannot be cancelled', (tester) async {
    await tester.pumpWidget(
        _host(DeactivateAccountCard(service: _FakeService(existing: _req('approved')))));
    await tester.pumpAndSettle();
    expect(find.text('Cancel request'), findsNothing);
  });

  testWidgets('a rejection shows the admin note', (tester) async {
    await tester.pumpWidget(_host(DeactivateAccountCard(
        service: _FakeService(
            existing: _req('rejected', note: 'Settle the open dispute first.')))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Settle the open dispute first.'), findsOneWidget);
  });

  testWidgets('MLD01 names the suspension route, by SQLSTATE not wording',
      (tester) async {
    await tester.pumpWidget(
        _host(DeactivateAccountCard(service: _FakeService(throwCode: 'MLD01'))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate my account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'DEACTIVATE');
    await tester.tap(find.text('Deactivate my account').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('suspended'), findsOneWidget);
  });

  for (final width in <double>[360, 800]) {
    for (final scale in <double>[0.85, 1.0, 1.3]) {
      testWidgets('no overflow at ${width}px / scale $scale', (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
            DeactivateAccountCard(service: _FakeService()), scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
flutter test test/features/deactivate_account_card_test.dart
```
Expected: FAIL — none of the three source files exist.

- [ ] **Step 3: Implement model, service and card**

`account_deactivation_request.dart` — plain data class with `fromJson`, plus:

```dart
/// Thrown with the Postgres SQLSTATE intact.
///
/// The card branches on `code`, never on `message`. Matching on wording is
/// what `getErrorCode` in company-user-admin/index.ts exists to avoid: the
/// branch breaks silently the moment somebody edits the sentence.
class AccountDeactivationException implements Exception {
  const AccountDeactivationException(this.code, this.message);
  final String code;
  final String message;
}
```

`account_deactivation_service.dart` — the only file that touches
`SupabaseConfig.client` for this feature. Catch `PostgrestException`, rethrow as
`AccountDeactivationException(e.code ?? '', e.message)`.

`deactivate_account_card.dart` — states `none → confirming → pending → approved → rejected`. Requirements:

- Card border and heading `MlTone.error`; no raw colours.
- Confirm dialog, in this order: **what happens** (you will be signed out and cannot sign in again), **that it is reversible** (an administrator can restore your account), **what is kept** (records of loads you were part of are retained either way), then the 30-day note.
- Requires typing `DEACTIVATE` **and** re-entering the password (re-auth via `signInWithPassword` against the current email before calling the RPC).
- `MLD01` → *"You own {company}. A platform admin must suspend it, or ownership must be transferred, first."* `MLD02` → *"You already have a request in progress."* Anything else → the message plus a support pointer.
- Dates through `MlTime.sast` — never `DateTime.now()` / `toLocal()`.
- Every `Text` inside a `Row` wrapped in `Flexible`; `ConstrainedBox(minHeight:)` not `Container(height:)`; any `Wrap` inside a `Row` gets `SizedBox(width: double.infinity)` first (CLAUDE.md §10.4).

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/deactivate_account_card_test.dart
```
Expected: PASS.

- [ ] **Step 5: Mount it on both profile surfaces**

In `account_security_screen.dart`, in the `Column` after `ProfileSignatureCard()`:

```dart
              SizedBox(height: 18),
              DeactivateAccountCard(),
```

Do the equivalent at the bottom of `profile_screen.dart`'s content column. **Both** are needed — portal roles never see the super-admin shell.

- [ ] **Step 6: Verify and commit**

```bash
flutter analyze
flutter test
```
```bash
git add lib/features/profile/models/account_deactivation_request.dart lib/features/profile/services/account_deactivation_service.dart lib/features/profile/widgets/deactivate_account_card.dart lib/features/profile/screens/account_security_screen.dart lib/features/profile/screens/profile_screen.dart test/features/deactivate_account_card_test.dart
git commit -m "feat(profile): in-app account deactivation, on both profile surfaces

Mounted on account_security_screen AND profile_screen because portal
roles never see the super-admin shell.

A test asserts the card never uses the word 'delete' anywhere. The
product does not delete, and copy that says otherwise misleads the user
about what happened to their data -- a worse disclosure failure than the
one this set out to fix.

MLD01/MLD02 are branched on by SQLSTATE, never wording."
```

---

## Task 10: `/super-admin/account-deactivations` review queue

**Files:**
- Create: `lib/features/super_admin/screens/account_deactivations_screen.dart`
- Modify: `lib/core/routing/app_router.dart`, `console_sidebar_bridge.dart`, `super_admin_shell_layout.dart`
- Test: `test/features/account_deactivations_screen_test.dart`

**Interfaces:**
- Consumes: `list_account_deactivation_requests(p_status text)`, `review_account_deactivation_request(p_id, p_approve, p_note)`, `reactivate_account(p_user_id)`.
- Produces: route `/super-admin/account-deactivations`.

- [ ] **Step 1: Read the pattern first**

Open `lib/features/super_admin/screens/token_requests_screen.dart` and follow its structure — list/detail, providers, empty state, `MlSemantic.of(context)`. Match it; do not invent a new console screen shape.

- [ ] **Step 2: Write the failing test**

`test/features/account_deactivations_screen_test.dart` — `loadRealFonts()`, widths `[360, 800, 1440]` × scales `[0.85, 1.0, 1.3]`, injected rows so no database is needed, plus these three behavioural cases:

```dart
  testWidgets('renders blocker chips for an owner and an active trip',
      (tester) async {
    await tester.pumpWidget(_host(AccountDeactivationsScreen(rows: [
      AccountDeactivationRow(
        id: 'r1', userId: 'u1', displayName: 'Sipho Ndlovu',
        email: 's@example.test', companyName: 'Iron Hills Mining',
        role: 'driver', status: 'pending',
        requestedAt: DateTime.utc(2026, 8, 19),
        autoApplyAt: DateTime.utc(2026, 9, 18),
        isCompanyOwner: true, activeTrips: 2,
      ),
    ])));
    await tester.pumpAndSettle();
    expect(find.text('Company owner'), findsOneWidget);
    expect(find.text('2 active trips'), findsOneWidget);
  });

  testWidgets('rejecting requires a note', (tester) async {
    await tester.pumpWidget(_host(AccountDeactivationsScreen(rows: [
      AccountDeactivationRow(
        id: 'r1', userId: 'u1', displayName: 'Sipho Ndlovu',
        email: 's@example.test', companyName: 'Iron Hills Mining',
        role: 'driver', status: 'pending',
        requestedAt: DateTime.utc(2026, 8, 19),
        autoApplyAt: DateTime.utc(2026, 9, 18),
        isCompanyOwner: false, activeTrips: 0,
      ),
    ])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Reject request'));
    expect(button.onPressed, isNull, reason: 'empty note must disable Reject');
    expect(find.textContaining('A reason is required'), findsOneWidget);
  });

  testWidgets('a deactivated row offers Reactivate, a pending one does not',
      (tester) async {
    await tester.pumpWidget(_host(AccountDeactivationsScreen(rows: [
      AccountDeactivationRow(
        id: 'r1', userId: 'u1', displayName: 'Sipho Ndlovu',
        email: 's@example.test', companyName: 'Iron Hills Mining',
        role: 'driver', status: 'deactivated',
        requestedAt: DateTime.utc(2026, 8, 19),
        autoApplyAt: DateTime.utc(2026, 9, 18),
        deactivatedAt: DateTime.utc(2026, 8, 20),
        isCompanyOwner: false, activeTrips: 0,
      ),
    ])));
    await tester.pumpAndSettle();
    // Reactivate is the control that makes the whole design honest -- if it
    // is not reachable, "reversible" is a claim nobody can act on.
    expect(find.text('Reactivate'), findsOneWidget);
  });
```

- [ ] **Step 3: Run it, confirm failure, then implement**

Mirror `token_requests_screen.dart`. Requirements:

- A status filter across `pending` / `approved` / `deactivated` / `rejected`.

  🚨 **It must NOT default to `pending`-only** (controller ruling, from Task 8's review). The nightly backstop deliberately *skips* a request whose requester owns a company — that row sits at `approved` forever, and `review_account_deactivation_request` does not prevent an admin approving such a request in the first place. A pending-only default would hide exactly the state that needs a human. **Default to everything except the terminal states** (`deactivated` / `rejected` / `cancelled`), so an `approved`-but-stuck row is on screen by default.

  Render a stuck row so it reads as stuck: an `approved` row whose requester `is_company_owner` gets a distinct chip — *"Blocked — owns a company"* — not the same neutral "approved" treatment as one that is simply waiting for tonight's run. The two look identical in the data and mean opposite things.
- Columns: requester, company, role, requested (via `MlTime.sast`), reason, blocker chips.
- **`Auto-applies in N days`** on pending rows — an admin must be able to see the clock they are not the only thing in front of.
- Actions: Approve, Reject (note required, `MlTone.error`), and on a `deactivated` row **Reactivate** (`MlTone.done`, confirm dialog naming the person).
- Every text cell in a `Row` wrapped in `Flexible`.

- [ ] **Step 4: Register route and sidebar**

```dart
          GoRoute(
            path: '/super-admin/account-deactivations',
            builder: (context, state) => const AccountDeactivationsScreen(),
          ),
```
```dart
  'platform.accountDeactivations': '/super-admin/account-deactivations',
```
```dart
  '/super-admin/account-deactivations': 'platform.accountDeactivations',
```
Plus the `super_admin_shell_layout.dart` nav entry beside Token requests. **Do not clobber the `/super-admin/crash-reports` entries added in Task 4** — both tasks edit these same three files.

- [ ] **Step 5: Verify**

```bash
flutter test test/features/account_deactivations_screen_test.dart
python tool/route_reachability.py
flutter analyze
flutter test
```

- [ ] **Step 6: Commit**

```bash
git add lib/features/super_admin/screens/account_deactivations_screen.dart lib/core/routing/app_router.dart lib/features/super_admin/widgets/sidebar/console_sidebar_bridge.dart lib/features/super_admin/widgets/super_admin_shell_layout.dart test/features/account_deactivations_screen_test.dart
git commit -m "feat(super-admin): account deactivation queue, with Reactivate

Blocker chips surface what the RPC deliberately does not refuse -- an
active trip does not block a request, so the reviewer is the one who
gets to see it.

Reactivate is the control that makes the whole design honest: without a
reachable way back, 'reversible' is a claim nobody can act on. A test
asserts it appears on a deactivated row.

Rows show 'Auto-applies in N days' so an admin knows they are not the
only thing standing between a user and their request."
```

---

## Task 11: `prune_telemetry_job`

**Files:**
- Create: `supabase/migrations/20260819150000_prune_telemetry_job.sql`

**Interfaces:**
- Consumes: `crash_reports` (Task 2), `device_tokens` (Task 5).
- Produces: `prune_telemetry_job(p_crash_keep_days int default 90, p_token_idle_days int default 180) returns int`; cron job `prune-telemetry`.

CLAUDE.md §10.2: *"When adding any high-frequency write path, ship its retention job in the same migration."* Both tables are new write paths and neither had one; one job covers both rather than adding two cron entries for two `delete`s.

### 🚨 This migration also carries four deferred comment corrections (Rulings 10 and 13)

Three earlier findings were deliberately parked here rather than spent on their own migrations — a migration whose entire payload is a corrected comment is noise in the ledger, and **this is the migration that makes them true.** All four go in the same file:

1. **`crash_reports` — "account deletion" → "account deactivation".** Both crash-reports migrations justify `user_id ... on delete set null` as protecting a report from "an account **deletion** (R-1)". R-1 is deactivation now and `deactivate_account` never deletes a `profiles` row, so that sentence describes a path that does not fire. The **column choice is still correct** (SET NULL remains right defensively if a profile is ever deleted by another route) — only the rationale is stale, and the corrected text must say so rather than implying the column was wrong.
2. **`crash_reports` — retention is now present tense.** Its comment currently reads "pruned at 90 days by `prune_telemetry_job()`, added in `20260819150000` — **not yet present as of this migration**." This *is* `20260819150000`. Drop the hedge.
3. **`device_tokens` — same forward reference, but it never got the hedge.** Its comment asserts "Idle tokens are removed at 180 days by `prune_telemetry_job()`" as present-tense fact, which has been false since `20260819090000`. It becomes true here.
4. **`device_tokens` — record the accepted token-reassignment risk.** `register_device_token`'s `on conflict (token) do update set user_id = auth.uid()` lets whoever supplies a raw FCM token claim it. Reviewed and **accepted**: exploitation requires already holding another user's opaque high-entropy token (RLS never exposes it), and the impact is denial of push on that one token rather than disclosure, because `push-fanout` selects tokens by the *notification's* `user_id` and never by the token's claimed owner. The comment must state the accepted risk and that reasoning, so the next reader does not have to re-derive whether it is a hole.

**Rule for whoever writes this:** do not restate a forward reference you are not resolving. Task 2 shipped a comment asserting a function existed when it did not, and it took a review round to catch. If a comment names something, either it exists by the end of this file or the comment says plainly that it does not yet.

- [ ] **Step 1: Write it, batched and bounded**

Copy the shape of `prune_vehicle_positions_job` — a `p_max_rows` cap per run, for the reason written across this repo: an unbounded bulk write on this free-plan instance took Postgres down for two hours on 2026-08-16.

```sql
create or replace function public.prune_telemetry_job(
  p_crash_keep_days int default 90,
  p_token_idle_days int default 180,
  p_max_rows        int default 20000
)
returns int
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare v_n int := 0; v_c int;
begin
  delete from public.crash_reports
   where ctid in (
     select ctid from public.crash_reports
      where created_at < timezone('utc', now()) - make_interval(days => p_crash_keep_days)
      limit p_max_rows
   );
  get diagnostics v_c = row_count; v_n := v_n + v_c;

  delete from public.device_tokens
   where ctid in (
     select ctid from public.device_tokens
      where last_seen_at < timezone('utc', now()) - make_interval(days => p_token_idle_days)
      limit p_max_rows
   );
  get diagnostics v_c = row_count; v_n := v_n + v_c;

  return v_n;
end;
$$;

revoke execute on function public.prune_telemetry_job(int, int, int)
  from public, anon, authenticated;

select cron.unschedule('prune-telemetry')
 where exists (select 1 from cron.job where jobname = 'prune-telemetry');

-- 03:55 UTC, after the deactivation backstop and offset from the rest.
select cron.schedule('prune-telemetry', '55 3 * * *',
                     'select public.prune_telemetry_job()');
```

- [ ] **Step 2: Apply, repoint in its own call, run it once**

```sql
update supabase_migrations.schema_migrations
set version = '20260819150000' where name = 'prune_telemetry_job';
```
```sql
select public.prune_telemetry_job() as pruned;
select jobname, schedule from cron.job order by jobname;
```
Expected: `pruned = 0`, and eleven cron jobs listed.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260819150000_prune_telemetry_job.sql
git commit -m "feat(telemetry): retention for crash_reports and device_tokens

Two new write paths, shipped with their retention rather than without
it -- vehicle_positions was never pruned and reached 40 MB of index on
55 rows before anyone noticed.

Batched and bounded at 20k rows a run, because an unbounded bulk write
on this free-plan instance is what took Postgres down for two hours on
2026-08-16."
```

---

## Task 12: `PushService` and platform wiring

**Files:**
- Create: `lib/core/push/device_token_repository.dart`, `lib/core/push/push_service.dart`
- Create: `docs/push-setup.md`
- Modify: `lib/main.dart`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/AppDelegate.swift`, `ios/Runner/Info.plist`, `.gitignore`
- Test: `test/core/push_service_test.dart`

**Interfaces:**
- Consumes: `register_device_token`, `unregister_device_token`.
- Produces: `PushService.initialise()`, `PushService.registerCurrentDevice()`, `PushService.unregisterCurrentDevice()`; `DeviceTokenRepository.register(token, platform, appVersion)` / `.unregister(token)`.

- [ ] **Step 1: Write the failing test — the degradation property**

The one behaviour that must hold today, with no Firebase project in existence:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/push/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialise() completes and reports unconfigured when Firebase is absent',
      () async {
    final svc = PushService(isConfigured: () => false);
    await expectLater(svc.initialise(), completes);
    expect(svc.isAvailable, isFalse);
  });

  test('registerCurrentDevice() is a no-op when unavailable', () async {
    var called = false;
    final svc = PushService(
      isConfigured: () => false,
      register: (_, __, ___) async => called = true,
    );
    await svc.initialise();
    await svc.registerCurrentDevice();
    expect(called, isFalse);
  });
}
```

- [ ] **Step 2: Run it, confirm failure, implement**

`PushService` takes injectable `isConfigured`, `register`, `unregister` so the degradation path is testable without Firebase. `initialise()` wraps `Firebase.initializeApp()` in try/catch, logs via `LoggerFactory.getLogger('Push')`, and sets `_available = false` on any failure.

The class doc must say why:

```dart
/// Push notifications, and the fact that they are allowed to be absent.
///
/// There is no Firebase project yet. `google-services.json` and
/// `GoogleService-Info.plist` are gitignored and not in this repo, so on every
/// machine and in CI this service initialises into an unavailable state and
/// the app behaves exactly as it did before push existed.
///
/// That is the same contract `PlaceIndexConfig` has for the extras project: a
/// capability that can be missing must degrade, not throw. See docs/push-setup.md
/// for the five artifacts that turn it on.
```

Wire into `main()` after the crash-sink swap, and call `registerCurrentDevice()` on auth sign-in / `unregisterCurrentDevice()` on sign-out via the existing `onAuthStateChange` subscription.

- [ ] **Step 3: Platform config — conditional, never a placeholder credential**

`.gitignore`:
```
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

`android/app/build.gradle.kts` — apply the plugin only when the file exists:

```kotlin
// Conditional on purpose. A committed placeholder google-services.json does
// not degrade -- it breaks the Gradle plugin with an error that reads like a
// build bug -- and a fake file that looks like a credential is the class of
// thing that once shipped a live ArcGIS token (see pubspec.yaml, config/).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
```

Add the matching classpath in `android/build.gradle.kts`, the FCM default-channel `meta-data` in `AndroidManifest.xml`, `UIBackgroundModes` → `remote-notification` in `Info.plist`, and `UNUserNotificationCenter.current().delegate = self` in `AppDelegate.swift`.

- [ ] **Step 4: Write `docs/push-setup.md`**

The five artifacts, each with the console it comes from and where it goes — reproduce the table from spec §3.4 verbatim, then add a "how to verify it worked" section: register a device, insert a test notification, confirm `net._http_response` shows a 200 and the handset rings.

- [ ] **Step 5: Verify and commit**

```bash
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=config/supabase.live.json
```

The web build must still succeed with no Firebase config present. Then:

```bash
git add lib/core/push docs/push-setup.md lib/main.dart android ios .gitignore test/core/push_service_test.dart
git commit -m "feat(push): PushService, platform wiring, and the setup Jean must do

Code-complete and inert. There is no Firebase project, so initialise()
lands in an unavailable state and the app behaves exactly as it did
before push existed -- the same contract PlaceIndexConfig has for a
paused extras project.

No placeholder google-services.json is committed. A fake one does not
degrade, it breaks the Gradle plugin with an error that reads like a
build bug, and a file that looks like a credential is how a live ArcGIS
token shipped once already. The Gradle apply is conditional instead.

docs/push-setup.md lists the five artifacts and how to verify them."
```

---

## Task 13: Full verification sweep and honest status

**Files:**
- Modify: `COMPLETION-CHECKLIST.md`, `CLAUDE.md` (§4 table rows only)

- [ ] **Step 1: Run everything**

```bash
flutter analyze
flutter test
dart run tool/release_guards.dart --selftest
dart run tool/release_guards.dart
python tool/migration_ledger_check.py
python tool/one_clock_check.py
python tool/route_reachability.py
python tool/health_probe.py
```

Record the actual numbers. Any failure is fixed here, not deferred.

- [ ] **Step 2: Cold replay — the only thing that tests the migrations**

```bash
python tool/cold_replay.py --org <org>
```

All six new migrations must apply into an empty project. Expected: exit 0, `bodies` still the expected-different shape, no new deltas. If a new migration fails on cold replay, fix the migration — the stamp ordering trap in CLAUDE.md §6 (a repair's stamp is not the ledger's stamp) applies to anything with a foreign key or an RLS policy calling a function.

- [ ] **Step 3: Verify the ledger matches the files**

```bash
ls supabase/migrations/ | grep -E '^20260819'
```
```sql
select version, name from supabase_migrations.schema_migrations
 where version >= '20260819100000' order by version;
```

Expected: **six** files and **six** rows, stamps identical, in this order — `090000` device_tokens, `100000` account_deactivation_requests, `110000` account_deactivation_apply, `120000` account_deactivation_apply_job, `140000` crash_reports, `150000` prune_telemetry_job. There is deliberately no `130000`.

- [ ] **Step 4: Update the checklists honestly**

- `COMPLETION-CHECKLIST.md`: tick S9-1's open `ASK` (the sink now has a destination), and add the four R-items with what was proven and what was not.
- `CLAUDE.md` §4: add rows for account deactivation and push. Push is **🟡 — it must not be 🟢**: no Firebase project exists, so no FCM delivery has ever happened.
- 🚨 **Record that the store blocker is still open.** R-1 shipped as deactivation on Jean's ruling, and Google Play's User Data policy does not accept deactivation in place of deletion. The checklist must say so in words, next to the R-1 entry. A reader who sees a green R-1 and infers Play compliance has been misled by this document, which is the one failure mode worse than the gap itself.

The §4 rule is explicit: 🟢 means complete frontend **and** backend, wired through the full flow, in proper working state. Push is not that. Marking it 🟢 would be a false claim in the one document agents trust most.

- [ ] **Step 5: Commit**

```bash
git add COMPLETION-CHECKLIST.md CLAUDE.md
git commit -m "docs: record what R-1..R-4 proved, and what they did not

Push is 🟡, not 🟢. There is no Firebase project, so no FCM delivery has
ever happened -- the DB half, the trigger, the edge function and the
Dart half are all verified, and the last mile is not. §4's rule is that
🟢 means the full flow works, and a green marker on an unproven feature
is worth less than an honest amber one."
```

---

## Self-Review

Re-run after R-1 was re-scoped from deletion to deactivation (Jean, 2026-08-19,
mid-planning). Task numbering changed: `device_tokens` moved ahead of the
account work as Task 5, the old Task 7 (`account-deletion` edge function) is
struck, and everything after renumbered. 13 tasks, not 14.

**Spec coverage.** §1 FK finding → Tasks 6/7 headers (kept as the reason a
delete is impossible). §1.1 the ruling → the banner in Global Constraints, and
restated at the head of Tasks 6 and 7. §2.1 flow → Tasks 6–8. §2.2 schema →
Task 6. §2.3 RPCs → Tasks 6–7. §2.4 *no* edge function → nothing to build;
recorded in the identifier table and the File Structure gap note. §2.5 cron →
Task 8. §2.6 UI → Tasks 9–10. §3.1 device_tokens → Task 5. §3.2 delivery →
Task 5. §3.3 Flutter → Task 12. §3.4 credentials → Task 12 Step 4. §4.1
crash_reports → Task 2. §4.2 sink → Task 3. §4.3 reader → Task 4. §5 pubspec +
guards → Task 1. §6 verification → Task 13. Retention (§3.1, §4.1) → Task 11.
**No gaps.**

**Placeholder scan.** Three steps delegate rather than transcribe, each naming
the exact file to copy and listing concrete requirements: Task 4 Step 4 and
Task 10 Step 3 (both mirror `token_requests_screen.dart`), and Task 5 Step 3,
which describes `push-fanout` in prose because the OAuth2 JWT-grant details
depend on a service-account JSON shape nobody here has seen — speculative code
would be worse than four named behaviours. Flagged, not hidden.

**Type consistency.** `AccountDeactivationService` (`current`/`request`/`cancel`)
matches between Task 9's fake and its interface block. `AccountDeactivationRequest`
fields (`status`, `requestedAt`, `autoApplyAt`, `reviewNote`) match across Task 9's
tests, its `_req` helper and the interface. `AccountDeactivationRow` (Task 10) is
a deliberately distinct type carrying `userId`, `isCompanyOwner`, `activeTrips`
and `deactivatedAt` — console-only fields the user's own view must never see;
`userId` is present because Task 10's Reactivate action calls
`reactivate_account(p_user_id)`, not by request id.
`SupabaseReportingSink({postBatch, queueLimit, appVersion})` matches its use in
Task 3 Step 5. `deactivate_account`/`reactivate_account` both return `jsonb` and
neither is consumed for its shape. ✔

**Assumptions the plan flags rather than asserts**, each with a stated fallback:
`insert_audit_log`'s real signature and `trips.vehicle_id` (Task 7 Step 2 note),
and `app.settings.service_role_key` for the push trigger (Task 5). Two
assumptions from the deletion design are **gone**, not resolved: the `\gset`
question disappeared with the scrub probe (Task 7's cycle probe is a single
`do $$` block), and `app.settings.service_role_key` is no longer needed by the
cron backstop, which is now plain SQL.

**What the re-scope removed:** one edge function, one migration, the storage
purge, the `pg_net` round trip in the backstop, and every `UPDATE` that nulled a
personal-data column. **What it added:** `reactivate_account`, two columns
recording who reversed a deactivation and when, and a test asserting the user-
facing card never says "delete".

---

Plan complete and saved to `docs/superpowers/plans/2026-08-19-release-hardening.md`.
