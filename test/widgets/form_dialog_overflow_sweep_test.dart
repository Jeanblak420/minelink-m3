// Width x text-scale sweep for the OTHER form dialogs built on DialogUtils.
//
// The two fleet vehicle dialogs were swept on 2026-08-17 and four distinct
// defects fell out — a dropdown laid out at natural width, field labels cut at
// the SMALLEST text size the app offers, a two-column breakpoint that measured
// the screen instead of the fields, and Material's dialog chrome eating a third
// of a 320px phone. Every one of those lives in `DialogUtils` or in the shared
// habits around it, and these dialogs are built the same way by the same hands.
//
// They had never been rendered at anything but a desktop width. This is the
// same instrument pointed at them.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/layout/text_scale.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/widgets/company_employee_form_dialog.dart';
import 'package:flutter_application_1/features/super_admin/widgets/token_generator_dialog.dart';

import '../test_helpers/dialog_sweep.dart';
import '../test_helpers/real_fonts.dart';

void main() {
  // A guard on the sweep itself: raising the shells' ceiling without widening
  // the shared list would leave real sizes unrendered while the suite stayed
  // green.
  test('the shared sweep reaches the largest scale the shells install', () {
    expect(kDialogSweepScales.reduce((a, b) => a > b ? a : b),
        greaterThanOrEqualTo(kMaxEffectiveTextScale),
        reason: 'text_scale.dart caps the composed scale at '
            '$kMaxEffectiveTextScale; the shared dialog sweep tops out lower.');
  });

  setUpAll(loadRealFonts);

  group('company employee form', () {
    // Both modes: create shows a password field the edit mode does not, so
    // they are different layouts and only one of them was ever looked at.
    for (final orgType in OrgType.values) {
      testWidgets('create (${orgType.name}) survives every width x scale',
          (tester) async {
        await sweepDialog(
            tester, () => CompanyEmployeeFormDialog(orgType: orgType));
      });
    }

    testWidgets('create survives bold text', (tester) async {
      await sweepDialog(
        tester,
        () => const CompanyEmployeeFormDialog(orgType: OrgType.transporter),
        boldText: true,
      );
    });

    testWidgets('nothing is silently cut', (tester) async {
      await sweepDialog(
        tester,
        () => const CompanyEmployeeFormDialog(orgType: OrgType.mineSupplier),
        checkCutText: true,
      );
    });
  });

  group('token generator', () {
    // A deliberately long organisation name: wide strings are half of all
    // overflows, and this dialog interpolates the name into its body.
    testWidgets('survives every width x text scale', (tester) async {
      await sweepDialog(
        tester,
        () => const TokenGeneratorDialog(
          organizationId: 'org-1',
          organizationName:
              'Consolidated Mineral Offtake & Logistics Holdings',
          currentSeatLimit: 5,
        ),
      );
    });

    testWidgets('nothing is silently cut', (tester) async {
      await sweepDialog(
        tester,
        () => const TokenGeneratorDialog(
          organizationId: 'org-1',
          organizationName:
              'Consolidated Mineral Offtake & Logistics Holdings',
          currentSeatLimit: 5,
        ),
        checkCutText: true,
      );
    });
  });
}
