import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/mine_location.dart';
import 'package:flutter_application_1/features/portal/services/mine_location_service.dart';

final mineLocationServiceProvider =
    Provider<MineLocationService>((ref) => MineLocationService());

/// The mine's configured navigation anchors (Main Gate / Weighbridge /
/// Loading Point), keyed by the mine company id — resolve it with
/// `resolvePortalCompanyId(ref)` on portal screens.
final mineLocationsProvider = FutureProvider.autoDispose
    .family<List<MineLocation>, String>((ref, mineCompanyId) {
  return ref.watch(mineLocationServiceProvider).list(mineCompanyId);
});
