import 'package:flutter/foundation.dart';

/// Base class for all Supabase models
///
/// This class provides a common interface for all models that interact with Supabase.
/// It ensures that all models have the necessary methods for serialization and deserialization.
abstract class SupabaseModel {
  /// Converts the model to a JSON map
  Map<String, dynamic> toJson();

  @override
  String toString() {
    return '${runtimeType.toString()}: ${toJson().toString()}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupabaseModel &&
        other.runtimeType == runtimeType &&
        mapEquals(other.toJson(), toJson());
  }

  @override
  int get hashCode => toJson().hashCode;
}

/// Interface for models that have a primary key
abstract class SupabaseModelWithId implements SupabaseModel {
  /// The primary key of the model
  String get id;
}

/// Interface for models that have a user ID
abstract class SupabaseModelWithUserId implements SupabaseModel {
  /// The user ID associated with the model
  String get userId;
}

/// Interface for models that have a company ID
abstract class SupabaseModelWithCompanyId implements SupabaseModel {
  /// The company ID associated with the model
  String get companyId;
}

/// Interface for models that have timestamps
abstract class SupabaseModelWithTimestamps implements SupabaseModel {
  /// The creation timestamp
  DateTime get createdAt;

  /// The last update timestamp
  DateTime? get updatedAt;
}
