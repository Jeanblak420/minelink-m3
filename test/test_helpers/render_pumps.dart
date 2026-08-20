// The pump schedule a render capture needs before it photographs anything.
//
// WHY THIS IS A SHARED FILE AND NOT FOUR LINES INSIDE `shoot()`
// -------------------------------------------------------------
// Because it has been wrong twice, and both times the symptom was a render that
// looked fine. A picture with a missing affordance is worse than no picture: it
// is evidence, and it says the wrong thing.
//
//   1. **One pump was not enough.** `RawScrollbar` fades its thumb in from a
//      post-frame callback, so no scrollbar had ever appeared in any render —
//      measured 2026-08-20 by painting the thumb pure red and finding zero red
//      pixels. A second timed pump was added.
//
//   2. **Two pumps were not enough either, for any screen whose data arrives
//      from a `FutureProvider`** — which is nearly every screen in this product.
//      Measured 2026-08-20 on the load controller: the screen renders a spinner
//      on the first frame, the future resolves, the table is built on the
//      *second*, its scroll metrics notify from that frame's post-frame
//      callback, and the 300ms fade therefore does not even START until the
//      third. The final `pump()` carried no duration, so the clock never moved
//      and the thumb was captured at zero opacity. Bisected: the thumb appears
//      exactly 200ms after the last timed pump.
//
//      That is why `screen-load-controller-phone-dark` and
//      `screen-employees-phone-dark` showed a table cut off mid-column with
//      nothing to say more existed — the one fault `MlWideTable` was built to
//      end, still in the pictures of it.
//
// The schedule lives here so the render harness and the test that PROVES it
// works cannot drift apart. `wide_table_scrollbar_test.dart` drives this exact
// function and then counts thumb pixels; shorten anything below and it fails.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// How long `RawScrollbar` takes to fade a thumb in. Not exported by Flutter
/// (`_kScrollbarFadeDuration`), so it is restated — and the final pump below is
/// comfortably longer than it.
const Duration kScrollbarFade = Duration(milliseconds: 300);

/// Settle a freshly-pumped widget tree to the point where it can be
/// photographed.
///
/// Call after `pumpWidget`. Never `pumpAndSettle`: the console has continuously
/// running animations (the live pill, the bell), so it would hang.
Future<void> pumpForCapture(WidgetTester tester) async {
  // 1. The shell's entrance transition and any staged reveal.
  await tester.pump(const Duration(milliseconds: 900));

  // 2. Anything a POST-FRAME CALLBACK registered during frame 1 — and anything
  //    a resolved future built during frame 1, which then registers its own.
  await tester.pump(const Duration(milliseconds: 400));

  // 3. Load every `Image` for real.
  //
  //    `Image.asset` reads the bundle asynchronously and a widget test's fake
  //    async never lets that future complete, so an image resolves only if it
  //    is ALREADY in the global cache — which depends entirely on whether an
  //    earlier test in the same file happened to draw it. The rail's MineLink
  //    wordmark is one, and it is in every render. The symptom was a render
  //    that passed alone and failed in the suite: "Pixel test failed, 0.05%,
  //    895px". 895px is the wordmark.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });

  // 4. A LAST TIMED pump — the one that was missing.
  //
  //    Long enough for a fade that only began at step 2 to finish. A bare
  //    `pump()` does not move the clock at all, which is what left every
  //    future-fed table's scrollbar captured at zero opacity.
  await tester.pump(kScrollbarFade + const Duration(milliseconds: 100));
}
