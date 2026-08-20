// Renders the targets screen so the two locks are checked as the user meets
// them, not just as predicates: a closed month must offer no input at all, and
// a locked cycle must offer none either.
//
// "Disabled" is not good enough for either. A disabled field can still be
// focused and puzzled over; an absent one cannot.
//
// The real fonts are loaded first, for the reason `super_admin_overflow_sweep
// _test.dart` documents: `flutter test` otherwise renders in a fallback font
// whose every glyph is a full em wide. Against that, this screen's outcome
// badges "overflow" by 4.4px — an artefact of the test font, not the layout.
// Fake failures are as expensive as missed ones.
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_targets.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_target_dial.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';
import '../fixtures/ml_targets_sample.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// The width the super-admin shell hands the content area on a 1920px window.
const double _contentWidth = 1612;

/// Widths the console content area actually sees, down through the screen's
/// own two-column breakpoint at 760.
const _widths = <double>[1612, 1440, 1280, 1024, 860, 720];

/// 1.0 plus both ends of the UiPrefs text-size slider.
const _scales = <double>[0.85, 1.0, 1.15, 1.3, 1.6, 2.0];

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var loaded = false;
  for (final f in files) {
    final file = File('assets/fonts/$f');
    if (!file.existsSync()) continue;
    loaded = true;
    loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  if (loaded) await loader.load();
}

Future<void> _loadRealFonts() async {
  await _loadFont('PlusJakartaSans', [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await _loadFont('JetBrainsMono', [
    'JetBrainsMono-Regular.ttf',
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
  await _loadFont('Fraunces', ['Fraunces-Medium.ttf', 'Fraunces-SemiBold.ttf']);
}

Widget _host(
  Widget child, {
  bool reduceMotion = false,
  double width = _contentWidth,
  double scale = 1.0,
}) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Builder(
    builder: (context) => MediaQuery(
      // The console is used with reduce-motion on, so the animated tab
      // switch has to be exercised that way too.
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduceMotion,
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: 1000, child: child),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadRealFonts();
  });

  MlTargetsData sample() => MlTargetsSample.build();

  group('short term', () {
    testWidgets('a closed month renders no input, an open one does', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final d = sample();
      await tester.pumpWidget(_host(MineLinkTargetsScreen(data: d)));
      await tester.pump();

      expect(tester.takeException(), isNull);

      final editable = [
        for (var i = 0; i < d.months.length; i++)
          if (d.canEditMonth(i)) i,
      ];
      expect(editable, hasLength(7));

      // One field per editable month and not one more. The eleven closed
      // months contribute nothing focusable anywhere on the screen.
      expect(find.byType(TextField), findsNWidgets(editable.length));

      // The closed months are still listed — read-only, with a padlock. Twice
      // each: once in the all-months table, once in the history record below.
      expect(find.text('Sep 2025'), findsNWidgets(2));
      expect(find.textContaining('300 t'), findsWidgets);
      expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
    });

    testWidgets('the current month is the one marked current', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(MineLinkTargetsScreen(data: sample())));
      await tester.pump();

      expect(find.text('CURRENT'), findsOneWidget);
      expect(find.text('CURRENT MONTH · IN PROGRESS'), findsOneWidget);
      expect(find.text('PLANNED — EDITABLE'), findsOneWidget);
    });

    testWidgets('history filters isolate one band', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(MineLinkTargetsScreen(data: sample())));
      await tester.pump();

      expect(find.text('Target history'), findsOneWidget);
      expect(find.text('SURPASSED'), findsWidgets);
      expect(find.text('SHORT'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('long term', () {
    Future<void> openLongTerm(
      WidgetTester tester, {
      bool reduceMotion = false,
    }) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _host(
          MineLinkTargetsScreen(data: sample()),
          reduceMotion: reduceMotion,
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Long term targets & goals'));
      await tester.pumpAndSettle();
    }

    testWidgets('a locked cycle offers no input at all', (tester) async {
      await openLongTerm(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Locked for'), findsWidgets);
      expect(find.text('Progress against each horizon'), findsOneWidget);
    });

    testWidgets('an unreached horizon reads pending, never short', (
      tester,
    ) async {
      await openLongTerm(tester);

      final d = sample();
      final last = kMlHorizons.last;
      expect(d.horizonReached(last), isFalse);
      expect(d.horizonOutcome(last), MlTargetOutcome.pending);

      expect(find.text('PENDING'), findsWidgets);
      expect(find.text('not reached'), findsWidgets);
    });

    testWidgets('the cycle card shows elapsed days and the reopen date', (
      tester,
    ) async {
      await openLongTerm(tester);

      final d = sample();
      expect(find.text('${d.elapsedCycleDays}'), findsWidgets);
      expect(find.text('OF 365 DAYS'), findsOneWidget);
      expect(
        find.text('LOCKED FOR ${d.daysUntilCycleReopens} MORE DAYS'),
        findsOneWidget,
      );
    });

    testWidgets('it all still renders with reduce motion on', (tester) async {
      await openLongTerm(tester, reduceMotion: true);

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Cycle progress'), findsOneWidget);
    });
  });

  // The console lets each admin scale text 0.85–1.3 and this screen is full of
  // fixed-width slots — a 116px badge column, 104/96/92px ladder columns. A
  // tile one pixel inside its box at 1.0 overflows for anyone who nudged the
  // slider, so both ends of the slider are swept at every width the content
  // area actually sees.
  group('the dial reports a refusal', _dialTests);

  // The controller keys its results `m:<period>` / `h:<key>`; the screen asks
  // errorFor() with the same strings. The two are built in different files, so
  // this is what stops a rename quietly turning the message off.
  group('a refusal reaches the dial it belongs to', () {
    testWidgets('a month refusal lands on that month, and nowhere else', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final d = sample();
      final current = d.months[d.currentIndex].key; // '2026-08'
      await tester.pumpWidget(
        _host(
          MineLinkTargetsScreen(
            data: d,
            errorFor: (key) =>
                key == 'm:$current' ? 'Target for $current is closed' : null,
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Target for $current is closed'),
        findsOneWidget,
        reason: 'exactly one dial claims it',
      );
    });

    testWidgets('a horizon refusal lands on that horizon', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The sample's cycle is locked, so the horizon dials are read-only and
      // must show no error UI at all — there is no input to correct.
      await tester.pumpWidget(
        _host(
          MineLinkTargetsScreen(
            data: sample(),
            initialTab: MlTargetsTab.longTerm,
            errorFor: (_) => 'should not be shown on a locked cycle',
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('should not be shown on a locked cycle'), findsNothing);
    });

    testWidgets('no errorFor callback renders no error anywhere', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(MineLinkTargetsScreen(data: sample())));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    });
  });

  group('layout survives every width x text scale', () {
    Future<void> sweepTab(WidgetTester tester, MlTargetsTab tab) async {
      for (final width in _widths) {
        for (final scale in _scales) {
          tester.view.physicalSize = Size(width + 80, 1400);
          tester.view.devicePixelRatio = 1.0;

          // Capture the full FlutterErrorDetails, not just the exception.
          // `takeException()` drops the "relevant error-causing widget" line,
          // which is the only part that says WHERE to fix it.
          final captured = <String>[];
          final prior = FlutterError.onError;
          FlutterError.onError = (d) {
            captured.add(d
                .toDiagnosticsNode(style: DiagnosticsTreeStyle.error)
                .toStringDeep());
            prior?.call(d);
          };

          await tester.pumpWidget(
            _host(
              MineLinkTargetsScreen(data: sample(), initialTab: tab),
              width: width,
              scale: scale,
            ),
          );
          await tester.pump();
          FlutterError.onError = prior;

          final failure = tester.takeException();
          if (failure != null) {
            fail(
              'Layout error at width=$width textScale=$scale '
              'tab=${tab.name}: $failure\n${captured.join('\n')}',
            );
          }
        }
      }
      addTearDown(tester.view.reset);
    }

    testWidgets('short term', (tester) async {
      await sweepTab(tester, MlTargetsTab.shortTerm);
    });

    testWidgets('long term', (tester) async {
      await sweepTab(tester, MlTargetsTab.longTerm);
    });
  });
}

// ---------------------------------------------------------------------------
// The dial's rejected-input state
// ---------------------------------------------------------------------------

void _dialTests() {
  // The dial renders the target twice — the big figure (the server's truth)
  // and the input (what the person typed). They deliberately diverge while a
  // refusal is on screen, so assertions have to name which one they mean.
  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  String bigFigure(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? '')
      .firstWhere(
        (d) => d.isNotEmpty && RegExp(r'^[\d,]+$').hasMatch(d),
        orElse: () => '',
      );

  Widget hostDial({required double target, String? errorText}) => MaterialApp(
    theme: AppTheme.darkTheme,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: SizedBox(
            width: 260,
            child: MlTargetDial(
              tokens: MlGlass.of(context),
              label: 'Sep 2026',
              target: target,
              errorText: errorText,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a refused write keeps what was typed, and says why', (
    tester,
  ) async {
    await tester.pumpWidget(hostDial(target: 450));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '999');
    await tester.pump();

    // The server refuses, the screen re-reads, and the target comes back
    // unchanged — exactly when a naive didUpdateWidget would wipe the figure
    // the person is in the middle of correcting.
    await tester.pumpWidget(
      hostDial(
        target: 450,
        errorText: 'Target for 2026-07 is closed and cannot be changed',
      ),
    );
    await tester.pump();

    expect(
      fieldText(tester),
      '999',
      reason: 'the typed value must survive the refusal',
    );
    expect(
      find.text('Target for 2026-07 is closed and cannot be changed'),
      findsOneWidget,
    );
  });

  testWidgets(
    'the figure shows the truth while the field keeps the correction',
    (tester) async {
      await tester.pumpWidget(hostDial(target: 450));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '999');
      await tester.pump();

      // Someone else's edit lands while the refusal is showing.
      await tester.pumpWidget(hostDial(target: 500, errorText: 'refused'));
      await tester.pump();

      expect(fieldText(tester), '999', reason: 'correction is not wiped');
      expect(
        bigFigure(tester),
        '500',
        reason: 'the headline still tells truth',
      );
    },
  );

  testWidgets('with no error, an outside change does update the field', (
    tester,
  ) async {
    await tester.pumpWidget(hostDial(target: 450));
    await tester.pump();
    expect(fieldText(tester), '450');

    await tester.pumpWidget(hostDial(target: 500));
    await tester.pump();
    expect(fieldText(tester), '500');
  });
}
