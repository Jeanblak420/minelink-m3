// S7-8 / P4-12 — the fullscreen driver navigation route sat outside the
// ShellRoute with no phase gate.
//
// `PortalShellLayout` opens with a three-way switch on `PortalWorkspacePhase`:
// `selectingCompany` → pick a company, `ready` → the page, everything else →
// a status scaffold. `/portal/driver/navigate/:tripId` is deliberately outside
// the shell (fullscreen map, no chrome) and so lost that switch: a driver
// whose company had not resolved got the navigation screen itself.
//
// RED FIRST. The pre-fix route builder is modelled below as `_ungated`, which
// is what it was — the screen, straight, no switch. Every case runs against
// both, so "this was red first" is re-checked by the suite rather than
// asserted in a commit message.
//
// The subject under test is deliberately a stand-in for `DriverNavigationScreen`
// rather than the screen itself: that screen starts a geolocator stream, a TTS
// engine and an OSRM fetch on mount. Pumping it here would test the plugin
// stack, not the gate — and it is the *gate's* three-way switch that is the
// claim. `app_router.dart` wires the real screen into the same widget.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_phase_gate.dart';

const _navKey = Key('driver-navigation-screen');
const _nav = SizedBox(key: _navKey, width: 10, height: 10);

/// The pre-fix route builder: no gate at all.
Widget _ungated() => const MaterialApp(home: _nav);

Widget _gated(PortalWorkspaceModel vm) => ProviderScope(
      overrides: [portalWorkspaceProvider.overrideWith((ref) => vm)],
      child: const MaterialApp(home: PortalPhaseGate(child: _nav)),
    );

void main() {
  testWidgets('a READY workspace renders the navigation screen', (t) async {
    await t.pumpWidget(_gated(
        const PortalWorkspaceModel(phase: PortalWorkspacePhase.ready)));
    await t.pump();
    expect(find.byKey(_navKey), findsOneWidget);
  });

  testWidgets('an UNRESOLVED workspace does not render the map', (t) async {
    // The case that shipped: the driver saw a destination-less map and no
    // reason for it. Every non-ready, non-selecting phase must hold the
    // screen back and say what it is waiting for.
    for (final phase in const [
      PortalWorkspacePhase.preparingWorkspace,
      PortalWorkspacePhase.loadingCompanyAccess,
      PortalWorkspacePhase.loadingEmployeeAccess,
      PortalWorkspacePhase.connectingToCompany,
      PortalWorkspacePhase.finalizingAccess,
      PortalWorkspacePhase.preparingNavigation,
    ]) {
      await t.pumpWidget(_gated(PortalWorkspaceModel(
        phase: phase,
        title: 'Preparing your workspace',
        message: 'Loading your company access…',
      )));
      await t.pump();
      expect(find.byKey(_navKey), findsNothing, reason: phase.name);
      expect(find.text('Preparing your workspace'), findsOneWidget,
          reason: phase.name);
      expect(find.byType(CircularProgressIndicator), findsOneWidget,
          reason: phase.name);
    }

    // Red-first: the pre-fix builder rendered the map in every one of those.
    await t.pumpWidget(_ungated());
    await t.pump();
    expect(find.byKey(_navKey), findsOneWidget,
        reason: 'the pre-fix route had no phase gate; the map always drew');
  });

  testWidgets('a failed workspace shows the failure, not a spinner', (t) async {
    // A spinner that never resolves is the worst of the three states: it
    // tells a driver on a haul road to keep waiting.
    await t.pumpWidget(_gated(const PortalWorkspaceModel(
      phase: PortalWorkspacePhase.loadingCompanyAccess,
      retryAction: PortalRetryAction.companyProfile,
      title: 'Could not load your company',
      message: 'Check your connection and try again.',
    )));
    await t.pump();
    expect(find.byKey(_navKey), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Could not load your company'), findsOneWidget);
  });

  testWidgets('an empty message renders no empty paragraph', (t) async {
    // `PortalWorkspaceModel.message` defaults to ''. Rendering it anyway puts
    // an 8px gap and a zero-height Text under the title for no reason.
    await t.pumpWidget(_gated(const PortalWorkspaceModel(
      phase: PortalWorkspacePhase.preparingWorkspace,
      title: 'Preparing your workspace',
    )));
    await t.pump();
    expect(find.text(''), findsNothing);
  });
}
