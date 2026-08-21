// The registry is the console's front door, and on a phone it was blank.
//
// `OrganizationManagementScreen` lays its four columns out as `Expanded`s with
// no minimum, so at 412px each got roughly 70px and every one truncated:
//
//   COMPANY       "Iron …"  "Atlas …"  "Road…"  "Cons…"  "Sable…"
//   ORG TYPE      "MI…"     "BU…"      "TR…"
//   TOKEN EXPIRY  "10…"     "1D…"      "Ex…"    "1A…"
//
// A registry where no column can be read is not a narrow registry, it is a
// blank one — and it passed every sweep, because an ellipsis is a layout that
// fits. Found 2026-08-20 by rendering the screen at phone width for the first
// time.
//
// The fix is `MlWideTable`: the table scrolls sideways below the width its own
// content needs, rather than compressing into it.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_management_screen.dart';

import '../../fixtures/console_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'org-registry',
    );
  });

  Future<void> pumpRegistry(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [...companyScopeOverrides(), ...consoleCaptureOverrides()],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: OrganizationManagementScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<bool> truncations(WidgetTester tester, String text) => [
        for (final e in find.text(text).evaluate())
          (e.renderObject! as RenderParagraph).didExceedMaxLines,
      ];

  for (final width in const [360.0, 412.0]) {
    testWidgets('the registry keeps its words at ${width.toInt()}px',
        (tester) async {
      await pumpRegistry(tester, width);

      // The org-type pill is the shortest column's content and the first thing
      // that went. `TRANSPORTER` is the widest of the three.
      for (final label in const ['MINE', 'BUYER', 'TRANSPORTER']) {
        final found = truncations(tester, label);
        expect(found, isNotEmpty,
            reason: '"$label" is not in the registry. `kOrganizations` carries '
                'one of each org type; if that changed, change this too.');
        expect(found.any((t) => t), isFalse,
            reason: '"$label" is truncated at ${width.toInt()}px. The org-type '
                'column is being compressed instead of the table scrolling.');
      }

      // A company name that comfortably fits its column must not ellipsise.
      // (The 48-character one in the fixture legitimately does — a name column
      // is allowed to ellipsise a name; it is not allowed to ellipsise ALL of
      // them.)
      final iron = truncations(tester, 'Iron Hills Mining');
      expect(iron, isNotEmpty);
      expect(iron.any((t) => t), isFalse,
          reason: 'a 17-character company name is being cut. That is the '
              'column having ~70px rather than the ~180 a name needs.');
    });
  }

  testWidgets('the registry scrolls rather than compressing', (tester) async {
    await pumpRegistry(tester, 412);
    expect(find.byType(MlWideTable), findsWidgets,
        reason: 'the table is laid straight into the page again, so its '
            'columns compress on a phone instead of the table scrolling. '
            'MlWideTable is the component for exactly this and it draws a '
            'scrollbar, which is what tells a reader there are columns past '
            'the edge.');
  });

  testWidgets('and it does NOT scroll on a desktop', (tester) async {
    // A scrollbar over content that fits is a promise of more. 620 is what the
    // content needs; a 1600px console is far above it.
    await pumpRegistry(tester, 1600);
    expect(find.byType(Scrollbar), findsNothing,
        reason: 'the registry is scrolling on a 1600px window, which means its '
            'declared minimum has grown past what the columns actually need.');
  });
}
