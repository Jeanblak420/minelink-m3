// The operations page takes the menu's name (Jean, 2026-10-25: "rename the
// page to match the menu"). A guard tapped "Incidents & gate checks" and a
// load controller "Weighbridge records", and both landed on a page headed
// "Operations Hub", in the bar and on the page.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/operations/screens/operations_hub_screen.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';

void main() {
  test('the heading is the menu entry the role tapped', () {
    String title(OrgType o, UserRole? r) =>
        operationsHubTitle(orgType: o, role: r);
    expect(title(OrgType.mineSupplier, UserRole.security),
        'Incidents & gate checks');
    expect(title(OrgType.mineSupplier, UserRole.controllerWB),
        'Weighbridge records');
    expect(title(OrgType.mineSupplier, UserRole.admin), 'Operations hub');
    expect(title(OrgType.mineSupplier, null), 'Operations hub');
    // No rail entry for these: a tab opens it, and the neutral name stands.
    expect(title(OrgType.transporter, UserRole.management), 'Operations hub');
    expect(title(OrgType.buyer, null), 'Operations hub');
  });

  test('the bar reads the menu label for an exact route, nothing otherwise',
      () {
    final guard =
        portalNavTree(orgType: OrgType.mineSupplier, role: UserRole.security);
    expect(portalNavLabelFor(guard, '/portal/mine/operations'),
        'Incidents & gate checks');
    expect(portalNavLabelFor(guard, '/portal/mine/security'), 'Security gate');
    // A detail page under a leaf is not that leaf.
    expect(portalNavLabelFor(guard, '/portal/mine/operations/x'), isNull);
  });

  test('the description names only the tabs on the page', () {
    expect(
        operationsHubDescription(
            const [OperationsTab.security, OperationsTab.gate]),
        'The live working day — security and gate checks.');
    expect(operationsHubDescription(const [OperationsTab.weighbridge]),
        'The live working day — weighbridge.');
    expect(
        operationsHubDescription(const [
          OperationsTab.minerals,
          OperationsTab.transactions,
          OperationsTab.loads,
        ]),
        'The live working day — minerals, transactions and loads.');
  });
}
