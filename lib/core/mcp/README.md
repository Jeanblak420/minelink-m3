# Model Context Protocol (MCP) Implementation

This directory contains the Model Context Protocol implementation for The Mineral Guide application.

## What is MCP?

Model Context Protocol (MCP) is a standardized way to interact with Supabase data models. It ensures type safety and consistency across the application by providing a structured approach to data handling.

## Structure

- `models/`: Contains MCP model definitions
- `repositories/`: Contains repositories for interacting with Supabase
- `extensions/`: Contains extensions for MCP models

## Core Components

### SupabaseModel

Base class for all models that interact with Supabase. It provides common functionality like serialization and equality comparison.

```dart
abstract class SupabaseModel {
  Map<String, dynamic> toJson();
}
```

### SupabaseRepository

Base repository class for CRUD operations with Supabase. It provides methods for fetching, creating, updating, and deleting records.

```dart
abstract class SupabaseRepository<T extends SupabaseModel> {
  String get tableName;
  T fromJson(Map<String, dynamic> json);

  Future<List<T>> getAll();
  Future<T> getById(String id);
  Future<T> insert(T model);
  Future<T> update(T model);
  Future<void> delete(String id);
  Stream<List<T>> stream();
}
```

## Implemented Models

### CompanyMCP

Model for company data.

```dart
class CompanyMCP extends SupabaseModelWithId with SupabaseModelWithTimestamps, SupabaseModelWithUserId {
  final String id;
  final String userId;
  final String companyName;
  final String whatsappNumber;
  final OrgType orgType;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? logoUrl;
  final String? ceoFirstName;
  final String? ceoLastName;

  // Constructor, fromJson, toJson, copyWith methods...
}
```

### EmployeeMCP

Model for employee data.

```dart
class EmployeeMCP extends SupabaseModelWithId with SupabaseModelWithTimestamps, SupabaseModelWithUserId {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String whatsappNumber;
  final String? companyId;
  final UserRole? role;
  final String? status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? profilePhotoUrl;
  // Additional fields...

  // Constructor, fromJson, toJson, copyWith methods...
}
```

## Usage Examples

```dart
// Get a repository instance
final companyRepository = CompanyRepository();

// Get a company by user ID
final company = await companyRepository.getByUserId(userId);

// Get employees for a company
final employeeRepository = EmployeeRepository();
final employees = await employeeRepository.getByCompanyId(companyId);

// Create a new company
final newCompany = CompanyMCP(
  id: const Uuid().v4(),
  userId: currentUserId,
  companyName: 'New Company',
  whatsappNumber: '+1234567890',
  orgType: OrgType.mineSupplier,
  createdAt: DateTime.now(),
);
await companyRepository.insert(newCompany);

// Update a company
final updatedCompany = company.copyWith(
  companyName: 'Updated Company Name',
);
await companyRepository.update(updatedCompany);

// Delete a company
await companyRepository.delete(company.id);

// Stream companies for real-time updates
companyRepository.stream().listen((companies) {
  // Handle updated companies list
});
```

## Benefits

- **Type Safety**: Reduces runtime errors with strong typing
- **Consistency**: Standardized approach to data handling
- **Maintainability**: Easier to maintain and extend
- **Reusability**: Common patterns for all data models
- **Real-time Support**: Built-in support for Supabase real-time updates
