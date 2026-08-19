// S3-9. A proof of delivery cannot be recorded without a photo.
//
// The photo is EVIDENCE — it is the only thing standing between "the load
// arrived" and somebody's word for it, and `pod_photos` had never held a
// single file, so the rule had never actually bound anything.
//
// Enforcement now exists at three depths, and this test pins the outermost
// one, which is the only one a Dart change can break:
//
//   1. the dialog returns a non-nullable XFile, so the driver screen cannot
//      reach the call without one;
//   2. `LifecycleService.recordPod` takes a REQUIRED, non-empty photo path —
//      what this file asserts;
//   3. `record_pod` refuses a null/blank path, a path that is not in storage,
//      and a path outside the hauling company's folder.
//
// Depth 3 is verified against production, not here: four refusals and one
// success, walked in rolled-back transactions on 2026-08-15. Depth 2 is a
// runtime check because Dart cannot express "non-empty String" in a type —
// and an empty string was the exact hole, since it satisfies `String` and
// then travels all the way to Postgres before anything objects.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/portal/services/lifecycle_service.dart';

void main() {
  // `LifecycleService`'s constructor reads `SupabaseConfig.client`, which
  // asserts the instance is initialised. Without this the test fails in the
  // CONSTRUCTOR and never reaches the assertion — which is how the first run
  // of this file produced a red that proved nothing at all
  // (COMPLETION-PLAN.md §1: "a green test is not proof unless you have seen it
  // red" cuts both ways — a red for the wrong reason is not proof either).
  // No request is ever made: the guard throws before any RPC.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'record-pod-photo-required',
    );
  });

  group('recordPod refuses a missing photo before it reaches the server', () {
    test('an empty photo path is refused locally', () async {
      final service = LifecycleService();
      expect(
        () => service.recordPod(
          tripId: 'trip-1',
          deliveredTons: 34,
          photoUrl: '',
        ),
        throwsA(isA<ArgumentError>()),
        reason: 'an empty string satisfies `String` and would otherwise travel '
            'to Postgres before anything objected',
      );
    });

    test('a whitespace-only photo path is refused locally', () async {
      final service = LifecycleService();
      expect(
        () => service.recordPod(
          tripId: 'trip-1',
          deliveredTons: 34,
          photoUrl: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    // There is deliberately no "null is refused" case: `photoUrl` is a
    // REQUIRED non-nullable parameter, so null does not compile. That is the
    // strongest form this check can take, and a test asserting it would only
    // be asserting that Dart works.
  });
}
