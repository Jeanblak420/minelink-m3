import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';

/// Account-setup data access (CLAUDE.md §6 — all DB access via a service).
/// The completion state comes from the self-authorizing `get_profile_setup`
/// RPC; self-service document writes go through `upsert_my_compliance_document`
/// / `delete_my_compliance_document`, which force ownership server-side.
/// Files land in the same private `compliance_docs` bucket (`{company_id}/…`)
/// the employer compliance register uses.
class ProfileSetupService {
  static const bucket = 'compliance_docs';
  final SupabaseClient _client = SupabaseConfig.client;

  /// The caller's own setup state (employee or company owner), or — when
  /// [employeeId] is given — that employee's state for a manager/platform
  /// admin (server-authorized).
  Future<ProfileSetup> fetch({String? employeeId}) async {
    final res = await _client.rpc(
      'get_profile_setup',
      params: {'p_employee_id': employeeId},
    );
    return ProfileSetup.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Creates or updates one of MY documents. `docType` is the requirement
  /// item_key (drivers_license, prdp, medical, psira, tax_clearance, …).
  Future<String> upsertMyDocument({
    required String docType,
    String? id,
    String? title,
    String? docNumber,
    DateTime? issuedAt,
    DateTime? expiresAt,
    String? filePath,
    String? notes,
  }) async {
    String? d(DateTime? v) => v?.toIso8601String().substring(0, 10);
    final res = await _client.rpc('upsert_my_compliance_document', params: {
      'p_doc_type': docType,
      'p_id': id,
      'p_title': title,
      'p_doc_number': docNumber,
      'p_issued_at': d(issuedAt),
      'p_expires_at': d(expiresAt),
      'p_file_path': filePath,
      'p_notes': notes,
    });
    return (Map<String, dynamic>.from(res as Map)['id']).toString();
  }

  Future<void> deleteMyDocument(String id) async {
    await _client.rpc('delete_my_compliance_document', params: {'p_id': id});
  }

  /// Uploads a document file and returns its storage object path (same
  /// `{company_id}/{uuid}_{name}` convention as the employer register).
  Future<String> uploadFile(
    String companyId,
    Uint8List bytes,
    String fileName,
  ) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$companyId/${const Uuid().v4()}_$safe';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
    return path;
  }

  Future<String?> resolveFileUrl(String path) async {
    try {
      return await _client.storage.from(bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }
}

final profileSetupServiceProvider =
    Provider<ProfileSetupService>((ref) => ProfileSetupService());
