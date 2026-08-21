// Fixture data for THE CONSOLE'S TAIL — the super-admin screens that had never
// been rendered.
//
// Added 2026-08-21. Separate from `console_capture_fixtures.dart` so the four
// screens already photographed keep exactly the providers they were
// photographed with, and separate from `portal_capture_fixtures.dart` because
// none of this is one company's view of its own loop: it is the platform's view
// of everybody, which is the data that must never leak into a portal render.
//
// Every list here is deliberately UNEVEN. The whole value of a fixture is that
// it contains the row a uniform one would never have — the user with no
// company, the revoked token, the crash with no stack, the deactivation already
// applied, the route nobody has ever run, the truck that has stopped moving.
// A screen that renders five identical healthy rows has been photographed
// without being tested.
//
// The figures are invented and the companies are the seeded demo ones, so
// nothing in these images can be mistaken for a real organisation's data. What
// is real is every pixel of layout, type, colour and shape.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/live_tracking_provider.dart';
import 'package:flutter_application_1/features/super_admin/data/models/account_deactivation_row.dart';
import 'package:flutter_application_1/features/super_admin/data/models/audit_log.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/data/models/crash_report_row.dart';
import 'package:flutter_application_1/features/super_admin/data/models/organization_seat.dart';
import 'package:flutter_application_1/features/super_admin/data/models/serial_token.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/screens/driver_limit_requests_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/available_routes_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/route_marketplace_screen.dart';

import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/super_admin/data/models/business_pair.dart';

import 'console_capture_fixtures.dart'
    show kOrganizations, kTransporterInsights;
import 'portal_capture_fixtures.dart' show kCaptureNow;

DateTime _ago(Duration d) => kCaptureNow.subtract(d);

const String kLongOrgName =
    'Consolidated Mineral Offtake & Logistics Holdings';

// ---------------------------------------------------------------------------
// Platform users
// ---------------------------------------------------------------------------

Map<String, dynamic> _user(
  String id,
  String first,
  String last,
  String role, {
  String? companyId,
  String? companyName,
  String? orgType,
  String? email,
}) =>
    {
      'id': id,
      'first_name': first,
      'last_name': last,
      'role': role,
      'company_id': companyId,
      'company_name': companyName,
      'org_type': orgType,
      'profiles': {
        'email': email ?? '${first.toLowerCase()}@example.co.za',
        'display_name': '$first $last',
      },
    };

/// Users across four organisations, plus one with no company at all.
///
/// The orphan is the point. `PlatformUsersScreen` groups by `company_id` and
/// files anything without one under `__orphan__`; a fixture where every user
/// belongs somewhere never renders that group — and it is the group an admin
/// most needs, because a user with no company can sign in and reach nothing.
final List<Map<String, dynamic>> kPlatformUsers = [
  _user('u1', 'Thabo', 'Mahlangu', 'admin',
      companyId: 'o1',
      companyName: 'Iron Hills Mining',
      orgType: 'mineSupplier'),
  _user('u2', 'Naledi', 'Khoza', 'supervisorForeman',
      companyId: 'o1',
      companyName: 'Iron Hills Mining',
      orgType: 'mineSupplier'),
  _user('u3', 'Pieter', 'van der Merwe', 'controllerWB',
      companyId: 'o1',
      companyName: 'Iron Hills Mining',
      orgType: 'mineSupplier'),
  _user('u4', 'Sarah', 'Bennett', 'management',
      companyId: 'o2',
      companyName: 'Atlas Buyer Group',
      orgType: 'buyer'),
  _user('u5', 'Sipho', 'Dlamini', 'driver',
      companyId: 'o3',
      companyName: 'Roadhaul Logistics',
      orgType: 'transporter'),
  _user('u6', 'Johannes', 'Oosthuizen', 'admin',
      companyId: 'o4',
      companyName: kLongOrgName,
      orgType: 'buyer',
      email: 'johannes.oosthuizen@consolidatedmineralofftake.co.za'),
  _user('u7', 'Unassigned', 'Account', 'driver'),
];

// ---------------------------------------------------------------------------
// Audit logs
// ---------------------------------------------------------------------------

AuditLog _log(
  String id,
  String action,
  String targetType,
  String description,
  Duration ago, {
  String actor = 'jean@cyberhouse.co.za',
  String? orgName,
  String? orgType,
  String? targetName,
  String? ip,
}) =>
    AuditLog(
      id: id,
      actorUserId: 'admin-1',
      actorEmail: actor,
      actorPlatformRole: 'super_global_serial_admin_main',
      actionType: action,
      targetType: targetType,
      targetName: targetName,
      organizationId: 'o1',
      organizationName: orgName,
      organizationType: orgType,
      description: description,
      ipAddress: ip,
      createdAt: _ago(ago),
    );

/// Nine entries across the action families the screen tones differently, and
/// three with no IP recorded — an absent column has to render as an absence.
final List<AuditLog> kAuditLogs = [
  _log('a1', 'TOKEN_GENERATED', 'serial_token',
      'Issued a 365-day serial token with 5 seats.',
      const Duration(minutes: 22),
      orgName: 'Iron Hills Mining',
      orgType: 'mineSupplier',
      targetName: 'MLK-4F2A',
      ip: '102.132.14.7'),
  _log('a2', 'TOKEN_REQUEST_APPROVED', 'token_request',
      'Approved 2 extra seats for Atlas Buyer Group.',
      const Duration(hours: 3),
      orgName: 'Atlas Buyer Group', orgType: 'buyer', ip: '102.132.14.7'),
  _log('a3', 'COMPANY_SUSPENDED', 'company',
      'Suspended for non-payment; the owner was notified by email and phone.',
      const Duration(hours: 9),
      orgName: kLongOrgName,
      orgType: 'buyer',
      targetName: kLongOrgName,
      ip: '41.13.208.190'),
  _log('a4', 'USER_ASSIGNED_TO_SEAT', 'organization_seat',
      'Seat 4 assigned to sipho@roadhaul.co.za.', const Duration(days: 1),
      orgName: 'Roadhaul Logistics',
      orgType: 'transporter',
      ip: '41.13.208.190'),
  _log('a5', 'SEAT_LIMIT_UPDATED', 'company', 'Seat limit 5 to 8.',
      const Duration(days: 2),
      orgName: 'Roadhaul Logistics', orgType: 'transporter'),
  _log('a6', 'TOKEN_REVOKED', 'serial_token',
      'Revoked: the token had been shared outside the company.',
      const Duration(days: 3),
      actor: 'second.admin@cyberhouse.co.za',
      orgName: 'Sable Ridge Chrome',
      orgType: 'mineSupplier',
      targetName: 'MLK-91C7',
      ip: '196.44.2.11'),
  _log('a7', 'ORGANIZATION_PROFILE_UPDATED', 'company',
      'Physical address corrected.', const Duration(days: 4),
      orgName: 'Iron Hills Mining', orgType: 'mineSupplier'),
  _log('a8', 'COMPANY_REACTIVATED', 'company',
      'Reactivated after payment cleared.', const Duration(days: 6),
      orgName: 'Northvale Alloys', orgType: 'buyer', ip: '196.44.2.11'),
  _log('a9', 'TOKEN_EXPIRED', 'serial_token',
      'Token lapsed; the company can no longer sign in.',
      const Duration(days: 11),
      actor: 'system', orgName: 'Sable Ridge Chrome', orgType: 'mineSupplier'),
];

// ---------------------------------------------------------------------------
// One organisation, in detail
// ---------------------------------------------------------------------------

/// `o4`'s tokens: one live, one replaced, one revoked with its reason.
final List<SerialToken> kOrgTokens = [
  SerialToken(
    id: 'tok-1',
    organizationId: 'o4',
    organizationName: kLongOrgName,
    organizationType: 'buyer',
    tokenHash: 'hash-1',
    tokenPreview: 'MLK-4F2A',
    validDays: 365,
    issuedAt: _ago(const Duration(days: 51)),
    expiresAt: _ago(const Duration(days: -314)),
    seatLimit: 5,
    status: 'active',
    generatedByUserId: 'admin-1',
    generatedByEmail: 'jean@cyberhouse.co.za',
    generatedByPlatformRole: 'super_global_serial_admin_main',
    createdAt: _ago(const Duration(days: 51)),
    updatedAt: _ago(const Duration(days: 51)),
  ),
  SerialToken(
    id: 'tok-2',
    organizationId: 'o4',
    organizationName: kLongOrgName,
    organizationType: 'buyer',
    tokenHash: 'hash-2',
    tokenPreview: 'MLK-77B1',
    validDays: 90,
    issuedAt: _ago(const Duration(days: 150)),
    expiresAt: _ago(const Duration(days: 60)),
    seatLimit: 3,
    status: 'replaced',
    generatedByUserId: 'admin-1',
    generatedByEmail: 'jean@cyberhouse.co.za',
    generatedByPlatformRole: 'super_global_serial_admin_main',
    createdAt: _ago(const Duration(days: 150)),
    updatedAt: _ago(const Duration(days: 51)),
  ),
  SerialToken(
    id: 'tok-3',
    organizationId: 'o4',
    organizationName: kLongOrgName,
    organizationType: 'buyer',
    tokenHash: 'hash-3',
    tokenPreview: 'MLK-91C7',
    validDays: 365,
    issuedAt: _ago(const Duration(days: 300)),
    expiresAt: _ago(const Duration(days: -65)),
    seatLimit: 3,
    status: 'revoked',
    generatedByUserId: 'admin-2',
    generatedByEmail: 'second.admin@cyberhouse.co.za',
    generatedByPlatformRole: 'super_global_serial_admin_main',
    revokedBy: 'jean@cyberhouse.co.za',
    revokedAt: _ago(const Duration(days: 152)),
    revokeReason: 'Token shared outside the company.',
    createdAt: _ago(const Duration(days: 300)),
    updatedAt: _ago(const Duration(days: 152)),
  ),
];

/// Five seats: three occupied, one free, one disabled.
final List<OrganizationSeat> kOrgSeats = [
  OrganizationSeat(
    id: 'seat-1',
    organizationId: 'o4',
    seatNumber: 1,
    status: 'occupied',
    occupiedByUserId: 'u6',
    occupiedByName: 'Johannes Oosthuizen',
    occupiedByEmail: 'johannes.oosthuizen@consolidatedmineralofftake.co.za',
    occupiedByEmployeeRole: 'admin',
    employeeFirstName: 'Johannes',
    employeeLastName: 'Oosthuizen',
    serialNumber: 'CMO-001',
    assignedAt: _ago(const Duration(days: 50)),
    createdAt: _ago(const Duration(days: 51)),
    updatedAt: _ago(const Duration(days: 50)),
  ),
  OrganizationSeat(
    id: 'seat-2',
    organizationId: 'o4',
    seatNumber: 2,
    status: 'occupied',
    occupiedByUserId: 'u8',
    occupiedByName: 'Refilwe Motaung',
    occupiedByEmail: 'refilwe@consolidatedmineralofftake.co.za',
    occupiedByEmployeeRole: 'management',
    employeeFirstName: 'Refilwe',
    employeeLastName: 'Motaung',
    serialNumber: 'CMO-002',
    assignedAt: _ago(const Duration(days: 40)),
    createdAt: _ago(const Duration(days: 51)),
    updatedAt: _ago(const Duration(days: 40)),
  ),
  OrganizationSeat(
    id: 'seat-3',
    organizationId: 'o4',
    seatNumber: 3,
    status: 'occupied',
    occupiedByUserId: 'u9',
    occupiedByName: 'Kagiso Nkosi',
    occupiedByEmail: 'kagiso@consolidatedmineralofftake.co.za',
    occupiedByEmployeeRole: 'admin',
    employeeFirstName: 'Kagiso',
    employeeLastName: 'Nkosi',
    serialNumber: 'CMO-003',
    assignedAt: _ago(const Duration(days: 12)),
    createdAt: _ago(const Duration(days: 51)),
    updatedAt: _ago(const Duration(days: 12)),
  ),
  OrganizationSeat(
    id: 'seat-4',
    organizationId: 'o4',
    seatNumber: 4,
    status: 'available',
    createdAt: _ago(const Duration(days: 51)),
    updatedAt: _ago(const Duration(days: 51)),
  ),
  OrganizationSeat(
    id: 'seat-5',
    organizationId: 'o4',
    seatNumber: 5,
    status: 'disabled',
    createdAt: _ago(const Duration(days: 51)),
    updatedAt: _ago(const Duration(days: 20)),
  ),
];

/// `o4`'s users, grouped the way `getUsersGroupedByRole` returns them.
final Map<String, List<Map<String, dynamic>>> kCompanyUsersGrouped = {
  'admin': [
    _user('u6', 'Johannes', 'Oosthuizen', 'admin',
        companyId: 'o4',
        companyName: kLongOrgName,
        orgType: 'buyer',
        email: 'johannes.oosthuizen@consolidatedmineralofftake.co.za'),
    _user('u9', 'Kagiso', 'Nkosi', 'admin',
        companyId: 'o4', companyName: kLongOrgName, orgType: 'buyer'),
  ],
  'management': [
    _user('u8', 'Refilwe', 'Motaung', 'management',
        companyId: 'o4', companyName: kLongOrgName, orgType: 'buyer'),
  ],
};

// ---------------------------------------------------------------------------
// Crash reports
// ---------------------------------------------------------------------------

/// Four fingerprints: a fatal one, a non-fatal advisory, one with NO STACK at
/// all, and one from a platform with no app version recorded.
final List<CrashReportRow> kCrashReports = [
  CrashReportRow(
    id: 'cr-1',
    userId: 'u5',
    at: _ago(const Duration(hours: 2)),
    platform: 'android',
    appVersion: '1.0.4+42',
    error: 'RangeError (index): Invalid value: Valid value range is empty: 0',
    stack: '#0      List.[] (dart:core-patch/growable_array.dart:264:36)\n'
        '#1      _DriverRoutesScreenState._hero (driver_routes_screen.dart:412)\n'
        '#2      StatefulElement.build (framework.dart:5588:27)',
    fatal: true,
    createdAt: _ago(const Duration(hours: 2)),
  ),
  CrashReportRow(
    id: 'cr-2',
    userId: 'u1',
    at: _ago(const Duration(hours: 7)),
    platform: 'web',
    appVersion: '1.0.4+42',
    error: 'A RenderFlex overflowed by 37 pixels on the right.',
    stack: '#0      RenderFlex.paint (flex.dart:1044:15)',
    fatal: false,
    createdAt: _ago(const Duration(hours: 7)),
  ),
  CrashReportRow(
    id: 'cr-3',
    at: _ago(const Duration(days: 1, hours: 4)),
    platform: 'ios',
    appVersion: '1.0.3+38',
    error: 'PlatformException(channel-error, Unable to establish connection '
        'on channel., null, null)',
    fatal: true,
    createdAt: _ago(const Duration(days: 1, hours: 4)),
  ),
  CrashReportRow(
    id: 'cr-4',
    userId: 'u4',
    at: _ago(const Duration(days: 3)),
    platform: 'windows',
    error: 'Bad state: Cannot add new events after calling close',
    stack: '#0      _BroadcastStreamController.add (broadcast_stream.dart:239)',
    fatal: false,
    createdAt: _ago(const Duration(days: 3)),
  ),
];

const ({Set<String> platforms, Set<String> appVersions}) kCrashFacets = (
  platforms: {'android', 'ios', 'web', 'windows'},
  appVersions: {'1.0.4+42', '1.0.3+38'},
);

// ---------------------------------------------------------------------------
// Account deactivations
// ---------------------------------------------------------------------------

/// One waiting on review, one approved and counting down, one already applied,
/// and — the row that matters — a company OWNER with live trips on the road.
///
/// The status strings are the WIRE values the screen switches on: `pending`,
/// `approved`, `deactivated`, `rejected`, `cancelled`, `reactivated`. The first
/// draft of this fixture invented `requested`, which matches none of them — so
/// the queue rendered with no Approve/Reject buttons and no auto-apply
/// countdown, and looked like a screen that had simply not been built. Same
/// trap as the token-request fixture that invented `seats` and `validity`.
/// Rendering it is what caught both.
final List<AccountDeactivationRow> kDeactivations = [
  AccountDeactivationRow(
    id: 'd1',
    userId: 'u5',
    displayName: 'Sipho Dlamini',
    email: 'sipho@roadhaul.co.za',
    companyName: 'Roadhaul Logistics',
    role: 'driver',
    reason: 'Leaving the company at the end of the month.',
    status: 'pending',
    requestedAt: _ago(const Duration(hours: 5)),
    autoApplyAt: _ago(const Duration(days: -6, hours: -19)),
    isCompanyOwner: false,
    activeTrips: 0,
  ),
  AccountDeactivationRow(
    id: 'd2',
    userId: 'u10',
    displayName: 'Elmarie Steyn',
    email: 'elmarie@ironhills.co.za',
    companyName: 'Iron Hills Mining',
    role: 'controllerWB',
    reason: 'Retiring.',
    status: 'approved',
    requestedAt: _ago(const Duration(days: 2)),
    autoApplyAt: _ago(const Duration(days: -5)),
    reviewNote: 'Confirmed with the mine manager on the phone.',
    isCompanyOwner: false,
    activeTrips: 0,
  ),
  AccountDeactivationRow(
    id: 'd3',
    userId: 'u11',
    displayName: 'Bongani Zulu',
    email: 'bongani@northline.co.za',
    companyName: 'Northline Carriers',
    role: 'driver',
    status: 'deactivated',
    requestedAt: _ago(const Duration(days: 21)),
    autoApplyAt: _ago(const Duration(days: 14)),
    deactivatedAt: _ago(const Duration(days: 14)),
    isCompanyOwner: false,
    activeTrips: 0,
  ),
  AccountDeactivationRow(
    id: 'd4',
    userId: 'u6',
    displayName: 'Johannes Oosthuizen',
    email: 'johannes.oosthuizen@consolidatedmineralofftake.co.za',
    companyName: kLongOrgName,
    role: 'admin',
    reason: 'Requested by the owner directly.',
    status: 'pending',
    requestedAt: _ago(const Duration(days: 1, hours: 3)),
    autoApplyAt: _ago(const Duration(days: -5, hours: -21)),
    isCompanyOwner: true,
    activeTrips: 3,
  ),
];

// ---------------------------------------------------------------------------
// Available routes and the marketplace
// ---------------------------------------------------------------------------

/// Four learned routes: one assigned to two organisations, two assigned to
/// none, and one with NO agreed transit time — every trip on which is
/// unjudgeable for on-time, so the cell has to say so rather than print a zero.
final List<AdminAvailableRoute> kAvailableRoutes = [
  AdminAvailableRoute(
    routeId: 'rt-1',
    routeNumber: 'RT-0042',
    commodity: 'Chrome concentrate',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: 'Richards Bay Dry Bulk Terminal',
    paymentTerms: '30 days from POD',
    tons: '4000',
    numTrucks: '6',
    supplierName: 'Iron Hills Mining',
    buyerName: 'Atlas Buyer Group',
    assignedCompanies: 'Atlas Buyer Group, Northvale Alloys',
    expectedTransitHours: 18,
    createdAt: _ago(const Duration(days: 26)),
  ),
  AdminAvailableRoute(
    routeId: 'rt-2',
    routeNumber: 'RT-0043',
    commodity: 'Manganese',
    loadingPoint: 'Sable Ridge Chrome',
    offloadingPoint: 'Maputo Port',
    paymentTerms: 'COD',
    tons: '1200',
    numTrucks: '3',
    supplierName: 'Sable Ridge Chrome',
    buyerName: 'Northvale Alloys',
    expectedTransitHours: 26.5,
    createdAt: _ago(const Duration(days: 11)),
  ),
  AdminAvailableRoute(
    routeId: 'rt-3',
    routeNumber: 'RT-0044',
    commodity: 'Chrome',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: '$kLongOrgName, Rosebank',
    paymentTerms: '14 days',
    tons: '800',
    numTrucks: '2',
    supplierName: 'Iron Hills Mining',
    buyerName: kLongOrgName,
    createdAt: _ago(const Duration(days: 4)),
  ),
  AdminAvailableRoute(
    routeId: 'rt-4',
    routeNumber: 'RT-0045',
    commodity: 'Iron ore fines',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: 'Saldanha Bay',
    paymentTerms: '45 days',
    tons: '12000',
    numTrucks: '14',
    supplierName: 'Iron Hills Mining',
    buyerName: 'Atlas Buyer Group',
    expectedTransitHours: 34,
    createdAt: _ago(const Duration(days: 2)),
  ),
];

/// The marketplace: the same routes as run by real hauliers, including one
/// accepted a day ago that has moved nothing yet.
final List<MarketplaceRoute> kMarketplaceRoutes = [
  MarketplaceRoute(
    routeId: 'rt-1',
    routeNumber: 'RT-0042',
    commodity: 'Chrome concentrate',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: 'Richards Bay Dry Bulk Terminal',
    transporterName: 'Roadhaul Logistics',
    acceptedAt: _ago(const Duration(days: 25)),
    tripsTotal: 42,
    tripsCompleted: 38,
    tonsDelivered: 1284.60,
  ),
  MarketplaceRoute(
    routeId: 'rt-2',
    routeNumber: 'RT-0043',
    commodity: 'Manganese',
    loadingPoint: 'Sable Ridge Chrome',
    offloadingPoint: 'Maputo Port',
    transporterName: 'Northline Carriers',
    acceptedAt: _ago(const Duration(days: 10)),
    tripsTotal: 14,
    tripsCompleted: 12,
    tonsDelivered: 412.10,
  ),
  MarketplaceRoute(
    routeId: 'rt-4',
    routeNumber: 'RT-0045',
    commodity: 'Iron ore fines',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: 'Saldanha Bay',
    transporterName: 'Vaal Bulk Movers',
    acceptedAt: _ago(const Duration(days: 1)),
    tripsTotal: 0,
    tripsCompleted: 0,
    tonsDelivered: 0,
  ),
];

/// The buyers and mines the assignment picker offers.
const List<({String id, String name, String orgType})> kRequesterCompanies = [
  (id: 'o1', name: 'Iron Hills Mining', orgType: 'mineSupplier'),
  (id: 'o2', name: 'Atlas Buyer Group', orgType: 'buyer'),
  (id: 'o4', name: kLongOrgName, orgType: 'buyer'),
  (id: 'o5', name: 'Sable Ridge Chrome', orgType: 'mineSupplier'),
];

// ---------------------------------------------------------------------------
// Chat links
// ---------------------------------------------------------------------------

/// One granted link, between the two organisations that trade with each other.
final List<OrgConnection> kOrgConnections = [
  OrgConnection(
    id: 'conn-1',
    companyLowId: 'o1',
    companyHighId: 'o2',
    status: 'granted',
    grantedAt: _ago(const Duration(days: 30)),
  ),
];

// ---------------------------------------------------------------------------
// Live trip positions — the console's live map
// ---------------------------------------------------------------------------

/// Four trucks, on four different legs, in four different states.
///
/// One is standing still and has been for over an hour, which is the state the
/// map exists to make visible; one is loading at the mine and therefore has no
/// speed; one has a navigation instruction mirrored from the driver's device;
/// and one has never reported a position at all — the row that a map cannot
/// draw and a list still has to.
///
/// The coordinates are real South African places on the routes named, so the
/// map's own geometry — the spread of the pins, the zoom it settles on — is
/// the geometry the product will actually have.
final List<LiveTripPosition> kLivePositions = [
  LiveTripPosition(
    tripId: 'trip-1',
    status: TripStatus.enRouteToOffload,
    vehicleId: 'v1',
    truckReg: 'RH 128 GP',
    transporterName: 'Roadhaul Logistics',
    supplierName: 'Iron Hills Mining',
    buyerName: 'Atlas Buyer Group',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: 'Richards Bay Dry Bulk Terminal',
    lat: -25.9,
    lng: 30.68,
    heading: 118,
    speedKmh: 74.2,
    recordedAt: _ago(const Duration(seconds: 40)),
    driverName: 'Sipho Dlamini',
    driverPhone: '+27 82 555 0114',
    tripCreatedAt: _ago(const Duration(hours: 9)),
    arrivedAt: _ago(const Duration(hours: 8)),
    loadedAt: _ago(const Duration(hours: 6)),
    leftAt: _ago(const Duration(hours: 5, minutes: 40)),
    navInstruction: 'In 1.2 km — Turn left onto the N4 towards Komatipoort',
    navEta: _ago(const Duration(hours: -4, minutes: -10)),
    navTimeLeftS: 14 * 60 * 60 + 600,
    navDistanceLeftM: 421000,
    navSpeedKmh: 74.2,
    navUpdatedAt: _ago(const Duration(seconds: 40)),
  ),
  // Stopped, and stopped for a while. The whole reason a live map is worth
  // looking at.
  LiveTripPosition(
    tripId: 'trip-2',
    status: TripStatus.enRouteToOffload,
    vehicleId: 'v2',
    truckReg: 'NL 004 MP',
    transporterName: 'Northline Carriers',
    supplierName: 'Sable Ridge Chrome',
    buyerName: 'Northvale Alloys',
    loadingPoint: 'Sable Ridge Chrome',
    offloadingPoint: 'Maputo Port',
    lat: -25.45,
    lng: 31.99,
    heading: 74,
    speedKmh: 0,
    recordedAt: _ago(const Duration(minutes: 2)),
    stationarySince: _ago(const Duration(hours: 1, minutes: 26)),
    driverName: 'Bongani Zulu, Elias Mabuza',
    driverPhone: '+27 71 555 0192',
    tripCreatedAt: _ago(const Duration(hours: 14)),
    loadedAt: _ago(const Duration(hours: 11)),
    leftAt: _ago(const Duration(hours: 10, minutes: 30)),
  ),
  // At the mine, being loaded. No speed, no navigation.
  LiveTripPosition(
    tripId: 'trip-3',
    status: TripStatus.loading,
    vehicleId: 'v3',
    truckReg: 'RH 131 GP',
    transporterName: 'Roadhaul Logistics',
    supplierName: 'Iron Hills Mining',
    buyerName: kLongOrgName,
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: '$kLongOrgName, Rosebank',
    lat: -24.7285,
    lng: 30.2038,
    heading: 0,
    speedKmh: 0,
    recordedAt: _ago(const Duration(minutes: 6)),
    stationarySince: _ago(const Duration(minutes: 48)),
    driverName: 'Kabelo Sithole',
    tripCreatedAt: _ago(const Duration(hours: 3)),
    arrivedAt: _ago(const Duration(minutes: 55)),
    loadingAt: _ago(const Duration(minutes: 48)),
  ),
  // Scheduled, never reported a position. A map cannot draw this and a list
  // still has to.
  const LiveTripPosition(
    tripId: 'trip-4',
    status: TripStatus.scheduled,
    vehicleId: 'v4',
    truckReg: 'VB 077 GP',
    transporterName: 'Vaal Bulk Movers',
    supplierName: 'Iron Hills Mining',
    buyerName: 'Atlas Buyer Group',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: 'Saldanha Bay',
    driverName: 'Unassigned',
  ),
];

// ---------------------------------------------------------------------------
// The overrides
// ---------------------------------------------------------------------------

/// Everything the console's tail screens read.
///
/// Families are overridden wholesale, so the argument is ignored — a capture
/// renders one fixture whichever key the screen resolves. That is honest for a
/// LAYOUT reference and dishonest for anything else, which is why the company
/// names in it are visibly invented.
List<Override> consoleTailOverrides() => [
      allPlatformUsersProvider.overrideWith((ref) async => kPlatformUsers),
      // One granted chat link, so the organisation detail screen's "Chat
      // connections" section renders its list rather than its empty state —
      // and, more importantly, so the provider RESOLVES. Left alone it goes to
      // Supabase, fails after the capture's pump window has closed, and
      // rebuilds the picker underneath the photograph: the list's scrollbar
      // fade restarts on a tree nobody pumps again, so the affordance is
      // missing from the render while being perfectly present in the app.
      orgConnectionsProvider.overrideWith((ref) async => kOrgConnections),
      // The organisation the detail screen is opened on. Without it that whole
      // screen renders "Could not load organization" — an honest error state,
      // and a picture of nothing.
      organizationDetailProvider.overrideWith((ref, id) async {
        final base = kOrganizations.cast<Map<String, dynamic>?>().firstWhere(
              (o) => o?['id'] == id,
              orElse: () => kOrganizations.first,
            )!;
        // The detail screen reads four fields the REGISTRY row does not carry
        // — the CEO's name, the WhatsApp number and the nested `owner_profile`
        // — and renders a dash for each. Four dashes in a row is an honest
        // empty state and a poor picture of the section they are the whole
        // content of, so the fixture supplies them here rather than widening
        // the registry rows the list screen is photographed with.
        return {
          ...base,
          'ceo_first_name': 'Johannes',
          'ceo_last_name': 'Oosthuizen',
          'whatsapp_number': '+27 82 555 0173',
          'owner_profile': {
            'display_name': 'Johannes Oosthuizen',
            'email': 'johannes.oosthuizen@consolidatedmineralofftake.co.za',
          },
        };
      }),
      auditLogsProvider.overrideWith((ref, _) async => kAuditLogs),
      tokenHistoryAuditLogsProvider.overrideWith((ref, _) async => kAuditLogs),
      organizationTokensProvider.overrideWith((ref, _) async => kOrgTokens),
      organizationSeatsProvider.overrideWith((ref, _) async => kOrgSeats),
      companyUsersGroupedProvider
          .overrideWith((ref, _) async => kCompanyUsersGrouped),
      crashReportsProvider.overrideWith((ref, _) async => kCrashReports),
      crashReportFacetsProvider.overrideWith((ref) async => kCrashFacets),
      accountDeactivationRequestsProvider
          .overrideWith((ref) async => kDeactivations),
      adminAvailableRoutesProvider.overrideWith((ref) async => kAvailableRoutes),
      routeMarketplaceProvider.overrideWith((ref) async => kMarketplaceRoutes),
      requesterCompaniesProvider.overrideWith((ref) async => kRequesterCompanies),
      // A StreamProvider over Supabase realtime. Left alone it does not merely
      // render an error — its subscription outlives the widget tree and throws
      // from `runOnDispose`, after the harness has restored
      // `FlutterError.onError`, so the test fails with the capture already
      // written. A green PNG behind a red test is the most confusing outcome
      // available.
      liveTripPositionsProvider
          .overrideWith((ref, _) => Stream.value(kLivePositions)),
    ];

// ---------------------------------------------------------------------------
// The last of the console tail — the screens with no fixtures at all
// ---------------------------------------------------------------------------

/// What `super_admin_dashboard_v2_screen` reads for its stat band.
///
/// Every key the screen asks for, and no two of them equal: a dashboard
/// fixture whose numbers agree cannot show which tile is which. Active +
/// expired + suspended sums to the total, because the screen draws that split
/// as a bar and an inconsistent fixture photographs a bar that does not add up.
final Map<String, dynamic> kDashboardStats = {
  'totalCompanies': 24,
  'activeCompanies': 19,
  'expiredCompanies': 3,
  'suspendedCompanies': 2,
  'totalUsers': 187,
  'openTokenRequests': 4,
  'tokensExpiringSoon': 5,
  'activeRoutes': 11,
  'totalTonsManaged': 128420.5,
  'newCompanies24h': 2,
  'newUsers24h': 9,
  'newTokenRequests24h': 1,
  'newExpired24h': 1,
  'activeUsersNow': 12,
  'tons24h': 1284.0,
};

/// Which companies have traded with which, for the chat-connections screen.
///
/// The ids are `kOrganizations`' own, so both sides of every pair resolve to a
/// name — a pair that resolves to nothing photographs two blank rows.
///
/// `reason` is a SENTENCE, which is what `BusinessPair`'s own doc calls it and
/// what `fromTransactions` / `fromDispatches` really produce ("Accepted
/// transport request — Chrome", "Route dispatch to transporter", "Active
/// transaction between parties"). The first draft of this fixture used the
/// wire words `trip` and `transportation_request`, and the render printed them
/// straight onto the card — a fixture inventing a defect the product does not
/// have.
final List<BusinessPair> kBusinessPairs = [
  BusinessPair(
    companyIdA: 'o1',
    companyIdB: 'o2',
    date: _ago(const Duration(days: 2)),
    reason: 'Active transaction between parties',
  ),
  BusinessPair(
    companyIdA: 'o2',
    companyIdB: 'o4',
    date: _ago(const Duration(days: 9)),
    reason: 'Accepted transport request — Chrome',
  ),
  BusinessPair(
    companyIdA: 'o1',
    companyIdB: 'o4',
    date: _ago(const Duration(days: 31)),
    reason: 'Route dispatch to transporter',
  ),
];

/// Transporters asking to put more than two drivers on one truck.
///
/// One pending, one approved and one declined — the three states the screen
/// renders differently. A pending-only fixture shows one of them.
final List<DriverLimitRequest> kDriverLimitRequests = [
  DriverLimitRequest(
    id: 'dlr-1',
    companyId: 'co-transporter',
    companyName: 'Roadhaul Logistics',
    vehicleId: 'veh-1',
    registration: 'CK 84 RT GP',
    currentLimit: 2,
    requestedLimit: 4,
    status: 'pending',
    requestedByName: 'Thandi Mokoena',
    createdAt: _ago(const Duration(hours: 6)),
  ),
  DriverLimitRequest(
    id: 'dlr-2',
    companyId: 'co-transporter-2',
    companyName: 'Northline Carriers',
    vehicleId: 'veh-9',
    registration: 'BX 09 LM NW',
    currentLimit: 2,
    requestedLimit: 5,
    status: 'approved',
    requestedByName: 'Sipho Ndlovu',
    createdAt: _ago(const Duration(days: 4)),
    decidedAt: _ago(const Duration(days: 3)),
  ),
  DriverLimitRequest(
    id: 'dlr-3',
    companyId: 'co-transporter-3',
    companyName: 'Kalahari Freight',
    vehicleId: 'veh-12',
    registration: 'KF 220 NC',
    currentLimit: 2,
    requestedLimit: 3,
    status: 'declined',
    createdAt: _ago(const Duration(days: 18)),
    decidedAt: _ago(const Duration(days: 17)),
  ),
];

/// The company mirror, keyed to ONE organisation from the registry.
///
/// The mirror looks its subject up in `monthlyInsightsBundleProvider` BY
/// COMPANY ID, and the two console fixtures use different id namespaces on
/// purpose — the registry is `o1`..`o5`, the insight bundle is `co-t-1`..`4`.
/// So the mirror found no stats, and its "Operational snapshot" read
/// Employees 0 · Trips 0 · Tons 0.0t · Fleet 0 directly above a seven-day
/// chart drawing real bars and a timeline listing five real loads. One screen
/// contradicting itself, and none of it a product fault.
///
/// This re-keys one company in the bundle to the organisation being mirrored,
/// so the whole page describes the same company.
List<Override> companyMirrorOverrides({String companyId = 'o4'}) => [
      monthlyInsightsBundleProvider.overrideWith((ref, _) async {
        final base = kTransporterInsights;
        final first = base.companies.first;
        return MonthlyInsightsBundle(
          aggregate: base.aggregate,
          companies: [
            CompanyMonthlyOpsStats(
              companyId: companyId,
              companyName: first.companyName,
              orgType: first.orgType,
              fleetVehicles: first.fleetVehicles,
              drivers: first.drivers,
              employees: first.employees,
              routesDistinct: first.routesDistinct,
              trips: first.trips,
              loadsCount: first.loadsCount,
              tonsMoved: first.tonsMoved,
              completedWaybills: first.completedWaybills,
              pendingWaybills: first.pendingWaybills,
              onTimeTrips: first.onTimeTrips,
              dueTrips: first.dueTrips,
            ),
            ...base.companies.skip(1),
          ],
        );
      }),
    ];

/// The console screens that had no fixtures at all until 2026-08-21.
///
/// Kept apart from [consoleTailOverrides] so the screens already photographed
/// keep exactly the data they were judged against.
List<Override> consoleLastOverrides() => [
      dashboardStatsProvider.overrideWith((ref) async => kDashboardStats),
      businessPairsProvider.overrideWith((ref) async => kBusinessPairs),
      driverLimitRequestsProvider
          .overrideWith((ref) async => kDriverLimitRequests),
      // The leaderboard reads the bundle over a chosen PERIOD, which is a
      // different provider from the month-to-date one the overview uses.
      periodInsightsBundleProvider
          .overrideWith((ref, _) async => kTransporterInsights),
    ];
