// A width x text-scale sweep for dialogs, and the two assertions worth making.
//
// Extracted 2026-08-18 from test/features/fleet/vehicle_dialog_overflow_sweep_test
// .dart, where it found four distinct real defects in one sitting. The point of
// having it here is that dialogs are the densest layout surface in the product
// and there are dozens of them; a harness that lives inside one test file only
// ever guards one file's worth.
//
// TWO assertions, because they catch different things and only having the first
// is how the seal-points control passed for a day while being unreadable:
//
//   sweepDialog     — nothing THREW. Overflows, infinite constraints.
//   cutText         — nothing was silently TRUNCATED. `TextOverflow.ellipsis`
//                     and `isExpanded: true` between them guarantee an overflow
//                     never happens, by cutting the words instead. Measured on
//                     the shipped seal control, a 320px phone at ORDINARY text
//                     size gave a 238px label 132px of room and ellipsised the
//                     rest, in silence, with every test green.
//
// Callers must load the real fonts first (see real_fonts.dart) or the metrics
// are those of a fallback font in which every glyph is one em wide.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';

/// Widths a dialog is really opened at.
///
/// 320 is the narrowest phone still in use; 360 and 412 are the two commonest
/// Android widths; 479/480 straddle the breakpoint `DialogUtils` switches on,
/// so it is swept from both sides; the rest walk up to a desktop window.
const kDialogSweepWidths = <double>[320, 360, 412, 479, 480, 600, 768, 1024];

/// 1.0, the two ends of the in-app slider, and up to the ceiling the shells
/// install. Tests should assert this reaches [kMaxEffectiveTextScale].
const kDialogSweepScales = <double>[0.85, 1.0, 1.15, 1.3, 1.6, 2.0];

/// Pumps [dialog] into a real [showDialog] at [width] x [scale].
Future<void> pumpDialogAt(
  WidgetTester tester,
  Widget Function() dialog, {
  required double width,
  required double scale,
  bool boldText = false,
  List<Override> overrides = const [],
  double height = 720,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;

  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.darkTheme,
        // Inside MaterialApp, whose own MediaQuery.fromView would otherwise
        // replace an outer one — exactly how the portal shell installs its
        // scaler.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale), boldText: boldText),
          child: child!,
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    ),
  );

  // Unawaited on purpose — it completes when the dialog is dismissed, which a
  // sweep never does.
  unawaited(showDialog<void>(
    context: navigatorKey.currentContext!,
    builder: (_) => dialog(),
  ));
  await tester.pumpAndSettle();
}

/// Every string the renderer had to cut to make it fit.
///
/// `RenderParagraph.didExceedMaxLines` is the exact signal: the text painter
/// reporting it had more to draw than it was allowed to.
List<String> cutText(WidgetTester tester) {
  final cut = <String>[];
  void visit(Element el) {
    final ro = el.renderObject;
    if (ro is RenderParagraph && ro.didExceedMaxLines) {
      cut.add(ro.text.toPlainText());
    }
    el.visitChildren(visit);
  }

  tester.binding.rootElement!.visitChildren(visit);
  return cut;
}

/// Renders [dialog] across every width x scale and fails on the first layout
/// fault, naming the corner so the failure is actionable.
///
/// [then] runs after the dialog settles — use it to open a menu or provoke
/// validation errors, which are different layouts and break differently.
Future<void> sweepDialog(
  WidgetTester tester,
  Widget Function() dialog, {
  bool boldText = false,
  List<Override> overrides = const [],
  Future<void> Function(WidgetTester tester)? then,
  bool checkCutText = false,
}) async {
  addTearDown(tester.view.reset);

  for (final width in kDialogSweepWidths) {
    for (final scale in kDialogSweepScales) {
      // Capture the full FlutterErrorDetails, not just the exception:
      // takeException() drops the "relevant error-causing widget" line, which
      // is the only part that says WHERE to fix it.
      final captured = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = captured.add;

      await pumpDialogAt(tester, dialog,
          width: width, scale: scale, boldText: boldText, overrides: overrides);
      if (then != null) await then(tester);

      FlutterError.onError = previousOnError;
      tester.takeException();

      bool isLayoutFault(FlutterErrorDetails d) {
        final s = d.exception.toString();
        return s.contains('overflowed') ||
            s.contains('forces an infinite') ||
            s.contains('BoxConstraints');
      }

      final layout = captured.where(isLayoutFault).toList();
      if (layout.isNotEmpty) {
        final where = layout
            .map((d) => d
                .toDiagnosticsNode(style: DiagnosticsTreeStyle.error)
                .toStringDeep())
            .join('\n');
        fail('Layout error at width=$width textScale=$scale '
            'boldText=$boldText\n$where');
      }

      if (checkCutText) {
        final cut = cutText(tester);
        expect(cut, isEmpty,
            reason: 'text was silently cut at width=$width textScale=$scale: '
                '${cut.join(" | ")}');
      }
    }
  }
}
