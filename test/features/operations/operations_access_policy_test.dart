import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';

void main() {
  group('OperationsAccessPolicy', () {
    test('management access can see and create across all tabs', () {
      expect(
        OperationsAccessPolicy.visibleTabs(
          canEditAll: true,
          orgType: OrgType.mineSupplier,
          role: UserRole.management,
        ),
        OperationsTab.values,
      );

      for (final tab in OperationsTab.values) {
        expect(
          OperationsAccessPolicy.canCreate(
            canEditAll: true,
            orgType: OrgType.mineSupplier,
            tab: tab,
            role: UserRole.management,
          ),
          isTrue,
        );
      }
    });

    test('security role can only create security and gate records', () {
      expect(
        OperationsAccessPolicy.visibleTabs(
          canEditAll: false,
          orgType: OrgType.mineSupplier,
          role: UserRole.security,
        ),
        const [
          OperationsTab.security,
          OperationsTab.gate,
          OperationsTab.transactions,
        ],
      );

      expect(
        OperationsAccessPolicy.canCreate(
          canEditAll: false,
          orgType: OrgType.mineSupplier,
          tab: OperationsTab.security,
          role: UserRole.security,
        ),
        isTrue,
      );
      expect(
        OperationsAccessPolicy.canCreate(
          canEditAll: false,
          orgType: OrgType.mineSupplier,
          tab: OperationsTab.gate,
          role: UserRole.security,
        ),
        isTrue,
      );
      expect(
        OperationsAccessPolicy.canCreate(
          canEditAll: false,
          orgType: OrgType.mineSupplier,
          tab: OperationsTab.transactions,
          role: UserRole.security,
        ),
        isFalse,
      );
    });

    test('controller role can only create weighbridge records', () {
      expect(
        OperationsAccessPolicy.visibleTabs(
          canEditAll: false,
          orgType: OrgType.mineSupplier,
          role: UserRole.controllerWB,
        ),
        const [OperationsTab.transactions, OperationsTab.weighbridge],
      );

      expect(
        OperationsAccessPolicy.canCreate(
          canEditAll: false,
          orgType: OrgType.mineSupplier,
          tab: OperationsTab.weighbridge,
          role: UserRole.controllerWB,
        ),
        isTrue,
      );
      expect(
        OperationsAccessPolicy.canCreate(
          canEditAll: false,
          orgType: OrgType.mineSupplier,
          tab: OperationsTab.security,
          role: UserRole.controllerWB,
        ),
        isFalse,
      );
    });

    test('driver role cannot create operational records', () {
      expect(
        OperationsAccessPolicy.visibleTabs(
          canEditAll: false,
          orgType: OrgType.mineSupplier,
          role: UserRole.driver,
        ),
        const [OperationsTab.transactions, OperationsTab.loads],
      );

      for (final tab in const [
        OperationsTab.transactions,
        OperationsTab.loads,
      ]) {
        expect(
          OperationsAccessPolicy.canCreate(
            canEditAll: false,
            orgType: OrgType.mineSupplier,
            tab: tab,
            role: UserRole.driver,
          ),
          isFalse,
        );
      }
    });
  });
}
