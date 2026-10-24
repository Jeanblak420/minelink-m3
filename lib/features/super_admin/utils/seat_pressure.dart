/// How close a company is to its seat limit (admin phone audit, 2026-10-24:
/// "a seat warning when a company nears its limit").
///
/// Seats now count people (the 2026-10-24 seat fix), so this is read straight
/// off `seats_used` / `seat_limit`.
enum SeatPressure { none, near, full, over }

/// [SeatPressure] for [used] of [limit].
///
/// Near means at most a fifth of the seats are left \u2014 and always when only
/// one is: 8 of 10, 4 of 5, 1 of 2. A company with no limit set (0) is never
/// warned about; there is nothing to run out of.
SeatPressure seatPressure(int used, int limit) {
  if (limit <= 0) return SeatPressure.none;
  final left = limit - used;
  if (left < 0) return SeatPressure.over;
  if (left == 0) return SeatPressure.full;
  final nearAt = (limit / 5).ceil().clamp(1, limit);
  return left <= nearAt ? SeatPressure.near : SeatPressure.none;
}

/// The words for it, or null when there is nothing to say.
String? seatPressureLabel(int used, int limit) {
  switch (seatPressure(used, limit)) {
    case SeatPressure.none:
      return null;
    case SeatPressure.near:
      final left = limit - used;
      return left == 1 ? '1 seat left' : '$left seats left';
    case SeatPressure.full:
      return 'All seats used';
    case SeatPressure.over:
      final over = used - limit;
      return over == 1 ? '1 person over the limit' : '$over people over the limit';
  }
}
