// P10-04 regression guard — employee dismissal removed (client ruling,
// 2026-08-11).
//
// `PortalWorkspacePhase.dismissed` used to catch a user with
// `employees.is_dismissed = true` and render `EmployeeDismissedScreen`. Both
// are gone. The thing that must NOT have gone with them is the guarantee that a
// user taken off a company never receives a company tab set — which is the same
// privilege-escalation surface P4-08 / P2-06 were raised over.
//
// Two independent halves are asserted here:
//   1. behaviour — `resolvePortalTabs` hands a removed employee the waiting tab,
//      never `PortalNavigation.companyTabs(...)`;
//   2. absence — the enum value, the two routes and the four Dart files really
//      are gone, and `grep -ri dismiss lib/ test/` yields only `is_dismissed`
//      reads, which is P10-06's acceptance criterion made permanent.
//
// The fixture is proved live before anything is concluded from it: an employee
// WITH a role must produce real operational tabs. A resolver that returned the
// waiting tab for everybody would otherwise pass part 1 while being broken.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/portal/portal_navigation.dart';
import 'package:flutter_application_1/features/portal/portal_tabs_resolver.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';

final _now = DateTime.utc(2026, 8, 11);

Company _mine() => Company(
      id: 'company-1',
      userId: 'owner-user',
      companyName: 'Iron Hills Mining',
      whatsappNumber: '+27000000000',
      orgType: OrgType.mineSupplier,
      createdAt: _now,
    );

Employee _employee({String? companyId, UserRole? role, String? status}) =>
    Employee(
      id: 'employee-1',
      userId: 'employee-user',
      firstName: 'Thandi',
      lastName: 'Mokoena',
      whatsappNumber: '+27000000001',
      companyId: companyId,
      role: role,
      status: status,
      createdAt: _now,
    );

List<String> _labels(List<PortalTabItem> tabs) =>
    tabs.map((t) => t.label).toList();

List<PortalTabItem> _resolve(EmployeeState employeeState) => resolvePortalTabs(
      authState: AuthState(userType: UserType.employee),
      companyState: CompanyState(),
      employeeState: employeeState,
      isEmployeeWithoutRole: employeeState.employee?.companyId != null &&
          employeeState.employee?.role == null,
      employeeDashboard: const SizedBox.shrink(),
    );

void main() {
  // ---------------------------------------------------------------- fixture
  //
  // Nothing below this may be believed unless the fixture produces a real
  // workspace for a real employee. Asserted first, deliberately.
  group('fixture is live', () {
    test('a security guard at a mine gets real operational tabs', () {
      final tabs = _resolve(EmployeeState(
        employee: _employee(
          companyId: 'company-1',
          role: UserRole.security,
          status: 'active',
        ),
        company: _mine(),
      ));

      expect(tabs, isNotEmpty);
      expect(
        _labels(tabs),
        contains('Security'),
        reason: 'the resolver must return a real tab set for a real role, '
            'otherwise the assertions below are vacuous',
      );
    });
  });

  // -------------------------------------------------------------- behaviour
  group('a removed employee never receives a company tab set', () {
    // `remove_company_employee` nulls company_id and role and sets
    // status = 'inactive'. This is exactly that row.
    final removed = EmployeeState(
      employee: _employee(companyId: null, role: null, status: 'inactive'),
    );

    test('is not linked, so the workspace stops at selectingCompany', () {
      // The phase provider tests this before it builds any tabs. That ordering
      // is what makes removing the `dismissed` branch safe.
      expect(removed.isLinkedToCompany, isFalse);
    });

    test('resolvePortalTabs hands them the waiting tab only', () {
      final tabs = _resolve(removed);
      expect(_labels(tabs), ['Account']);
    });

    test('and not one label from any org type\'s company tab set', () {
      final tabs = _resolve(removed).map((t) => t.label).toSet();
      for (final orgType in OrgType.values) {
        final owner =
            PortalNavigation.companyTabs(orgType).map((t) => t.label).toSet();
        expect(
          owner, isNotEmpty,
          reason: 'companyTabs(${orgType.name}) must be non-empty for this '
              'comparison to mean anything',
        );
        expect(
          tabs.intersection(owner.difference({'Account'})),
          isEmpty,
          reason: 'a removed employee reached ${orgType.name} owner tabs',
        );
      }
    });

    test('an employee still linked but with no role also waits', () {
      // P4-08's case, re-asserted here because the dismissal removal touched
      // the same resolver.
      final tabs = _resolve(EmployeeState(
        employee: _employee(
            companyId: 'company-1', role: null, status: 'pending_role'),
        company: _mine(),
      ));
      expect(_labels(tabs), ['Account']);
    });
  });

  // ---------------------------------------------------------------- absence
  group('the dismissal surface is gone', () {
    test('PortalWorkspacePhase carries no dismissed value', () {
      expect(
        PortalWorkspacePhase.values.map((p) => p.name),
        isNot(contains('dismissed')),
      );
      // Guard against the enum being emptied or renamed out from under this.
      expect(PortalWorkspacePhase.values, contains(PortalWorkspacePhase.ready));
      expect(PortalWorkspacePhase.values,
          contains(PortalWorkspacePhase.selectingCompany));
    });

    test('the four Dart files are deleted', () {
      for (final path in const [
        'lib/features/employee/screens/employee_dismissal_management_screen.dart',
        'lib/features/employee/screens/employee_dismissed_screen.dart',
        'lib/features/employee/widgets/employee_dismissal_form.dart',
        'lib/features/employee/providers/employee_dismissal_provider.dart',
      ]) {
        expect(File(path).existsSync(), isFalse, reason: '$path still exists');
      }
    });

    test('the router carries neither dismissal route', () {
      final router = File('lib/core/routing/app_router.dart');
      expect(router.existsSync(), isTrue);
      final src = router.readAsStringSync();
      expect(src, isNot(contains("'/employee-dismissed'")));
      expect(src, isNot(contains("'/dismissal-management/:employeeId'")));
      // Prove the file was actually read, not silently empty.
      expect(src, contains('GoRoute'));
    });

    test('lib/ and test/ mention dismissal only as is_dismissed reads', () {
      final offenders = <String>[];
      var scanned = 0;

      for (final dir in ['lib', 'test']) {
        for (final entity in Directory(dir).listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          if (_absenceGuards.any(entity.path.endsWith)) continue;
          scanned++;
          final lines = entity.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (!line.toLowerCase().contains('dismiss')) continue;
            if (_permitted(line)) continue;
            offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
          }
        }
      }

      // The sweep must have actually read the tree.
      expect(scanned, greaterThan(200),
          reason: 'only $scanned Dart files scanned — the sweep did not run');
      expect(offenders, isEmpty,
          reason: 'dismissal references survive:\n${offenders.join('\n')}');
    });
  });
  // ------------------------------------------ suspended (2026-10-24)
  group('a suspended or inactive member gets "Access suspended", not tabs', () {
    // Seats are held by active people only (20261024100000) and the database
    // refuses everyone else company data, so a normal workspace for them was
    // an empty app that looked broken.
    final auth = AuthState(userType: UserType.employee);

    for (final status in const ['suspended', 'inactive']) {
      test(status, () {
        final vm = portalSuspendedModel(
          auth,
          EmployeeState(
            employee: _employee(
                companyId: 'company-1',
                role: UserRole.security,
                status: status),
            company: _mine(),
          ),
        );
        expect(vm, isNotNull);
        expect(vm!.phase, PortalWorkspacePhase.accessSuspended);
        expect(vm.phase.endsInSignOut, isTrue);
        expect(vm.message, contains('Iron Hills Mining'));
      });
    }

    test('an active member is not caught', () {
      expect(
        portalSuspendedModel(
          auth,
          EmployeeState(
            employee: _employee(
                companyId: 'company-1',
                role: UserRole.security,
                status: 'active'),
            company: _mine(),
          ),
        ),
        isNull,
      );
    });

    test('an unlinked person still goes to company selection instead', () {
      expect(
        portalSuspendedModel(
          auth,
          EmployeeState(
            employee: _employee(companyId: null, role: null, status: 'inactive'),
          ),
        ),
        isNull,
      );
    });
  });
}

const _thisFile = 'portal_workspace_removed_employee_test.dart';

/// Files whose whole job is to assert the feature is absent. They must name the
/// removed symbols in order to prove they are not rendered, so a sweep that
/// counted those mentions would make the guards unwritable.
///
/// Exactly one entry, deliberately: every exemption is a hole, and this file is
/// the only one that has to name what it is proving gone.
const _absenceGuards = <String>[_thisFile];

/// The removed feature's vocabulary, distinguished from the several unrelated
/// things in this codebase that contain the letters "dismiss".
///
/// Two patterns and no token list, because a token list only ever grows and
/// silently permits whatever nobody thought to add:
///
///   * the word **dismissal** — only ever the employee feature;
///   * the quoted string **'dismissed'** — the status value and the UI label.
///
/// Everything legitimately left over falls outside both: `is_dismissed` and
/// `isDismissed` (the surviving column and its Dart mirror), Flutter's
/// `barrierDismissible` / `Dismissible` / `onDismissed`, and the private
/// `_dismissed` flags behind the tutorial banner, the welcome notification and
/// the demo-data indicator, none of which have anything to do with employment.
bool _permitted(String line) {
  final trimmed = line.trimLeft();
  if (trimmed.startsWith('//') || trimmed.startsWith('*')) return true;

  // Strip the surviving column first so `is_dismissed` cannot be read as the
  // quoted status string.
  final rest = line.replaceAll('is_dismissed', '').replaceAll('isDismissed', '');
  final lower = rest.toLowerCase();

  if (lower.contains('dismissal')) return false;
  if (lower.contains("'dismissed'") || lower.contains('"dismissed"')) {
    return false;
  }
  return true;
}
