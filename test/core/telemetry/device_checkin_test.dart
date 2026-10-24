// The daily device check-in (Jean's go-ahead, 2026-10-24): every signed-in
// install says "I am here and I can write" once a day, through the same
// authenticated path as the crash sink, so a quiet crash table can be read.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/core/telemetry/device_checkin.dart';

void main() {
  late List<Map<String, dynamic>> sent;
  late DateTime now;
  String? user;
  var failNext = false;

  Future<DeviceCheckin> make() async {
    final prefs = await SharedPreferences.getInstance();
    return DeviceCheckin(
      prefs: () async => prefs,
      clock: () => now,
      userId: () => user,
      platform: 'android',
      appVersion: '1.0.0',
      post: (params) async {
        if (failNext) {
          failNext = false;
          throw Exception('offline');
        }
        sent.add(params);
      },
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sent = [];
    now = DateTime.utc(2026, 10, 24, 8);
    user = 'u1';
    failNext = false;
  });

  test('the first run checks in, with a stable id for this install', () async {
    final c = await make();
    await c.checkInIfDue();
    expect(sent, hasLength(1));
    expect(sent.single['p_platform'], 'android');
    expect(sent.single['p_app_version'], '1.0.0');
    final id = sent.single['p_device_id'] as String;
    expect(id.length, inInclusiveRange(8, 64));

    now = now.add(const Duration(days: 1));
    await (await make()).checkInIfDue();
    expect(sent[1]['p_device_id'], id, reason: 'same install, same id');
  });

  test('at most once in 20 hours', () async {
    final c = await make();
    await c.checkInIfDue();
    now = now.add(const Duration(hours: 19, minutes: 59));
    await c.checkInIfDue();
    expect(sent, hasLength(1));
    now = now.add(const Duration(minutes: 1));
    await c.checkInIfDue();
    expect(sent, hasLength(2));
  });

  test('signed out: nothing is sent and nothing is recorded as done', () async {
    user = null;
    final c = await make();
    await c.checkInIfDue();
    expect(sent, isEmpty);
    user = 'u1';
    await c.checkInIfDue();
    expect(sent, hasLength(1), reason: 'signing in later still checks in');
  });

  test('a failed send is retried next time, and never throws', () async {
    final c = await make();
    failNext = true;
    await c.checkInIfDue(); // must not throw
    expect(sent, isEmpty);
    await c.checkInIfDue();
    expect(sent, hasLength(1));
  });

  test('two calls at once send once', () async {
    final c = await make();
    await Future.wait([c.checkInIfDue(), c.checkInIfDue()]);
    expect(sent, hasLength(1));
  });
}
