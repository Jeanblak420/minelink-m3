// App-lifetime providers that work FOR a user must follow the signed-in
// account (emulator walk, 2026-10-24): Account & security named the PREVIOUS
// user after a sign-out/sign-in, and the chat providers had the same shape —
// delivery receipts never started for a user who signed in after a fresh
// install, and the chat role stayed the last user's.
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/providers/session_user_provider.dart';

/// Every top-level, non-autoDispose provider in [src] whose own body (up to
/// its matching close bracket) reads `auth.currentUser`.
List<String> capturesCurrentUser(String src) {
  final out = <String>[];
  // The declaration may wrap: `final x =\n    StateNotifierProvider<…>(`.
  final decl = RegExp(r'^final\s+(\w+)\s*=\s*(\w*Provider)((?:\.\w+)*)',
      multiLine: true);
  for (final m in decl.allMatches(src)) {
    if (m.group(3)!.contains('autoDispose')) continue;
    // Skip any type arguments, then take the call's own parentheses.
    var i = m.end;
    var angle = 0;
    while (i < src.length) {
      final ch = src[i];
      if (ch == '<') angle++;
      if (ch == '>') angle--;
      if (ch == '(' && angle == 0) break;
      i++;
    }
    var depth = 0;
    final start = i;
    for (; i < src.length; i++) {
      if (src[i] == '(') depth++;
      if (src[i] == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (src.substring(start, i).contains('auth.currentUser')) {
      out.add(m.group(1)!);
    }
  }
  return out;
}

void main() {
  test('sessionUserIdProvider follows sign-in and sign-out', () async {
    final auth = StreamController<String?>();
    addTearDown(auth.close);
    final c = ProviderContainer(overrides: [
      sessionUserIdStreamProvider.overrideWith((ref) => auth.stream),
    ]);
    addTearDown(c.dispose);
    c.listen(sessionUserIdProvider, (_, __) {}, fireImmediately: true);

    for (final id in ['u1', null, 'u2']) {
      auth.add(id);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(sessionUserIdProvider), id);
    }
  });

  test('the scanner flags the shapes that leaked, and not their neighbours', () {
    const leaked = '''
final roleProvider = FutureProvider<String?>((ref) async {
  final uid = client.auth.currentUser?.id;
  return uid;
});

final inboxProvider =
    StateNotifierProvider<Inbox, State>((ref) {
  return Inbox(SupabaseConfig.client.auth.currentUser?.id);
});

final onlineProvider = Provider<Set<String>>((ref) => ref.watch(p).online);
final scopedProvider = FutureProvider.autoDispose<String?>((ref) async {
  return client.auth.currentUser?.id;
});
''';
    expect(capturesCurrentUser(leaked), ['roleProvider', 'inboxProvider']);
  });

  test('no app-lifetime provider reads auth.currentUser in its body', () {
    // Watch sessionUserIdProvider (or authStateProvider) instead.
    final offenders = <String>[];
    for (final dir in ['lib/features/chat', 'lib/features/auth', 'lib/features/profile']) {
      for (final f in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart') || f.path.contains('session_user_provider')) {
          continue;
        }
        for (final name in capturesCurrentUser(f.readAsStringSync())) {
          offenders.add('${f.path}: $name');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
