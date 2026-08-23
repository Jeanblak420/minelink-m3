// The chat profile panel's "Role" row says the role.
//
// `get_chat_contacts` returns `role` for every contact: `owner` for a company
// account, the employee's `employees.role` otherwise, `member` when that is
// null. The panel used to ignore it and print "Company member" for everyone
// who was not a super admin — a row labelled *Role* that never said one.
// Seen on 2026-08-23 as ironhills.admin, opening Controller Test's profile
// from the dock: a weighbridge controller, described as a member, while the
// Contacts list beside it had grouped the same person under CONTROLLERS from
// the same field.
//
// The label goes through `UserRole.labelFor`, so `controllerWB` reads
// "Load Controller" here the way it does on the platform-users list and the
// organisation detail screen (56df087's family, the other way round: that one
// showed Postgres's vocabulary, this one hid it entirely).

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/chat/models/messaging_models.dart';

ChatContact _contact({String? role, bool superAdmin = false}) => ChatContact(
      userId: 'u1',
      displayName: 'Controller Test',
      role: role,
      isSuperAdmin: superAdmin,
    );

void main() {
  group("the profile panel's Role row reads the contact's role", () {
    test('an employee role is shown by its display label, not the wire value',
        () {
      expect(_contact(role: 'controllerWB').roleLabel, 'Load Controller');
      expect(_contact(role: 'management').roleLabel, 'Management');
      expect(_contact(role: 'security').roleLabel, 'Security');
      expect(_contact(role: 'driver').roleLabel, 'Driver');
      expect(
          _contact(role: 'supervisorForeman').roleLabel, 'Supervisor/Foreman');
      expect(_contact(role: 'admin').roleLabel, 'Admin');
    });

    test('the specific wrongness: a controller is not "Company member"', () {
      expect(_contact(role: 'controllerWB').roleLabel,
          isNot('Company member'));
    });

    test('the wire value never reaches the screen', () {
      expect(_contact(role: 'controllerWB').roleLabel,
          isNot(contains('controllerWB')));
    });

    test('a company account reads as the owner', () {
      expect(_contact(role: 'owner').roleLabel, 'Company owner');
    });

    test('a super admin reads as such whatever role the row carries', () {
      expect(_contact(role: 'admin', superAdmin: true).roleLabel,
          'Super Global Admin');
    });

    test("the server's own 'member' — no role recorded — keeps the old wording",
        () {
      // This is the case that must STAY green under sabotage: the fix must not
      // turn a genuinely unknown role into something invented.
      expect(_contact(role: 'member').roleLabel, 'Company member');
      expect(_contact(role: null).roleLabel, 'Company member');
      expect(_contact(role: '  ').roleLabel, 'Company member');
    });

    test('a role this build does not know shows raw, per UserRole.labelFor',
        () {
      expect(_contact(role: 'geologist').roleLabel, 'geologist');
    });
  });
}
