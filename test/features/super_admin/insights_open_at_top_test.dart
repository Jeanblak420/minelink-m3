// Each insights page opens at the top (admin phone audit, 2026-10-24): Buyers
// and Mines are one route with a different parameter, the router kept the one
// screen, and Mines opened at the bottom wherever Buyers had been scrolled to.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_org_insights_screen.dart';

import '../../fixtures/console_capture_fixtures.dart';
import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/frozen_clock.dart';

/// Buyers, scrolled down, then Mines in the same slot \u2014 what the router does.
/// Returns how far down Mines opened.
Future<double> _mineOpensAt(WidgetTester tester,
    Widget Function(String orgType) page) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Mines first, so its figures are already loaded when it is opened again
  // — as in the app, where the dashboard reads all three org types.
  final orgType = ValueNotifier('mineSupplier');
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...companyScopeOverrides(),
      ...consoleCaptureOverrides(),
      ...portalCaptureOverrides(),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: ValueListenableBuilder<String>(
          valueListenable: orgType,
          builder: (_, t, __) => page(t),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  orgType.value = 'buyer';
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));

  final scrollable = find.byType(Scrollable).first;
  await tester.drag(scrollable, const Offset(0, -1500));
  await tester.pump(const Duration(milliseconds: 600));
  final buyersAt = tester.state<ScrollableState>(scrollable).position.pixels;
  expect(buyersAt, greaterThan(500), reason: 'Buyers did not scroll');

  orgType.value = 'mineSupplier';
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return tester
      .state<ScrollableState>(find.byType(Scrollable).first)
      .position
      .pixels;
}

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(url: 'http://localhost:54321', anonKey: 'insights-top');
  });

  testWidgets('Mines opens at the top after scrolling Buyers', (tester) async {
    expect(
        await _mineOpensAt(tester,
            (t) => SuperAdminOrgInsightsScreen(key: ValueKey('insights-$t'), orgType: t)),
        0);
  });

  test('and the router builds the insights page with that key', () {
    // The route builder is not reachable without the whole authenticated
    // router; its source is. If the key is dropped, this fails.
    final src = File('lib/core/routing/app_router.dart').readAsStringSync();
    expect(src, contains("key: ValueKey('insights-\$orgType')"));
  });

  testWidgets('the test bites: unkeyed, Mines keeps Buyers\u2019 scroll', (tester) async {
    expect(
        await _mineOpensAt(
            tester, (t) => SuperAdminOrgInsightsScreen(orgType: t)),
        greaterThan(0));
  });
}
