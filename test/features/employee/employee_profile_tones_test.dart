// The employee profile: a downward delta is amber, a document's well carries
// its own status, the footer's button reaches the right edge, the CTA is one
// line, and the employer's setup card is photographed at all.
//
// Phase 3 mine-portal pass, 2026-08-23 (two reviewers). "▼ −3" under "Tons
// moved" drew red — the reference makes a negative delta amber and keeps red
// for a fault. Every document tile sat in a RED well, "Identity document ·
// Verified" included: `statusColor` was computed and then ignored. The footer
// was a `Wrap` with no alignment, so "Export profile PDF" landed mid-row at
// x≈740–927 in a column ending at 1570. The primary CTA read
// "Message  Thandi" with two spaces and wrapped at 1600px. And
// `ProfileSetupEmployerCard` returned `SizedBox.shrink()` because its
// provider had no fixture — a failure that photographed as nothing.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/employee/screens/employee_profile_screen.dart';
import 'package:flutter_application_1/features/profile_setup/widgets/profile_setup_employer_card.dart';

import '../../fixtures/employee_profile_fixtures.dart';
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
      anonKey: 'employee-profile-tones-test',
    );
  });

  Future<void> pump(WidgetTester tester, {double width = 1600}) async {
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.admin, orgType: OrgType.transporter),
        ...employeeProfileOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: EmployeeProfileScreen(
            employeeId: 'FIXTURE-employee',
            canManage: true,
            inPortal: true,
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  Color? inkOf(Finder f) =>
      (f.evaluate().single.renderObject! as RenderParagraph).text.style?.color;

  testWidgets('a downward delta is amber, not red', (tester) async {
    await pump(tester);
    final down = find.text('-3');
    expect(down, findsOneWidget, reason: 'the fixture carries a -3 delta');
    expect(inkOf(down), MlTokens.amber500);
    expect(inkOf(down), isNot(MlTokens.red500));
  });

  testWidgets('a verified document does not sit in a red well',
      (tester) async {
    await pump(tester);
    final verified = find.text('Verified');
    expect(verified, findsWidgets);
    final tile = find.ancestor(
      of: verified.first,
      matching: find.byWidgetPredicate(
          (w) => w is Container && w.padding == const EdgeInsets.all(12)),
    );
    final well = find
        .descendant(of: tile.first, matching: find.byType(Icon))
        .evaluate()
        .map((e) => e.widget as Icon)
        .firstWhere((i) => i.icon == Icons.description_outlined);
    expect(well.color, isNot(MlTokens.red500),
        reason: 'a verified document icon is drawn in the fault colour');
    // And it carries the document's own tone — green for Verified.
    expect(well.color, MlTokens.green500);
  });

  testWidgets('the footer button reaches the right edge of its column',
      (tester) async {
    await pump(tester);
    final button = tester.getRect(find.text('Export profile PDF'));
    final sentence = tester.getRect(find.textContaining('Live profile'));
    final column = tester.getRect(find.ancestor(
      of: find.text('Export profile PDF'),
      matching: find.byType(LayoutBuilder),
    ).first);
    expect(button.right, greaterThan(column.right - 40),
        reason: 'button ends at ${button.right} in a column ending at '
            '${column.right}');
    expect(sentence.left, lessThan(button.left));
  });

  testWidgets('the CTA is one line, whole, with one space', (tester) async {
    await pump(tester);
    final cta = find.textContaining(RegExp(r'^Message'));
    expect(cta, findsOneWidget);
    final p = cta.evaluate().single.renderObject! as RenderParagraph;
    expect(p.size.height, closeTo(p.getMaxIntrinsicHeight(double.infinity), 0.5),
        reason: 'the CTA label wrapped');
    // Never a half-name: either the whole name or none.
    expect(p.didExceedMaxLines, isFalse, reason: 'the CTA ellipsised');
    expect(find.textContaining('Message  '), findsNothing);
  });

  testWidgets('the setup card itemises what the summary counts',
      (tester) async {
    await pump(tester);
    expect(find.text('Nothing outstanding'), findsNothing,
        reason: '"Nothing outstanding" over a 70% summary with a missing item');
    expect(find.textContaining(RegExp(r'need(s)? attention')), findsOneWidget);
  });

  testWidgets('the employer setup card is rendered', (tester) async {
    await pump(tester);
    final card = find.byType(ProfileSetupEmployerCard);
    expect(card, findsOneWidget);
    expect(tester.getSize(card).height, greaterThan(40),
        reason: 'the setup card collapsed to nothing — its provider errored');
  });
}
