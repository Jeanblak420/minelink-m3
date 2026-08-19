/// Pure policy for WhatsApp-OTP re-verification.
///
/// Rule: verify on a new device, then again only once [kReverificationInterval]
/// has elapsed since the last successful verification on that device. Combined
/// with persistent Supabase sessions and per-device memory, this keeps OTP
/// frequency (and WhatsApp cost) low — a returning user is not re-prompted on
/// every login, only after the interval lapses.
library;

/// How long a device stays "verified" before another OTP is required.
///
/// Single source of truth for OTP cadence — change this one value to tune how
/// often returning users must re-verify (the main lever on WhatsApp cost).
const Duration kReverificationInterval = Duration(days: 30);

/// Whether the device must re-verify via WhatsApp OTP before use.
///
/// Returns true when the device has never verified ([lastVerifiedAt] is null)
/// or when at least [interval] has elapsed since the last verification.
bool requiresReverification(
  DateTime? lastVerifiedAt,
  DateTime now, {
  Duration interval = kReverificationInterval,
}) {
  if (lastVerifiedAt == null) return true;
  return now.difference(lastVerifiedAt) >= interval;
}
