# Company Chat Links Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **NOTE (this project):** the user forbids subagents — execute inline via superpowers:executing-plans.

**Goal:** Make super-admin company chat-linking 100% manual with an org-type-grouped two-sided selector, a request-driven recommendations panel (with date + reason), connected/history lists, clickable company names → profile, and a link-for-chat section on each company's profile.

**Architecture:** Remove the DB auto-link triggers and wipe existing links (manual-only). Add a live-derived `businessPairsProvider` (pairs + reason + date from accepted requests/dispatches/transactions) with no schema change. Rebuild `chat_connections_screen.dart` around a reusable `CompanyLinkBuilder` selector and `CompanyNameLink` widget; add a Chat-connections section to `organization_detail_screen.dart`.

**Tech Stack:** Flutter (Material 3), Riverpod, Supabase (Postgres + RLS), go_router, `MlTokens`/`MlSemantic`/`MlTone`/`Ml*` design system.

## Global Constraints

- Package name is `flutter_application_1`; all imports use `package:flutter_application_1/...`. Never rename.
- No raw `Color(0x...)` or magic numbers in feature code — use `MlTokens`, `MlSemantic.of(context)`, `MlTone`, and existing `Ml*` widgets.
- DB access only through a service/repository (never `SupabaseConfig.client` from screens/providers). Follow `SuperAdminRepository` pattern.
- Logging via `LoggerFactory.getLogger('Scope')`, not `print`.
- Enums/wire strings: accepted request statuses are `'accepted'` and `'dispatched'`; connection statuses are `'granted'` and `'revoked'`.
- Company org types: `'mineSupplier'`, `'buyer'`, `'transporter'` (label: Mine / Supplier, Buyer, Transporter; unknown → Company).
- Org profile route: `context.go('/super-admin/organization/$orgId')` (defined in `app_router.dart`).
- Run `flutter analyze` (must stay clean) and `flutter test` before considering any task done.
- Supabase MCP connector is NOT authorized in this session — write the migration file, but it must be applied by the user in an authorized session. Do not claim it is applied.

---

### Task 1: DB migration — stop auto-linking and wipe existing links

**Files:**
- Create: `supabase/migrations/20260714120000_manual_only_chat_links.sql`

**Interfaces:**
- Consumes: nothing (schema-level).
- Produces: `org_connections` populated only by manual `grantConnection`; no triggers on `transactions`/`request_dispatches`.

- [ ] **Step 1: Verify `chat_connect_orgs` has no other callers**

Run: search for remaining references before dropping the helper.
```
Grep pattern: chat_connect_orgs  path: supabase/migrations
```
Expected: only `20260713060000_auto_connect_business_parties.sql` references it. If any other migration calls it, keep the function and drop only the triggers.

- [ ] **Step 2: Write the migration**

Create `supabase/migrations/20260714120000_manual_only_chat_links.sql`:
```sql
-- Manual-only chat links (Jean, 2026-07-14).
-- Reverses 20260713060000_auto_connect_business_parties.sql: companies must NOT
-- be chat-linked automatically when they do business. The super global admin
-- links every pair by hand. Also wipe existing links so the Connected list
-- starts clean (auto vs manual is not distinguishable, and the product intent
-- is a from-scratch manual build).

-- 1. Remove the auto-connect triggers.
drop trigger if exists connect_transaction_parties on public.transactions;
drop trigger if exists connect_dispatch_parties on public.request_dispatches;

-- 2. Remove the trigger functions and the shared helper (helper is only used by
--    the dropped triggers — confirmed 2026-07-14).
drop function if exists public.trg_connect_transaction_parties();
drop function if exists public.trg_connect_dispatch_parties();
drop function if exists public.chat_connect_orgs(uuid, uuid, uuid);

-- 3. Start clean: remove every existing connection row.
delete from public.org_connections;
```

- [ ] **Step 3: Commit**
```bash
git add supabase/migrations/20260714120000_manual_only_chat_links.sql
git commit -m "feat(chat-links): manual-only chat links — drop auto-connect triggers, wipe existing"
```

- [ ] **Step 4: Application note (do NOT mark applied)**

Add a line to the PR/commit body: migration must be applied by the user via Supabase MCP `apply_migration` or dashboard (connector unauthorized in dev session). After application, verify with: `select count(*) from public.org_connections;` → `0`, and that inserting a dispatch/transaction adds no connection row.

---

### Task 2: `businessPairsProvider` — live-derived recommendation pairs

**Files:**
- Create: `lib/features/super_admin/data/models/business_pair.dart`
- Modify: `lib/features/super_admin/data/repositories/super_admin_repository.dart` (add `getBusinessPairs()`)
- Modify: `lib/features/super_admin/providers/super_admin_providers.dart` (add provider)
- Test: `test/features/super_admin/business_pair_test.dart`

**Interfaces:**
- Produces:
  - `class BusinessPair { final String companyIdA; final String companyIdB; final DateTime date; final String reason; String get key; }` where `key` = `min(id)|max(id)` (matches `org_connections` low/high ordering).
  - `List<BusinessPair> buildBusinessPairs(List<Map<String,dynamic>> requests, List<Map<String,dynamic>> dispatches, List<Map<String,dynamic>> transactions)` — pure function, most-recent-wins per pair key.
  - `Future<List<BusinessPair>> SuperAdminRepository.getBusinessPairs()`.
  - `final businessPairsProvider = FutureProvider<List<BusinessPair>>(...)`.

- [ ] **Step 1: Write the failing test**

Create `test/features/super_admin/business_pair_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/super_admin/data/models/business_pair.dart';

void main() {
  test('derives buyer<->supplier pair from an accepted request with reason', () {
    final pairs = buildBusinessPairs(
      [
        {
          'id': 'r1',
          'status': 'accepted',
          'buyer_company_id': 'B',
          'supplier_company_id': 'A',
          'commodity': 'Chrome',
          'tons': '40000',
          'updated_at': '2026-07-12T10:00:00Z',
        },
      ],
      const [],
      const [],
    );
    expect(pairs, hasLength(1));
    expect(pairs.first.key, 'A|B');
    expect(pairs.first.reason, contains('transport request'));
    expect(pairs.first.reason, contains('Chrome'));
  });

  test('ignores non-accepted requests and self/null pairs', () {
    final pairs = buildBusinessPairs(
      [
        {'id': 'r1', 'status': 'submitted', 'buyer_company_id': 'B', 'supplier_company_id': 'A'},
        {'id': 'r2', 'status': 'accepted', 'buyer_company_id': 'A', 'supplier_company_id': 'A'},
        {'id': 'r3', 'status': 'accepted', 'buyer_company_id': 'B', 'supplier_company_id': null},
      ],
      const [], const [],
    );
    expect(pairs, isEmpty);
  });

  test('most recent source wins for the same pair', () {
    final pairs = buildBusinessPairs(
      [
        {'id': 'r1', 'status': 'accepted', 'buyer_company_id': 'B', 'supplier_company_id': 'A', 'updated_at': '2026-07-10T00:00:00Z'},
      ],
      [
        {'id': 'd1', 'status': 'accepted', 'transporter_company_id': 'A', 'request_buyer_company_id': 'B', 'dispatched_at': '2026-07-13T00:00:00Z'},
      ],
      const [],
    );
    // pair A|B appears from both; keeps the later dispatch date.
    final ab = pairs.firstWhere((p) => p.key == 'A|B');
    expect(ab.date.toUtc().toIso8601String(), '2026-07-13T00:00:00.000Z');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/super_admin/business_pair_test.dart`
Expected: FAIL — `business_pair.dart` / `buildBusinessPairs` not found.

- [ ] **Step 3: Implement the model + pure builder**

Create `lib/features/super_admin/data/models/business_pair.dart`:
```dart
/// A company pair implied by accepted business (request / dispatch / transaction),
/// with the date they were tied together and a human reason. Derived live — no
/// DB column stores this. `key` matches org_connections' low<high ordering so it
/// can be compared against existing connections.
class BusinessPair {
  final String companyIdA; // low
  final String companyIdB; // high
  final DateTime date;
  final String reason;

  const BusinessPair({
    required this.companyIdA,
    required this.companyIdB,
    required this.date,
    required this.reason,
  });

  String get key => '$companyIdA|$companyIdB';
}

DateTime _parseDate(dynamic v) {
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v)?.toUtc() ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

String? _s(dynamic v) => (v is String && v.trim().isNotEmpty) ? v.trim() : null;

void _add(Map<String, BusinessPair> out, String? a, String? b, DateTime date, String reason) {
  if (a == null || b == null || a == b) return;
  final low = a.compareTo(b) < 0 ? a : b;
  final high = a.compareTo(b) < 0 ? b : a;
  final key = '$low|$high';
  final existing = out[key];
  if (existing == null || date.isAfter(existing.date)) {
    out[key] = BusinessPair(companyIdA: low, companyIdB: high, date: date, reason: reason);
  }
}

/// Pure derivation — most-recent source wins per pair.
List<BusinessPair> buildBusinessPairs(
  List<Map<String, dynamic>> requests,
  List<Map<String, dynamic>> dispatches,
  List<Map<String, dynamic>> transactions,
) {
  final out = <String, BusinessPair>{};

  for (final r in requests) {
    final status = _s(r['status']);
    if (status != 'accepted' && status != 'dispatched') continue;
    final commodity = _s(r['commodity']) ?? 'product';
    final tons = _s(r['tons']);
    final reason = 'Accepted transport request — $commodity'
        '${tons != null ? ' ($tons t)' : ''}';
    _add(out, _s(r['buyer_company_id']), _s(r['supplier_company_id']),
        _parseDate(r['updated_at'] ?? r['created_at']), reason);
  }

  for (final d in dispatches) {
    final date = _parseDate(d['dispatched_at']);
    const reason = 'Route dispatch to transporter';
    _add(out, _s(d['transporter_company_id']), _s(d['request_buyer_company_id']), date, reason);
    _add(out, _s(d['transporter_company_id']), _s(d['request_supplier_company_id']), date, reason);
    _add(out, _s(d['request_buyer_company_id']), _s(d['request_supplier_company_id']), date, reason);
  }

  for (final t in transactions) {
    final date = _parseDate(t['created_at']);
    const reason = 'Active transaction between parties';
    final s = _s(t['supplier_company_id']);
    final b = _s(t['buyer_company_id']);
    final tr = _s(t['transporter_company_id']);
    _add(out, s, b, date, reason);
    _add(out, s, tr, date, reason);
    _add(out, b, tr, date, reason);
  }

  final list = out.values.toList()..sort((x, y) => y.date.compareTo(x.date));
  return list;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/super_admin/business_pair_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Add the repository method**

In `lib/features/super_admin/data/repositories/super_admin_repository.dart`, add (match the file's existing method style and `_client` field name — read the file first to confirm the client field is named `_client`):
```dart
/// Company pairs implied by accepted business, for the chat-link recommendations
/// panel. Returns most-recent-wins pairs (see [buildBusinessPairs]).
Future<List<BusinessPair>> getBusinessPairs() async {
  final requests = await _client
      .from('transportation_requests')
      .select('id,status,buyer_company_id,supplier_company_id,commodity,tons,updated_at,created_at')
      .inFilter('status', ['accepted', 'dispatched']);

  // Dispatch rows joined to their request's buyer/supplier via a nested select.
  final dispatchRows = await _client
      .from('request_dispatches')
      .select('id,status,transporter_company_id,dispatched_at,'
          'transportation_requests(buyer_company_id,supplier_company_id)');
  final dispatches = [
    for (final d in (dispatchRows as List))
      {
        ...Map<String, dynamic>.from(d as Map),
        'request_buyer_company_id':
            (d['transportation_requests'] as Map?)?['buyer_company_id'],
        'request_supplier_company_id':
            (d['transportation_requests'] as Map?)?['supplier_company_id'],
      }
  ];

  List<Map<String, dynamic>> transactions = const [];
  try {
    final tx = await _client
        .from('transactions')
        .select('supplier_company_id,buyer_company_id,transporter_company_id,created_at');
    transactions = [for (final t in (tx as List)) Map<String, dynamic>.from(t as Map)];
  } catch (_) {
    // transactions table/columns optional — recommendations still work without it.
  }

  return buildBusinessPairs(
    [for (final r in (requests as List)) Map<String, dynamic>.from(r as Map)],
    dispatches,
    transactions,
  );
}
```
Add the import at the top of the repository file:
```dart
import '../models/business_pair.dart';
```
(If `models/models.dart` is a barrel, also export `business_pair.dart` from it.)

- [ ] **Step 6: Add the provider**

In `lib/features/super_admin/providers/super_admin_providers.dart` add:
```dart
import '../data/models/business_pair.dart';

/// Company pairs implied by accepted business — feeds the chat-link
/// recommendations panel and annotates "why" on connected cards.
final businessPairsProvider = FutureProvider<List<BusinessPair>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getBusinessPairs();
});
```

- [ ] **Step 7: Analyze + commit**

Run: `flutter analyze` → clean. Then:
```bash
git add lib/features/super_admin/data/models/business_pair.dart lib/features/super_admin/data/repositories/super_admin_repository.dart lib/features/super_admin/providers/super_admin_providers.dart test/features/super_admin/business_pair_test.dart
git commit -m "feat(chat-links): live-derived business pairs for chat-link recommendations"
```

---

### Task 3: `CompanyNameLink` widget — clickable name → profile

**Files:**
- Create: `lib/features/super_admin/widgets/company_name_link.dart`
- Test: `test/features/super_admin/company_name_link_test.dart`

**Interfaces:**
- Produces: `class CompanyNameLink extends StatelessWidget { const CompanyNameLink({required String companyId, required String name, TextStyle? style, ...}); }` — renders `name` in accent link style; on tap `context.go('/super-admin/organization/$companyId')`.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/super_admin/company_name_link_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_name_link.dart';

void main() {
  testWidgets('tapping a CompanyNameLink navigates to the org profile route', (tester) async {
    String? landed;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (c, s) => const Scaffold(
        body: CompanyNameLink(companyId: 'org-123', name: 'Acme Mine'))),
      GoRoute(path: '/super-admin/organization/:id', builder: (c, s) {
        landed = s.pathParameters['id'];
        return const Scaffold(body: Text('profile'));
      }),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Acme Mine'));
    await tester.pumpAndSettle();
    expect(landed, 'org-123');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/super_admin/company_name_link_test.dart`
Expected: FAIL — `company_name_link.dart` not found.

- [ ] **Step 3: Implement the widget**

Create `lib/features/super_admin/widgets/company_name_link.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

/// A company name rendered as a link. Tapping navigates the super-admin to that
/// company's profile (`/super-admin/organization/:id`).
class CompanyNameLink extends StatelessWidget {
  final String companyId;
  final String name;
  final TextStyle? style;

  const CompanyNameLink({
    super.key,
    required this.companyId,
    required this.name,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final base = (style ?? const TextStyle()).copyWith(
      color: MlTokens.accent,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: MlTokens.accent,
    );
    return InkWell(
      onTap: () => context.go('/super-admin/organization/$companyId'),
      child: Text(name, overflow: TextOverflow.ellipsis, style: base),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/super_admin/company_name_link_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze` → clean.
```bash
git add lib/features/super_admin/widgets/company_name_link.dart test/features/super_admin/company_name_link_test.dart
git commit -m "feat(chat-links): CompanyNameLink — clickable company name to profile"
```

---

### Task 4: `CompanyLinkBuilder` — two-sided org-type-grouped selector

**Files:**
- Create: `lib/features/super_admin/widgets/company_link_builder.dart`
- Test: `test/features/super_admin/company_link_builder_test.dart`

**Interfaces:**
- Consumes: `organizationsProvider` value (list of maps: `id`, `company_name`, `org_type`), `messagingServiceProvider.grantConnection`, `orgConnectionsProvider`.
- Produces:
  - `String companyOrgTypeLabel(String? orgType)` (top-level helper, reused by the screen).
  - `class CompanyLinkBuilder extends ConsumerStatefulWidget { const CompanyLinkBuilder({required List<Map<String,dynamic>> companies, String? lockedLeftCompanyId, VoidCallback? onLinked}); }` — renders the two grouped lists, the live "Connect **X** to **Y** via MineLink Messenger" sentence, and a Connect button that calls `grantConnection` then invalidates `orgConnectionsProvider` and calls `onLinked`.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/super_admin/company_link_builder_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_link_builder.dart';

void main() {
  test('companyOrgTypeLabel maps org types to display labels', () {
    expect(companyOrgTypeLabel('mineSupplier'), 'Mine / Supplier');
    expect(companyOrgTypeLabel('buyer'), 'Buyer');
    expect(companyOrgTypeLabel('transporter'), 'Transporter');
    expect(companyOrgTypeLabel('weird'), 'Company');
    expect(companyOrgTypeLabel(null), 'Company');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/super_admin/company_link_builder_test.dart`
Expected: FAIL — file not found.

- [ ] **Step 3: Implement the builder**

Create `lib/features/super_admin/widgets/company_link_builder.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

String companyOrgTypeLabel(String? orgType) {
  switch (orgType) {
    case 'mineSupplier':
      return 'Mine / Supplier';
    case 'buyer':
      return 'Buyer';
    case 'transporter':
      return 'Transporter';
    default:
      return 'Company';
  }
}

const _orgTypeOrder = ['mineSupplier', 'buyer', 'transporter'];

/// Two-sided, org-type-grouped company selector. Pick one company on the left
/// and one on the right; the sentence reads "Connect X to Y via MineLink
/// Messenger" and Connect grants the chat link. When [lockedLeftCompanyId] is
/// set, the left side is fixed (used from a company's profile page).
class CompanyLinkBuilder extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> companies;
  final String? lockedLeftCompanyId;
  final VoidCallback? onLinked;

  const CompanyLinkBuilder({
    super.key,
    required this.companies,
    this.lockedLeftCompanyId,
    this.onLinked,
  });

  @override
  ConsumerState<CompanyLinkBuilder> createState() => _CompanyLinkBuilderState();
}

class _CompanyLinkBuilderState extends ConsumerState<CompanyLinkBuilder> {
  String? _left;
  String? _right;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _left = widget.lockedLeftCompanyId;
  }

  String _nameOf(String id) {
    final c = widget.companies.firstWhere(
      (e) => e['id'] == id,
      orElse: () => const {'company_name': 'Company'},
    );
    final n = (c['company_name'] as String?)?.trim();
    return (n != null && n.isNotEmpty) ? n : 'Company';
  }

  Future<void> _connect() async {
    final a = _left, b = _right;
    if (a == null || b == null || a == b) return;
    setState(() => _busy = true);
    try {
      await ref.read(messagingServiceProvider).grantConnection(a, b);
      ref.invalidate(orgConnectionsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_nameOf(a)} and ${_nameOf(b)} are now connected in chat.')),
      );
      setState(() {
        if (widget.lockedLeftCompanyId == null) _left = null;
        _right = null;
      });
      widget.onLinked?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final canConnect = _left != null && _right != null && _left != _right && !_busy;

    Widget column({
      required String title,
      required String? selected,
      required String? exclude,
      required bool locked,
      required ValueChanged<String> onPick,
    }) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: semantic.surfaceCard,
            borderRadius: BorderRadius.circular(MlTokens.rXl),
            border: Border.all(color: semantic.borderCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: semantic.textFaint)),
              const SizedBox(height: 8),
              _GroupedCompanyList(
                companies: widget.companies,
                selectedId: selected,
                excludeId: exclude,
                enabled: !locked,
                onPick: onPick,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(builder: (context, c) {
          final side = <Widget>[
            column(
              title: 'First company',
              selected: _left,
              exclude: _right,
              locked: widget.lockedLeftCompanyId != null,
              onPick: (id) => setState(() => _left = id),
            ),
            const SizedBox(width: 12, height: 12),
            column(
              title: 'Second company',
              selected: _right,
              exclude: _left,
              locked: false,
              onPick: (id) => setState(() => _right = id),
            ),
          ];
          return c.maxWidth < 640
              ? Column(children: [side[0], side[1], side[2]])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: side);
        }),
        const SizedBox(height: 14),
        RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 14, color: semantic.textStrong),
            children: [
              const TextSpan(text: 'Connect '),
              TextSpan(
                text: _left != null ? _nameOf(_left!) : '…',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              const TextSpan(text: ' to '),
              TextSpan(
                text: _right != null ? _nameOf(_right!) : '…',
                style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(
                text: ' via MineLink Messenger',
                style: TextStyle(color: semantic.textFaint)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MlButton.primary(
          label: 'Connect via MineLink Messenger',
          icon: Icons.hub_outlined,
          compact: true,
          onPressed: canConnect ? _connect : null,
        ),
      ],
    );
  }
}

/// A scrollable list of companies grouped under org-type headers, single-select.
class _GroupedCompanyList extends StatelessWidget {
  final List<Map<String, dynamic>> companies;
  final String? selectedId;
  final String? excludeId;
  final bool enabled;
  final ValueChanged<String> onPick;

  const _GroupedCompanyList({
    required this.companies,
    required this.selectedId,
    required this.excludeId,
    required this.enabled,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final c in companies) {
      if (c['id'] == excludeId) continue;
      final t = (c['org_type'] as String?) ?? 'other';
      groups.putIfAbsent(t, () => []).add(c);
    }
    final orderedTypes = [
      ..._orgTypeOrder.where(groups.containsKey),
      ...groups.keys.where((t) => !_orgTypeOrder.contains(t)),
    ];

    return SizedBox(
      height: 220,
      child: ListView(
        children: [
          for (final t in orderedTypes) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Text(
                companyOrgTypeLabel(t == 'other' ? null : t).toUpperCase(),
                style: TextStyle(
                  fontSize: 11, letterSpacing: 0.6,
                  fontWeight: FontWeight.w800, color: semantic.textFaint),
              ),
            ),
            for (final c in groups[t]!)
              _CompanyRow(
                name: (c['company_name'] as String?)?.trim().isNotEmpty == true
                    ? c['company_name'] as String
                    : 'Company',
                selected: c['id'] == selectedId,
                enabled: enabled,
                onTap: () => onPick(c['id'] as String),
              ),
          ],
        ],
      ),
    );
  }
}

class _CompanyRow extends StatelessWidget {
  final String name;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _CompanyRow({
    required this.name,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: selected ? MlTokens.accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(
              color: selected ? MlTokens.accent : semantic.borderCard,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 16,
                color: selected ? MlTokens.accent : semantic.textFaint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: semantic.textStrong,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

> Before implementing, confirm `MlTokens.rMd` exists (read `ml_tokens.dart`); if the radius token is named differently, use the nearest existing small radius token. Confirm `Color.withValues` is available (Flutter 3.8+) — it is per the SDK floor; otherwise use `.withOpacity`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/super_admin/company_link_builder_test.dart`
Expected: PASS (the label helper test).

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze` → clean.
```bash
git add lib/features/super_admin/widgets/company_link_builder.dart test/features/super_admin/company_link_builder_test.dart
git commit -m "feat(chat-links): CompanyLinkBuilder two-sided org-type-grouped selector"
```

---

### Task 5: Rebuild `chat_connections_screen.dart`

**Files:**
- Modify (rewrite): `lib/features/super_admin/screens/chat_connections_screen.dart`

**Interfaces:**
- Consumes: `organizationsProvider`, `orgConnectionsProvider`, `businessPairsProvider`, `messagingServiceProvider`, `CompanyLinkBuilder`, `CompanyNameLink`, `companyOrgTypeLabel`, `BusinessPair`, `OrgConnection`.

- [ ] **Step 1: Rewrite the screen**

Replace the whole file with the four-section layout. Full file:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/super_admin/data/models/business_pair.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_link_builder.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_name_link.dart';

/// Super-admin screen for manually linking companies in chat. Linking is 100%
/// manual (auto-linking was removed 2026-07-14). Four sections: the two-sided
/// grouped Connect builder, request-driven Recommendations, the live Connected
/// list, and revoked History.
class ChatConnectionsScreen extends ConsumerStatefulWidget {
  const ChatConnectionsScreen({super.key});

  @override
  ConsumerState<ChatConnectionsScreen> createState() => _ChatConnectionsScreenState();
}

class _ChatConnectionsScreenState extends ConsumerState<ChatConnectionsScreen> {
  static final _dateFmt = DateFormat('dd MMM yyyy · HH:mm');
  bool _busy = false;

  Future<void> _grant(String a, String b, String okMsg) =>
      _run(() => ref.read(messagingServiceProvider).grantConnection(a, b), okMsg);

  Future<void> _revoke(OrgConnection conn, String aName, String bName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke chat link'),
        content: Text(
          '$aName and $bName will no longer see each other in chat, and existing '
          'conversations between them become unavailable. You can grant the link again later.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke link'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => ref.read(messagingServiceProvider).revokeConnection(conn.id), 'Chat link revoked.');
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(orgConnectionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMessage)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final companies = ref.watch(organizationsProvider).valueOrNull ?? const [];
    final connectionsAsync = ref.watch(orgConnectionsProvider);
    final pairsAsync = ref.watch(businessPairsProvider);

    final nameById = <String, String>{
      for (final c in companies)
        (c['id'] as String): (c['company_name'] as String?)?.trim().isNotEmpty == true
            ? c['company_name'] as String
            : 'Unknown company',
    };
    final orgTypeById = <String, String?>{
      for (final c in companies) (c['id'] as String): c['org_type'] as String?,
    };
    String nameOf(String id) => nameById[id] ?? 'Company ${id.length >= 6 ? id.substring(0, 6) : id}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(semantic),
          const SizedBox(height: 16),
          // 1. Connect builder.
          _sectionTitle(semantic, 'Connect two companies'),
          const SizedBox(height: 10),
          if (companies.length < 2)
            _hintCard(semantic, 'Add at least two companies to create a chat link.')
          else
            CompanyLinkBuilder(companies: companies),
          const SizedBox(height: 28),
          // 2. Recommendations from accepted requests.
          _sectionTitle(semantic, 'Recommended from accepted requests'),
          const SizedBox(height: 4),
          Text(
            'Companies tied together by an accepted request or transaction. They are '
            'NOT linked automatically — review and connect the ones you want.',
            style: TextStyle(fontSize: 12.5, color: semantic.textFaint),
          ),
          const SizedBox(height: 10),
          _recommendations(semantic, pairsAsync, connectionsAsync.valueOrNull ?? const [], nameOf, orgTypeById),
          const SizedBox(height: 28),
          // 3 + 4. Connected + History.
          connectionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator())),
            error: (e, _) => MlEmptyState(
              icon: Icons.error_outline, title: 'Could not load chat links', message: '$e'),
            data: (connections) => _connectedAndHistory(
                semantic, connections, nameOf, orgTypeById),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header(MlSemantic semantic) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Company chat links',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSerif, fontSize: 19,
                      fontWeight: FontWeight.w500, color: semantic.textStrong)),
                const SizedBox(height: 4),
                Text(
                  'Manually connect two companies so their people can message each '
                  'other in MineLink Messenger. Company names link to their profiles.',
                  style: TextStyle(fontSize: 13, color: semantic.textFaint)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(orgConnectionsProvider);
              ref.invalidate(businessPairsProvider);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );

  Widget _sectionTitle(MlSemantic semantic, String text) => Text(text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: semantic.textStrong));

  Widget _hintCard(MlSemantic semantic, String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: semantic.surfaceCard,
          borderRadius: BorderRadius.circular(MlTokens.rXl),
          border: Border.all(color: semantic.borderCard),
        ),
        child: Text(message, style: TextStyle(fontSize: 13, color: semantic.textFaint)),
      );

  Widget _recommendations(
    MlSemantic semantic,
    AsyncValue<List<BusinessPair>> pairsAsync,
    List<OrgConnection> connections,
    String Function(String) nameOf,
    Map<String, String?> orgTypeById,
  ) {
    final connectedKeys = {
      for (final c in connections.where((c) => !c.isRevoked))
        '${c.companyLowId}|${c.companyHighId}'
    };
    return pairsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator())),
      error: (e, _) => _hintCard(semantic, 'Could not load recommendations: $e'),
      data: (pairs) {
        final open = pairs.where((p) => !connectedKeys.contains(p.key)).toList();
        if (open.isEmpty) {
          return _hintCard(semantic,
              'No new recommendations — every business pair is already connected or none exist yet.');
        }
        return Column(
          children: [
            for (final p in open) ...[
              _RecommendationCard(
                semantic: semantic,
                pair: p,
                aName: nameOf(p.companyIdA),
                bName: nameOf(p.companyIdB),
                aType: companyOrgTypeLabel(orgTypeById[p.companyIdA]),
                bType: companyOrgTypeLabel(orgTypeById[p.companyIdB]),
                dateFmt: _dateFmt,
                busy: _busy,
                onConnect: () => _grant(p.companyIdA, p.companyIdB,
                    '${nameOf(p.companyIdA)} and ${nameOf(p.companyIdB)} are now connected in chat.'),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _connectedAndHistory(
    MlSemantic semantic,
    List<OrgConnection> connections,
    String Function(String) nameOf,
    Map<String, String?> orgTypeById,
  ) {
    final active = connections.where((c) => !c.isRevoked).toList()
      ..sort((a, b) => nameOf(a.companyLowId).toLowerCase().compareTo(nameOf(b.companyLowId).toLowerCase()));
    final revoked = connections.where((c) => c.isRevoked).toList()
      ..sort((a, b) => (b.revokedAt ?? DateTime(0)).compareTo(a.revokedAt ?? DateTime(0)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(semantic, 'Connected  ·  ${active.length}'),
        const SizedBox(height: 10),
        if (active.isEmpty)
          _hintCard(semantic, 'No active chat links yet. Connect two companies above.')
        else
          for (final conn in active) ...[
            _ConnectionCard(
              semantic: semantic, conn: conn, revoked: false, dateFmt: _dateFmt, busy: _busy,
              aId: conn.companyLowId, bId: conn.companyHighId,
              aName: nameOf(conn.companyLowId), bName: nameOf(conn.companyHighId),
              aType: companyOrgTypeLabel(orgTypeById[conn.companyLowId]),
              bType: companyOrgTypeLabel(orgTypeById[conn.companyHighId]),
              onAction: () => _revoke(conn, nameOf(conn.companyLowId), nameOf(conn.companyHighId)),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 24),
        _sectionTitle(semantic, 'History — revoked  ·  ${revoked.length}'),
        const SizedBox(height: 10),
        if (revoked.isEmpty)
          _hintCard(semantic, 'No revoked links.')
        else
          for (final conn in revoked) ...[
            _ConnectionCard(
              semantic: semantic, conn: conn, revoked: true, dateFmt: _dateFmt, busy: _busy,
              aId: conn.companyLowId, bId: conn.companyHighId,
              aName: nameOf(conn.companyLowId), bName: nameOf(conn.companyHighId),
              aType: companyOrgTypeLabel(orgTypeById[conn.companyLowId]),
              bType: companyOrgTypeLabel(orgTypeById[conn.companyHighId]),
              onAction: () => _grant(conn.companyLowId, conn.companyHighId, 'Chat link granted again.'),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final MlSemantic semantic;
  final BusinessPair pair;
  final String aName, bName, aType, bType;
  final DateFormat dateFmt;
  final bool busy;
  final VoidCallback onConnect;

  const _RecommendationCard({
    required this.semantic,
    required this.pair,
    required this.aName,
    required this.bName,
    required this.aType,
    required this.bType,
    required this.dateFmt,
    required this.busy,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: CompanyNameLink(companyId: pair.companyIdA, name: aName)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.sync_alt_rounded, size: 16, color: semantic.textFaint)),
              Flexible(child: CompanyNameLink(companyId: pair.companyIdB, name: bName)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$aType  ·  $bType',
              style: TextStyle(fontSize: 12.5, color: semantic.textFaint)),
          const SizedBox(height: 6),
          Text(pair.reason,
              style: TextStyle(fontSize: 13, color: semantic.textStrong)),
          const SizedBox(height: 2),
          Text('Tied together ${dateFmt.format(pair.date.toLocal())}',
              style: TextStyle(fontSize: 12, color: semantic.textFaint)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: MlButton.primary(
              label: 'Connect via MineLink Messenger',
              icon: Icons.link_rounded,
              compact: true,
              onPressed: busy ? null : onConnect,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final MlSemantic semantic;
  final OrgConnection conn;
  final bool revoked;
  final String aId, bId, aName, bName, aType, bType;
  final DateFormat dateFmt;
  final bool busy;
  final VoidCallback onAction;

  const _ConnectionCard({
    required this.semantic,
    required this.conn,
    required this.revoked,
    required this.aId,
    required this.bId,
    required this.aName,
    required this.bName,
    required this.aType,
    required this.bType,
    required this.dateFmt,
    required this.busy,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final when = revoked ? conn.revokedAt : conn.grantedAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: CompanyNameLink(companyId: aId, name: aName)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.sync_alt_rounded, size: 16, color: semantic.textFaint)),
                    Flexible(child: CompanyNameLink(companyId: bId, name: bName)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$aType  ·  $bType'
                  '${when != null ? '  ·  ${revoked ? 'Revoked' : 'Linked'} ${dateFmt.format(when.toLocal())}' : ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: semantic.textFaint)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          MlStatusBadge(
            label: revoked ? 'Revoked' : 'Connected',
            tone: revoked ? MlTone.error : MlTone.done),
          const SizedBox(width: 10),
          if (revoked)
            MlButton.go(
              label: 'Grant again', icon: Icons.link_rounded, compact: true,
              onPressed: busy ? null : onAction)
          else
            MlButton.danger(
              label: 'Revoke', icon: Icons.link_off_rounded, compact: true,
              onPressed: busy ? null : onAction),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/super_admin/screens/chat_connections_screen.dart`
Expected: no errors. Fix any token-name mismatches (e.g. `MlTokens.rXl`, `MlTokens.fontSerif`) against `ml_tokens.dart`.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: all green (no regressions).

- [ ] **Step 4: Commit**
```bash
git add lib/features/super_admin/screens/chat_connections_screen.dart
git commit -m "feat(chat-links): rebuild screen — builder, recommendations, connected, history"
```

---

### Task 6: Add "Chat connections" section to the company profile

**Files:**
- Modify: `lib/features/super_admin/screens/organization_detail_screen.dart`

**Interfaces:**
- Consumes: `orgConnectionsProvider`, `organizationsProvider`, `businessPairsProvider` (optional), `CompanyLinkBuilder`, `CompanyNameLink`, `companyOrgTypeLabel`, `messagingServiceProvider`.

- [ ] **Step 1: Read the screen to find the insertion point**

Read `organization_detail_screen.dart` and locate where the org's detail body sections are laid out (a `Column`/`ListView` of section cards, keyed off `organizationId`). Identify the variable holding the current org id (the widget field `organizationId`) and the company list for the picker.

- [ ] **Step 2: Add a Chat-connections section widget**

Add a private `ConsumerWidget` in the file (or a section builder method) that renders:
```dart
// Pseudocode-anchored real code — adapt names to the file's existing section style.
class _ChatConnectionsSection extends ConsumerWidget {
  final String orgId;
  const _ChatConnectionsSection({required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final companies = ref.watch(organizationsProvider).valueOrNull ?? const [];
    final connections = ref.watch(orgConnectionsProvider).valueOrNull ?? const [];
    String nameOf(String id) {
      final c = companies.firstWhere((e) => e['id'] == id, orElse: () => const {'company_name': 'Company'});
      final n = (c['company_name'] as String?)?.trim();
      return (n != null && n.isNotEmpty) ? n : 'Company';
    }
    String? typeOf(String id) {
      final c = companies.firstWhere((e) => e['id'] == id, orElse: () => const {});
      return c['org_type'] as String?;
    }

    final mine = connections.where((c) =>
        !c.isRevoked && (c.companyLowId == orgId || c.companyHighId == orgId)).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chat connections',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: semantic.textStrong)),
          const SizedBox(height: 4),
          Text('Companies this organization can message in MineLink Messenger.',
              style: TextStyle(fontSize: 12.5, color: semantic.textFaint)),
          const SizedBox(height: 12),
          if (mine.isEmpty)
            Text('No chat links yet.', style: TextStyle(fontSize: 13, color: semantic.textFaint))
          else
            for (final c in mine) ...[
              Builder(builder: (context) {
                final otherId = c.companyLowId == orgId ? c.companyHighId : c.companyLowId;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(child: CompanyNameLink(companyId: otherId, name: nameOf(otherId))),
                            const SizedBox(width: 8),
                            Text('· ${companyOrgTypeLabel(typeOf(otherId))}',
                                style: TextStyle(fontSize: 12, color: semantic.textFaint)),
                          ],
                        ),
                      ),
                      MlButton.danger(
                        label: 'Revoke', icon: Icons.link_off_rounded, compact: true,
                        onPressed: () async {
                          await ref.read(messagingServiceProvider).revokeConnection(c.id);
                          ref.invalidate(orgConnectionsProvider);
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          const SizedBox(height: 14),
          Text('Link for chat',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: semantic.textStrong)),
          const SizedBox(height: 8),
          if (companies.length >= 2)
            CompanyLinkBuilder(
              companies: companies,
              lockedLeftCompanyId: orgId,
              onLinked: () => ref.invalidate(orgConnectionsProvider),
            )
          else
            Text('Add another company to create a link.',
                style: TextStyle(fontSize: 12.5, color: semantic.textFaint)),
        ],
      ),
    );
  }
}
```
Add imports at the top of the file:
```dart
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_link_builder.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_name_link.dart';
```

- [ ] **Step 3: Insert the section into the detail body**

Add `_ChatConnectionsSection(orgId: organizationId)` into the detail screen's section list (with the same vertical spacing used between the screen's other section cards). Confirm `organizationId` is the same id used by `org_connections.company_low_id/high_id` (the companies table id).

- [ ] **Step 4: Analyze + test + commit**

Run: `flutter analyze` → clean; `flutter test` → green.
```bash
git add lib/features/super_admin/screens/organization_detail_screen.dart
git commit -m "feat(chat-links): chat-connections section on company profile with link-for-chat"
```

---

### Task 7: Manual verification pass

**Files:** none (verification only).

- [ ] **Step 1: Run app on web/windows as super-admin**

Run per the project's run command (see `run_web*.bat`), navigate to the Chat connections screen. Verify: builder groups companies by org type; selecting left+right renders the sentence; Connect creates a link that appears under Connected; Revoke moves it to History; Grant again restores it.

- [ ] **Step 2: Verify recommendations + clickable names**

Verify Recommended cards show date + reason for accepted-request pairs and disappear once connected. Click a company name → lands on `/super-admin/organization/:id`. On that profile, the Chat connections section lists links and the pre-locked builder connects to a chosen counterpart.

- [ ] **Step 3: Verify manual-only after migration applied (once user applies it)**

After the user applies migration `20260714120000`, insert (or trigger) a dispatch/transaction and confirm NO new `org_connections` row appears; confirm the table started empty.

- [ ] **Step 4: Final analyze + full test**

Run: `flutter analyze` (clean) and `flutter test` (green). Update the CLAUDE.md §4 chat-link note if it references auto-linking as current behavior.

---

## Self-Review

**Spec coverage:**
- Manual-only linking → Task 1 (drop triggers) ✓
- Org-type-grouped two-sided selector w/ sentence → Task 4 ✓
- Recommended-from-accepted-requests w/ date + reason → Tasks 2 + 5 ✓
- Connected + History (revoked) lists → Task 5 ✓
- Clickable names → profile → Task 3, used in Tasks 5 + 6 ✓
- Profile chat-connections section + link-for-chat (both) → Task 6 ✓
- Reason derived live (no schema change) → Task 2 ✓
- Wipe existing links → Task 1 Step 2 (`delete from org_connections`) ✓

**Placeholder scan:** No TBD/TODO; all code blocks concrete. The org-detail insertion (Task 6) is adapt-to-existing-layout by necessity — flagged with the exact widget to insert and imports.

**Type consistency:** `BusinessPair.key` = `low|high` matches `org_connections` low/high and the `connectedKeys` set in Task 5. `companyOrgTypeLabel` defined in Task 4, used in Tasks 5 + 6. `grantConnection(a,b)` / `revokeConnection(id)` match the existing service. `businessPairsProvider` defined Task 2, consumed Task 5.

**Open confirmations for the implementer (non-blocking):** token names (`MlTokens.rXl/rMd/fontSerif/accent`) and `_client` field name in the repository — verify against source before each edit.
