import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';

/// Load quality data access: the per-load certificates (structured Cr2O3 /
/// moisture / sizing + lab PDF in the private `quality_certs` bucket), the
/// route contract specs, and the server-side payable-tons penalty calc.
/// Scoping is server-side: parties see their own loop, the platform admin all.
class QualityService {
  final SupabaseClient _client = SupabaseConfig.client;

  static const qualityCertsBucket = 'quality_certs';

  /// Quality rows per loaded trip. Null [companyId] = everything the caller
  /// may see (the platform admin's combined view).
  Future<List<LoadQualityRow>> listLoadQuality(String? companyId) async {
    final rows = await _client.rpc(
      'list_load_quality',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => LoadQualityRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Uploads the lab certificate file for a load under the mine's company
  /// folder and returns the object path to hand to [setLoadQualityCert].
  Future<String> uploadCertFile({
    required String supplierCompanyId,
    required String tripId,
    required String name,
    required Uint8List bytes,
  }) async {
    final safeName = (name.isEmpty ? 'certificate.pdf' : name)
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$supplierCompanyId/quality/$tripId/${const Uuid().v4()}_$safeName';
    final ext = safeName.contains('.')
        ? safeName.substring(safeName.lastIndexOf('.') + 1).toLowerCase()
        : 'pdf';
    await _client.storage.from(qualityCertsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: switch (ext) {
              'png' => 'image/png',
              'jpg' || 'jpeg' => 'image/jpeg',
              'webp' => 'image/webp',
              'heic' || 'heif' => 'image/heic',
              _ => 'application/pdf',
            },
          ),
        );
    return path;
  }

  /// Attach/replace the quality certificate on a load. Server-validated: only
  /// the loading mine's staff (or the platform admin) may write; the trip must
  /// have its weighbridge Net Weight recorded.
  Future<void> setLoadQualityCert({
    required String tripId,
    double? cr2o3Pct,
    double? moisturePct,
    String? sizing,
    String? notes,
    String? certPath,
    String? fileName,
  }) async {
    await _client.rpc('set_load_quality_cert', params: {
      'p_trip_id': tripId,
      'p_cr2o3_pct': cr2o3Pct,
      'p_moisture_pct': moisturePct,
      'p_sizing': sizing,
      'p_notes': notes,
      'p_cert_path': certPath,
      'p_file_name': fileName,
    });
  }

  /// The mine's routes with their contract quality specs (for the spec editor).
  Future<List<RouteQualitySpec>> listSupplierRouteSpecs(
    String supplierCompanyId,
  ) async {
    final rows = await _client
        .from('routes')
        .select(
            'id, route_number, commodity, offloading_point, spec_cr2o3_pct, '
            'spec_moisture_max_pct, spec_sizing, seal_required')
        .eq('supplier_company_id', supplierCompanyId)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => RouteQualitySpec.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Set the contract quality spec on a route (mine staff or platform admin).
  Future<void> setRouteQualitySpec({
    required String routeId,
    double? specCr2o3Pct,
    double? specMoistureMaxPct,
    String? specSizing,
  }) async {
    await _client.rpc('set_route_quality_spec', params: {
      'p_route_id': routeId,
      'p_spec_cr2o3_pct': specCr2o3Pct,
      'p_spec_moisture_max_pct': specMoistureMaxPct,
      'p_spec_sizing': specSizing,
    });
  }

  /// Turn the seal requirement on or off for a live route.
  ///
  /// Supplying mine or platform admin only, enforced in
  /// `set_route_seal_requirement`. Seals are physically applied at the mine, so
  /// the mine can set this without going back through the admin. Until
  /// 2026-08-17 `routes.seal_required` had **no writer anywhere in the
  /// product**, so the Load Controller's capture rule and the server-side
  /// enforcement in `record_truck_load` could never fire (migration
  /// `20260817170000`).
  Future<void> setRouteSealRequirement({
    required String routeId,
    required bool required,
  }) async {
    await _client.rpc('set_route_seal_requirement', params: {
      'p_route_id': routeId,
      'p_required': required,
    });
  }

  /// Short-lived signed URL for a certificate file (party-scoped by RLS).
  Future<String?> resolveCertUrl(String? path) async {
    final p = path?.trim();
    if (p == null || p.isEmpty) return null;
    return _client.storage.from(qualityCertsBucket).createSignedUrl(p, 3600);
  }
}

final qualityServiceProvider = Provider<QualityService>((ref) => QualityService());

/// Quality rows for a company (null = the platform admin's combined view).
final loadQualityProvider = FutureProvider.family
    .autoDispose<List<LoadQualityRow>, String?>(
  (ref, companyId) =>
      ref.read(qualityServiceProvider).listLoadQuality(companyId),
);

/// A mine's routes + contract specs for the quality spec editor.
final supplierRouteSpecsProvider = FutureProvider.family
    .autoDispose<List<RouteQualitySpec>, String>(
  (ref, companyId) =>
      ref.read(qualityServiceProvider).listSupplierRouteSpecs(companyId),
);
