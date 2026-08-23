// The fleet register was the last Material `DataTable` in the product, and the
// last table not laid out for the width it is read at.
//
// Transporter pass, 2026-08-23 (reviewer finding #5). It had a filled heading
// band and bold sans title-case heads where every other register draws
// uppercase letter-spaced overline heads on a plain surface; registrations in
// plain sans where the same plates are `MlPlatePill` everywhere else; and BOTH
// `-` and `—` for "empty", one cell apart in the same row.
//
// ## The half of it that a re-skin would not have found
//
// At seventeen columns the table was ~1890px wide and the register at 1600px
// has ~1250px to draw it in — so STATUS, the whole subject of the screen and
// of the four cards above it, was column fifteen and had NEVER BEEN
// PHOTOGRAPHED. `screen-fleet-desktop-dark` ran from Registration to `ID Doc`
// and stopped.
//
// The first rebuild kept thirteen columns and was still too wide, so the table
// COMPRESSED rather than scrolled and Flutter broke inside the words: the
// header read `YEA / R`, a four-digit year rendered `202…`, `Freightliner`
// became `Freightlin…`, and the status pill itself read `IN MAINTENA…`.
// Nothing overflowed — a wrapped or ellipsised cell is a cell that fits — so
// no sweep would ever have caught it. `recon_table_legibility_test.dart` pins
// the identical fault on the recon table, and this is its sibling.
//
// So there are two kinds of assertion here: the VOCABULARY (overline heads,
// plate pills, one empty marker) and the LEGIBILITY (no header broken inside a
// word, no cell ellipsised) — measured at the widths this screen is read at.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/widgets/fleet_vehicle_table.dart';

import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

/// The derived state for the fixture fleet, the same story `kFleetStatus`
/// tells: one available, two on route, one down for repair.
Map<String, FleetVehicleStatus> _derived() => {
      'veh-1': const FleetVehicleStatus(
        vehicleId: 'veh-1',
        registration: 'CK 84 RT GP',
        isActive: true,
        onRoute: false,
        drivers: 'Sipho Ndlovu',
        driverCount: 1,
      ),
      'veh-2': const FleetVehicleStatus(
        vehicleId: 'veh-2',
        registration: 'JD 22 PL MP',
        isActive: true,
        onRoute: true,
        drivers: 'Thandi Mokoena, Fixture Operator',
        driverCount: 2,
      ),
      'veh-3': const FleetVehicleStatus(
        vehicleId: 'veh-3',
        registration: 'BX 09 LM NW',
        isActive: true,
        onRoute: true,
      ),
      'veh-4': const FleetVehicleStatus(
        vehicleId: 'veh-4',
        registration: 'MN 07 PL GP',
        isActive: true,
        onRoute: false,
        inMaintenance: true,
        maintenanceTitle: 'Gearbox rebuild',
      ),
    };

void main() {
  setUpAll(() async {
    await loadRealFonts();
  });

  /// The register at [width] — the width the CARD gives the table, which is
  /// what decides whether it compresses. On the 1600px desktop render that is
  /// ~1250px: 1600 less the 274px rail, less the page and card padding.
  Future<void> pump(WidgetTester tester, double width,
      {double textScale = 1.0}) async {
    tester.view.physicalSize = Size(width + 80, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width + 80, 2400),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: width,
                child: FleetVehicleTable(
                  vehicles: fixtureFleet(),
                  statusByVehicleId: _derived(),
                  // THE CALLBACKS MATTER. Every action button is conditional
                  // on its callback being non-null, so a table pumped without
                  // them renders an EMPTY actions column — which is exactly
                  // the shape the first version of this test measured, and it
                  // is not the shape the screen draws.
                  onEditVehicle: (_) {},
                  onAssignDriver: (_) {},
                  onUnassignDriver: (_) {},
                  onRemoveVehicle: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------- vocabulary

  testWidgets('the register is an MlDataTable, not a Material DataTable',
      (tester) async {
    await pump(tester, 1250);

    expect(find.byType(MlDataTable), findsOneWidget);
    expect(
      find.byType(DataTable),
      findsNothing,
      reason: 'the last Material DataTable in the product',
    );
    // Uppercase overline heads, not bold sans title case.
    expect(find.text('REGISTRATION'), findsOneWidget);
    expect(find.text('Registration'), findsNothing);
  });

  testWidgets('every registration is a plate pill', (tester) async {
    await pump(tester, 1250);

    // Four trucks, and CK 84 RT GP carries two trailer plates as well.
    expect(find.byType(MlPlatePill), findsNWidgets(4 + 3));
    for (final reg in const [
      'CK 84 RT GP',
      'JD 22 PL MP',
      'BX 09 LM NW',
      'MN 07 PL GP',
    ]) {
      expect(
        find.ancestor(
          of: find.text(reg),
          matching: find.byType(MlPlatePill),
        ),
        findsOneWidget,
        reason: '$reg is drawn in plain sans',
      );
    }
  });

  testWidgets('ONE empty marker — an em dash, never a hyphen', (tester) async {
    await pump(tester, 1250);

    expect(find.text('—'), findsWidgets);
    expect(
      find.text('-'),
      findsNothing,
      reason: 'this file used — for a missing odometer and - for a missing '
          'trailer, one cell apart in the same row',
    );
  });

  // ---------------------------------------------------------- legibility

  /// How many lines [text] may occupy: one, plus one per place a break can
  /// legitimately fall. More than that means Flutter broke inside a word.
  int allowedLines(String text) =>
      1 + ' -/'.split('').fold(0, (n, c) => n + text.split(c).length - 1);

  const headers = [
    'REGISTRATION',
    'STATUS',
    'VEHICLE',
    'ODOMETER',
    'DISK EXPIRY',
    'TRAILERS',
    // No ID NUMBER or DOCUMENTS head: they are inside the drivers cell now,
    // because they describe the PERSON on the truck and not the truck.
    'DRIVERS',
  ];

  // 1250 is the desktop render's own figure; 1440 a common laptop; 1600 a wide
  // one. All three were wider than the OLD table's minimum in the sense that
  // mattered — it simply squeezed at every one of them.
  for (final width in const [1250.0, 1440.0, 1600.0]) {
    testWidgets('no head breaks inside a word at ${width.toInt()}px',
        (tester) async {
      await pump(tester, width);

      final oneLine = tester.getRect(find.text('STATUS')).height;
      final broken = <String>[];
      for (final h in headers) {
        final f = find.text(h);
        if (f.evaluate().isEmpty) {
          broken.add('$h: not painted (renamed? rename it here too)');
          continue;
        }
        final lines = (tester.getRect(f.first).height / oneLine).round();
        if (lines > allowedLines(h)) {
          broken.add('$h: $lines lines, ${allowedLines(h)} break place(s)');
        }
      }
      expect(broken, isEmpty, reason: broken.join('; '));
    });

    testWidgets('no cell is ellipsised at ${width.toInt()}px', (tester) async {
      await pump(tester, width);

      // The four that the thirteen-column draft actually cut, plus the status
      // pill, which is the longest thing on the row and the subject of it.
      for (final text in const [
        'Freightliner · Interlink · 2021',
        'Scania · Side tipper · 2019',
        'MAN · Tautliner · 2020',
        'IN MAINTENANCE',
        'Thandi Mokoena, Fixture Operator',
      ]) {
        final f = find.text(text);
        expect(f, findsOneWidget, reason: '"$text" is not painted at all');
        expect(
          tester.renderObject<RenderParagraph>(f).didExceedMaxLines,
          isFalse,
          reason: '"$text" was cut at ${width.toInt()}px',
        );
      }
    });
  }

  // The register's actions are the point of it — edit, assign or manage
  // drivers, unassign, retire. They were the LAST column of a seventeen-column
  // table and therefore permanently off a 1600px screen; now they are on it,
  // and on ONE row.
  //
  // 204px, and it is measured: each button declares
  // `BoxConstraints(maxWidth: 40)` and RENDERS AT 48, because an IconButton
  // keeps Material's padded 48px tap target whatever its own constraints say.
  // Four of them are 192, not 160, and both 168 and 184 wrapped the fourth
  // button onto a second row — on exactly the two rows that have a driver to
  // unassign, so it read as a rendering fault rather than a width one.
  testWidgets('the four row actions sit on one row', (tester) async {
    await pump(tester, 1250);

    final buttons = find.descendant(
      of: find.byType(FleetVehicleTable),
      matching: find.byType(IconButton),
    );
    // Two trucks with a driver (4 actions each) and two without (3 each).
    expect(buttons, findsNWidgets(4 + 4 + 3 + 3));

    final first = tester.getRect(buttons.at(0));
    for (var i = 1; i < 4; i++) {
      expect(
        (tester.getRect(buttons.at(i)).center.dy - first.center.dy).abs(),
        lessThan(2),
        reason: 'action $i wrapped onto a second row',
      );
    }
  });

  // THE CASE THAT MUST STAY GREEN. The register is read on a phone too, and
  // there it is a list of cards, not a table — the fix must not have turned the
  // compact branch into a squeezed table.
  testWidgets('a phone still gets cards, not a table', (tester) async {
    await pump(tester, 380);

    expect(find.byType(MlDataTable), findsNothing);
    expect(find.text('CK 84 RT GP'), findsOneWidget);
    expect(find.text('AVAILABLE'), findsOneWidget);
  });
}
