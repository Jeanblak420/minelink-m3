// A screen mounted inside a `ShellRoute` must not draw an app bar of its own.
//
// ## What this exists to stop
//
// Both of the router's `ShellRoute`s wrap their children in chrome that already
// carries a top bar: the portal's `PortalShellLayout` builds it from
// `mlRouteTitle`, and the console's `SuperAdminShellLayout` does the same. So a
// leaf that returns `Scaffold(appBar: AppBar(title: Text('Notifications')))`
// puts the word "Notifications" on the screen a second time, directly beneath
// the first, and on a phone that is two thirds of the first 200 pixels spent
// saying one thing twice.
//
// It had happened **thirteen times**, on twelve screens, and it kept happening
// because nothing about it is visible from inside the screen: the file compiles,
// nothing overflows, and out of the shell — which is how most of them were
// tested — the bar is correct and necessary. It was found by photographing the
// shared tail on 2026-08-21 and then scanning for the shape.
//
// ## Why a source scan and not a widget test
//
// The question is "which widgets are shell leaves", and that is a fact about
// `app_router.dart`, not about any one widget tree. Rendering all 87 of them
// inside their real shell would need 87 fixture sets. Reading the router is
// exact and costs nothing.
//
// ## The exemption
//
// A screen may legitimately build a `Scaffold(appBar:)` for a page it PUSHES —
// `Navigator.push` inside a shell covers the shell's body with a page that
// nothing else names, so that page needs its own bar and its own back button.
// Mark such a line with `shell-app-bar-exempt: <reason>` in a comment on the
// line above it. Exemptions are PRINTED on every run, because one nobody can
// see is how a rule rots.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _exemptMarker = 'shell-app-bar-exempt:';

/// The text between `opener` and the `)` that closes it.
List<String> _parenRegions(String text, String opener) {
  final out = <String>[];
  var from = 0;
  while (true) {
    final at = text.indexOf(opener, from);
    if (at < 0) break;
    var depth = 0;
    var j = at + opener.length - 1; // on the '('
    final start = j;
    while (j < text.length) {
      final c = text[j];
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
        if (depth == 0) break;
      }
      j++;
    }
    out.add(text.substring(start, j));
    from = at + opener.length;
  }
  return out;
}

class _ClassBody {
  _ClassBody(this.file, this.body, this.firstLine);
  final String file;
  final String body;
  final int firstLine;
}

void main() {
  test('no screen inside a ShellRoute builds its own app bar', () {
    final router = File('lib/core/routing/app_router.dart').readAsStringSync();
    final shells = _parenRegions(router, 'ShellRoute(');
    expect(shells, isNotEmpty,
        reason: 'the router should still have at least one ShellRoute — if it '
            'does not, this test is scanning nothing and passing');

    final screens = <String>{};
    final nameRe = RegExp(r'\b([A-Z][A-Za-z0-9_]*Screen)\b');
    for (final shell in shells) {
      for (final m in nameRe.allMatches(shell)) {
        screens.add(m.group(1)!);
      }
    }
    expect(screens.length, greaterThan(50),
        reason: 'the shells should name dozens of screens; a small number '
            'means the paren scan broke and the test is blind');

    // Index every top-level class in `lib/` with the span of its body.
    final bodies = <String, _ClassBody>{};
    final classRe = RegExp(r'^class ([A-Za-z_][A-Za-z0-9_]*)\b', multiLine: true);
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final m in classRe.allMatches(src)) {
        final open = src.indexOf('{', m.end);
        if (open < 0) continue;
        var depth = 0;
        var j = open;
        while (j < src.length) {
          final c = src[j];
          if (c == '{') {
            depth++;
          } else if (c == '}') {
            depth--;
            if (depth == 0) break;
          }
          j++;
        }
        bodies[m.group(1)!] = _ClassBody(
          entity.path.replaceAll(r'\', '/'),
          src.substring(open, j),
          '\n'.allMatches(src.substring(0, open)).length + 1,
        );
      }
    }

    final offenders = <String>[];
    final exempt = <String>[];
    final appBarRe = RegExp(r'\bappBar:');
    for (final screen in screens.toList()..sort()) {
      // The screen and its State: a `ConsumerStatefulWidget` builds through
      // `_XState`, so the bar is almost never in the class the router names.
      for (final cls in [screen, '_${screen}State']) {
        final found = bodies[cls];
        if (found == null) continue;
        final lines = found.body.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final trimmed = line.trim();
          if (trimmed.startsWith('//') ||
              trimmed.startsWith('///') ||
              trimmed.startsWith('*')) {
            continue;
          }
          if (!appBarRe.hasMatch(line)) continue;
          final window = lines
              .sublist(i > 4 ? i - 4 : 0, i)
              .join('\n');
          final where = '$screen — ${found.file}:${found.firstLine + i}';
          if (window.contains(_exemptMarker)) {
            exempt.add(where);
          } else {
            offenders.add(where);
          }
        }
      }
    }

    for (final e in exempt) {
      // ignore: avoid_print
      print('EXEMPT (pushed page, names itself)  $e');
    }
    expect(exempt, isNotEmpty,
        reason: 'the one known exemption should still be found — if it is not, '
            'the marker or the scan has drifted and the exemption path is '
            'untested');

    expect(
      offenders,
      isEmpty,
      reason: 'These screens are leaves of a ShellRoute, which has already '
          'drawn a top bar carrying the section name. Use `MlPageHeader` for '
          'the title and the screen-level actions instead of an `AppBar`. If '
          'the bar belongs to a page this screen PUSHES, mark the line with '
          '`$_exemptMarker <reason>`.\n\n${offenders.join('\n')}',
    );
  });
}
