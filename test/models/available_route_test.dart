import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/available_route.dart';
import 'package:flutter_application_1/features/super_admin/screens/available_routes_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/route_marketplace_screen.dart';

void main() {
  test('AvailableRoute parses a list_my_available_routes row', () {
    final r = AvailableRoute.fromJson({
      'route_id': 'rt-1',
      'route_number': 'RT-1A2B3C4D',
      'commodity': 'Chrome 38/40',
      'loading_point': 'Duma Mine',
      'offloading_point': 'Saldanha Port',
      'payment_terms': '30 days',
      'operating_hours_24h': true,
      'tons': '4000',
      'num_trucks': '6',
      'route_notes': 'Night loading preferred',
      'permanent': true,
      'assigned_at': '2026-07-12T09:00:00Z',
    });
    expect(r.routeNumber, 'RT-1A2B3C4D');
    expect(r.routeLabel, 'Duma Mine → Saldanha Port');
    expect(r.permanent, isTrue);
    expect(r.operatingHours24h, isTrue);
    expect(r.numTrucks, '6');
  });

  test('AdminAvailableRoute parses assignments summary', () {
    final r = AdminAvailableRoute.fromJson({
      'route_id': 'rt-1',
      'route_number': 'RT-1A2B3C4D',
      'loading_point': 'Duma Mine',
      'offloading_point': 'Depot',
      'created_at': '2026-07-12T09:00:00Z',
      'assigned_companies': 'SteelWorks (permanent), Haul Co',
    });
    expect(r.assignedCompanies, contains('permanent'));
    expect(r.routeLabel, 'Duma Mine → Depot');
  });

  test('MarketplaceRoute parses stats', () {
    final r = MarketplaceRoute.fromJson({
      'route_id': 'rt-1',
      'route_number': 'RT-1A2B3C4D',
      'transporter_name': 'Haul Co',
      'accepted_at': '2026-07-12T09:00:00Z',
      'trips_total': 5,
      'trips_completed': 3,
      'tons_delivered': 120.5,
    });
    expect(r.tripsTotal, 5);
    expect(r.tripsCompleted, 3);
    expect(r.tonsDelivered, 120.5);
    expect(r.routeLabel, '— → —');
  });
}
