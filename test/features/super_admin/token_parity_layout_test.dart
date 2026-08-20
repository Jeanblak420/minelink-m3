import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/layout/app_breakpoints.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/profile/widgets/company_token_requests_panel.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_history_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_requests_screen.dart';

import '../../test_helpers/test_supabase.dart';

void main() {
  setUpAll(() async {
    await ensureTestSupabaseInitialized();
  });

  group('token parity layout', () {
    testWidgets('TokenRequestsScreen has no inner AppBar under shell', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            openTokenRequestsProvider.overrideWith(
              (ref) async => <TokenRequest>[],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const TokenRequestsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Queue is clear'), findsOneWidget);
    });

    testWidgets('TokenHistoryScreen uses in-body TabBar without AppBar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenHistoryAuditLogsProvider.overrideWith(
              (ref, orgType) async => <AuditLog>[],
            ),
          ],
          child: MaterialApp(
          theme: AppTheme.darkTheme,
            home: TokenHistoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Transporters'), findsOneWidget);
    });

    testWidgets('CompanyTokenRequestsPanel stacks actions on narrow width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: CompanyTokenRequestsPanel(companyId: 'test-co'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Request more seats'), findsOneWidget);
      expect(find.text('Renew token'), findsOneWidget);
      expect(find.text('Request new token'), findsOneWidget);

      final narrowButtons = tester.widgetList<SizedBox>(
        find.descendant(
          of: find.byType(CompanyTokenRequestsPanel),
          matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == double.infinity),
        ),
      );
      expect(narrowButtons.length, greaterThanOrEqualTo(3));
    });

    testWidgets('CompanyTokenRequestsPanel uses wrap on wide width', (tester) async {
      const wideWidth = AppBreakpoints.dashboardWideMin + 100;
      await tester.binding.setSurfaceSize(const Size(wideWidth, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SizedBox(
                width: wideWidth,
                child: CompanyTokenRequestsPanel(companyId: 'test-co'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Wrap), findsOneWidget);
    });
  });
}
