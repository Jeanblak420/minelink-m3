import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/models/trip_reconciliation.dart';

/// Reads the system-computed reconciliations (Side B), the raw as-captured
/// records (Side A), and drives the two-version export→edit→re-upload
/// round-trip. Scoping is server-side (party companies or the platform admin).
class ReconciliationService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<TripReconciliation>> listTripReconciliations(
    String companyId,
  ) async {
    final rows = await _client.rpc(
      'list_trip_reconciliations',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => TripReconciliation.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Side A: every trip as captured, before reconciliation logic. A null
  /// [companyId] returns every row the caller may see (platform admin: all).
  Future<List<RawReconRow>> listRawRows(String? companyId) async {
    final rows = await _client.rpc(
      'list_raw_recon_rows',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => RawReconRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// The retained version pairs (original + latest edited) for a company.
  Future<List<ReconUploadPair>> listUploadPairs(String companyId) async {
    final rows = await _client
        .from('reconciliation_uploads')
        .select()
        .eq('company_id', companyId);
    return (rows as List)
        .map((e) => ReconUploadPair.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Stores an edited re-upload for (company, side). On the FIRST upload the
  /// current system export is snapshotted as the immutable original (built by
  /// [buildOriginalCsv]); afterwards only the edited copy is replaced —
  /// exactly two versions are ever retained (CLAUDE.md §4).
  Future<ReconUploadPair> saveEditedUpload({
    required String companyId,
    required String side, // 'A' | 'B'
    required String fileName,
    required Uint8List bytes,
    required String Function() buildOriginalCsv,
  }) async {
    final storage = _client.storage.from(StorageAssetService.reconDocsBucket);

    final existing = await _client
        .from('reconciliation_uploads')
        .select('id')
        .eq('company_id', companyId)
        .eq('side', side)
        .maybeSingle();

    String? originalPath;
    if (existing == null) {
      originalPath = '$companyId/${const Uuid().v4()}_side${side}_original.csv';
      await storage.uploadBinary(
        originalPath,
        Uint8List.fromList(utf8.encode(buildOriginalCsv())),
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
          contentType: 'text/csv',
        ),
      );
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final editedPath = '$companyId/${const Uuid().v4()}_$safeName';
    await storage.uploadBinary(
      editedPath,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: false,
        contentType: _contentTypeFor(safeName),
      ),
    );

    final row = await _client.rpc(
      'save_recon_upload',
      params: {
        'p_company_id': companyId,
        'p_side': side,
        'p_original_path': originalPath,
        'p_edited_path': editedPath,
      },
    );
    return ReconUploadPair.fromJson(Map<String, dynamic>.from(row as Map));
  }

  static String _contentTypeFor(String fileName) {
    final ext = fileName.contains('.')
        ? fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase()
        : '';
    switch (ext) {
      case 'csv':
        return 'text/csv';
      case 'pdf':
        return 'application/pdf';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }
}

final reconciliationServiceProvider = Provider<ReconciliationService>(
  (ref) => ReconciliationService(),
);

/// Per-trip weight reconciliations for a company (buyer / mine / transporter),
/// newest first. Invalidate after a POD is recorded to refresh variance.
final tripReconciliationsProvider = FutureProvider.family
    .autoDispose<List<TripReconciliation>, String>(
      (ref, companyId) => ref
          .read(reconciliationServiceProvider)
          .listTripReconciliations(companyId),
    );

/// Side A raw rows for a company (newest first). Key null = every row the
/// caller may see (super-admin combined view).
final rawReconRowsProvider = FutureProvider.family
    .autoDispose<List<RawReconRow>, String?>(
      (ref, companyId) =>
          ref.read(reconciliationServiceProvider).listRawRows(companyId),
    );

/// The retained original/edited version pairs for a company (sides A + B).
final reconUploadPairsProvider = FutureProvider.family
    .autoDispose<List<ReconUploadPair>, String>(
      (ref, companyId) =>
          ref.read(reconciliationServiceProvider).listUploadPairs(companyId),
    );
