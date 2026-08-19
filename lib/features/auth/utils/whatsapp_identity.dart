/// Helpers for the WhatsApp-number identity model used by admin-created
/// Mine/Supplier users.
///
/// These users have no real email address — they are identified by their
/// WhatsApp number. Until WhatsApp OTP login lands (Phase B), Supabase still
/// requires an email per auth user, so we derive a deterministic synthetic
/// email from the WhatsApp number. The same derivation is used at creation
/// (to register the auth user) and at login (to map a typed WhatsApp number
/// back to its synthetic email), so the two always agree.
library;

/// Domain used for synthetic WhatsApp-identity emails. Not a real mailbox —
/// these accounts never receive email; the `wa.` subdomain marks them clearly.
const String kWhatsappAuthEmailDomain = 'wa.mineralguide.com';

/// Returns the digits of [whatsappNumber] with all spaces, `+`, dashes,
/// parentheses and other non-digit characters stripped. Returns an empty
/// string if there are no digits.
String normalizeWhatsappNumber(String whatsappNumber) {
  return whatsappNumber.replaceAll(RegExp(r'\D'), '');
}

/// Builds the deterministic synthetic email for a WhatsApp [whatsappNumber],
/// e.g. `+27 82 123 4567` -> `wa-27821234567@wa.mineralguide.com`.
///
/// Returns an empty string when [whatsappNumber] contains no digits, so callers
/// can validate before use.
String whatsappAuthEmail(String whatsappNumber) {
  final digits = normalizeWhatsappNumber(whatsappNumber);
  if (digits.isEmpty) return '';
  return 'wa-$digits@$kWhatsappAuthEmailDomain';
}

/// Whether [identifier] looks like an email address (contains `@`) rather than
/// a bare WhatsApp number. Used by the login form to decide how to sign in.
bool looksLikeEmail(String identifier) => identifier.contains('@');

/// Formats [whatsappNumber] as an E.164 phone string (`+<digits>`) for Supabase
/// phone auth. Returns an empty string when there are no digits.
String whatsappToE164(String whatsappNumber) {
  final digits = normalizeWhatsappNumber(whatsappNumber);
  if (digits.isEmpty) return '';
  return '+$digits';
}
