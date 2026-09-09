// The tour system's state machine, persistence, debug utilities and overlay
// behaviour, verified as code rather than claimed.
//
// Covers the "Testing & Debugging" items that can be exercised without a
// device: tour navigation, seen-persistence across container restarts, every
// TourDebugNotifier method, and the overlay's skip-when-target-missing rule
// plus the mounted-target spotlight.
//
// The device-only items — visual tooltip positioning per screen size, the
// 300ms render delay on real navigation, and end-to-end tours per role —
// still need a running app; see docs/tour/REMAINING_WORK.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/tour/models/tour_step.dart';
import 'package:flutter_application_1/features/tour/providers/tour_debug_provider.dart';
import 'package:flutter_application_1/features/tour/providers/tour_provider.dart';
import 'package:flutter_application_1/features/tour/providers/tour_seen_provider.dart';
import 'package:flutter_application_1/features/tour/providers/tour_service_provider.dart';
import 'package:flutter_application_1/features/tour/services/tour_service.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_overlay.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';

/// Mounted the way `portal_shell_layout.dart` mounts it — inside a Stack over
/// the screen content — so the overlay's full-screen painting does not
/// participate in the body's flex layout.
Widget _overlayHarness({required GlobalKey mountedKey}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: TourTarget(
                id: 'test.mounted',
                targetKey: mountedKey,
                child: const Text('Target widget'),
              ),
            ),
            const TourOverlay(),
          ],
        ),
      ),
    ),
  );
}

TourStep _step(String id, GlobalKey key) => TourStep(
  id: id,
  targetKey: key,
  title: 'Step $id',
  description: 'Description for $id',
  icon: Icons.dashboard_outlined,
);

/// Lets a freshly constructed [TourSeenNotifier] finish its async restore.
/// The SharedPreferences mock resolves through the platform channel, which
/// needs a real (if tiny) delay — two microtasks are not enough.
Future<void> _settleRestore() async {
  await Future<void>.delayed(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TourService', () {
    const service = TourService();

    test('returns a non-empty tour with valid steps for every role', () {
      final combos = <(OrgType?, String?)>{
        (OrgType.mineSupplier, 'security'),
        (OrgType.mineSupplier, 'controllerWB'),
        (OrgType.mineSupplier, 'supervisorForeman'),
        (OrgType.mineSupplier, null),
        (OrgType.buyer, 'admin'),
        (OrgType.buyer, null),
        (OrgType.transporter, 'driver'),
        (OrgType.transporter, 'admin'),
        (OrgType.transporter, null),
        (null, null),
      };

      for (final (orgType, role) in combos) {
        final steps = service.getTourForUser(orgType, role);
        expect(
          steps,
          isNotEmpty,
          reason: 'no tour for orgType=$orgType role=$role',
        );

        final ids = steps.map((s) => s.id).toSet();
        expect(
          ids.length,
          steps.length,
          reason:
              'duplicate step ids in tour for orgType=$orgType '
              'role=$role',
        );

        for (final step in steps) {
          expect(step.targetKey, isNotNull);
          expect(step.title, isNotEmpty);
          expect(step.description, isNotEmpty);
        }
      }
    });

    test('transporter admin tour walks the fleet and routes screens', () {
      final steps = service.getTourForUser(OrgType.transporter, 'admin');
      final ids = steps.map((s) => s.id).toList();

      // Dashboard steps come first — their targets are only mounted there.
      expect(ids.take(3), [
        'transporter.fleet_status',
        'transporter.available_routes',
        'transporter.active_trips',
      ]);

      // Then the fleet management screen (a real go() navigation).
      final fleetStep = steps.firstWhere(
        (s) => s.id == 'transporter.fleet_summary',
      );
      expect(fleetStep.navigateTo, '/portal/transporter/fleet');

      // Then the routes screen.
      final routesStep = steps.firstWhere(
        (s) => s.id == 'transporter.routes_waiting',
      );
      expect(routesStep.navigateTo, '/portal/transporter/routes');
    });

    test(
      'buyer admin tour reaches the requests and reconciliations screens',
      () {
        final steps = service.getTourForUser(OrgType.buyer, 'admin');

        // The requests step navigates to the requests screen and targets a key
        // WRAPPED THERE — not the dashboard's Product Requests section, which
        // unmounts the moment the navigation happens.
        final requests = steps.firstWhere((s) => s.id == 'buyer.requests');
        expect(requests.navigateTo, '/portal/buyer/requests');
        expect(requests.targetKey, isNot(same(steps.first.targetKey)));

        expect(
          steps.firstWhere((s) => s.id == 'buyer.reconciliations').navigateTo,
          '/portal/buyer/reconciliations',
        );
      },
    );

    test('mine supervisor tour reaches requests and reconciliations', () {
      final steps = service.getTourForUser(OrgType.mineSupplier, null);
      expect(
        steps
            .firstWhere((s) => s.id == 'mine.transportation_requests')
            .navigateTo,
        '/portal/mine/requests',
      );
      expect(
        steps.firstWhere((s) => s.id == 'mine.reconciliations').navigateTo,
        '/portal/mine/reconciliations',
      );
    });
  });

  group('TourProvider', () {
    late ProviderContainer container;
    final keyA = GlobalKey();
    final keyB = GlobalKey();

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('start / next / previous / goToStep walk the steps', () {
      final notifier = container.read(tourProvider.notifier);
      expect(container.read(tourProvider).isActive, isFalse);

      notifier.startTour([_step('a', keyA), _step('b', keyB)]);
      expect(container.read(tourProvider).currentStep?.id, 'a');

      notifier.nextStep();
      expect(container.read(tourProvider).currentStep?.id, 'b');

      notifier.previousStep();
      expect(container.read(tourProvider).currentStep?.id, 'a');

      notifier.goToStep(1);
      expect(container.read(tourProvider).currentStep?.id, 'b');

      // nextStep on the last step ENDS the tour…
      notifier.nextStep();
      expect(container.read(tourProvider).isActive, isFalse);
    });

    test('stopping the tour marks it seen', () async {
      final notifier = container.read(tourProvider.notifier);
      notifier.startTour([_step('a', keyA)]);

      // Construct the seen notifier first — the provider is lazy — then let
      // its async restore finish before judging the restored value.
      container.read(tourSeenProvider);
      await _settleRestore();
      expect(
        container.read(tourSeenProvider),
        isFalse,
        reason: 'a fresh user has not seen the tour yet',
      );

      notifier.stopTour();
      expect(container.read(tourSeenProvider), isTrue);
    });
  });

  group('TourSeenProvider (persistence)', () {
    test(
      'a fresh install has not seen the tour; markSeen persists it',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(tourSeenProvider); // construct — the provider is lazy
        await _settleRestore();
        expect(container.read(tourSeenProvider), isFalse);

        await container.read(tourSeenProvider.notifier).markSeen();
        expect(container.read(tourSeenProvider), isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('tour_seen'), isTrue);
      },
    );

    test(
      'the seen flag survives an app restart (a new container restores it)',
      () async {
        SharedPreferences.setMockInitialValues({'tour_seen': true});
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(tourSeenProvider); // construct — the provider is lazy
        await _settleRestore();
        expect(
          container.read(tourSeenProvider),
          isTrue,
          reason: 'a returning user who completed the tour sees no badge',
        );
      },
    );

    test('reset clears the flag and persists the cleared value', () async {
      SharedPreferences.setMockInitialValues({'tour_seen': true});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(tourSeenProvider); // construct — the provider is lazy
      await _settleRestore();
      expect(container.read(tourSeenProvider), isTrue);

      await container.read(tourSeenProvider.notifier).reset();
      expect(container.read(tourSeenProvider), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tour_seen'), isFalse);
    });
  });

  group('TourDebugNotifier', () {
    final keyA = GlobalKey();
    final keyB = GlobalKey();

    /// A container whose `tourStepsProvider` is overridden with [steps].
    ///
    /// The real provider reads the auth/company/employee providers, which
    /// construct an `AuthService` and touch `Supabase.instance` — none of
    /// which this suite initializes. The debug notifier only counts and
    /// names the steps, so a stub list isolates it cleanly.
    ProviderContainer makeContainer(List<TourStep> steps) {
      final c = ProviderContainer(
        overrides: [tourStepsProvider.overrideWith((ref) => steps)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('startTourFromStep begins the tour at the requested step', () {
      final container = makeContainer([_step('a', keyA), _step('b', keyB)]);
      final debug = container.read(tourDebugProvider.notifier);
      container.read(tourProvider.notifier).startTour([
        _step('a', keyA),
        _step('b', keyB),
      ]);

      debug.startTourFromStep(1);

      final state = container.read(tourProvider);
      expect(state.isActive, isTrue);
      expect(state.currentStepIndex, 1);
      expect(state.currentStep?.id, 'b');
      expect(
        container.read(tourDebugProvider).lastDebugAction,
        contains('step 1'),
      );
    });

    test('startTourFromStep rejects an out-of-range index without jumping', () {
      // No steps at all — a no-op, not a crash.
      final empty = makeContainer(const []);
      empty.read(tourDebugProvider.notifier).startTourFromStep(0);
      expect(empty.read(tourProvider).isActive, isFalse);

      // Steps exist, but the index is out of range — the tour stays put.
      final container = makeContainer([_step('a', keyA), _step('b', keyB)]);
      container.read(tourProvider.notifier).startTour([
        _step('a', keyA),
        _step('b', keyB),
      ]);
      container.read(tourDebugProvider.notifier).startTourFromStep(99);
      expect(container.read(tourProvider).currentStepIndex, 0);
    });

    test('resetTourCompletion clears the seen flag', () async {
      final container = makeContainer(const []);
      container.read(tourSeenProvider); // construct — the provider is lazy
      await _settleRestore(); // let the restore finish BEFORE markSeen, or it
      // lands afterwards and overwrites the seen value back to false.

      await container.read(tourSeenProvider.notifier).markSeen();
      expect(container.read(tourSeenProvider), isTrue);

      await container.read(tourDebugProvider.notifier).resetTourCompletion();
      expect(container.read(tourSeenProvider), isFalse);
      expect(
        container.read(tourDebugProvider).lastDebugAction,
        'Reset tour completion',
      );
    });

    test('logTourState records the debug action', () {
      final container = makeContainer([_step('a', keyA), _step('b', keyB)]);
      container.read(tourProvider.notifier).startTour([
        _step('a', keyA),
        _step('b', keyB),
      ]);

      container.read(tourDebugProvider.notifier).logTourState();
      expect(
        container.read(tourDebugProvider).lastDebugAction,
        'Logged tour state',
      );
    });

    testWidgets('debugTarget reports geometry for a mounted target and null '
        'for one that is not in the tree', (tester) async {
      final mountedKey = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: TourTarget(
                id: 'test.mounted',
                targetKey: mountedKey,
                child: const Text('Target widget'),
              ),
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('Target widget')),
      );

      final debug = container.read(tourDebugProvider.notifier);
      debug.debugTarget(mountedKey, 'test.mounted');
      // lastDebugAction reads "Target <id>: <offset> <size>" once mounted.
      expect(
        container.read(tourDebugProvider).lastDebugAction,
        contains('Target test.mounted'),
      );

      debug.debugTarget(GlobalKey(), 'never.built');
      expect(
        container.read(tourDebugProvider).lastDebugAction,
        contains('context is null'),
      );
    });
  });

  group('TourOverlay', () {
    testWidgets('spotlights a mounted target and shows its tooltip', (
      tester,
    ) async {
      final mountedKey = GlobalKey();
      await tester.pumpWidget(_overlayHarness(mountedKey: mountedKey));
      final container = ProviderScope.containerOf(
        tester.element(find.text('Target widget')),
      );

      container.read(tourProvider.notifier).startTour([
        _step('only', mountedKey),
      ]);

      // One pump to build the overlay, one post-frame for the measurement.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Step only'), findsOneWidget);
      expect(find.text('Description for only'), findsOneWidget);
      expect(
        find.text('Got it!'),
        findsOneWidget,
        reason: 'a one-step tour shows the final button, not Next',
      );

      container.read(tourProvider.notifier).stopTour();
      await tester.pump();
      expect(container.read(tourProvider).isActive, isFalse);
    });

    testWidgets('skips a step whose target is not mounted, and ending the '
        'tour marks it seen', (tester) async {
      final mountedKey = GlobalKey();
      await tester.pumpWidget(_overlayHarness(mountedKey: mountedKey));
      final container = ProviderScope.containerOf(
        tester.element(find.text('Target widget')),
      );

      // NOTE: the fresh-user restore semantics are covered by the
      // TourSeenProvider group above; here we only assert the skip behaviour
      // and that ending the tour marks it seen (a synchronous write).

      // Step 'ghost' targets a key that was never inserted into the tree.
      container.read(tourProvider.notifier).startTour([
        _step('ghost', GlobalKey()),
        _step('real', mountedKey),
      ]);
      await tester.pump();

      // The missing target costs one 500ms delay before the step is skipped.
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        container.read(tourProvider).currentStep?.id,
        'real',
        reason: 'the unmounted target was skipped, not stuck on',
      );

      // And the mounted step still gets its spotlight.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Step real'), findsOneWidget);

      container.read(tourProvider.notifier).stopTour();
      await tester.pump();
      expect(
        container.read(tourSeenProvider),
        isTrue,
        reason: 'stopTour (skip or finish) marks the tour seen',
      );
    });

    testWidgets('a stale skip timer never skips the step that followed it', (
      tester,
    ) async {
      // Regression for the "Fleet Register → Next kills the rest of the
      // tour" wedge: the missing-target skip timer armed by step N must not
      // fire a skip once the user is already on step N+1 (e.g. a slow
      // navigateTo render armed a timer, then Back/Next moved on).
      final mountedKey = GlobalKey();
      await tester.pumpWidget(_overlayHarness(mountedKey: mountedKey));
      final container = ProviderScope.containerOf(
        tester.element(find.text('Target widget')),
      );

      container.read(tourProvider.notifier).startTour([
        _step('ghost', GlobalKey()),
        _step('real', mountedKey),
      ]);
      await tester.pump();

      // User moves on BEFORE the ghost's 500ms skip timer elapses
      // (Back/Next tap, or the overlay re-measuring after navigation).
      container.read(tourProvider.notifier).nextStep();
      expect(container.read(tourProvider).currentStep?.id, 'real');

      // Let every stale timer elapse: the tour must still sit on 'real'
      // with its tooltip visible — not skipped to completion.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        container.read(tourProvider).currentStep?.id,
        'real',
        reason:
            'a stale skip timer from the previous step must not skip '
            'the current step',
      );
      expect(
        container.read(tourProvider).isActive,
        isTrue,
        reason: 'the tour must not have run to completion on its own',
      );
      expect(find.text('Step real'), findsOneWidget);

      container.read(tourProvider.notifier).stopTour();
      await tester.pump();
    });

    testWidgets('tapping Next advances through every step to completion', (
      tester,
    ) async {
      // The exact user report: Next on one card must never wedge the steps
      // after it.
      final keyA = GlobalKey();
      final keyB = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Stack(
                children: [
                  Column(
                    children: [
                      TourTarget(
                        id: 'test.a',
                        targetKey: keyA,
                        child: const Text('Target A'),
                      ),
                      TourTarget(
                        id: 'test.b',
                        targetKey: keyB,
                        child: const Text('Target B'),
                      ),
                    ],
                  ),
                  const TourOverlay(),
                ],
              ),
            ),
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('Target A')),
      );

      container.read(tourProvider.notifier).startTour([
        _step('a', keyA),
        _step('b', keyB),
      ]);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Step a'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        container.read(tourProvider).currentStep?.id,
        'b',
        reason: 'tapping Next advances to the following step',
      );
      expect(find.text('Step b'), findsOneWidget);

      await tester.tap(find.text('Got it!'));
      await tester.pump();
      expect(
        container.read(tourProvider).isActive,
        isFalse,
        reason: 'the final step finishes the tour',
      );
    });

    testWidgets('a tour whose every target is missing runs to completion', (
      tester,
    ) async {
      final mountedKey = GlobalKey();
      await tester.pumpWidget(_overlayHarness(mountedKey: mountedKey));
      final container = ProviderScope.containerOf(
        tester.element(find.text('Target widget')),
      );

      container.read(tourProvider.notifier).startTour([
        _step('ghost1', GlobalKey()),
        _step('ghost2', GlobalKey()),
      ]);

      // Each missing step costs one 500ms skip delay.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(
        container.read(tourProvider).isActive,
        isFalse,
        reason: 'the tour did not wedge on targets that do not exist',
      );
    });
  });
}
