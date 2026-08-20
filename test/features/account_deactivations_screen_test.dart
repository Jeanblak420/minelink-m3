import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/data/repositories/super_admin_repository.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/screens/account_deactivations_screen.dart';
import '../test_helpers/real_fonts.dart';

/// Records `reviewAccountDeactivationRequest(approve: true)` calls instead of
/// hitting the network, so the Approve-confirmation fix (round 1) can be
/// proved without a live Supabase project. The `SupabaseClient` passed to
/// `super` is never used by the overridden method — same pattern as
/// `test/core/services/storage_asset_service_test.dart`, which constructs a
/// real client against a fake URL purely to satisfy a non-nullable field.
class _RecordingRepo extends SuperAdminRepository {
  // `autoRefreshToken: false` -- without it GoTrueClient starts a periodic
  // Timer that outlives the widget tree, and flutter_test's binding fails
  // every test in this suite with "A Timer is still pending even after the
  // widget tree was disposed." This client's auth machinery is never
  // exercised (only `reviewAccountDeactivationRequest` is overridden below),
  // so there is nothing to refresh in the first place.
  _RecordingRepo()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  int approveCalls = 0;
  String? lastApprovedRequestId;

  @override
  Future<void> reviewAccountDeactivationRequest({
    required String requestId,
    required bool approve,
    String? note,
  }) async {
    if (approve) {
      approveCalls++;
      lastApprovedRequestId = requestId;
    }
  }
}

/// A single 300-character unbroken token — no spaces, so nothing offers a
/// soft-wrap point. This is what actually overflows a `Row`; a long sentence
/// with spaces wraps and hides the bug a solid token exposes.
final String _longToken = List.generate(300, (i) => 'x').join();

const String _longCompanyName =
    'Ekurhuleni Ferrochrome & Alloys Consolidated Mining Operations (Pty) Ltd';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: child),
);

final List<AccountDeactivationRow> _populatedRows = <AccountDeactivationRow>[
  AccountDeactivationRow(
    id: 'p1',
    userId: 'u-p1',
    displayName: 'Sipho Ndlovu',
    email: 's@example.test',
    companyName: _longCompanyName,
    role: 'driver',
    reason: _longToken,
    status: 'pending',
    requestedAt: DateTime.utc(2026, 8, 19),
    autoApplyAt: DateTime.utc(2026, 9, 18),
    isCompanyOwner: false,
    activeTrips: 0,
  ),
  AccountDeactivationRow(
    id: 'p2',
    userId: 'u-p2',
    displayName: 'Naledi Mokoena',
    email: null,
    companyName: null,
    role: null,
    reason: null,
    status: 'approved',
    requestedAt: DateTime.utc(2026, 8, 10),
    autoApplyAt: DateTime.utc(2026, 9, 9),
    isCompanyOwner: true,
    activeTrips: 3,
  ),
  AccountDeactivationRow(
    id: 'p3',
    userId: 'u-p3',
    displayName: 'Thabo Khumalo',
    email: 't@example.test',
    companyName: 'Roadhaul Logistics',
    role: 'admin',
    reason: 'No longer with the company',
    status: 'deactivated',
    requestedAt: DateTime.utc(2026, 7, 1),
    autoApplyAt: DateTime.utc(2026, 7, 31),
    deactivatedAt: DateTime.utc(2026, 7, 15),
    isCompanyOwner: false,
    activeTrips: 0,
  ),
  AccountDeactivationRow(
    id: 'p4',
    userId: 'u-p4',
    displayName: 'Zanele Dlamini',
    email: 'z@example.test',
    companyName: 'Atlas Buyer Group',
    role: 'management',
    reason: null,
    status: 'rejected',
    requestedAt: DateTime.utc(2026, 6, 1),
    autoApplyAt: DateTime.utc(2026, 7, 1),
    reviewNote: _longToken,
    isCompanyOwner: false,
    activeTrips: 0,
  ),
];

Future<void> _pumpAt(
  WidgetTester tester, {
  required double width,
  required double scale,
  required List<AccountDeactivationRow> rows,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: AccountDeactivationsScreen(rows: rows)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFonts);

  for (final width in <double>[360, 800, 1440]) {
    for (final scale in <double>[0.85, 1.0, 1.3, 1.6, 2.0]) {
      testWidgets('renders an empty queue without overflow at ${width}px / '
          'scale $scale', (tester) async {
        await _pumpAt(tester, width: width, scale: scale, rows: const []);

        expect(tester.takeException(), isNull);
        expect(find.textContaining('Nothing needs review'), findsOneWidget);
      });
    }
  }

  // The sweep above only ever proves the empty state (CLAUDE.md s10.5 / the
  // Task 4 lesson: an empty-fixture sweep proves nothing about the real
  // screen). This sweep pumps a hostile, populated, MIXED-status fixture
  // through the same width x scale matrix and asserts real content rendered.
  for (final width in <double>[360, 800, 1440]) {
    for (final scale in <double>[0.85, 1.0, 1.3, 1.6, 2.0]) {
      testWidgets('renders a populated mixed-status queue without overflow at '
          '${width}px / scale $scale', (tester) async {
        await _pumpAt(tester, width: width, scale: scale, rows: _populatedRows);

        expect(tester.takeException(), isNull);

        // The unbroken 300-char token reached the card as real Text data
        // (ellipsis only affects painting) for both `reason` and
        // `review_note`.
        expect(find.text(_longToken), findsWidgets);
        expect(find.textContaining(_longCompanyName), findsOneWidget);
        // Null company_name / role fall back to readable placeholders
        // instead of rendering "null".
        expect(find.textContaining('No company'), findsOneWidget);
      });
    }
  }

  testWidgets('renders blocker chips for an owner and an active trip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AccountDeactivationsScreen(
          rows: [
            AccountDeactivationRow(
              id: 'r1',
              userId: 'u1',
              displayName: 'Sipho Ndlovu',
              email: 's@example.test',
              companyName: 'Iron Hills Mining',
              role: 'driver',
              status: 'pending',
              requestedAt: DateTime.utc(2026, 8, 19),
              autoApplyAt: DateTime.utc(2026, 9, 18),
              isCompanyOwner: true,
              activeTrips: 2,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Company owner'), findsOneWidget);
    expect(find.text('2 active trips'), findsOneWidget);
  });

  testWidgets(
    'an approved row for a company owner is blocked distinctly from an '
    'ordinary approval',
    (tester) async {
      await tester.pumpWidget(
        _host(
          AccountDeactivationsScreen(
            rows: [
              AccountDeactivationRow(
                id: 'stuck',
                userId: 'u-stuck',
                displayName: 'Owner Stuck',
                email: 'o@example.test',
                companyName: 'Iron Hills Mining',
                role: 'admin',
                status: 'approved',
                requestedAt: DateTime.utc(2026, 8, 1),
                autoApplyAt: DateTime.utc(2026, 8, 31),
                isCompanyOwner: true,
                activeTrips: 0,
              ),
              AccountDeactivationRow(
                id: 'ok',
                userId: 'u-ok',
                displayName: 'Ordinary Waiting',
                email: 'w@example.test',
                companyName: 'Roadhaul Logistics',
                role: 'driver',
                status: 'approved',
                requestedAt: DateTime.utc(2026, 8, 2),
                autoApplyAt: DateTime.utc(2026, 9, 1),
                isCompanyOwner: false,
                activeTrips: 0,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The stuck row gets its own chip -- not the same neutral treatment as
      // an approved row simply waiting for tonight's cron run.
      expect(find.text('Blocked — owns a company'), findsOneWidget);
      // The ordinary approval shows no owner chip at all.
      expect(find.text('Company owner'), findsNothing);
    },
  );

  testWidgets('rejecting requires a note', (tester) async {
    await tester.pumpWidget(
      _host(
        AccountDeactivationsScreen(
          rows: [
            AccountDeactivationRow(
              id: 'r1',
              userId: 'u1',
              displayName: 'Sipho Ndlovu',
              email: 's@example.test',
              companyName: 'Iron Hills Mining',
              role: 'driver',
              status: 'pending',
              requestedAt: DateTime.utc(2026, 8, 19),
              autoApplyAt: DateTime.utc(2026, 9, 18),
              isCompanyOwner: false,
              activeTrips: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reject request'),
    );
    expect(button.onPressed, isNull, reason: 'empty note must disable Reject');
    expect(find.textContaining('A reason is required'), findsOneWidget);
  });

  testWidgets('typing a note enables Reject request', (tester) async {
    await tester.pumpWidget(
      _host(
        AccountDeactivationsScreen(
          rows: [
            AccountDeactivationRow(
              id: 'r1',
              userId: 'u1',
              displayName: 'Sipho Ndlovu',
              email: 's@example.test',
              companyName: 'Iron Hills Mining',
              role: 'driver',
              status: 'pending',
              requestedAt: DateTime.utc(2026, 8, 19),
              autoApplyAt: DateTime.utc(2026, 9, 18),
              isCompanyOwner: false,
              activeTrips: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Not a real request');
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Reject request'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('a deactivated row offers Reactivate, a pending one does not', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AccountDeactivationsScreen(
          rows: [
            AccountDeactivationRow(
              id: 'r1',
              userId: 'u1',
              displayName: 'Sipho Ndlovu',
              email: 's@example.test',
              companyName: 'Iron Hills Mining',
              role: 'driver',
              status: 'deactivated',
              requestedAt: DateTime.utc(2026, 8, 19),
              autoApplyAt: DateTime.utc(2026, 9, 18),
              deactivatedAt: DateTime.utc(2026, 8, 20),
              isCompanyOwner: false,
              activeTrips: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Reactivate is the control that makes the whole design honest -- if it
    // is not reachable, "reversible" is a claim nobody can act on.
    expect(find.text('Reactivate'), findsOneWidget);

    // A pending row, by contrast, offers Approve/Reject but never Reactivate
    // -- there is nothing to reverse yet.
    await tester.pumpWidget(
      _host(
        AccountDeactivationsScreen(
          rows: [
            AccountDeactivationRow(
              id: 'r2',
              userId: 'u2',
              displayName: 'Naledi Mokoena',
              email: 'n@example.test',
              companyName: 'Atlas Buyer Group',
              role: 'management',
              status: 'pending',
              requestedAt: DateTime.utc(2026, 8, 19),
              autoApplyAt: DateTime.utc(2026, 9, 18),
              isCompanyOwner: false,
              activeTrips: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reactivate'), findsNothing);
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('a pending row shows the auto-apply clock', (tester) async {
    await tester.pumpWidget(
      _host(
        AccountDeactivationsScreen(
          rows: [
            AccountDeactivationRow(
              id: 'r1',
              userId: 'u1',
              displayName: 'Sipho Ndlovu',
              email: 's@example.test',
              companyName: 'Iron Hills Mining',
              role: 'driver',
              status: 'pending',
              requestedAt: DateTime.utc(2026, 8, 19),
              autoApplyAt: DateTime.utc(2026, 9, 18),
              isCompanyOwner: false,
              activeTrips: 0,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Auto-applies in'), findsOneWidget);
  });

  // The load-bearing default (see the screen's class doc): the LIVE queue —
  // the one a platform admin actually lands on — must default to everything
  // except the terminal states, not to `pending`-only. Proved against the
  // real provider via ProviderScope.overrideWith, the same shape
  // `super_admin_overflow_sweep_test.dart` uses, rather than the injected
  // `rows:` constructor param (which a test uses to control exactly what
  // renders, and which is therefore deliberately NOT subject to this
  // default — see the class doc's second paragraph).
  testWidgets(
    'the live queue defaults to everything except the terminal states',
    (tester) async {
      final rows = <AccountDeactivationRow>[
        AccountDeactivationRow(
          id: 'pending-1',
          userId: 'u1',
          displayName: 'Pending Person',
          email: 'p@example.test',
          companyName: 'Iron Hills Mining',
          role: 'driver',
          status: 'pending',
          requestedAt: DateTime.utc(2026, 8, 19),
          autoApplyAt: DateTime.utc(2026, 9, 18),
          isCompanyOwner: false,
          activeTrips: 0,
        ),
        AccountDeactivationRow(
          id: 'approved-stuck',
          userId: 'u2',
          displayName: 'Approved Stuck',
          email: 'a@example.test',
          companyName: 'Roadhaul Logistics',
          role: 'admin',
          status: 'approved',
          requestedAt: DateTime.utc(2026, 8, 1),
          autoApplyAt: DateTime.utc(2026, 8, 31),
          isCompanyOwner: true,
          activeTrips: 0,
        ),
        AccountDeactivationRow(
          id: 'deactivated-1',
          userId: 'u3',
          displayName: 'Already Gone',
          email: 'd@example.test',
          companyName: 'Atlas Buyer Group',
          role: 'management',
          status: 'deactivated',
          requestedAt: DateTime.utc(2026, 7, 1),
          autoApplyAt: DateTime.utc(2026, 7, 31),
          deactivatedAt: DateTime.utc(2026, 7, 15),
          isCompanyOwner: false,
          activeTrips: 0,
        ),
        AccountDeactivationRow(
          id: 'rejected-1',
          userId: 'u4',
          displayName: 'Declined Person',
          email: 'r@example.test',
          companyName: 'Atlas Buyer Group',
          role: 'management',
          status: 'rejected',
          requestedAt: DateTime.utc(2026, 6, 1),
          autoApplyAt: DateTime.utc(2026, 7, 1),
          isCompanyOwner: false,
          activeTrips: 0,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountDeactivationRequestsProvider.overrideWith(
              (ref) async => rows,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(body: AccountDeactivationsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pending Person'), findsOneWidget);
      expect(find.text('Approved Stuck'), findsOneWidget);
      expect(find.text('Already Gone'), findsNothing);
      expect(find.text('Declined Person'), findsNothing);
    },
  );

  // Fix round 1 (coordinator + reviewer, 2026-08-19): Approve used to fire
  // immediately with zero friction while Reject asked for confirmation AND a
  // mandatory note -- the lower-consequence action was the guarded one.

  testWidgets(
    'approve asks for confirmation naming the person, and does nothing '
    'on cancel',
    (tester) async {
      final repo = _RecordingRepo();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [superAdminRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: AccountDeactivationsScreen(
                rows: [
                  AccountDeactivationRow(
                    id: 'r1',
                    userId: 'u1',
                    displayName: 'Sipho Ndlovu',
                    email: 's@example.test',
                    companyName: 'Iron Hills Mining',
                    role: 'driver',
                    status: 'pending',
                    requestedAt: DateTime.utc(2026, 8, 19),
                    autoApplyAt: DateTime.utc(2026, 9, 18),
                    isCompanyOwner: false,
                    activeTrips: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();

      // Names the person -- the confirm exists to catch a misclick on the
      // wrong row, and a generic "are you sure?" cannot do that.
      expect(find.textContaining('Sipho Ndlovu'), findsWidgets);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.approveCalls, 0, reason: 'must not act until confirmed');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.approveCalls, 0, reason: 'Cancel must not call the RPC');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('confirming approve calls the review RPC', (tester) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [superAdminRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AccountDeactivationsScreen(
              rows: [
                AccountDeactivationRow(
                  id: 'r7',
                  userId: 'u7',
                  displayName: 'Thabo Khumalo',
                  email: 't@example.test',
                  companyName: 'Roadhaul Logistics',
                  role: 'admin',
                  status: 'pending',
                  requestedAt: DateTime.utc(2026, 8, 19),
                  autoApplyAt: DateTime.utc(2026, 9, 18),
                  isCompanyOwner: false,
                  activeTrips: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    // Two 'Approve' buttons exist once the dialog is open -- the card's own
    // (still mounted beneath the modal barrier) and the dialog's confirm
    // button. Scope to the dialog so this taps the right one.
    final dialogApprove = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(MlButton, 'Approve'),
    );
    expect(dialogApprove, findsOneWidget);
    await tester.tap(dialogApprove);
    await tester.pumpAndSettle();

    expect(repo.approveCalls, 1);
    expect(repo.lastApprovedRequestId, 'r7');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the approve dialog warns when the requester owns a company', (
    tester,
  ) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [superAdminRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AccountDeactivationsScreen(
              rows: [
                AccountDeactivationRow(
                  id: 'owner-row',
                  userId: 'u-owner',
                  displayName: 'Owner Person',
                  email: 'o@example.test',
                  companyName: 'Iron Hills Mining',
                  role: 'admin',
                  status: 'pending',
                  requestedAt: DateTime.utc(2026, 8, 19),
                  autoApplyAt: DateTime.utc(2026, 9, 18),
                  isCompanyOwner: true,
                  activeTrips: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.textContaining('owns a company'), findsWidgets);
    expect(find.textContaining('will skip this request'), findsOneWidget);
  });

  testWidgets('the approve dialog shows no owner warning for a non-owner', (
    tester,
  ) async {
    final repo = _RecordingRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [superAdminRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AccountDeactivationsScreen(
              rows: [
                AccountDeactivationRow(
                  id: 'plain-row',
                  userId: 'u-plain',
                  displayName: 'Ordinary Person',
                  email: 'p@example.test',
                  companyName: 'Roadhaul Logistics',
                  role: 'driver',
                  status: 'pending',
                  requestedAt: DateTime.utc(2026, 8, 19),
                  autoApplyAt: DateTime.utc(2026, 9, 18),
                  isCompanyOwner: false,
                  activeTrips: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(find.textContaining('will skip this request'), findsNothing);
  });
}
