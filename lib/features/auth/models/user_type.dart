enum UserType {
  company,
  employee;

  bool get isCompany => this == UserType.company;
  bool get isEmployee => this == UserType.employee;

  static UserType? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final userType in UserType.values) {
      if (userType.name == value) {
        return userType;
      }
    }

    return null;
  }
}

enum OrgType {
  mineSupplier('Mine/Supplier'),
  buyer('Buyer'),
  transporter('Transporter');

  final String label;
  const OrgType(this.label);

  static OrgType? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final orgType in OrgType.values) {
      if (orgType.name == value) {
        return orgType;
      }
    }

    return null;
  }
}

enum UserRole {
  security('Security'),
  // Stored DB value stays `controllerWB`; only the display label changed.
  controllerWB('Load Controller'),
  supervisorForeman('Supervisor/Foreman'),
  admin('Admin'),
  management('Management'),
  driver('Driver'),
  // Organization-specific roles
  mineSupplier('Mine/Supplier'),
  buyer('Buyer'),
  transporter('Transporter');

  final String label;
  const UserRole(this.label);

  static UserRole? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final role in UserRole.values) {
      if (role.name == value) {
        return role;
      }
    }

    return null;
  }

  static List<UserRole> getRolesForOrgType(OrgType orgType) {
    switch (orgType) {
      case OrgType.mineSupplier:
        return [
          UserRole.security,
          UserRole.controllerWB,
          UserRole.supervisorForeman,
          UserRole.admin,
          UserRole.management,
        ];
      case OrgType.buyer:
        return [UserRole.admin, UserRole.management];
      case OrgType.transporter:
        return [UserRole.driver, UserRole.admin, UserRole.management];
    }
  }

  static UserRole getDefaultRoleForOrgType(OrgType orgType) {
    switch (orgType) {
      case OrgType.mineSupplier:
        return UserRole.security;
      case OrgType.buyer:
        return UserRole.admin;
      case OrgType.transporter:
        return UserRole.driver;
    }
  }
}

extension UserRoleNotificationX on UserRole {
  List<UserRole?> get managementNotificationScopes {
    switch (this) {
      // S8-6: `driver` was missing from BOTH supervisory lists, so every
      // notification written with role_scope='driver' was invisible to exactly
      // the two roles that supervise drivers — on a haulage platform, most of
      // the operational traffic: assignment, trip lifecycle, POD capture.
      // Management was told about a weighbridge reading and not about the
      // driver who never arrived.
      case UserRole.management:
        return const [
          UserRole.management,
          UserRole.admin,
          UserRole.controllerWB,
          UserRole.supervisorForeman,
          UserRole.security,
          UserRole.driver,
          null,
        ];
      case UserRole.admin:
        return const [
          UserRole.admin,
          UserRole.controllerWB,
          UserRole.supervisorForeman,
          UserRole.security,
          UserRole.driver,
          null,
        ];
      case UserRole.controllerWB:
        return const [UserRole.controllerWB, null];
      case UserRole.supervisorForeman:
        return const [UserRole.supervisorForeman, null];
      case UserRole.security:
        return const [UserRole.security, null];
      case UserRole.driver:
        return const [UserRole.driver, null];
      case UserRole.mineSupplier:
      case UserRole.buyer:
      case UserRole.transporter:
        return const [null];
    }
  }

  String get managementNotificationFilter {
    return managementNotificationScopes
        .map(
          (scope) => scope == null
              ? 'role_scope.is.null'
              : 'role_scope.eq.${scope.name}',
        )
        .join(',');
  }
}
