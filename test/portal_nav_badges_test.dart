// Pins the two properties of the badge resolver that are easy to break and
// expensive to notice (P7-05).
//
// The per-source *predicates* — which request status counts as pending, which
// dispute states are open — are not covered here: every one needs a fully
// constructed domain model, and the assertions would end up restating the
// one-line `.where` they are checking. They are stated in prose beside each
// count in `portal_nav_badges.dart` and belong to the P7-42 hand-count
// against the live queues, which is the check that would actually catch a
// wrong predicate.
//
// What IS covered is the structure around them, because a fault there is
// silent: a rail that quietly fires seven queries for a driver, or a badge
// that reads "0 waiting" because the query failed.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/fleet/models/maintenance_record.dart';
import 'package:flutter_application_1/features/fleet/models/service_schedule.dart';
import 'package:flutter_application_1/features/fleet/providers/maintenance_providers.dart';
import 'package:flutter_application_1/features/portal/models/compliance_document.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav_badges.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/compliance_service.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';

/// Records which sources a read actually touched.
///
/// Deliberately a side-effect counter and NOT a throwing stub: Riverpod
/// captures an exception thrown inside a `FutureProvider` body as an
/// `AsyncError`, so a throw never propagates out of `container.read` and every
/// assertion built on one would pass whether the source was queried or not.
/// The first version of this file made exactly that mistake.
class _Touched {
  final Set<String> names = <String>{};
  T record<T>(String name, T value) {
    names.add(name);
    return value;
  }
}

void main() {
  setUpAll(() async {
    // `unreadNotifications` reads `notificationProvider`, which reaches
    // `Supabase.instance` on construction. A dummy instance is enough — the
    // count starts at 0 and no request is ever made.
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'portal-nav-badges-test-key',
    );
  });

  /// Stubs every source the resolver can reach with an empty result that
  /// records the visit.
  List<Override> recordingAll(_Touched touched) => [
        companyRequestsProvider.overrideWith(
            (ref, arg) => touched.record('requests', const [])),
        transporterDispatchesProvider.overrideWith(
            (ref, arg) => touched.record('dispatches', const [])),
        reconDisputesProvider.overrideWith(
            (ref, arg) => touched.record('disputes', const [])),
        complianceDocumentsProvider.overrideWith(
            (ref, arg) => touched.record('compliance', const [])),
        mineInboundTripsProvider.overrideWith(
            (ref, arg) => touched.record('inbound', const [])),
        fleetMaintenanceProvider.overrideWith((ref, arg) => touched.record(
            'maintenance',
            (
              records: const <MaintenanceRecord>[],
              schedules: const <ServiceSchedule>[],
            ))),
      ];

  /// The source names a tree naming [badges] is entitled to read.
  Set<String> expectedSources(Set<PortalNavBadge> badges) => {
        if (badges.contains(PortalNavBadge.pendingRequests)) 'requests',
        if (badges.contains(PortalNavBadge.unacceptedDispatches)) 'dispatches',
        if (badges.contains(PortalNavBadge.openDisputes)) 'disputes',
        if (badges.contains(PortalNavBadge.expiringCompliance)) 'compliance',
        if (badges.contains(PortalNavBadge.arrivalsAwaitingCheckIn) ||
            badges.contains(PortalNavBadge.loadsAwaitingWeigh))
          'inbound',
        if (badges.contains(PortalNavBadge.maintenanceDue)) 'maintenance',
      };

  /// The badge sources a given tree actually names.
  Set<PortalNavBadge> named(OrgType orgType, UserRole? role) => {
        for (final leaf in portalNavTree(orgType: orgType, role: role)
            .expand((n) => n.leaves))
          if (leaf.badge != null) leaf.badge!,
      };

  group('a rail queries only the sources its own tree names', () {
    const cases = <({OrgType orgType, UserRole? role})>[
      (orgType: OrgType.mineSupplier, role: null),
      (orgType: OrgType.mineSupplier, role: UserRole.security),
      (orgType: OrgType.mineSupplier, role: UserRole.controllerWB),
      (orgType: OrgType.mineSupplier, role: UserRole.supervisorForeman),
      (orgType: OrgType.buyer, role: null),
      (orgType: OrgType.transporter, role: null),
      (orgType: OrgType.transporter, role: UserRole.driver),
    ];

    for (final c in cases) {
      test('${c.orgType.name} / ${c.role?.name ?? 'company account'}', () {
        final touched = _Touched();
        final container =
            ProviderContainer(overrides: recordingAll(touched));
        addTearDown(container.dispose);

        container.read(portalNavBadgeCountsProvider((
          orgType: c.orgType,
          role: c.role,
          companyId: 'company-1',
        )));

        // Exactly the sources this tree names — no more, no fewer. A driver's
        // rail firing the mine's inbound-trips query is a real cost on a phone
        // on a haul road, not a tidiness point; and a source the tree names
        // but never reads is a badge that would silently stay dark.
        expect(touched.names, expectedSources(named(c.orgType, c.role)));
      });
    }
  });

  test('a restricted role names exactly the queues it can act on', () {
    // Written as an equality rather than a subset so that adding a badge to a
    // restricted tree has to be a deliberate edit here too. A supervisor and a
    // load controller are chased for their own documents and nothing else; the
    // load controller additionally owns the weighbridge queue.
    expect(
      named(OrgType.mineSupplier, UserRole.supervisorForeman),
      {PortalNavBadge.expiringCompliance},
    );
    expect(
      named(OrgType.mineSupplier, UserRole.controllerWB),
      {PortalNavBadge.loadsAwaitingWeigh, PortalNavBadge.expiringCompliance},
    );
    expect(
      named(OrgType.mineSupplier, UserRole.security),
      {
        PortalNavBadge.arrivalsAwaitingCheckIn,
        PortalNavBadge.expiringCompliance,
      },
    );
    expect(
      named(OrgType.transporter, UserRole.driver),
      {PortalNavBadge.expiringCompliance},
    );
  });

  test('the isolation check is not vacuous', () {
    // Guard the guard. If the overrides ever stopped applying, or the resolver
    // stopped reading anything at all, every case in the group above would
    // pass while proving nothing.
    final touched = _Touched();
    final container = ProviderContainer(overrides: recordingAll(touched));
    addTearDown(container.dispose);

    container.read(portalNavBadgeCountsProvider((
      orgType: OrgType.mineSupplier,
      role: null,
      companyId: 'company-1',
    )));

    expect(touched.names, isNotEmpty);
    expect(touched.names, contains('inbound'));
  });

  test('a source that has not loaded yields no badge, not a zero', () {
    // The distinction matters: "0 waiting" is a claim, and a failed or
    // in-flight query has not earned it. Same class of fault as the empty
    // partner list that used to hide an RLS denial.
    final container = ProviderContainer(overrides: [
      // Never completes, so the provider stays in AsyncLoading.
      complianceDocumentsProvider.overrideWith((ref, arg) => Completer<
          List<ComplianceDocument>>().future),
    ]);
    addTearDown(container.dispose);

    final counts = container.read(portalNavBadgeCountsProvider((
      orgType: OrgType.transporter,
      role: UserRole.driver,
      companyId: 'company-1',
    )));
    expect(counts.containsKey(PortalNavBadge.expiringCompliance), isFalse);
  });

  test('a source that fails yields no badge either', () {
    final container = ProviderContainer(overrides: [
      complianceDocumentsProvider.overrideWith(
        (ref, arg) => Future<List<ComplianceDocument>>.error(
            StateError('RLS denied')),
      ),
    ]);
    addTearDown(container.dispose);

    final counts = container.read(portalNavBadgeCountsProvider((
      orgType: OrgType.transporter,
      role: UserRole.driver,
      companyId: 'company-1',
    )));
    expect(counts.containsKey(PortalNavBadge.expiringCompliance), isFalse);
  });
}
