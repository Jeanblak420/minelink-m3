import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Local, per-install record of WhatsApp-OTP verification used by the
/// re-verification guard. Low-sensitivity (an attacker editing it still needs a
/// valid Supabase session), so plain shared_preferences is sufficient.
class DeviceVerificationStore {
  static const _kLastVerified = 'wa_otp_last_verified_at';
  static const _kDeviceId = 'wa_otp_device_id';

  Future<DateTime?> lastVerifiedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastVerified);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markVerified(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastVerified, now.toIso8601String());
  }

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_kDeviceId, id);
    return id;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastVerified);
  }
}

final deviceVerificationStoreProvider =
    Provider<DeviceVerificationStore>((ref) => DeviceVerificationStore());
