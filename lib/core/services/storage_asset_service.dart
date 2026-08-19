import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageObjectReference {
  final String bucketName;
  final String objectPath;

  const StorageObjectReference({
    required this.bucketName,
    required this.objectPath,
  });

  String get qualifiedReference => 'storage://$bucketName/$objectPath';
}

class StorageAssetService {
  static const String companyAssetsBucket = 'company_assets';
  static const String employeeAssetsBucket = 'employee_assets';
  static const String chatFilesBucket = 'chat_files';
  static const String signaturesBucket = 'signatures';
  static const String requestDocsBucket = 'request_docs';
  static const String reconDocsBucket = 'recon_docs';
  static const String podPhotosBucket = 'pod_photos';
  static const String loadPhotosBucket = 'load_photos';
  static const int signedUrlExpirySeconds = 60 * 60;

  static const Map<String, String?> _companyFields = {
    'logo_url': companyAssetsBucket,
  };

  static const Map<String, String?> _employeeFields = {
    'profile_photo_url': employeeAssetsBucket,
    'id_document_url': employeeAssetsBucket,
    'passport_document_url': employeeAssetsBucket,
    'work_visa_document_url': employeeAssetsBucket,
    'license_document_url': employeeAssetsBucket,
  };

  static const Map<String, String?> _fleetVehicleFields = {
    'driver_id_document_url': employeeAssetsBucket,
    'driver_passport_document_url': employeeAssetsBucket,
    'driver_work_visa_document_url': employeeAssetsBucket,
    'driver_license_document_url': employeeAssetsBucket,
  };

  static const Map<String, String?> _chatMessageFields = {
    'file_url': chatFilesBucket,
    'sender_avatar_url': null,
  };

  final SupabaseClient _supabase;

  StorageAssetService({SupabaseClient? supabase})
    : _supabase = supabase ?? SupabaseConfig.client;

  Future<String?> resolveCompanyAssetUrl(String? value) {
    return resolveUrl(value, defaultBucketName: companyAssetsBucket);
  }

  Future<String?> resolveEmployeeAssetUrl(String? value) {
    return resolveUrl(value, defaultBucketName: employeeAssetsBucket);
  }

  Future<String?> resolveChatFileUrl(String? value) {
    return resolveUrl(value, defaultBucketName: chatFilesBucket);
  }

  Future<String?> resolveSignatureUrl(String? value) {
    return resolveUrl(value, defaultBucketName: signaturesBucket);
  }

  Future<String?> resolveRequestDocUrl(String? value) {
    return resolveUrl(value, defaultBucketName: requestDocsBucket);
  }

  Future<String?> resolveReconDocUrl(String? value) {
    return resolveUrl(value, defaultBucketName: reconDocsBucket);
  }

  Future<String?> resolvePodPhotoUrl(String? value) {
    return resolveUrl(value, defaultBucketName: podPhotosBucket);
  }

  Future<String?> resolveLoadPhotoUrl(String? value) {
    return resolveUrl(value, defaultBucketName: loadPhotosBucket);
  }

  Future<String?> resolveUrl(
    String? value, {
    String? defaultBucketName,
    int expiresIn = signedUrlExpirySeconds,
  }) async {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final reference = parseReference(
      trimmed,
      defaultBucketName: defaultBucketName,
    );
    if (reference == null) {
      return trimmed;
    }

    if (_isPublicBucket(reference.bucketName)) {
      return _supabase.storage
          .from(reference.bucketName)
          .getPublicUrl(reference.objectPath);
    }

    return _supabase.storage
        .from(reference.bucketName)
        .createSignedUrl(reference.objectPath, expiresIn);
  }

  Future<Map<String, dynamic>> resolveCompanyRecord(
    Map<String, dynamic> record,
  ) async {
    final records = await resolveCompanyRecords([record]);
    return records.first;
  }

  Future<List<Map<String, dynamic>>> resolveCompanyRecords(
    Iterable<Map<String, dynamic>> records,
  ) {
    return _resolveRecordBatch(records, _companyFields);
  }

  Future<Map<String, dynamic>> resolveEmployeeRecord(
    Map<String, dynamic> record,
  ) async {
    final records = await resolveEmployeeRecords([record]);
    return records.first;
  }

  Future<List<Map<String, dynamic>>> resolveEmployeeRecords(
    Iterable<Map<String, dynamic>> records,
  ) {
    return _resolveRecordBatch(records, _employeeFields);
  }

  Future<Map<String, dynamic>> resolveFleetVehicleRecord(
    Map<String, dynamic> record,
  ) async {
    final records = await resolveFleetVehicleRecords([record]);
    return records.first;
  }

  Future<List<Map<String, dynamic>>> resolveFleetVehicleRecords(
    Iterable<Map<String, dynamic>> records,
  ) {
    return _resolveRecordBatch(records, _fleetVehicleFields);
  }

  Future<Map<String, dynamic>> resolveChatMessageRecord(
    Map<String, dynamic> record,
  ) async {
    final records = await resolveChatMessageRecords([record]);
    return records.first;
  }

  Future<List<Map<String, dynamic>>> resolveChatMessageRecords(
    Iterable<Map<String, dynamic>> records,
  ) {
    return _resolveRecordBatch(records, _chatMessageFields);
  }

  String toBucketQualifiedReference({
    required String bucketName,
    required String objectPath,
  }) {
    return StorageObjectReference(
      bucketName: bucketName,
      objectPath: objectPath,
    ).qualifiedReference;
  }

  String? toStorableReference(
    String? value, {
    String? defaultBucketName,
    bool bucketQualified = false,
  }) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final reference = parseReference(
      trimmed,
      defaultBucketName: defaultBucketName,
    );
    if (reference == null) {
      return trimmed;
    }

    return bucketQualified
        ? reference.qualifiedReference
        : reference.objectPath;
  }

  StorageObjectReference? parseReference(
    String? value, {
    String? defaultBucketName,
  }) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'storage' && uri.host.isNotEmpty) {
      final objectPath = uri.pathSegments.join('/');
      if (objectPath.isEmpty || !_isKnownBucket(uri.host)) {
        return null;
      }
      return StorageObjectReference(
        bucketName: uri.host,
        objectPath: objectPath,
      );
    }

    if (uri != null && uri.hasScheme) {
      return _parseSupabaseStorageUrl(uri);
    }

    if (defaultBucketName == null || !_isKnownBucket(defaultBucketName)) {
      return null;
    }

    var objectPath = trimmed.replaceFirst(RegExp(r'^/+'), '');
    if (objectPath.startsWith('$defaultBucketName/')) {
      objectPath = objectPath.substring(defaultBucketName.length + 1);
    }

    if (objectPath.isEmpty) {
      return null;
    }

    return StorageObjectReference(
      bucketName: defaultBucketName,
      objectPath: objectPath,
    );
  }

  Future<List<Map<String, dynamic>>> _resolveRecordBatch(
    Iterable<Map<String, dynamic>> records,
    Map<String, String?> fieldBuckets,
  ) async {
    final resolvedRecords = records
        .map((record) => Map<String, dynamic>.from(record))
        .toList();

    final pendingByBucket = <String, List<_PendingFieldResolution>>{};

    for (
      var recordIndex = 0;
      recordIndex < resolvedRecords.length;
      recordIndex++
    ) {
      final record = resolvedRecords[recordIndex];

      for (final entry in fieldBuckets.entries) {
        final rawValue = record[entry.key];
        if (rawValue is! String || rawValue.trim().isEmpty) {
          continue;
        }

        final reference = parseReference(
          rawValue,
          defaultBucketName: entry.value,
        );
        if (reference == null) {
          continue;
        }

        if (_isPublicBucket(reference.bucketName)) {
          record[entry.key] = _supabase.storage
              .from(reference.bucketName)
              .getPublicUrl(reference.objectPath);
          continue;
        }

        pendingByBucket
            .putIfAbsent(reference.bucketName, () => [])
            .add(
              _PendingFieldResolution(
                recordIndex: recordIndex,
                fieldName: entry.key,
                objectPath: reference.objectPath,
              ),
            );
      }
    }

    for (final entry in pendingByBucket.entries) {
      final bucketName = entry.key;
      final pendingFields = entry.value;
      final objectPaths = pendingFields
          .map((resolution) => resolution.objectPath)
          .toSet()
          .toList();

      final signedUrls = await _supabase.storage
          .from(bucketName)
          .createSignedUrls(objectPaths, signedUrlExpirySeconds);
      final signedUrlByPath = {
        for (final item in signedUrls) item.path: item.signedUrl,
      };

      for (final resolution in pendingFields) {
        resolvedRecords[resolution.recordIndex][resolution.fieldName] =
            signedUrlByPath[resolution.objectPath];
      }
    }

    return resolvedRecords;
  }

  StorageObjectReference? _parseSupabaseStorageUrl(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    return _extractReference(segments, const [
          'storage',
          'v1',
          'object',
          'public',
        ]) ??
        _extractReference(segments, const [
          'storage',
          'v1',
          'object',
          'sign',
        ]) ??
        _extractReference(segments, const [
          'storage',
          'v1',
          'render',
          'image',
          'public',
        ]) ??
        _extractReference(segments, const [
          'storage',
          'v1',
          'render',
          'image',
          'authenticated',
        ]);
  }

  StorageObjectReference? _extractReference(
    List<String> segments,
    List<String> prefix,
  ) {
    final startIndex = _indexOfSequence(segments, prefix);
    if (startIndex == -1) {
      return null;
    }

    final bucketIndex = startIndex + prefix.length;
    if (bucketIndex >= segments.length) {
      return null;
    }

    final bucketName = segments[bucketIndex];
    if (!_isKnownBucket(bucketName)) {
      return null;
    }

    final objectPath = segments.skip(bucketIndex + 1).join('/');
    if (objectPath.isEmpty) {
      return null;
    }

    return StorageObjectReference(
      bucketName: bucketName,
      objectPath: objectPath,
    );
  }

  int _indexOfSequence(List<String> source, List<String> target) {
    if (target.isEmpty || source.length < target.length) {
      return -1;
    }

    for (var index = 0; index <= source.length - target.length; index++) {
      var matches = true;
      for (var offset = 0; offset < target.length; offset++) {
        if (source[index + offset] != target[offset]) {
          matches = false;
          break;
        }
      }
      if (matches) {
        return index;
      }
    }

    return -1;
  }

  bool _isKnownBucket(String bucketName) {
    switch (bucketName) {
      case companyAssetsBucket:
      case employeeAssetsBucket:
      case chatFilesBucket:
      case signaturesBucket:
      case requestDocsBucket:
      case reconDocsBucket:
      case podPhotosBucket:
      case loadPhotosBucket:
        return true;
      default:
        return false;
    }
  }

  bool _isPublicBucket(String bucketName) => bucketName == companyAssetsBucket;
}

class _PendingFieldResolution {
  final int recordIndex;
  final String fieldName;
  final String objectPath;

  const _PendingFieldResolution({
    required this.recordIndex,
    required this.fieldName,
    required this.objectPath,
  });
}

final storageAssetServiceProvider = Provider<StorageAssetService>((ref) {
  return StorageAssetService();
});
