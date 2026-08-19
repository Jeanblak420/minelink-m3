import 'package:supabase_flutter/supabase_flutter.dart';

/// The SQLSTATE `enforce_employee_seat_limit` raises when a company has no
/// free seat (migration `20260815112000`).
///
/// A dedicated code rather than a message match: the wording of the refusal is
/// user-facing and will be edited, and a client that greps the sentence breaks
/// silently the first time it is. Postgres surfaces this as
/// `PostgrestException.code`; the `company-user-admin` edge function forwards
/// it as `code` in its error body, because that hop otherwise flattens the
/// failure to a bare string.
const String kSeatLimitSqlState = 'MLS01';

/// Thrown when the seat gate refused a write.
///
/// [message] is the server's own sentence — it already names the company and
/// the limit ("All 10 seat(s) at Iron Hills Mining are in use…"), so the UI
/// shows it rather than inventing its own wording.
class SeatLimitException implements Exception {
  const SeatLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// True when [error] is the seat gate refusing, whichever path it came back
/// through — a direct RPC (`assign_employee_role`) surfaces a
/// [PostgrestException]; the edge function surfaces a [SeatLimitException]
/// raised by the service layer.
bool isSeatLimitError(Object error) {
  if (error is SeatLimitException) return true;
  if (error is PostgrestException) return error.code == kSeatLimitSqlState;
  return false;
}

/// The server's sentence, when there is one worth showing.
String? seatLimitMessage(Object error) {
  if (error is SeatLimitException) return error.message;
  if (error is PostgrestException && error.code == kSeatLimitSqlState) {
    return error.message;
  }
  return null;
}
