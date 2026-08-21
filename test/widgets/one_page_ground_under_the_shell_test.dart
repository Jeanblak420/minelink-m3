// A screen mounted inside a `ShellRoute` must not paint a page ground of its
// own.
//
// ## What this exists to stop
//
// `MlWorkspaceCanvasPainter` paints the page behind every routed screen —
// `#060B15` in dark, `#EEF2F8` in light, one flat colour, which is what
// `docs/design-reference/` measures. A leaf that wraps itself in a `Scaffold`
// paints `theme.scaffoldBackgroundColor` (`#0A1424`) over that, and one that
// wraps itself in `ColoredBox(color: MlSemantic.surfaceApp)` paints the same
// thing by another route.
//
// Measured across the desktop render set on 2026-08-21: **64 screens sat on
// the canvas and 18 on the Scaffold base.** Two page colours in one product,
// decided by nothing but whether a screen happened to wrap itself. In dark the
// difference is four RGB units and reads as a faint seam; in light it is
// fourteen units of luminance, and `ml_rail_tokens.dart` already records that
// as "what made the buyer dashboard look like a different product from the
// console beside it".
//
// It is invisible from inside any one screen — the file compiles, nothing
// overflows, and out of the shell (which is how most of them are tested) the
// ground is correct and necessary.
//
// ## Why a source scan and not a widget test
//
// Same reason as `no_second_app_bar_under_the_shell_test.dart`: the question
// is "which widgets are shell leaves", and that is a fact about
// `app_router.dart`. Rendering all 87 inside their real shell would need 87
// fixture sets.
//
// ## The exemptions
//
// A `Scaffold` is legitimate when it carries something only a `Scaffold`
// provides — a floating action button, a bottom bar, or the app bar of a page
// this screen PUSHES. Those keep the `Scaffold` and pass
// `backgroundColor: Colors.transparent` so the canvas shows through; a pushed
// page has no shell behind it and passes `mlWorkspaceGround(brightness)`
// instead, because transparent leaves it black. Either satisfies this test.
// Anything else must be marked `shell-ground-exempt: <reason>`, and exemptions
// are PRINTED on every run.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _exemptMarker = 'shell-ground-exempt:';

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
  test('no screen inside a ShellRoute paints its own page ground', () {
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

    final bodies = <String, _ClassBody>{};
    final classRe =
        RegExp(r'^class ([A-Za-z_][A-Za-z0-9_]*)\b', multiLine: true);
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

    // `Scaffold(` without a background of its own, and any page-ground paint.
    //
    // THREE disguises, all found in the wild: a `Scaffold`; a
    // `ColoredBox(color: MlSemantic.surfaceApp)`; and a `Container(color:
    // Theme.of(context).scaffoldBackgroundColor)`, which is what `/home` did
    // — painting the shell's own base back over the canvas the shell painted.
    final scaffoldRe = RegExp(r'\bScaffold\(');
    final groundRe = RegExp(r'(ColoredBox|Container)\(');
    final surfaceAppRe = RegExp(r'\.surfaceApp|scaffoldBackgroundColor');
    final okBackground = RegExp(
        r'backgroundColor:\s*(Colors\.transparent|mlWorkspaceGround\()');

    final offenders = <String>[];
    final exempt = <String>[];
    for (final screen in screens.toList()..sort()) {
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
          final isScaffold = scaffoldRe.hasMatch(line);
          // A `ColoredBox` or `Container` only counts when a PAGE ground is
          // its colour: a card or a well painting a tone is not one.
          final isGround = groundRe.hasMatch(line) &&
              lines
                  .sublist(i, i + 3 > lines.length ? lines.length : i + 3)
                  .any(surfaceAppRe.hasMatch);
          if (!isScaffold && !isGround) continue;

          final after = lines
              .sublist(i, i + 6 > lines.length ? lines.length : i + 6)
              .join('\n');
          if (isScaffold && okBackground.hasMatch(after)) continue;

          final window = lines.sublist(i > 4 ? i - 4 : 0, i).join('\n');
          final what = isScaffold ? 'Scaffold' : 'page-ground paint';
          final where =
              '$screen — $what — ${found.file}:${found.firstLine + i}';
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
      print('EXEMPT (ground)  $e');
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These screens are leaves of a ShellRoute, whose workspace '
          'canvas has already painted the page. A second ground over it is a '
          'different colour — #0A1424 over #060B15 in dark, fourteen units of '
          'luminance in light.\n\n'
          'If the widget is only there to paint a ground, delete it. If the '
          'Scaffold carries a floating action button, a bottom bar, or the app '
          'bar of a PUSHED page, keep it and pass '
          '`backgroundColor: Colors.transparent` — or, for a pushed page, '
          '`backgroundColor: mlWorkspaceGround(Theme.of(context).brightness)`, '
          'because nothing paints behind a pushed page and transparent leaves '
          'it black.\n\n'
          'Otherwise mark the line with `$_exemptMarker <reason>`.\n\n'
          '${offenders.join('\n')}',
    );
  });
}
