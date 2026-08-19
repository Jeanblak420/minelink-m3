// Guardrail: no dead CTAs, and no promises the app cannot keep (P8, P0-12).
//
// Phase 8 was a list of buttons that did nothing — a snackbar saying the
// feature "opens with the platform marketplace", two stockpile uploads that
// were pure stubs, a "Test requests" action with no backing. They are gone.
// This is what stops the next one shipping.
//
// Source-reading, like `router_structure_test.dart`: the property is of the
// FILES, and a running app cannot prove the absence of a string.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every Dart file under lib/, with its text.
Iterable<(String, String)> _libFiles() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    yield (entity.path.replaceAll(r'\', '/'), entity.readAsStringSync());
  }
}

/// Strips `//` line comments and `///` doc comments, so a comment EXPLAINING a
/// removed stub does not count as one. Without this the test would forbid
/// writing down why the stub went, which is the note most worth keeping.
String _withoutComments(String source) => source
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('no unbuilt-feature language survives in shipped UI', () {
    // P8-09 asked for zero "coming soon" / "not implemented" / "will appear
    // here". Two of those three are enforced.
    //
    // ✅ CORRECTED on the third: "will appear here" is banned as written but
    // is, in 13 files, correct EMPTY-STATE copy — "When you receive
    // notifications, they will appear here" describes a working feature with
    // nothing in it yet. Forbidding it would push those screens toward saying
    // nothing, or worse toward rendering a fabricated row. The phrase is not
    // the fault; promising an unbuilt feature is, and "coming soon" /
    // "not implemented" are the phrases that do that.
    const forbidden = ['coming soon', 'not implemented'];
    final offenders = <String>[];
    for (final (path, text) in _libFiles()) {
      final code = _withoutComments(text);
      for (final phrase in forbidden) {
        if (RegExp(phrase, caseSensitive: false).hasMatch(code)) {
          offenders.add('$path — "$phrase"');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'A "coming soon" pill is a promise the build cannot keep. Build '
          'it or remove the control. Found in: $offenders',
    );
  });

  test('the sanity check: the scan actually reads files', () {
    // A guard on the guard. If `lib/` ever stops resolving from the test
    // working directory, every assertion above would pass vacuously — which is
    // the exact failure mode that made a green layout sweep meaningless
    // earlier in this effort.
    final files = _libFiles().toList();
    expect(files.length, greaterThan(200),
        reason: 'expected to scan the whole of lib/, saw ${files.length} files');
    expect(files.any((f) => f.$2.contains('class ')), isTrue);
  });

  test('the removed Phase 8 stubs have not returned', () {
    // Each string is one that shipped as a dead control and was removed.
    const gone = <String, String>{
      'Route requests open with the platform marketplace.':
          'P8-01 — transporters do not raise transport requests',
      'Buyer requests are coming soon.':
          'P8-02 — the Request Buyer form exists (showBuyersRequestDialog)',
    };
    final offenders = <String>[];
    for (final (path, text) in _libFiles()) {
      final code = _withoutComments(text);
      for (final entry in gone.entries) {
        if (code.contains(entry.key)) {
          offenders.add('$path — ${entry.value}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
