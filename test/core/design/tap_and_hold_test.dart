// Press and hold — the gesture a phone has that a mouse does not.
//
// Asked for directly (jean, 2026-08-22): *"include more mobile tap and hold
// controlls and features"*. Before this the product used long-press in exactly
// one place (a chat message), and every `MapOptions` in the tree left
// `onLongPress` null.
//
// Two surfaces got it, and both are pinned here:
//
//   * [MlPlatePill] — every plate, waybill number, ticket and serial in the
//     product. These are the strings a person has to move somewhere else:
//     read over a radio, typed into a weighbridge sheet, pasted into a search
//     box. Holding one copies it.
//   * [MlDroppedPinSheet] — what a long-press on a map opens.
//
// The subtle half is the SHORT tap. Plate pills sit inside rows that are
// themselves tappable, so a plate inside a trip row must still open the trip.
// A `GestureDetector` given both handlers would have been easy to get wrong in
// exactly that way, so it is asserted rather than assumed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/design/components/ml_dropped_pin.dart';
import 'package:flutter_application_1/core/design/components/ml_plate_pill.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

import '../../test_helpers/real_fonts.dart';

const _mine = LatLng(-25.7461, 28.1881);

/// Everything handed to the platform clipboard during a test.
late List<String> _copied;

void _captureClipboard() {
  _copied = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') {
      _copied.add((call.arguments as Map)['text'] as String);
    }
    return null;
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.build(Brightness.dark),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadRealFonts);
  setUp(_captureClipboard);

  group('MlPlatePill', () {
    testWidgets('holding it copies the code', (tester) async {
      await _pump(tester, const MlPlatePill('TRP-8CB20569AE'));
      await tester.longPress(find.byType(MlPlatePill));
      await tester.pump();
      expect(_copied, ['TRP-8CB20569AE']);
    });

    testWidgets('and says so, naming what it copied', (tester) async {
      await _pump(tester, const MlPlatePill('CK 84 RT GP'));
      await tester.longPress(find.byType(MlPlatePill));
      await tester.pumpAndSettle();
      // The value names itself — see the note in the component.
      expect(find.textContaining('CK 84 RT GP'), findsWidgets);
      expect(find.textContaining('Copied'), findsOneWidget);
    });

    testWidgets('a SHORT tap still reaches the row underneath', (tester) async {
      // A plate inside a trip row must still open the trip.
      var rowTaps = 0;
      await _pump(
        tester,
        GestureDetector(
          onTap: () => rowTaps++,
          child: const MlPlatePill('JD 22 PL MP'),
        ),
      );
      await tester.tap(find.byType(MlPlatePill));
      await tester.pump();
      expect(rowTaps, 1, reason: 'the pill swallowed the row\'s tap');
      expect(_copied, isEmpty, reason: 'a short tap must not copy');
    });

    testWidgets('copyable: false leaves the gesture to its host',
        (tester) async {
      await _pump(tester, const MlPlatePill('BX 09 LM NW', copyable: false));
      await tester.longPress(find.byType(MlPlatePill));
      await tester.pump();
      expect(_copied, isEmpty);
    });

    testWidgets('an empty pill is not offered as copyable', (tester) async {
      // The dash placeholder used at a dozen call sites for "no truck yet".
      await _pump(tester, const MlPlatePill('   '));
      await tester.longPress(find.byType(MlPlatePill));
      await tester.pump();
      expect(_copied, isEmpty);
      expect(find.byTooltip('Hold to copy'), findsNothing);
    });

    testWidgets('it says that holding it does something', (tester) async {
      // A gesture nobody knows about is not a feature.
      await _pump(tester, const MlPlatePill('TRP-000123'));
      expect(find.byTooltip('Hold to copy'), findsOneWidget);
    });
  });

  group('MlDroppedPinSheet', () {
    testWidgets('states the coordinate to six places', (tester) async {
      await _pump(tester, const MlDroppedPinSheet(point: _mine));
      expect(find.text('-25.746100, 28.188100'), findsOneWidget);
    });

    testWidgets('says how far and which way, when it knows where you are',
        (tester) async {
      await _pump(
        tester,
        MlDroppedPinSheet(
          point: LatLng(_mine.latitude + 0.09, _mine.longitude),
          from: _mine,
        ),
      );
      expect(find.textContaining('of you'), findsOneWidget);
    });

    testWidgets('says NOTHING about "you" when it does not know',
        (tester) async {
      // The live map is watched by office staff whose position the app does
      // not know. "12 km NE of you" there is a claim about somebody in another
      // province.
      await _pump(tester, const MlDroppedPinSheet(point: _mine));
      expect(find.textContaining('of you'), findsNothing);
    });

    testWidgets('copies the coordinate', (tester) async {
      await _pump(tester, const MlDroppedPinSheet(point: _mine));
      await tester.tap(find.text('Copy coordinates'));
      await tester.pump();
      expect(_copied, ['-25.746100, 28.188100']);
    });

    testWidgets('does not invent a name for the place', (tester) async {
      // Deliberate: reverse geocoding is the one answer that is confidently
      // wrong here — the same ladder put "Iron Hills Mine, Mpumalanga" at a
      // courier depot 460 km from the gate (CLAUDE.md §4). A coordinate
      // cannot be wrong.
      await _pump(tester, const MlDroppedPinSheet(point: _mine));
      expect(find.text('Dropped pin'), findsOneWidget);
      expect(find.textContaining('Street'), findsNothing);
      expect(find.textContaining('Road'), findsNothing);
    });
  });
}
