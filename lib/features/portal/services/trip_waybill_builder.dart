import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/waybill_data.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/profile/services/signature_service.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// Builds a [WaybillData] for a trip from the authoritative `get_trip_waybill`
/// RPC (both dispatch and received blocks) and resolves the two signature PNGs.
///
/// Shared by the Load Controller (dispatch-time copy, received block blank) and
/// the Driver (signed copy after POD, received block filled) so both render the
/// same server-assigned waybill number and fields. Returns null if the trip has
/// no waybill data or isn't visible to the caller.
/// A waybill timestamp, in the reader's own time.
///
/// `get_trip_waybill` returns UTC, and `DateTime.tryParse` keeps it UTC — so
/// `DateFormat('HH:mm')` printed the UTC wall clock. Measured 2026-08-17 on a
/// real load: `loaded_at = 05:51 UTC`, and the **printed waybill said 05:51**
/// while the clock at the mine said **07:51 SAST**. That document governs a
/// physical hand-off between a load controller and a driver standing next to
/// each other; a DATE/TIME two hours out, with no zone marker to explain it, is
/// the one field on the slip nobody can reconcile afterwards.
///
/// The slip prints the clock at the mine. This started as `.toLocal()`, which
/// was right for a device configured for South Africa and wrong for one that
/// was not; since Jean's ruling of the same day it goes through [MlTime], so
/// the printed time does not depend on the machine that printed it.
@visibleForTesting
DateTime? waybillTimestamp(String? v) {
  if (v == null) return null;
  return MlTime.sastOrNull(DateTime.tryParse(v));
}

Future<WaybillData?> buildTripWaybill(WidgetRef ref, String tripId) async {
  // Both services are resolved up front, before the round-trip: `ref` throws
  // `StateError` once the widget is gone, and a driver who backs out of the
  // trip screen mid-fetch would otherwise crash instead of simply getting no
  // waybill.
  final signatures = ref.read(signatureServiceProvider);
  final data = await ref.read(lifecycleServiceProvider).getTripWaybill(tripId);
  if (data == null) return null;
  Future<Uint8List?> sig(String? path) async {
    if (path == null || path.trim().isEmpty) return null;
    try {
      return await signatures.signatureBytes(path);
    } catch (_) {
      return null;
    }
  }

  return WaybillData(
    sourceMine: (data['source_mine'] as String?) ?? OrgType.mineSupplier.label,
    waybillNumber: (data['waybill_number'] as String?) ?? '',
    transporter: (data['transporter'] as String?) ?? '—',
    fleetReg: (data['fleet_reg'] as String?) ?? '—',
    destination: (data['destination'] as String?) ?? '',
    seals: [
      for (final s in (data['seals'] as List? ?? const []))
        if (s != null) s.toString(),
    ],
    product: (data['product'] as String?) ?? '',
    tons: ((data['tons'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    dispatchedBy: (data['dispatched_by'] as String?) ?? '',
    dispatchedAt:
        waybillTimestamp(data['dispatched_at'] as String?) ?? DateTime.now(),
    receivedBy: data['received_by'] as String?,
    receivedAt: waybillTimestamp(data['received_at'] as String?),
    dispatchSignature: await sig(data['dispatch_signature_path'] as String?),
    receivedSignature: await sig(data['received_signature_path'] as String?),
  );
}
