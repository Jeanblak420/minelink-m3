/// How one user can sign in, as `admin_login_methods` reads it from
/// `auth.users` (migration 20261024110000).
///
/// One password; an email and/or a WhatsApp number to name the account by.
/// The internal `wa-…@wa.mineralguide.com` placeholder is never reported as an
/// email — [email] is null for an account without a real address.
class LoginMethods {
  final String? email;

  /// E.164 (`+27…`), or null when WhatsApp sign-in is not set up.
  final String? phone;

  /// `email` or `whatsapp`.
  final String primary;

  /// A legacy WhatsApp account can sign in with its number through the
  /// placeholder even with no phone on file.
  final bool hasWhatsapp;

  const LoginMethods({
    required this.email,
    required this.phone,
    required this.primary,
    required this.hasWhatsapp,
  });

  bool get hasEmail => email != null;

  factory LoginMethods.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] as String?)?.trim();
    final phone = (json['phone'] as String?)?.trim();
    return LoginMethods(
      email: email == null || email.isEmpty ? null : email,
      phone: phone == null || phone.isEmpty ? null : phone,
      primary: json['primary'] == 'whatsapp' ? 'whatsapp' : 'email',
      hasWhatsapp: json['has_whatsapp'] == true,
    );
  }
}

/// What the admin changed in the login dialog. `null` / `false` means "leave
/// as it is"; the edge function works out the rest and refuses any change
/// that would leave no way to sign in.
class LoginEdit {
  final String? password;
  final String? email;
  final bool removeEmail;
  final String? phone;
  final bool removePhone;
  final String? primary;

  const LoginEdit({
    this.password,
    this.email,
    this.removeEmail = false,
    this.phone,
    this.removePhone = false,
    this.primary,
  });

  bool get isEmpty =>
      password == null &&
      email == null &&
      !removeEmail &&
      phone == null &&
      !removePhone &&
      primary == null;
}

/// `+27821234567` → `0821234567`, the shape people type.
String localWhatsappNumber(String e164) {
  final digits = e164.replaceAll(RegExp(r'\D'), '');
  return digits.startsWith('27') ? '0${digits.substring(2)}' : digits;
}
