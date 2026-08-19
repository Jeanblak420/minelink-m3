import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/push/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initialise() completes and reports unconfigured when Firebase is absent',
    () async {
      final svc = PushService(isConfigured: () => false);
      await expectLater(svc.initialise(), completes);
      expect(svc.isAvailable, isFalse);
    },
  );

  test('registerCurrentDevice() is a no-op when unavailable', () async {
    var called = false;
    final svc = PushService(
      isConfigured: () => false,
      register: (_, __, ___) async => called = true,
    );
    await svc.initialise();
    await svc.registerCurrentDevice();
    expect(called, isFalse);
  });

  test('unregisterCurrentDevice() is a no-op when unavailable', () async {
    var called = false;
    final svc = PushService(
      isConfigured: () => false,
      unregister: (_) async => called = true,
    );
    await svc.initialise();
    await svc.unregisterCurrentDevice();
    expect(called, isFalse);
  });
}
