// The company-information labels fit their column and read as sentences.
//
// Phase 3 mine-portal pass, 2026-08-23 (reviewer finding #45, verified in
// `screen-company-details-desktop-dark`). This card is `/portal/mine/company`
// and every other org's own-company page and the platform's company registry
// detail — five goldens.
//
// The heading read "Company Information" and the labels "Company Name",
// "MineLink Reference", "WhatsApp Number", "Organization Type", "Created At",
// "Last Updated" — title case, in a product that cases every label as a
// sentence. Three of them WRAPPED ONTO TWO LINES inside the 130px label column
// AT 1600px, with the rest of the screen empty to the right.
//
// Widening the column would have been the wrong repair. The words were
// carrying the card's own subject: the card sits under a heading that says
// "Company information", beneath an avatar reading "Fixture Haulage ·
// Transporter · FXH001", so "Company" and "MineLink" were each said three
// times before a reader reached the value. One word does it, and then nothing
// wraps at any width the card is drawn at.
//
// The label column still rides the text scaler (`MlColumn.minWidth`'s reason),
// so this test measures at scale 1.0 AND at the console's 1.3 ceiling.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/screens/company_list_screen.dart';

import '../../fixtures/portal_tail_fixtures.dart';
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
      anonKey: 'company-information-labels-test',
    );
  });

  /// Every label the card draws, in the order it draws them.
  const labels = [
    'Name',
    'Reference',
    'WhatsApp',
    'Org type',
    'CEO',
    'Created',
    'Updated',
  ];

  Future<void> pump(
    WidgetTester tester, {
    double width = 1600,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(
            role: UserRole.admin,
            orgType: OrgType.transporter,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: CompanyDetailsScreen(company: kCompanyRegistry.first),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the heading and the labels are sentence case', (tester) async {
    await pump(tester);

    expect(find.text('Company information'), findsOneWidget);
    expect(find.text('Company Information'), findsNothing);

    for (final gone in const [
      'Company Name',
      'MineLink Reference',
      'WhatsApp Number',
      'Organization Type',
      'Created At',
      'Last Updated',
    ]) {
      expect(find.text(gone), findsNothing, reason: '"$gone" is title case');
    }
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
  });

  for (final scale in const [1.0, 1.3]) {
    for (final width in const [1600.0, 412.0]) {
      testWidgets(
        'no label wraps — ${width.toInt()}px at text scale $scale',
        (tester) async {
          await pump(tester, width: width, textScale: scale);

          // "CEO" is three characters and cannot wrap at any scale, so it is
          // the height of exactly one line in this style. Every other label
          // must be that tall too.
          final oneLine = tester.getRect(find.text('CEO')).height;
          for (final label in labels) {
            expect(
              tester.getRect(find.text(label)).height,
              lessThan(oneLine * 1.5),
              reason:
                  '"$label" wrapped inside the 130px label column '
                  '(${width.toInt()}px, scale $scale) — the column is not the '
                  'problem, the words were',
            );
          }
        },
      );
    }
  }

  testWidgets('the reference reads in the code face, the rest do not', (
    tester,
  ) async {
    await pump(tester);

    // Scoped to the ROW, because the avatar block above the card names the
    // company and quotes its reference too — `find.text` alone matches both.
    String? valueFamilyFor(String label) {
      final row = find
          .ancestor(of: find.text(label), matching: find.byType(Row))
          .first;
      final texts = tester
          .widgetList<Text>(find.descendant(of: row, matching: find.byType(Text)))
          .toList();
      expect(texts.length, 2, reason: 'a fact row is a label and a value');
      return texts.last.style?.fontFamily;
    }

    expect(
      valueFamilyFor('Reference'),
      MlTokens.fontMono,
      reason: 'the reference is the string a reader quotes in a support call',
    );
    // The GREEN case: a company NAME is not a code, and neither is a person's.
    expect(valueFamilyFor('Name'), isNot(MlTokens.fontMono));
    expect(valueFamilyFor('CEO'), isNot(MlTokens.fontMono));
  });
}
