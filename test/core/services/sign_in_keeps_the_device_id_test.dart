// Signing in and out keeps this install's check-in id (emulator, 2026-10-25).
// Both call `CacheService.clearAllCache`, which wiped every preference, so each
// sign-in minted a new id and the admin's device list grew a phantom device
// every time somebody signed in — three for one emulator inside an hour.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/core/telemetry/device_checkin.dart';

void main() {
  test('the install id survives; user data and the WhatsApp stamp do not',
      () async {
    SharedPreferences.setMockInitialValues({
      DeviceCheckin.idKey: 'install-1234',
      'device_checkin.last': '2026-10-25T16:00:00Z',
      'wa_otp_last_verified_at': '2026-10-25T16:00:00Z',
      'company_cache_user1': '{}',
    });
    await CacheService.clearAllCache();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(DeviceCheckin.idKey), 'install-1234');
    // A new person on this phone checks in at once, and must verify their
    // own WhatsApp number.
    expect(prefs.getString('device_checkin.last'), isNull);
    expect(prefs.getString('wa_otp_last_verified_at'), isNull);
    expect(prefs.getString('company_cache_user1'), isNull);
  });

  test('a fresh install with no id yet clears cleanly', () async {
    SharedPreferences.setMockInitialValues({'x': 'y'});
    await CacheService.clearAllCache();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
  });
}
