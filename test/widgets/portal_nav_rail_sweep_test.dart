// Layout sweep for the rebuilt portal rail (P7-43).
//
// The rail is the one piece of chrome every role sees on every screen, and it
// is the piece most exposed to text scale: the labels are long ("Supervisor &
// stockpiles", "Recon tables (tons out)"), the tile is a fixed-width column,
// and a badge now sits at the end of the row. `PLAN.md` §6.4 requires every
// screen to survive 0.85–1.3 with bold text.
//
// ⚠ The fonts are loaded for real. `flutter test` otherwise renders in a
// fallback font where **every glyph is one em wide**, so a 21-character label
// at 14.5 px measures 304 px instead of ~150 — which invents overflows that do
// not exist in the app and hides ones that do (CLAUDE.md §7).

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_scaffold.dart';

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

/// Widths spanning both sides of the sidebar breakpoint, so the drawer layout
/// is swept too.
const _widths = <double>[1600, 1280, 1024, 430];

/// 1.0 plus the two ends of the user-settable scale range.
const _scales = <double>[0.85, 1.0, 1.15, 1.3];

/// Every (org type, role) the portal can produce, plus the company accounts.
const _cases = <({OrgType orgType, UserRole? role})>[
  (orgType: OrgType.mineSupplier, role: null),
  (orgType: OrgType.mineSupplier, role: UserRole.supervisorForeman),
  (orgType: OrgType.mineSupplier, role: UserRole.controllerWB),
  (orgType: OrgType.mineSupplier, role: UserRole.security),
  (orgType: OrgType.buyer, role: null),
  (orgType: OrgType.transporter, role: null),
  (orgType: OrgType.transporter, role: UserRole.driver),
];

void main() {
  setUpAll(() async {
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
  });

  /// Every badge source lit at once, and at a width that forces the `99+`
  /// cap — a badge is the widest thing that can appear at the end of a tile,
  /// so the worst case is every tile carrying one.
  const loudBadges = <PortalNavBadge, int>{
    PortalNavBadge.pendingRequests: 128,
    PortalNavBadge.unacceptedDispatches: 7,
    PortalNavBadge.openDisputes: 12,
    PortalNavBadge.expiringCompliance: 99,
    PortalNavBadge.unreadNotifications: 1004,
    PortalNavBadge.arrivalsAwaitingCheckIn: 8,
    PortalNavBadge.loadsAwaitingWeigh: 15,
    PortalNavBadge.maintenanceDue: 3,
  };

  Future<void> sweep(
    WidgetTester tester, {
    required OrgType orgType,
    required UserRole? role,
    required bool expanded,
    bool boldText = false,
  }) async {
    final tree = portalNavTree(orgType: orgType, role: role);

    for (final width in _widths) {
      for (final scale in _scales) {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // Capture the full FlutterErrorDetails rather than `takeException()`,
        // which drops the "relevant error-causing widget" line — the only part
        // that says where to fix it.
        final captured = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = captured.add;

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              boldText: boldText,
            ),
            child: child!,
          ),
          home: PortalScaffold(
            nav: tree,
            // Sits inside a group, so a group is always open and its children
            // are always laid out.
            selectedRoute: tree.expand((n) => n.leaves).last.route!,
            onNavigate: (_) {},
            badgeCounts: loudBadges,
            navLocked: false,
            sidebarExpanded: expanded,
            onSidebarExpandedChanged: (_) {},
            sidebarBrandTitle: 'Iron Hills Mining Proprietary Limited',
            userName: 'Nomvula Mthembu-Vandenberghe',
            userMeta: 'Supervisor/Foreman',
            onLogout: () {},
            onNotifications: () {},
            onProfile: () {},
            appBar: AppBar(title: const Text('Dashboard')),
            body: const Center(child: Text('page')),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 400));

        FlutterError.onError = previousOnError;
        tester.takeException();

        final faults = captured.where((d) {
          final s = d.exception.toString();
          return s.contains('overflowed') ||
              s.contains('forces an infinite') ||
              s.contains('BoxConstraints');
        }).toList();

        expect(
          faults,
          isEmpty,
          reason: '${orgType.name}/${role?.name ?? 'company'} '
              '${expanded ? 'expanded' : 'collapsed'} rail at '
              '${width.toInt()}px × $scale${boldText ? ' bold' : ''}: '
              '${faults.map((f) => f.exception).join('; ')}',
        );
      }
    }
  }

  for (final c in _cases) {
    final name = '${c.orgType.name} / ${c.role?.name ?? 'company account'}';

    testWidgets('$name — expanded rail survives width × text scale',
        (tester) async {
      await sweep(tester, orgType: c.orgType, role: c.role, expanded: true);
    });

    testWidgets('$name — collapsed rail survives width × text scale',
        (tester) async {
      await sweep(tester, orgType: c.orgType, role: c.role, expanded: false);
    });

    testWidgets('$name — expanded rail survives bold text', (tester) async {
      await sweep(
        tester,
        orgType: c.orgType,
        role: c.role,
        expanded: true,
        boldText: true,
      );
    });
  }
}
