// The write path's timing rules. A dial fires onChanged per arrow-key press,
// so without coalescing a held key is one RPC per key repeat — and the widget
// is the wrong place to know that.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/data/repositories/targets_controller.dart';
import 'package:flutter_application_1/features/super_admin/data/repositories/targets_repository.dart';

/// Records calls instead of making them. Never touches the client it is handed.
class _FakeRepo extends TargetsRepository {
  _FakeRepo(super.client);

  final List<String> calls = <String>[];
  Object? failWith;

  Future<void> _record(String call) async {
    calls.add(call);
    if (failWith != null) {
      final e = failWith!;
      failWith = null;
      throw e;
    }
  }

  @override
  Future<void> setMonthTarget(TargetScope s, String period, double tons) =>
      _record('month:$period=${tons.toStringAsFixed(0)}');

  @override
  Future<void> setHorizonDraft(TargetScope s, String horizon, double tons) =>
      _record('horizon:$horizon=${tons.toStringAsFixed(0)}');

  @override
  Future<void> lockCycle(TargetScope s, Map<String, double> targets) =>
      _record('lock');

  @override
  Future<void> startNewCycle(TargetScope s) => _record('newCycle');
}

void main() {
  const delay = Duration(milliseconds: 30);
  const settled = Duration(milliseconds: 120);

  late _FakeRepo repo;
  late int settles;

  TargetsController build() {
    settles = 0;
    return TargetsController(
      repository: repo,
      scope: TargetScope.platform,
      onSettled: () => settles++,
      delay: delay,
    );
  }

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'targets-controller-test-key',
    );
  });

  setUp(() => repo = _FakeRepo(Supabase.instance.client));

  test('a burst of nudges sends one write, carrying the last value', () async {
    final c = build();
    addTearDown(c.dispose);

    // What holding the up-arrow looks like.
    for (final v in [10.0, 20.0, 30.0, 40.0, 50.0]) {
      c.setMonthTarget('2026-09', v);
    }
    expect(repo.calls, isEmpty, reason: 'nothing should go out mid-burst');

    await Future<void>.delayed(settled);
    expect(repo.calls, ['month:2026-09=50']);
    expect(settles, 1);
  });

  test('different targets are coalesced independently', () async {
    final c = build();
    addTearDown(c.dispose);

    c.setMonthTarget('2026-09', 100);
    c.setMonthTarget('2026-10', 200);
    c.setHorizonDraft('d7', 300);
    await Future<void>.delayed(settled);

    expect(repo.calls, hasLength(3));
    expect(repo.calls, contains('month:2026-09=100'));
    expect(repo.calls, contains('month:2026-10=200'));
    expect(repo.calls, contains('horizon:d7=300'));
  });

  test('a value the server already has is not sent again', () async {
    final c = build();
    addTearDown(c.dispose);

    c.setMonthTarget('2026-09', 450);
    await Future<void>.delayed(settled);
    expect(repo.calls, ['month:2026-09=450']);

    // What a dial does on every blur, edited or not.
    c.setMonthTarget('2026-09', 450);
    await Future<void>.delayed(settled);
    expect(repo.calls, ['month:2026-09=450'], reason: 'no second write');

    // A real change still goes.
    c.setMonthTarget('2026-09', 460);
    await Future<void>.delayed(settled);
    expect(repo.calls, ['month:2026-09=450', 'month:2026-09=460']);
  });

  test('a rejected value stays retryable', () async {
    final c = build();
    addTearDown(c.dispose);

    repo.failWith = StateError('Target for 2026-09 is closed');
    final seen = <TargetsWriteResult>[];
    c.writes.where((r) => !r.ok).listen(seen.add);

    c.setMonthTarget('2026-09', 450);
    await Future<void>.delayed(settled);
    expect(repo.calls, hasLength(1));
    expect(seen, hasLength(1), reason: 'the failure must reach the UI');

    // The same value again must not be swallowed as "already committed".
    c.setMonthTarget('2026-09', 450);
    await Future<void>.delayed(settled);
    expect(repo.calls, hasLength(2));
  });

  test('the feed is re-read whether the write worked or not', () async {
    final c = build();
    addTearDown(c.dispose);

    repo.failWith = StateError('nope');
    c.setMonthTarget('2026-09', 1);
    await Future<void>.delayed(settled);
    expect(settles, 1, reason: 'a failure must still put the truth back');

    c.setMonthTarget('2026-10', 2);
    await Future<void>.delayed(settled);
    expect(settles, 2);
  });

  test('locking flushes queued edits first', () async {
    final c = build();
    addTearDown(c.dispose);

    c.setHorizonDraft('d7', 80);
    expect(c.pendingCount, 1);

    await c.lockCycle({'d7': 80});
    // The draft has to land before the lock reads it, or the cycle commits a
    // value the user cannot see on screen.
    expect(repo.calls, ['horizon:d7=80', 'lock']);
  });

  test('starting a new cycle is immediate, not debounced', () async {
    final c = build();
    addTearDown(c.dispose);

    await c.startNewCycle();
    expect(repo.calls, ['newCycle']);
  });

  test('a queued edit still goes out when the screen closes', () async {
    final c = build();
    c.setMonthTarget('2026-09', 999);
    expect(repo.calls, isEmpty);

    // Typing a target and navigating away is still setting a target.
    c.dispose();
    await Future<void>.delayed(settled);
    expect(repo.calls, ['month:2026-09=999']);
  });

  test('nothing is scheduled after dispose', () async {
    final c = build();
    c.dispose();

    c.setMonthTarget('2026-09', 1);
    await Future<void>.delayed(settled);
    expect(repo.calls, isEmpty);
  });

  // The dial shows a refusal only if the key the controller reports matches the
  // key the screen asks errorFor() about. They are built in two different
  // files, so nothing but a test holds them together.
  group('write results are keyed the way the screen looks them up', () {
    test('a month reports m:<period>, a horizon reports h:<key>', () async {
      final c = build();
      addTearDown(c.dispose);
      final seen = <TargetsWriteResult>[];
      c.writes.listen(seen.add);

      c.setMonthTarget('2026-09', 450);
      c.setHorizonDraft('d7', 80);
      await Future<void>.delayed(settled);

      expect(seen.map((r) => r.key), containsAll(['m:2026-09', 'h:d7']));
    });

    test('a failure carries the server wording, a success carries no key '
        'to clear but reports ok', () async {
      final c = build();
      addTearDown(c.dispose);
      final seen = <TargetsWriteResult>[];
      c.writes.listen(seen.add);

      repo.failWith = StateError('Target for 2026-07 is closed');
      c.setMonthTarget('2026-07', 1);
      await Future<void>.delayed(settled);

      expect(seen.single.key, 'm:2026-07');
      expect(seen.single.ok, isFalse);
      expect(seen.single.message, contains('closed'));

      // The retry succeeds, which is what clears the dial.
      seen.clear();
      c.setMonthTarget('2026-07', 2);
      await Future<void>.delayed(settled);
      expect(seen.single.key, 'm:2026-07');
      expect(seen.single.ok, isTrue);
    });

    test('whole-cycle actions report no key, so no dial claims them',
        () async {
      final c = build();
      addTearDown(c.dispose);
      final seen = <TargetsWriteResult>[];
      c.writes.listen(seen.add);

      repo.failWith = StateError('Cycle is locked until 01 Sep 2027');
      await c.lockCycle({'d7': 1});
      await Future<void>.delayed(settled);

      expect(seen.single.key, isNull);
      expect(seen.single.ok, isFalse);
    });
  });
}
