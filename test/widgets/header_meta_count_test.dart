// S5-22 — the shared meta-line count formatter.
//
// `mlCount` exists because 72 header call sites needed a meta line at once,
// and the way that goes wrong is not that a count is missing — it is that the
// same idea gets phrased 72 ways and the singular case is wrong in most of
// them. "1 loads" is the tell that a number was pasted into a sentence rather
// than written into one, and it is the sort of thing nobody files a bug about
// and everybody notices.
//
// There is no "before" for this to be red against — it is new code covering
// new behaviour — so it is registered in `tool/mutation_check.py` instead, per
// COMPLETION-PLAN.md §2. Break the singular branch and this must go red.

import 'package:flutter_application_1/core/design/components/ml_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mlCount', () {
    test('one is singular', () {
      expect(mlCount(1, 'load'), '1 load');
      expect(mlCount(1, 'trip'), '1 trip');
    });

    test('anything else is plural — including zero', () {
      // Zero deliberately reads "0 loads", not "0 load". An empty section
      // still has to say what it is empty OF, and the plural is the form a
      // reader scans for.
      expect(mlCount(0, 'load'), '0 loads');
      expect(mlCount(2, 'load'), '2 loads');
      expect(mlCount(147, 'load'), '147 loads');
    });

    test('an irregular plural is supplied, not guessed', () {
      // The four in the tree that are not singular-plus-s. "batchs",
      // "entrys" and "trucks reportings" are what the default would produce.
      expect(mlCount(1, 'batch', 'batches'), '1 batch');
      expect(mlCount(3, 'batch', 'batches'), '3 batches');
      expect(mlCount(1, 'entry', 'entries'), '1 entry');
      expect(mlCount(0, 'entry', 'entries'), '0 entries');
      expect(mlCount(1, 'truck reporting', 'trucks reporting'),
          '1 truck reporting');
      expect(mlCount(5, 'truck reporting', 'trucks reporting'),
          '5 trucks reporting');
      expect(mlCount(2, 'item needs attention', 'items need attention'),
          '2 items need attention');
    });

    test('a negative count never appears — but does not crash if it does', () {
      // No call site can produce one: every argument is a `.length`. Asserted
      // anyway because `active.length - 1` in the driver screen is one
      // subtraction away from -1, and a formatter that threw there would take
      // the whole trip screen down over a label.
      expect(mlCount(-1, 'trip'), '-1 trips');
    });
  });
}
