class Validators {
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
  );

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }

    // Remove leading/trailing whitespace
    final email = value.trim();

    if (email.length > 254) {
      return 'Email is too long';
    }

    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    // Additional checks
    if (email.contains('..')) {
      return 'Email cannot contain consecutive dots';
    }

    if (email.startsWith('.') || email.endsWith('.')) {
      return 'Email cannot start or end with a dot';
    }

    final parts = email.split('@');
    if (parts[0].length > 64) {
      return 'Local part of email is too long';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }
}
