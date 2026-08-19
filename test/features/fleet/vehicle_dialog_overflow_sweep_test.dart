// Width x text-scale sweep for the two fleet vehicle dialogs.
//
// WHY THIS EXISTS, and why one narrow-phone test was not enough.
//
// 2026-08-17 added a "Seal points on this rig" dropdown to
// `VehicleDetailsFields`, which the ADD and the EDIT dialog both render. It
// burst the add dialog by 357px on a 360px phone, because
// `DropdownButtonFormField` lays its selected item out at natural width unless
// given `isExpanded: true` and the longest option reads "4 seals — interlink,
// two trailers". `mobile_parity_verification_test` caught that one — but it
// renders ONE dialog at ONE width, so it could only ever have caught a fault
// that happened to land in that corner.
//
// These are portal surfaces, and since 2026-08-17 the portal shell COMPOSES
// the operating system's text scaler with the in-app preference rather than
// replacing it. So a transporter admin who runs their phone at large text
// reaches [kMaxEffectiveTextScale] on this dialog, which is 2.0 — not the 1.3
// the in-app slider tops out at. Every size below that is a size a real user
// can put this form in.
//
// The sweep loads the REAL fonts, because `flutter test` otherwise renders in
// a fallback font whose metrics differ from PlusJakartaSans and neither
// reproduces real overflows nor withholds invented ones (CLAUDE.md §10.5).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/layout/text_scale.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/widgets/add_vehicle_form.dart';
import 'package:flutter_application_1/features/fleet/widgets/edit_vehicle_dialog.dart';

import '../../test_helpers/real_fonts.dart';

/// Widths this dialog is really opened at.
///
/// 320 is the narrowest phone still in use (iPhone SE 1st gen / older Android
/// at 320dp); 360 and 412 are the two commonest Android widths; 480 is the
/// breakpoint `VehicleDetailsFields` and `DialogUtils` both switch on, so it
/// is swept from either side; the rest walk up to a desktop window, where the
/// dialog stops growing at its 520px cap.
const _widths = <double>[320, 360, 412, 479, 480, 600, 768, 1024];

/// 1.0, the two ends of the in-app slider, and on up to the ceiling the shell
/// will actually install. Held to that ceiling by the first test in `main`.
const _scales = <double>[0.85, 1.0, 1.15, 1.3, 1.6, 2.0];

/// A real interlink, with values as long as the form legitimately holds.
///
/// Short fixtures hide exactly the faults this sweep exists to find, so the
/// make/model here is a real long one and the odometer is seven digits.
FleetVehicle _vehicle() => FleetVehicle(
      id: 'veh-1',
      companyId: 'company-1',
      createdAt: DateTime(2026, 3, 4),
      vehicleRegistrationNumber: 'S6W001GP',
      vehicleRegistrationExpiryDate: DateTime(2027, 4, 30),
      vehicleMake: 'Mercedes-Benz',
      vehicleType: 'Actros 2645 LS/33 Interlink',
      vehicleYearModel: 2019,
      vehicleOdometerKm: 1250120,
      firstTrailerRegs: 'TJ-157-MP',
      secondTrailerRegs: 'TJ-158-MP',
      sealPoints: 4,
    );

void main() {
  // A guard on the sweep itself, not a layout assertion. Raising the shells'
  // ceiling without widening this list would leave real sizes unrendered while
  // the suite still went green.
  test('the sweep reaches the largest scale the shells will install', () {
    expect(_scales.reduce((a, b) => a > b ? a : b),
        greaterThanOrEqualTo(kMaxEffectiveTextScale),
        reason: 'lib/core/layout/text_scale.dart caps the composed scale at '
            '$kMaxEffectiveTextScale; this sweep tops out at '
            '${_scales.reduce((a, b) => a > b ? a : b)}. Widen _scales and fix '
            'what it finds before raising that constant.');
  });

  setUpAll(loadRealFonts);

  /// Opens [dialog] at every width x scale and fails on the first layout
  /// fault, naming the exact corner so the failure is actionable.
  Future<void> sweep(
    WidgetTester tester,
    Widget Function() dialog, {
    bool boldText = false,
    Future<void> Function(WidgetTester tester)? then,
  }) async {
    addTearDown(tester.view.reset);

    for (final width in _widths) {
      for (final scale in _scales) {
        // A phone in portrait, so the dialog is genuinely height-constrained
        // too: at 2.0 this form is far taller than the viewport and the
        // AlertDialog has to shrink its content rather than overflow it.
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1.0;

        // Capture the full FlutterErrorDetails rather than just the exception:
        // `takeException()` drops the "relevant error-causing widget" line,
        // which is the only part that says WHERE to fix it.
        final captured = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = captured.add;

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: navigatorKey,
              theme: AppTheme.darkTheme,
              // Inside MaterialApp, whose own MediaQuery.fromView would
              // otherwise replace an outer one — exactly how the portal shell
              // installs its scaler.
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  boldText: boldText,
                ),
                child: child!,
              ),
              home: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        );

        // Unawaited on purpose — the future completes when the dialog is
        // dismissed, which this sweep never does.
        unawaited(showDialog<void>(
          context: navigatorKey.currentContext!,
          builder: (_) => dialog(),
        ));
        await tester.pumpAndSettle();
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
      }
    }
  }

  /// Opens the seal-points menu.
  ///
  /// The closed control shows one item, ellipsised; the OPEN menu lays all
  /// four out at once in an overlay, which is a different layout with
  /// different constraints and is where a long option label would actually
  /// bite. `ensureVisible` first, because the control sits below the fold of
  /// the dialog's scroll view at the larger scales — and a tap on an offscreen
  /// widget is the kind of no-op that reports success.
  Future<void> openSealMenu(WidgetTester tester) async {
    final button = find.byType(DropdownButton<int>);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// Submits with the registration cleared, so the form renders its validator
  /// messages. Error text adds a line under a field and is the state most
  /// likely to push a tight dialog over.
  Future<void> Function(WidgetTester) submitEmpty(String button) =>
      (tester) async {
        final registration = find.byType(TextFormField).first;
        await tester.ensureVisible(registration);
        await tester.pumpAndSettle();
        await tester.enterText(registration, '');
        final submit = find.text(button);
        await tester.ensureVisible(submit);
        await tester.pumpAndSettle();
        await tester.tap(submit);
        await tester.pumpAndSettle();
        // Guard the guard: if validation did not actually fire, this callback
        // is sweeping the resting layout a second time and proving nothing.
        expect(find.text('Registration number is required'), findsOneWidget);
      };

  group('add vehicle', () {
    testWidgets('survives every width x text scale', (tester) async {
      await sweep(tester, () => const AddVehicleForm(companyId: 'company-1'));
    });

    testWidgets('survives bold text', (tester) async {
      await sweep(tester, () => const AddVehicleForm(companyId: 'company-1'),
          boldText: true);
    });

    testWidgets('survives the seal menu being open', (tester) async {
      await sweep(tester, () => const AddVehicleForm(companyId: 'company-1'),
          then: openSealMenu);
    });

    testWidgets('survives showing its validation errors', (tester) async {
      await sweep(tester, () => const AddVehicleForm(companyId: 'company-1'),
          then: submitEmpty('Add vehicle'));
    });
  });

  group('edit vehicle', () {
    testWidgets('survives every width x text scale', (tester) async {
      await sweep(
        tester,
        () => EditVehicleDialog(companyId: 'company-1', vehicle: _vehicle()),
      );
    });

    testWidgets('survives bold text', (tester) async {
      await sweep(
        tester,
        () => EditVehicleDialog(companyId: 'company-1', vehicle: _vehicle()),
        boldText: true,
      );
    });

    testWidgets('survives the seal menu being open', (tester) async {
      await sweep(
        tester,
        () => EditVehicleDialog(companyId: 'company-1', vehicle: _vehicle()),
        then: openSealMenu,
      );
    });

    testWidgets('survives showing its validation errors', (tester) async {
      await sweep(
        tester,
        () => EditVehicleDialog(companyId: 'company-1', vehicle: _vehicle()),
        then: submitEmpty('Save changes'),
      );
    });
  });

  // ---- silently-cut text -------------------------------------------------
  //
  // An overflow sweep cannot see this class of fault at all, and it is the one
  // the seal control actually had. `isExpanded: true` and `TextOverflow
  // .ellipsis` between them guarantee nothing ever overflows — by cutting the
  // text instead. Measured on the shipped control at 320px and ORDINARY text
  // size, the open menu gave "4 seals — interlink, two trailers" 132px of the
  // 238px it needs; every option on every phone width arrived truncated, so
  // the description that tells an operator which option is their rig was
  // decoration. Nothing overflowed, nothing threw, and the sweep above was
  // green throughout.
  //
  // `RenderParagraph.didExceedMaxLines` is the exact signal: the text painter
  // reporting that it had more to draw than it was allowed to. CLAUDE.md §10.4
  // — assert on geometry, not on the absence of an exception.
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

  Future<void> expectNothingCut(
    WidgetTester tester,
    Widget Function() dialog, {
    Future<void> Function(WidgetTester)? then,
  }) async {
    addTearDown(tester.view.reset);
    for (final width in _widths) {
      for (final scale in _scales) {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1.0;

        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: navigatorKey,
              theme: AppTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        );
        unawaited(showDialog<void>(
          context: navigatorKey.currentContext!,
          builder: (_) => dialog(),
        ));
        await tester.pumpAndSettle();
        if (then != null) await then(tester);

        final cut = cutText(tester);
        expect(cut, isEmpty,
            reason: 'text was silently cut at width=$width textScale=$scale: '
                '${cut.join(" | ")}');
      }
    }
  }

  group('nothing is silently cut', () {
    testWidgets('add vehicle, seal menu open', (tester) async {
      await expectNothingCut(
          tester, () => const AddVehicleForm(companyId: 'company-1'),
          then: openSealMenu);
    });

    testWidgets('edit vehicle, seal menu open', (tester) async {
      await expectNothingCut(
        tester,
        () => EditVehicleDialog(companyId: 'company-1', vehicle: _vehicle()),
        then: openSealMenu,
      );
    });
  });

  // A green sweep is only worth what its harness is worth. This proves the
  // scaler above actually reaches the widgets being swept — a MediaQuery
  // installed in the wrong place would leave every corner rendering at 1.0,
  // and the whole file would report green forever while covering one size.
  testWidgets('the swept text scale really reaches the form', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 720);

    Future<double> heightAt(double scale) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      unawaited(showDialog<void>(
        context: navigatorKey.currentContext!,
        builder: (_) => const AddVehicleForm(companyId: 'company-1'),
      ));
      await tester.pumpAndSettle();
      return tester.getSize(find.text('Seal points *').first).height;
    }

    final small = await heightAt(1.0);
    final large = await heightAt(2.0);
    expect(large, greaterThan(small * 1.5),
        reason: 'the sweep set textScale 2.0 but the label rendered at '
            '${large}px against ${small}px at 1.0 — the MediaQuery is not '
            'reaching the dialog, so every corner of this sweep is really '
            'rendering at 1.0');
  });

  // The seal control is the reason this file exists, so pin the two properties
  // that made it burst the dialog. A sweep proves nothing overflowed TODAY; a
  // dropdown reverted to its natural width would sail through at every size
  // whose longest option happens to fit.
  group('the seal-points control', () {
    testWidgets('is width-constrained in both dialogs', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;

      for (final dialog in <Widget Function()>[
        () => const AddVehicleForm(companyId: 'company-1'),
        () => EditVehicleDialog(companyId: 'company-1', vehicle: _vehicle()),
      ]) {
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              navigatorKey: navigatorKey,
              theme: AppTheme.darkTheme,
              home: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        );
        unawaited(showDialog<void>(
          context: navigatorKey.currentContext!,
          builder: (_) => dialog(),
        ));
        await tester.pumpAndSettle();

        // `isExpanded` is not readable off DropdownButtonFormField (it is a
        // FormField wrapper), so assert on the DropdownButton it builds.
        final button = tester.widget<DropdownButton<int>>(
          find.byType(DropdownButton<int>),
        );
        expect(button.isExpanded, isTrue,
            reason: 'without isExpanded the selected item is laid out at its '
                'natural width — "4 seals — interlink, two trailers" pushed '
                'this dialog 357px past a 360px phone');

        // The dialog must not be wider than the phone it is on. This is the
        // measurement the 357px defect actually failed, and it holds whether
        // or not anything reported an overflow.
        final dialogWidth =
            tester.getSize(find.byType(AlertDialog).first).width;
        expect(dialogWidth, lessThanOrEqualTo(360),
            reason: 'the dialog is wider than the screen');
      }
    });
  });
}
