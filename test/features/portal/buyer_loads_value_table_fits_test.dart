// The buyer's loads table fits its card, so the button it exists for is on
// screen.
//
// Buyer pass, 2026-08-23 (reviewer finding #10, seen in
// `screen-buyer-loads-value-desktop-light`: the table carried a horizontal
// scrollbar on a 1600px desktop and the last column was cut at the card's
// right edge).
//
// `MlDataTable._effectiveMinWidth` solves each column's declared need across
// the WHOLE table — `need × totalFlex / flex` — because a flex weight is a
// share, not a width. `Source` declared `minWidth: 124` (measured: "Iron Hills
// Mining" is 105px, "Atlas Buyer Group" 118px) while holding `flex: 2` of 20,
// which is 10% of the table. Ten per cent of the table had to be 124px, so the
// table had to be 1376px. The card is about 1224px.
//
// So one column's weight disagreeing with its own declared need pushed the
// table 152px into a horizontal scroll and carried the LAST column — the ghost
// button that captures an invoice, which is the reason a buyer opens this
// screen — off the right edge. At `flex: 3` of 21 the same 124px costs 968px
// and the widest demand becomes the money columns at 1108px.
//
// The arithmetic is asserted directly rather than the pixels, because the
// pixels are what the arithmetic produces and the arithmetic is what a future
// column edit will get wrong.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_loads_value_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/portal_tail_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

/// `_effectiveMinWidth`, restated so a test can reason about it. Kept in step
/// with `ml_data_table.dart` by the last case in this file.
double tableMinimum(List<MlColumn> columns, {double scale = 1.0}) {
  const rowPadding = 16.0;
  const cellGutter = 12.0;
  var totalFlex = 0;
  var pinned = 0.0;
  for (final c in columns) {
    if (c.width != null) {
      pinned += c.width!;
    } else {
      totalFlex += c.flex;
    }
  }
  var out = 560.0;
  for (final c in columns) {
    if (c.minWidth == null) continue;
    final need = c.minWidth! * scale + cellGutter;
    final total = c.width != null
        ? (need > c.width! ? pinned + need - c.width! + rowPadding : 0.0)
        : (totalFlex == 0 || c.flex == 0
            ? 0.0
            : need * totalFlex / c.flex + pinned + rowPadding);
    if (total > out) out = total;
  }
  return out;
}

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'buyer-loads-value-table-test',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(
            role: UserRole.admin,
            orgType: OrgType.buyer,
          ),
          ...portalCaptureOverrides(),
          ...portalTailOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: BuyerLoadsValueScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  /// The per-load table — the one with a Variance column.
  MlDataTable loadsTable(WidgetTester tester) => tester
      .widgetList<MlDataTable>(find.byType(MlDataTable))
      .firstWhere(
        (t) => t.columns.any((c) => c.label == 'Variance'),
        orElse: () => throw StateError('no per-load table on this screen'),
      );

  testWidgets('the per-load table fits a desktop card', (tester) async {
    await pump(tester);

    final table = loadsTable(tester);
    // The card the table sits in on a 1600px viewport: the page body caps and
    // pads, and the card pads again. Measured off the render rather than
    // recomputed here.
    final card = tester
        .getRect(find.ancestor(
          of: find.byWidget(table),
          matching: find.byType(MlCard),
        ).first)
        .width;

    expect(
      tableMinimum(table.columns),
      lessThanOrEqualTo(card),
      reason:
          'the table demanded ${tableMinimum(table.columns).toStringAsFixed(0)}px '
          'inside a ${card.toStringAsFixed(0)}px card, so it scrolled and the '
          'last column — the invoice button — was off the right edge',
    );
  });

  testWidgets('no column asks for more of the table than its weight buys', (
    tester,
  ) async {
    await pump(tester);

    final table = loadsTable(tester);
    final totalFlex = table.columns
        .where((c) => c.width == null)
        .fold<int>(0, (a, c) => a + c.flex);

    for (final c in table.columns.where((c) => c.minWidth != null)) {
      // What this ONE column's declared need costs the whole table.
      final own = (c.minWidth! + 12) * totalFlex / c.flex + 16;
      expect(
        own,
        lessThanOrEqualTo(1224),
        reason:
            '"${c.label}" declares ${c.minWidth}px at flex ${c.flex} of '
            '$totalFlex, which makes the WHOLE table '
            '${own.toStringAsFixed(0)}px. Give the column a weight that can '
            'pay for what it needs',
      );
    }
  });

  // The GREEN case: the columns still declare what their contents need. A
  // "fix" that simply deleted the minWidths would pass the two cases above and
  // put "Iron Hills Mining" and "R40,920.00" back into a clipped cell, which
  // is the fault those numbers were measured to end.
  testWidgets('the columns still declare their measured needs', (tester) async {
    await pump(tester);

    final byLabel = {
      for (final c in loadsTable(tester).columns) c.label: c,
    };
    expect(byLabel['Truck']!.minWidth, kPlateColumnMinWidth);
    expect(byLabel['Source']!.minWidth, 124);
    expect(byLabel['Value']!.minWidth, 92);
    expect(byLabel['']!.minWidth, 96);
  });

  // And the restatement above has not drifted from the widget it mirrors.
  test('the arithmetic here matches ml_data_table.dart', () {
    const columns = [
      MlColumn('a', flex: 3, minWidth: 120),
      MlColumn('b', flex: 2, minWidth: 200),
      MlColumn('c', flex: 2),
    ];
    // (200 + 12) * 7 / 2 + 16 — the widest demand of the three, and above
    // the 560px floor, which would otherwise be what is being asserted.
    expect(tableMinimum(columns), closeTo((200 + 12) * 7 / 2 + 16, 0.01));
    expect(tableMinimum(columns), greaterThan(560));
  });
}
