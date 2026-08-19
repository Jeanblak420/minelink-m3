// S6-26 — the operations hub must not offer a company tabs its org type has
// no one to staff.
//
// `OperationsAccessPolicy.visibleTabs` opened with
//
//     if (canEditAll) return OperationsTab.values;
//
// and `canEditAll` is true for **every company account** (see
// `_OperationsAccess.fromState` — `userType.isCompany` → `canEditAll: true`).
// So a buyer or transporter owner signing in got all six tabs, including
// `weighbridge`, `security` and `gate`.
//
// The argument that those are mine-only is not a matter of taste; the role
// model already states it. `UserRole.getRolesForOrgType` gives
//
//     mineSupplier → security, controllerWB, supervisorForeman, admin, management
//     buyer        → admin, management
//     transporter  → driver, admin, management
//
// Only a mine has a `security` or a `controllerWB`. A weighbridge tab on a
// buyer's console is a surface **nobody at that organisation could ever
// operate** — there is no role there that runs a weighbridge or a mine gate.
//
// The second half of the gate is `OperationsProvider.orgType` being *used*.
// It was carried on `OperationsKey` and referenced only in `==`/`hashCode` —
// a cache-key discriminator, never an access input. These tests make it one.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';

const _mineFloorOnly = {
  OperationsTab.weighbridge,
  OperationsTab.security,
  OperationsTab.gate,
  OperationsTab.minerals,
};

void main() {
  group('a company account (canEditAll) is still bounded by its org type', () {
    test('a mine keeps the whole floor', () {
      final tabs = OperationsAccessPolicy.visibleTabs(
        canEditAll: true,
        orgType: OrgType.mineSupplier,
      );
      expect(tabs, containsAll(OperationsTab.values),
          reason: 'the mine is the only org that runs a weighbridge and a gate, '
              'so it is the only one that should see all six');
    });

    test('a buyer is not offered the mine floor', () {
      final tabs = OperationsAccessPolicy.visibleTabs(
        canEditAll: true,
        orgType: OrgType.buyer,
      );
      for (final t in _mineFloorOnly) {
        expect(tabs, isNot(contains(t)),
            reason: '$t is a mine surface; a buyer has no role that operates it');
      }
      expect(tabs, contains(OperationsTab.transactions));
    });

    test('a transporter is not offered the mine floor', () {
      final tabs = OperationsAccessPolicy.visibleTabs(
        canEditAll: true,
        orgType: OrgType.transporter,
      );
      for (final t in _mineFloorOnly) {
        expect(tabs, isNot(contains(t)),
            reason: '$t is a mine surface; a transporter has no role that '
                'operates it');
      }
      expect(tabs, contains(OperationsTab.transactions));
    });

    test('no org type is offered an empty hub', () {
      for (final org in OrgType.values) {
        expect(
          OperationsAccessPolicy.visibleTabs(canEditAll: true, orgType: org),
          isNotEmpty,
          reason: '${org.name} would open the operations hub with no tabs',
        );
      }
    });
  });

  group('a role is bounded by BOTH its role and its org type', () {
    test('every role gets only tabs its own org type offers', () {
      for (final org in OrgType.values) {
        final orgTabs = OperationsAccessPolicy.visibleTabs(
          canEditAll: true,
          orgType: org,
        ).toSet();
        for (final role in UserRole.getRolesForOrgType(org)) {
          final roleTabs = OperationsAccessPolicy.visibleTabs(
            canEditAll: false,
            role: role,
            orgType: org,
          ).toSet();
          expect(roleTabs.difference(orgTabs), isEmpty,
              reason: '${org.name}/${role.name} reaches '
                  '${roleTabs.difference(orgTabs)}, which its org type does not '
                  'offer at all');
        }
      }
    });

    test('the mine roles that run the floor still reach it', () {
      final security = OperationsAccessPolicy.visibleTabs(
        canEditAll: false,
        role: UserRole.security,
        orgType: OrgType.mineSupplier,
      );
      expect(security, contains(OperationsTab.security));
      expect(security, contains(OperationsTab.gate));

      final wb = OperationsAccessPolicy.visibleTabs(
        canEditAll: false,
        role: UserRole.controllerWB,
        orgType: OrgType.mineSupplier,
      );
      expect(wb, contains(OperationsTab.weighbridge),
          reason: 'the load controller IS the weighbridge');
    });
  });

  group('canCreate is bounded the same way', () {
    test('a buyer company account cannot create a weighbridge record', () {
      expect(
        OperationsAccessPolicy.canCreate(
          canEditAll: true,
          tab: OperationsTab.weighbridge,
          orgType: OrgType.buyer,
        ),
        isFalse,
        reason: 'canEditAll returned true for every tab regardless of org — a '
            'buyer could be handed a create button for a weighbridge it does '
            'not have',
      );
    });

    test('a mine company account still can', () {
      expect(
        OperationsAccessPolicy.canCreate(
          canEditAll: true,
          tab: OperationsTab.weighbridge,
          orgType: OrgType.mineSupplier,
        ),
        isTrue,
      );
    });
  });
}
