import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a user in the application with additional properties
/// beyond what's provided by Supabase's User class.
class AppUser {
  final String userId;
  final String? email;
  final UserType? userType;
  final UserRole? role;
  final String? firstName;
  final String? lastName;
  final String? companyId;
  final String? employeeId;
  final OrgType? orgType;

  AppUser({
    required this.userId,
    this.email,
    this.userType,
    this.role,
    this.firstName,
    this.lastName,
    this.companyId,
    this.employeeId,
    this.orgType,
  });

  /// Create an AppUser from a Supabase User
  factory AppUser.fromUser(
    User user, {
    UserType? userType,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? companyId,
    String? employeeId,
    OrgType? orgType,
  }) {
    return AppUser(
      userId: user.id,
      email: user.email,
      userType: userType,
      role: role,
      firstName: firstName,
      lastName: lastName,
      companyId: companyId,
      employeeId: employeeId,
      orgType: orgType,
    );
  }

  /// Create a copy of this AppUser with some fields replaced
  AppUser copyWith({
    String? userId,
    String? email,
    UserType? userType,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? companyId,
    String? employeeId,
    OrgType? orgType,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      userType: userType ?? this.userType,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      orgType: orgType ?? this.orgType,
    );
  }

  /// Get the full name of the user
  String get fullName => [
    firstName,
    lastName,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

  /// Check if the user has a specific role
  bool hasRole(UserRole roleToCheck) => role == roleToCheck;

  /// Convert to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'user_type': userType?.name,
      'role': role?.name,
      'first_name': firstName,
      'last_name': lastName,
      'company_id': companyId,
      'employee_id': employeeId,
      'org_type': orgType?.name,
    };
  }

  /// Create an AppUser from a JSON map
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userId: json['user_id'],
      email: json['email'],
      userType: UserType.tryParse(json['user_type'] as String?),
      role: UserRole.tryParse(json['role'] as String?),
      firstName: json['first_name'],
      lastName: json['last_name'],
      companyId: json['company_id'],
      employeeId: json['employee_id'],
      orgType: OrgType.tryParse(json['org_type'] as String?),
    );
  }
}
