/// Organization/company status
enum OrganizationStatus {
  active,
  pendingActivation,
  expired,
  suspended,
  blocked;

  static OrganizationStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return OrganizationStatus.active;
      case 'pendingActivation':
        return OrganizationStatus.pendingActivation;
      case 'expired':
        return OrganizationStatus.expired;
      case 'suspended':
        return OrganizationStatus.suspended;
      case 'blocked':
        return OrganizationStatus.blocked;
      default:
        return OrganizationStatus.pendingActivation;
    }
  }

  String get displayName {
    switch (this) {
      case OrganizationStatus.active:
        return 'Active';
      case OrganizationStatus.pendingActivation:
        return 'Pending Activation';
      case OrganizationStatus.expired:
        return 'Expired';
      case OrganizationStatus.suspended:
        return 'Suspended';
      case OrganizationStatus.blocked:
        return 'Blocked';
    }
  }

  bool get isActive => this == OrganizationStatus.active;
  bool get isRestricted =>
      this == OrganizationStatus.expired ||
      this == OrganizationStatus.suspended ||
      this == OrganizationStatus.blocked;
}
