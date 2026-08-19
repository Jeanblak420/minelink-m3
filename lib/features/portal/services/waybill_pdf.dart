import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter_application_1/features/portal/models/waybill_data.dart';

/// Renders a non-editable, print-ready Manual Waybill PDF matching the real
/// reference slip (`assets/Varsiwave waybil 2l.png`): a tall cream slip with a
/// thin outer border, a huge serif SOURCE-mine header scaled to the full
/// width, "MANUAL WAYBILL" subtitle, right-aligned NUMBER / SECTION labels
/// beside boxed values, ruled label lines ("TRUCK SEAL SERIALNO." spelled as
/// on the slip), a heavy divider, and dispatch + received blocks with
/// auto-placed signatures.
class WaybillPdfBuilder {
  static const PdfColor _ink = PdfColor.fromInt(0xFF161514);
  static const PdfColor _cream = PdfColor.fromInt(0xFFFBF5C8);

  static Future<Uint8List> build(WaybillData d) async {
    final doc = pw.Document();
    // Embed the app's own TTF fonts: full Unicode support (built-in PDF fonts
    // are Latin1-only and can't render an em dash or accented names) plus
    // on-brand fidelity — Fraunces serif header, Plus Jakarta Sans body.
    final serif = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Fraunces-SemiBold.ttf'),
    );
    final sans = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
    );
    final sansBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
    );
    final sansXBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'),
    );
    final seals = d.fourSeals;
    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm');

    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(320, 640),
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Container(
          color: _cream,
          // Reference slip: small cream margin, then a thin ink border framing
          // everything.
          padding: const pw.EdgeInsets.all(5),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _ink, width: 1.2),
            ),
            padding: const pw.EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header fills the slip's width like "VARSIWAVE" on the
                // reference, whatever the mine name's length.
                pw.SizedBox(
                  height: 44,
                  // The empty case is not decorative. FittedBox derives its
                  // transform from the laid-out child, and a zero-width one
                  // yields a NaN scale that fails PdfNum.output — so a waybill
                  // whose source mine came back blank threw during save and
                  // produced no document at all, rather than a slip with an
                  // empty header. Rare, but the failure is total and it lands
                  // on a load controller with a driver waiting.
                  child: d.sourceMine.trim().isEmpty
                      ? pw.SizedBox()
                      : pw.FittedBox(
                          fit: pw.BoxFit.contain,
                          child: pw.Text(
                            d.sourceMine.toUpperCase(),
                            style: pw.TextStyle(font: serif, color: _ink),
                          ),
                        ),
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'MANUAL WAYBILL',
                    style: pw.TextStyle(
                      font: sansXBold,
                      fontSize: 15,
                      color: _ink,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                pw.SizedBox(height: 14),
                _box('NUMBER', d.waybillNumber, sansXBold, sans),
                pw.SizedBox(height: 8),
                _box('SECTION', d.sourceMine, sansXBold, sans),
                pw.SizedBox(height: 12),
                _line('TRANSPORTER', d.transporter, sansBold, sans),
                _line('FLEET/REGISTRATION NO.', d.fleetReg, sansBold, sans),
                _line('DESTINATION', d.destination, sansBold, sans),
                pw.SizedBox(height: 2),
                for (var i = 0; i < 4; i++)
                  _line(
                    // Spelled exactly as printed on the reference slip.
                    'TRUCK SEAL SERIALNO. ${i + 1}',
                    seals[i],
                    sansBold,
                    sans,
                    vPad: 3.5,
                  ),
                pw.SizedBox(height: 2),
                _split('PRODUCT', d.product, 'TONS', d.tons, sansBold, sans),
                pw.SizedBox(height: 4),
                _line('DISPATCHED BY', d.dispatchedBy, sansBold, sans),
                _sigLine('SIGNATURE', d.dispatchSignature, sansBold),
                _split(
                  'DATE',
                  dateFmt.format(d.dispatchedAt),
                  'TIME',
                  timeFmt.format(d.dispatchedAt),
                  sansBold,
                  sans,
                ),
                pw.SizedBox(height: 9),
                pw.Container(height: 2, color: _ink),
                pw.SizedBox(height: 7),
                _line('RECEIVED BY', d.receivedBy ?? '', sansBold, sans),
                _sigLine('SIGNATURE', d.receivedSignature, sansBold),
                _split(
                  'DATE',
                  d.receivedAt == null ? '' : dateFmt.format(d.receivedAt!),
                  'TIME',
                  d.receivedAt == null ? '' : timeFmt.format(d.receivedAt!),
                  sansBold,
                  sans,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return doc.save();
  }

  static pw.TextStyle _labelStyle(pw.Font font) =>
      pw.TextStyle(font: font, fontSize: 10, color: _ink);

  /// A ruled value line.
  ///
  /// [fitsChars] is how many characters this particular rule holds at 11pt, and
  /// it differs per call site because the rules are not the same width: a
  /// full-width one (TRANSPORTER, DESTINATION) holds about 37, while PRODUCT
  /// shares its row with TONS and holds roughly a third of that. Calibrating
  /// them all at 37 left PRODUCT clipping "Chrome Ore 42% Cr2O3 lumpy" back to
  /// "Chrome Ore" — measured on a rendered slip, which is the only way this is
  /// visible.
  static pw.Widget _fill(String value, pw.Font font,
      {double height = 16, int fitsChars = 37}) {
    return pw.Container(
      height: height,
      alignment: pw.Alignment.bottomLeft,
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _ink, width: 1.2)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 2, left: 2),
      child: pw.Text(
        _fitText(value, 11, fitsChars),
        maxLines: 1,
        style: pw.TextStyle(
          font: font,
          fontSize: _fitSize(value, 11, fitsChars),
          color: _ink,
        ),
      ),
    );
  }

  /// The point size at which [value] fits a rule [fitsChars] characters wide.
  ///
  /// These rules used to hold `maxLines: 1, overflow: TextOverflow.clip`, which
  /// silently amputates the end of a value on the document that governs a
  /// delivery. Read off a real slip in a browser on 2026-08-17, from a live
  /// completed trip:
  ///
  ///     PRODUCT      "Chrome Ore"                             was "Chrome Ore 42% Cr2O3 lumpy"
  ///     DESTINATION  "Richards Bay Dry Bulk Terminal, Berth"  was "... Berth 704"
  ///
  /// Both read as complete. The grade is what the load is priced on, and a
  /// berth is where the ship is — "Berth" with no number is not a shorter
  /// destination, it is a wrong one, and nothing on the paper said a character
  /// was missing.
  ///
  /// Scaling rather than ellipsising, because a waybill's job is to carry the
  /// whole value: a smaller berth number can still be read at the gate, an
  /// elided one cannot be recovered at all. The ruled single-line layout of the
  /// reference slip is preserved either way (`assets/Varsiwave waybil 2l.png`).
  ///
  /// Deliberately a character count and not a measurement, and deliberately not
  /// `FittedBox`. That widget derives its scale from the laid-out child, and in
  /// this document it fails two different ways: it asserts `width > 0` on a
  /// blank rule, and produces a NaN scale for several of the populated ones.
  /// Every waybill has blank rules by design — an unreceived load leaves the
  /// whole received block empty — so a helper that cannot survive one is not
  /// usable here at all. Both failures were caught by the tests below.
  ///
  /// [fitsChars] is calibrated against the real slip: at 11pt a ruled line held
  /// "Richards Bay Dry Bulk Terminal, Berth" and cut the "704" — 37 characters.
  /// An approximation is sound here because it only ever makes type SMALLER,
  /// and the alternative it replaces was removing characters without saying so.
  static double _fitSize(String value, double base, int fitsChars) {
    if (value.length <= fitsChars) return base;
    // Floored: past this the value stops being readable on a printed slip, and
    // a load controller squinting at a berth number is still better served
    // than one handed a berth with no number.
    return math.max(_minPt, base * fitsChars / value.length);
  }

  /// Below this the type stops being readable on a printed slip handed to a
  /// driver at a weighbridge.
  static const double _minPt = 6.0;

  /// [value] cut to what a rule [fitsChars] wide can hold at [_minPt] — WITH an
  /// ellipsis, so the reader can see that it was cut.
  ///
  /// Shrinking alone is not always enough. A 26-character product spec in the
  /// PRODUCT rule — which shares its row with TONS — needs about 4pt to fit
  /// whole, and 4pt on a printed slip is not a value, it is a smudge. So the
  /// floor binds, and past the floor characters do come off.
  ///
  /// The point is that they come off VISIBLY. The defect this replaces was not
  /// truncation; it was truncation that read as a complete value —
  /// "Chrome Ore" for "Chrome Ore 42% Cr2O3 lumpy". A trailing "…" tells the
  /// person holding the paper to go and look at the order, which is a thing
  /// they can act on.
  /// [_fitText], for tests. The truncation rule is the one thing on this slip
  /// that removes information, so it is asserted directly rather than inferred
  /// from a PDF byte count.
  @visibleForTesting
  static String debugFitText(String value, double base, int fitsChars) =>
      _fitText(value, base, fitsChars);

  static String _fitText(String value, double base, int fitsChars) {
    final capacity = (fitsChars * base / _minPt).floor();
    if (value.length <= capacity) return value;
    return '${value.substring(0, math.max(1, capacity - 1))}…';
  }

  static pw.Widget _box(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valueFont,
  ) {
    // Reference: label right-aligned beside a box that spans ~58% of the
    // content width, box flush with the right margin.
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          flex: 42,
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 10),
            child: pw.Text(
              label,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: labelFont, fontSize: 12, color: _ink),
            ),
          ),
        ),
        pw.Expanded(
          flex: 58,
          child: pw.Container(
            height: 28,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _ink, width: 1.4),
            ),
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 4),
              child: pw.Text(
                _fitText(value, 12, 30),
                maxLines: 1,
                style: pw.TextStyle(
                  font: valueFont,
                  fontSize: _fitSize(value, 12, 30),
                  color: _ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _line(
    String label,
    String value,
    pw.Font labelFont,
    pw.Font valueFont, {
    double vPad = 6.5,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: vPad),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('$label:', style: _labelStyle(labelFont)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: _fill(value, valueFont)),
        ],
      ),
    );
  }

  static pw.Widget _split(
    String l1,
    String v1,
    String l2,
    String v2,
    pw.Font labelFont,
    pw.Font valueFont, {
    /// The left rule shares its row with the right one, so it is far narrower
    /// than a full-width line.
    int fits1 = 13,
    /// The right rule is a fixed 78pt box.
    int fits2 = 8,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('$l1:', style: _labelStyle(labelFont)),
          pw.SizedBox(width: 6),
          pw.Expanded(child: _fill(v1, valueFont, fitsChars: fits1)),
          pw.SizedBox(width: 12),
          pw.Text('$l2:', style: _labelStyle(labelFont)),
          pw.SizedBox(width: 6),
          pw.SizedBox(width: 62, child: _fill(v2, valueFont, fitsChars: fits2)),
        ],
      ),
    );
  }

  static pw.Widget _sigLine(String label, Uint8List? bytes, pw.Font labelFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('$label:', style: _labelStyle(labelFont)),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Container(
              height: 34,
              alignment: pw.Alignment.bottomLeft,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _ink, width: 1.2),
                ),
              ),
              padding: const pw.EdgeInsets.only(bottom: 2, left: 2),
              child: bytes == null
                  ? pw.SizedBox()
                  : pw.Image(pw.MemoryImage(bytes), height: 30),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the platform print/preview sheet for a generated waybill.
class WaybillPreviewer {
  static Future<void> preview(WaybillData data) async {
    final label = data.waybillNumber.trim().isEmpty
        ? data.fleetReg
        : data.waybillNumber.trim();
    await Printing.layoutPdf(
      name: 'Waybill $label',
      onLayout: (format) => WaybillPdfBuilder.build(data),
    );
  }
}
