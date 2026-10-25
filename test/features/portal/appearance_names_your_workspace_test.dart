// Appearance only mentions the Mine/Supplier dashboard to a mine (S25 walk,
// 2026-10-25): a transporter owner read that the theme and density "apply to
// your Mine/Supplier dashboard" on a page that showed neither control.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';
import 'package:flutter_application_1/features/portal/screens/appearance_theme_screen.dart';

Future<void> _pump(WidgetTester tester, {required bool mine}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      portalWorkspaceProvider.overrideWithValue(PortalWorkspaceModel(
        phase: PortalWorkspacePhase.ready,
        isMineSupplier: mine,
      )),
    ],
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(body: AppearanceThemeScreen()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a transporter or buyer is not told about a mine dashboard',
      (tester) async {
    await _pump(tester, mine: false);
    expect(find.textContaining('Mine/Supplier'), findsNothing);
    expect(find.textContaining('Light or dark applies everywhere'),
        findsOneWidget);
  });

  testWidgets('a mine still is, and gets the controls it names',
      (tester) async {
    await _pump(tester, mine: true);
    expect(find.textContaining('your Mine/Supplier dashboard'), findsOneWidget);
    expect(find.text('Mine theme'), findsOneWidget);
  });
}
