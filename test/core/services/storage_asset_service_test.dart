import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late StorageAssetService service;

  setUp(() {
    service = StorageAssetService(
      supabase: SupabaseClient('https://example.supabase.co', 'test-key'),
    );
  });

  test('parses a raw employee asset path with a default bucket', () {
    final reference = service.parseReference(
      'profile_photos/employee-123/photo.png',
      defaultBucketName: StorageAssetService.employeeAssetsBucket,
    );

    expect(reference, isNotNull);
    expect(reference!.bucketName, StorageAssetService.employeeAssetsBucket);
    expect(reference.objectPath, 'profile_photos/employee-123/photo.png');
  });

  test('parses a legacy public employee asset URL', () {
    final reference = service.parseReference(
      'https://example.supabase.co/storage/v1/object/public/employee_assets/id_documents/employee-123/id_document.pdf',
    );

    expect(reference, isNotNull);
    expect(reference!.bucketName, StorageAssetService.employeeAssetsBucket);
    expect(reference.objectPath, 'id_documents/employee-123/id_document.pdf');
  });

  test('parses a signed chat file URL', () {
    final reference = service.parseReference(
      'https://example.supabase.co/storage/v1/object/sign/chat_files/room-123/message.png?token=abc',
    );

    expect(reference, isNotNull);
    expect(reference!.bucketName, StorageAssetService.chatFilesBucket);
    expect(reference.objectPath, 'room-123/message.png');
  });

  test('parses a bucket-qualified storage reference', () {
    final reference = service.parseReference(
      'storage://company_assets/company_logos/company-123/logo.png',
    );

    expect(reference, isNotNull);
    expect(reference!.bucketName, StorageAssetService.companyAssetsBucket);
    expect(reference.objectPath, 'company_logos/company-123/logo.png');
  });

  test('creates a bucket-qualified storable reference from a signed URL', () {
    final storedValue = service.toStorableReference(
      'https://example.supabase.co/storage/v1/object/sign/employee_assets/profile_photos/employee-123/photo.png?token=abc',
      bucketQualified: true,
    );

    expect(
      storedValue,
      'storage://employee_assets/profile_photos/employee-123/photo.png',
    );
  });

  test(
    'keeps external URLs unchanged when no storage bucket applies',
    () async {
      final resolvedValue = await service.resolveUrl(
        'https://example.com/file.pdf',
      );

      expect(resolvedValue, 'https://example.com/file.pdf');
    },
  );
}
