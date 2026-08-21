// The employee profile, with data behind it.
//
// `screen-employee-profile-desktop-dark` and its phone twin photographed an
// ERROR CARD — "Could not load profile · The server refused the request" —
// and were counted as photographed anyway. That is the fault CLAUDE.md §10.5
// and the handoff's §5 both warn about, and it survived four sessions of this
// phase because nobody opened the picture.
//
// Everything the screen reads goes through ONE seam: five providers all call
// `employeeProfileServiceProvider`. Overriding that with a subclass whose five
// `load*` methods return fixtures makes the whole screen real — the identity
// header, the metric sparklines, the activity feed, the documents, the flags
// and the register's prev/next arrows.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/employee/providers/employee_profile_provider.dart';
import 'package:flutter_application_1/features/employee/services/employee_profile_service.dart';

import 'screen_fixtures.dart';

/// The moment these fixtures are written against — the capture clock.
final DateTime _now = DateTime.utc(2026, 8, 15, 9, 30);

DateTime _ago(Duration d) => _now.subtract(d);

class _FixtureEmployeeProfileService extends EmployeeProfileService {
  @override
  Future<EmployeeProfileBundle> loadBundle(String employeeId) async =>
      EmployeeProfileBundle(
        person: ProfilePerson(
          employee: fixtureEmployee(),
          email: 'thandi.mokoena@fixturehaulage.co.za',
          lastSeenAt: _ago(const Duration(minutes: 3)),
          lastLoginAt: _ago(const Duration(hours: 6)),
        ),
        company: const ProfileCompany(
          id: 'FIXTURE-company',
          name: 'Fixture Haulage (Pty) Ltd',
          orgType: OrgType.transporter,
          seatsUsed: 4,
          seatLimit: 5,
          adminUserId: 'FIXTURE-user',
        ),
        supervisor: const ProfileSupervisor(
          employeeId: 'FIXTURE-employee-2',
          userId: 'FIXTURE-user-2',
          name: 'Johannes van der Merwe',
          roleLabel: 'Supervisor / Foreman',
        ),
        register: const [
          ProfileSibling('FIXTURE-employee-2', 'Johannes van der Merwe'),
          ProfileSibling('FIXTURE-employee', 'Thandi Mokoena'),
          ProfileSibling('FIXTURE-employee-3', 'Thandeka Nkosi'),
        ],
      );

  @override
  Future<List<ProfileMetric>> loadMetrics(EmployeeProfileBundle b) async =>
      const [
        ProfileMetric(
          label: 'Loads dispatched',
          value: '128',
          sub: 'last 7 days',
          delta: 6,
          spark: [14, 18, 21, 17, 22, 19, 17],
          tone: ProfileTone.green,
        ),
        ProfileMetric(
          label: 'Tons moved',
          value: '4,382.6',
          unit: 't',
          sub: 'last 7 days',
          delta: -3,
          deltaUp: false,
          spark: [612, 704, 588, 651, 690, 574, 563],
          tone: ProfileTone.blue,
        ),
        // Deliberately EMPTY spark — a count of what is true now has no daily
        // series behind it, and inventing a level one is the fault the metric
        // model's own doc comment describes.
        ProfileMetric(
          label: 'Seats used',
          value: '4',
          sub: 'of 5 on this company',
          spark: [],
          tone: ProfileTone.neutral,
        ),
      ];

  @override
  Future<List<ProfileActivityItem>> loadActivity(
    EmployeeProfileBundle b,
  ) async =>
      [
        ProfileActivityItem(
          bold: 'Load recorded',
          rest: ' · CK 84 RT GP · 36.22 t of Chrome',
          at: _ago(const Duration(minutes: 12)),
          tone: ProfileTone.green,
          route: '/portal/transporter/trips',
        ),
        ProfileActivityItem(
          bold: 'Gate check-out',
          rest: ' · JD 22 PL MP left Iron Hills Mining',
          at: _ago(const Duration(hours: 2, minutes: 20)),
          tone: ProfileTone.blue,
        ),
        ProfileActivityItem(
          bold: 'On shift',
          rest: ' · weighbridge',
          at: _ago(const Duration(hours: 6)),
          until: _ago(const Duration(hours: 1)),
          tone: ProfileTone.neutral,
        ),
        ProfileActivityItem(
          bold: 'Signature added',
          rest: ' · applied to waybill TRP-000123',
          at: _ago(const Duration(hours: 9)),
          tone: ProfileTone.green,
        ),
      ];

  @override
  Future<ProfileDocsAndFlags> loadDocsAndFlags(
    EmployeeProfileBundle b,
  ) async =>
      const ProfileDocsAndFlags(
        [
          ProfileDocItem(
            title: 'Identity document',
            subtitle: 'uploaded Mar 2024',
            statusLabel: 'Verified',
            statusTone: ProfileTone.green,
          ),
          ProfileDocItem(
            title: 'Professional driving permit',
            subtitle: 'renewed Sep 2025',
            statusLabel: 'Expires in 19 days',
            statusTone: ProfileTone.amber,
          ),
          ProfileDocItem(
            title: 'Medical certificate',
            subtitle: 'uploaded Aug 2023',
            statusLabel: 'Expired',
            statusTone: ProfileTone.red,
          ),
        ],
        [
          ProfileFlag(
            title: 'Permit expiring',
            body: 'The professional driving permit on file expires within a '
                'month. A driver cannot be dispatched on an expired permit.',
            metaLine: 'Opened by System · 2 days ago',
            tone: ProfileTone.amber,
          ),
        ],
      );

  @override
  Future<({DateTime? at, double? lat, double? lng, String? name})> loadLocation(
    EmployeeProfileBundle b,
  ) async =>
      (
        name: 'Iron Hills Mining, Steelpoort',
        lat: -24.7182,
        lng: 30.1094,
        at: _ago(const Duration(minutes: 8)),
      );
}

/// Overrides that make the employee profile screen render its layout.
List<Override> employeeProfileOverrides() => [
      employeeProfileServiceProvider
          .overrideWithValue(_FixtureEmployeeProfileService()),
      // The realtime channel too, and it is not optional.
      //
      // `employeeProfileRealtimeProvider` opens postgres_changes channels on
      // `SupabaseConfig.client` and starts a debounce timer. In a render that
      // is a real socket: the test passed when run alone and failed inside the
      // suite with "A Timer is still pending even after the widget tree was
      // disposed", with a `_NativeSocket.tryConnectToResolvedAddresses` frame
      // in the trace. A screen fixture has to stub the LIVE half as well as
      // the read half.
      employeeProfileRealtimeProvider.overrideWith((ref, employeeId) {}),
      employeeProfileSyncedAtProvider
          .overrideWith((ref, employeeId) => _ago(const Duration(seconds: 4))),
    ];
