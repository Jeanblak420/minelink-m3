import 'package:flutter_application_1/features/auth/services/device_verification_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lastVerifiedAt is null before any verification', () async {
    final store = DeviceVerificationStore();
    expect(await store.lastVerifiedAt(), isNull);
  });

  test('markVerified persists the timestamp (second-resolution)', () async {
    final store = DeviceVerificationStore();
    final t = DateTime(2026, 6, 17, 12, 30, 45);
    await store.markVerified(t);
    expect(await store.lastVerifiedAt(), t);
  });

  test('deviceId is stable across calls', () async {
    final store = DeviceVerificationStore();
    final a = await store.deviceId();
    final b = await store.deviceId();
    expect(a, isNotEmpty);
    expect(a, b);
  });

  test('clear removes the verification timestamp', () async {
    final store = DeviceVerificationStore();
    await store.markVerified(DateTime(2026, 6, 17));
    await store.clear();
    expect(await store.lastVerifiedAt(), isNull);
  });
}
