import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The vehicle a user asked to "track" by tapping a trip elsewhere in the app.
/// The Truck locations screens watch this and pass it to [VehiclePositionsMap]
/// as `highlightVehicleId`, backing the global "click a trip → highlight that
/// truck on the map" rule (§9).
final highlightedVehicleProvider = StateProvider<String?>((ref) => null);
