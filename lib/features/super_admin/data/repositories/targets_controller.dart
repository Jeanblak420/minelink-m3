import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/data/repositories/targets_repository.dart';

/// How one write finished.
///
/// Carries the target's key so the UI can put a refusal next to the dial it
/// belongs to, rather than only in a notice that scrolls away. [key] is null
/// for whole-cycle actions (lock, start new) which belong to no single dial.
@immutable
class TargetsWriteResult {
  const TargetsWriteResult({this.key, this.error});

  final String? key;
  final Object? error;

  bool get ok => error == null;

  /// The server's own wording where there is one — those messages are written
  /// to be read by a person.
  String get message => switch (error) {
        null => '',
        PostgrestException e => e.message,
        final Object e => '$e',
      };
}

/// One queued edit: the timer that will send it, and the write itself, kept
/// together so a flush can run what a cancelled timer would have.
class _Pending {
  _Pending(this.timer, this.write, this.value);

  final Timer timer;
  final Future<void> Function() write;
  final double value;
}

/// Owns *when* a target edit reaches the server, so the widgets don't have to.
///
/// A dial fires `onChanged` on every arrow-key press, so a held key would
/// otherwise be one RPC per key repeat. Writes are coalesced per target key on
/// a trailing delay: the last value in a burst is the one that lands, and a
/// value the server already has is not sent again.
///
/// Locking a cycle and starting a new one are deliberate, confirmed, one-shot
/// actions — they are never delayed.
class TargetsController {
  TargetsController({
    required TargetsRepository repository,
    required TargetScope scope,
    required void Function() onSettled,
    this.delay = const Duration(milliseconds: 400),
  })  : _repo = repository,
        _scope = scope,
        _onSettled = onSettled;

  final TargetsRepository _repo;
  final TargetScope _scope;

  /// Called after any write settles, successfully or not, so the caller can
  /// re-read. On success it picks up the write; on failure it puts the
  /// server's truth back on screen.
  final void Function() _onSettled;

  final Duration delay;

  final Map<String, _Pending> _pending = <String, _Pending>{};

  /// The last value the server accepted, per key — so a dial that fires on
  /// blur without having been edited costs nothing. Only recorded on success:
  /// a rejected value has to stay retryable.
  final Map<String, double> _committed = <String, double>{};

  final StreamController<TargetsWriteResult> _writes =
      StreamController<TargetsWriteResult>.broadcast();

  /// Every write as it settles, successful or not. Broadcast so the workspace
  /// can attach and detach without the controller caring.
  ///
  /// Successes are reported too, not just failures: that is what lets a dial's
  /// refusal be cleared the moment the same target is accepted.
  Stream<TargetsWriteResult> get writes => _writes.stream;

  bool _disposed = false;

  /// Visible for testing — how many edits are waiting to be sent.
  int get pendingCount => _pending.length;

  void setMonthTarget(String period, double tons) => _schedule(
        'm:$period',
        tons,
        () => _repo.setMonthTarget(_scope, period, tons),
      );

  void setHorizonDraft(String horizon, double tons) => _schedule(
        'h:$horizon',
        tons,
        () => _repo.setHorizonDraft(_scope, horizon, tons),
      );

  Future<void> lockCycle(Map<String, double> targets) async {
    // Anything still queued would be writing into a cycle that is about to be
    // committed, so flush first: the lock has to see what the user sees.
    await flush();
    await _run(() => _repo.lockCycle(_scope, targets));
  }

  Future<void> startNewCycle() => _run(() => _repo.startNewCycle(_scope));

  void _schedule(String key, double value, Future<void> Function() write) {
    if (_disposed) return;
    _pending.remove(key)?.timer.cancel();
    // Already the server's value — nothing to say.
    if (_committed[key] == value) return;
    _pending[key] = _Pending(
      Timer(delay, () {
        _pending.remove(key);
        unawaited(_run(write, key: key, value: value));
      }),
      write,
      value,
    );
  }

  Future<void> _run(
    Future<void> Function() write, {
    String? key,
    double? value,
  }) async {
    Object? failure;
    try {
      await write();
      if (key != null && value != null) _committed[key] = value;
    } catch (e) {
      failure = e;
      if (key != null) _committed.remove(key);
    } finally {
      if (!_disposed && !_writes.isClosed) {
        _writes.add(TargetsWriteResult(key: key, error: failure));
      }
      if (!_disposed) _onSettled();
    }
  }

  /// Sends everything still waiting, now.
  ///
  /// A target typed and then navigated away from is still a target the user
  /// set; dropping it silently would be worse than a late write.
  Future<void> flush() async {
    if (_pending.isEmpty) return;
    final due = Map<String, _Pending>.from(_pending);
    _pending.clear();
    for (final e in due.entries) {
      e.value.timer.cancel();
    }
    await Future.wait(
      due.entries.map(
        (e) => _run(e.value.write, key: e.key, value: e.value.value),
      ),
    );
  }

  /// Fire-and-forget flush, for teardown paths that cannot await. Errors have
  /// nowhere to go by then, so they are swallowed rather than thrown into a
  /// disposed zone — the write itself still goes out.
  void dispose() {
    final due = _pending.values.toList(growable: false);
    _pending.clear();
    _disposed = true;
    for (final p in due) {
      p.timer.cancel();
      unawaited(p.write().catchError((_) {}));
    }
    _writes.close();
  }
}
