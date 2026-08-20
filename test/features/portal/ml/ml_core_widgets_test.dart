import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('MlStatusBadge', () {
    testWidgets('renders uppercase label with tone colors', (tester) async {
      await tester.pumpWidget(_host(
        const MlStatusBadge(label: 'Loaded', tone: MlTone.done),
      ));
      expect(find.text('LOADED'), findsOneWidget);
      final text = tester.widget<Text>(find.text('LOADED'));
      expect(text.style?.color, MlTokens.green700);
      expect(text.style?.fontWeight, FontWeight.w700);
      expect(text.style?.fontSize, 12);
    });

    testWidgets('maps trip statuses to tones', (tester) async {
      expect(MlStatusBadge.toneForStatus('OTW TO LOADING'), MlTone.transit);
      expect(MlStatusBadge.toneForStatus('at mine'), MlTone.atMine);
      expect(MlStatusBadge.toneForStatus('Loaded'), MlTone.done);
      expect(MlStatusBadge.toneForStatus('available'), MlTone.done);
      expect(MlStatusBadge.toneForStatus('maintenance'), MlTone.warn);
      expect(MlStatusBadge.toneForStatus('declined'), MlTone.error);
      expect(MlStatusBadge.toneForStatus('anything else'), MlTone.neutral);
    });
  });

  group('MlPlatePill', () {
    testWidgets('renders plate in mono font', (tester) async {
      await tester.pumpWidget(_host(const MlPlatePill('CDF 789 LP')));
      final text = tester.widget<Text>(find.text('CDF 789 LP'));
      expect(text.style?.fontFamily, MlTokens.fontMono);
      expect(text.style?.fontWeight, FontWeight.w700);
    });
  });

  group('MlIconWell', () {
    testWidgets('renders tinted well with accent icon', (tester) async {
      await tester.pumpWidget(_host(
        const MlIconWell(icon: Icons.local_shipping_rounded, size: 48),
      ));
      final icon = tester.widget<Icon>(find.byIcon(Icons.local_shipping_rounded));
      expect(icon.color, MlTokens.accent);
      expect(icon.size, 24); // size * 0.5
    });
  });

  group('MlCard', () {
    testWidgets('standard card uses radius 16 and card border', (tester) async {
      await tester.pumpWidget(_host(const MlCard(child: Text('body'))));
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('hero card exposes title rule helper', (tester) async {
      await tester.pumpWidget(
          _host(MlCard(hero: true, child: MlCard.heroTitleRule())));
      expect(find.byType(MlCard), findsOneWidget);
    });
  });

  group('MlStatCard', () {
    testWidgets('shows value, label and icon', (tester) async {
      await tester.pumpWidget(_host(
        const MlStatCard(
          label: 'Active Waybills',
          value: '6',
          icon: Icons.description_outlined,
        ),
      ));
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Active Waybills'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });
  });

  group('MlFeatureCard', () {
    testWidgets('shows title, description and Open button', (tester) async {
      var opened = false;
      await tester.pumpWidget(_host(
        MlFeatureCard(
          title: 'Routes & Mines',
          description: 'View all your active routes.',
          icon: Icons.alt_route_rounded,
          onOpen: () => opened = true,
        ),
      ));
      expect(find.text('Routes & Mines'), findsOneWidget);
      await tester.tap(find.text('Open'));
      expect(opened, isTrue);
    });
  });

  group('MlSectionTitle', () {
    // Was "18/w800" in PlusJakartaSans until 2026-08-14. Changed deliberately,
    // not loosened: docs/design-reference.md §3 makes section titles Fraunces,
    // and the client designated the super-admin console the design reference.
    // The weight drops with the face — the serif's stroke contrast carries the
    // emphasis the sans needed w800 for. Fuller coverage of the reference
    // treatment (meta line, View → link, both themes) lives in
    // test/widgets/portal_section_header_test.dart.
    testWidgets('renders icon + an editorial-rung title + action',
        (tester) async {
      await tester.pumpWidget(_host(
        MlSectionTitle(
          'Active Trips',
          icon: Icons.local_shipping_outlined,
          action: TextButton(onPressed: () {}, child: const Text('View all')),
        ),
      ));
      final text = tester.widget<Text>(find.text('Active Trips'));
      // 18px until 2026-08-20. The serif had no rung on the type scale at all —
      // it ran 16 to 26 across twenty hand-written sites — so this asserted a
      // number that only this one widget believed in. It is `editorialMedium`
      // now, and the assertion is against the scale rather than against 20, so
      // moving the rung moves the test with it instead of breaking it.
      final scale = MlText.forTheme(Theme.of(
              tester.element(find.text('Active Trips')))
          .textTheme);
      expect(text.style?.fontSize, scale.editorialMedium.fontSize);
      expect(text.style?.fontFamily, MlGlass.display);
      // And it states a line height, which is what a hand-written literal
      // could not: it inherited bodyMedium's from the ambient DefaultTextStyle.
      expect(text.style?.height, scale.editorialMedium.height);
      expect(find.text('View all'), findsOneWidget);
    });
  });

  group('MlDataTable', () {
    testWidgets('renders uppercase headers and rows', (tester) async {
      await tester.pumpWidget(_host(
        SizedBox(
          width: 800,
          child: MlDataTable(
            columns: const [
              MlColumn('Truck / Driver', flex: 2),
              MlColumn('Status'),
              MlColumn('Updated', align: TextAlign.right),
            ],
            rows: [
              [
                const Text('CDF 789 LP'),
                const MlStatusBadge(label: 'Loaded', tone: MlTone.done),
                const Text('09:19'),
              ],
            ],
          ),
        ),
      ));
      expect(find.text('TRUCK / DRIVER'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('CDF 789 LP'), findsOneWidget);
    });
  });

  group('MlButton', () {
    testWidgets('primary, go, leave and outline variants build and tap',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MlButton.primary(label: 'Confirm Load', onPressed: () => taps++),
          MlButton.go(label: 'Mark Arrived', onPressed: () => taps++),
          MlButton.leave(label: 'Mark Left', onPressed: () => taps++),
          MlButton.outline(label: 'Open', onPressed: () => taps++),
        ],
      )));
      await tester.tap(find.text('Confirm Load'));
      await tester.tap(find.text('Mark Arrived'));
      await tester.tap(find.text('Mark Left'));
      await tester.tap(find.text('Open'));
      expect(taps, 4);
    });
  });

  group('MlEmptyState', () {
    testWidgets('renders icon, title and message', (tester) async {
      await tester.pumpWidget(_host(
        const MlEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'No trucks have GPS coordinates recorded.',
          message: 'GPS is updated when drivers report via the Driver App.',
        ),
      ));
      expect(
          find.text('No trucks have GPS coordinates recorded.'), findsOneWidget);
    });
  });

  group('MlMapCanvas', () {
    testWidgets('builds grid paper backdrop with child', (tester) async {
      await tester.pumpWidget(_host(
        const SizedBox(
          width: 400,
          height: 300,
          child: MlMapCanvas(child: Text('pin')),
        ),
      ));
      expect(find.text('pin'), findsOneWidget);
    });
  });

  group('Ml overlays', () {
    testWidgets('showMlModal displays title, child and footer', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_host(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      unawaited(showMlModal(
        ctx,
        title: 'Record Load',
        child: const Text('form'),
        footer: [TextButton(onPressed: () {}, child: const Text('Cancel'))],
      ));
      await tester.pumpAndSettle();
      expect(find.text('Record Load'), findsOneWidget);
      expect(find.text('form'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('showMlSlideOver slides in a right panel', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(_host(Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      unawaited(showMlSlideOver(ctx,
          title: 'Trip · WB-0045', child: const Text('detail')));
      await tester.pumpAndSettle();
      expect(find.text('Trip · WB-0045'), findsOneWidget);
      expect(find.text('detail'), findsOneWidget);
    });
  });
}
