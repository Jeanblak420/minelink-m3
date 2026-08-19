import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/employee/services/employee_service.dart';
import 'package:flutter_application_1/features/portal/models/compliance_document.dart';

/// A minimal owner option for the compliance add/edit picker.
class ComplianceOwnerOption {
  final String id;
  final String label;
  const ComplianceOwnerOption(this.id, this.label);
}

/// Compliance-document data access (CLAUDE.md §6 — all DB access via a service).
/// Reads/writes go through the RPCs, which self-authorize (company staff read;
/// manager/admin write). Optional files live in the private compliance_docs
/// bucket under `{company_id}/…`.
class ComplianceService {
  static const bucket = 'compliance_docs';
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<ComplianceDocument>> list(String? companyId) async {
    final rows = await _client.rpc(
      'list_compliance_documents',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => ComplianceDocument.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> upsert({
    required String companyId,
    required ComplianceOwnerType ownerType,
    required String ownerId,
    required String docType,
    DateTime? expiresAt,
    String? id,
    String? title,
    String? docNumber,
    DateTime? issuedAt,
    String? filePath,
    String? notes,
  }) async {
    String? d(DateTime? v) => v?.toIso8601String().substring(0, 10);
    final res = await _client.rpc('upsert_compliance_document', params: {
      'p_company_id': companyId,
      'p_owner_type': ownerType.wire,
      'p_owner_id': ownerId,
      'p_doc_type': docType,
      'p_expires_at': d(expiresAt),
      'p_id': id,
      'p_title': title,
      'p_doc_number': docNumber,
      'p_issued_at': d(issuedAt),
      'p_file_path': filePath,
      'p_notes': notes,
    });
    return (Map<String, dynamic>.from(res as Map)['id']).toString();
  }

  Future<void> delete(String id) async {
    await _client.rpc('delete_compliance_document', params: {'p_id': id});
  }

  /// Uploads an optional document file and returns its storage object path.
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

final complianceServiceProvider =
    Provider<ComplianceService>((ref) => ComplianceService());

/// Compliance documents for a company (or all, keyed null for a platform
/// admin), soonest-expiry first. Invalidate after any mutation.
final complianceDocumentsProvider =
    FutureProvider.family.autoDispose<List<ComplianceDocument>, String?>(
  (ref, companyId) => ref.read(complianceServiceProvider).list(companyId),
);

/// The company's employees as owner options (id + full name) for the picker.
final complianceEmployeeOptionsProvider =
    FutureProvider.family.autoDispose<List<ComplianceOwnerOption>, String>(
  (ref, companyId) async {
    final rows =
        await ref.read(employeeServiceProvider).getEmployeesByCompanyId(companyId);
    return [
      for (final e in rows)
        ComplianceOwnerOption(
          e['id'].toString(),
          [
            (e['first_name'] ?? '').toString().trim(),
            (e['last_name'] ?? '').toString().trim(),
          ].where((s) => s.isNotEmpty).join(' ').trim().isEmpty
              ? (e['email'] ?? 'Employee').toString()
              : [
                  (e['first_name'] ?? '').toString().trim(),
                  (e['last_name'] ?? '').toString().trim(),
                ].where((s) => s.isNotEmpty).join(' '),
        ),
    ];
  },
);
