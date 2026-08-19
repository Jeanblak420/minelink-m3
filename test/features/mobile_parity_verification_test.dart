import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/widgets/add_vehicle_form.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_widgets.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/screens/register_company_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_dashboard_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/super_admin_shell_layout.dart';

import '../test_helpers/test_supabase.dart';

PlatformAdminSettings _platformSettings() {
  final now = DateTime(2024, 1, 1);
  return PlatformAdminSettings(
    id: 'main',
    mainSuperAdminEmail: 'owner@example.com',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(() async {
    await ensureTestSupabaseInitialized();
  });

  group('mobile parity verification', () {
    testWidgets('SuperAdminShellLayout shows menu drawer control below 900px', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SuperAdminShellLayout(
              child: Text('workspace'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPlatformRoleProvider.overrideWith(
              (ref) async => PlatformRole.superGlobalSerialAdminMain,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      // The super-admin shell has continuous animations (live pill / bell), so
      // pump a fixed duration instead of pumpAndSettle (which would never
      // settle).
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byTooltip('Open navigation menu'), findsOneWidget);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.drawer, isNotNull);
    });

    testWidgets('SuperAdminShellLayout uses persistent sidebar at wide width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SuperAdminShellLayout(
              child: Text('workspace'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1000, 800)),
          child: ProviderScope(
            overrides: [
              currentPlatformRoleProvider.overrideWith(
                (ref) async => PlatformRole.superGlobalSerialAdminMain,
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byTooltip('Open navigation menu'), findsNothing);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.drawer, isNull);
    });

    testWidgets('super admin dashboard renders for the flattened admin role', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPlatformRoleProvider.overrideWith(
              (ref) async => PlatformRole.superGlobalSerialAdminMain,
            ),
            dashboardStatsProvider.overrideWith(
              (ref) async => {
                'total_organizations': 0,
                'total_users': 0,
                'active_tokens': 0,
              },
            ),
            platformAdminSettingsProvider.overrideWith(
              (ref) async => _platformSettings(),
            ),
          ],
          child: const MaterialApp(home: SuperAdminDashboardV2Screen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Child-admin flattened away: no distinct 'Platform administrator' label.
      expect(find.text('Normal User'), findsNothing);
    });

    testWidgets('super admin sees register company form', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentPlatformRoleProvider.overrideWith(
              (ref) async => PlatformRole.superGlobalSerialAdminMain,
            ),
            platformAdminSettingsProvider.overrideWith(
              (ref) async => _platformSettings(),
            ),
          ],
          child: const MaterialApp(home: RegisterCompanyScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Company name'), findsOneWidget);
      expect(
        find.textContaining('do not have permission'),
        findsNothing,
      );
    });

    testWidgets('PortalStatCard supports tap for navigation parity', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PortalStatCard(
              label: 'Fleet vehicles',
              value: '3',
              icon: Icons.local_shipping_outlined,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Fleet vehicles'));
      expect(tapped, isTrue);
    });

    testWidgets('AddVehicleForm dialog fits narrow phone width', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const AddVehicleForm(companyId: 'company-1'),
                  ),
                  child: const Text('Open add vehicle'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open add vehicle'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Add fleet vehicle'), findsOneWidget);
      expect(find.text('Add vehicle'), findsOneWidget);
    });
  });
}
