// Fixtures that get a gated screen far enough to render something.
//
// Several screens short-circuit before they lay anything out: a company gate,
// a null session, a workspace that has not reached `ready`. A sweep over one
// of those passes at every width and every text scale having rendered a
// spinner, which is the trap CLAUDE.md §10.5 names.
//
// Everything here is obviously fake — 'FIXTURE …' ids, a 2020 timestamp — so a
// figure from this file can never be mistaken for real data if one ever leaks
// into a render. Nothing here is a mock in the behavioural sense: these are
// values, and the screens run their real logic over them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/providers/company_access_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/portal/portal_navigation.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';

final DateTime _fixtureDate = DateTime.utc(2020, 1, 1);

/// A transporter, because that org type unlocks the most tabs and therefore
/// the widest layouts — the ones most likely to overflow.
Company fixtureCompany() => Company(
      id: 'FIXTURE-company',
      userId: 'FIXTURE-user',
      companyName: 'Fixture Haulage (Pty) Ltd',
      whatsappNumber: '+27000000000',
      orgType: OrgType.transporter,
      createdAt: _fixtureDate,
      physicalAddress: '1 Fixture Road, Fixtureville, Gauteng',
    );

Employee fixtureEmployee({UserRole role = UserRole.admin}) => Employee(
      id: 'FIXTURE-employee',
      userId: 'FIXTURE-user',
      firstName: 'Fixture',
      lastName: 'Operator',
      whatsappNumber: '+27000000000',
      companyId: 'FIXTURE-company',
      role: role,
      status: 'active',
      createdAt: _fixtureDate,
    );

/// `companyAccessProvider` is a plain `Provider`, so it can simply be handed a
/// value.
///
/// [canManageEmployees] decides which branch of `CompanyEmployeesScreen`
/// renders, and **both are real user-facing states**: managers get the roster,
/// everyone else gets the restricted notice. The default is `false` because the
/// managing branch additionally waits on `companyProvider`, whose notifier
/// takes four services and opens two realtime channels — faking that is a
/// different and much larger job (see `_unproven` in
/// `untested_screens_render_something_test.dart`).
Override companyAccessOverride({bool canManageEmployees = false}) {
  return companyAccessProvider.overrideWithValue(
    CompanyAccessContext(
      company: fixtureCompany(),
      visibleEmployees: [fixtureEmployee()],
      currentEmployee: fixtureEmployee(),
      isCompanyAccount: true,
      canManageEmployees: canManageEmployees,
    ),
  );
}

/// `portalWorkspaceProvider` is a plain `Provider` too. `HomeTabBodyScreen`
/// returns `SizedBox.shrink()` until the phase is `ready` with a non-empty tab
/// list, so this is the whole of what it needs.
///
/// The tab bodies are placeholders rather than the real screens: those have
/// their own sweeps, and nesting them here would mean this fixture's failures
/// were really theirs.
Override portalWorkspaceOverride() {
  return portalWorkspaceProvider.overrideWithValue(
    const PortalWorkspaceModel(
      phase: PortalWorkspacePhase.ready,
      workspaceName: 'Fixture Haulage (Pty) Ltd',
      operatorName: 'Fixture Operator',
      roleLabel: 'Admin',
      tabs: [
        PortalTabItem('Overview', Icons.dashboard_outlined,
            Center(child: Text('Overview tab body'))),
        PortalTabItem('Earnings', Icons.payments_outlined,
            Center(child: Text('Earnings tab body'))),
        PortalTabItem('Fleet', Icons.local_shipping_outlined,
            Center(child: Text('Fleet tab body'))),
      ],
    ),
  );
}
