import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/waybill_data.dart';
import 'package:flutter_application_1/features/portal/services/waybill_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('waybill builder produces a valid, non-empty PDF', () async {
    final data = WaybillData(
      sourceMine: 'Kolomela Mine',
      waybillNumber: 'WB-2026-001',
      transporter: 'Trans-Africa Haulage',
      fleetReg: 'CA 123-456',
      destination: 'Saldanha Port',
      seals: const ['A1', 'A2', 'B1', 'B2'],
      product: 'Iron Ore Lump',
      tons: '36.22',
      dispatchedBy: 'John Controller',
      dispatchedAt: DateTime(2026, 7, 12, 10, 30),
    );

    final bytes = await WaybillPdfBuilder.build(data);

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1000));
    // Valid PDFs start with the "%PDF-" magic number.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('waybill builder handles empty received block and missing seals', () async {
    final data = WaybillData(
      sourceMine: 'Sishen',
      waybillNumber: '',
      transporter: '—',
      fleetReg: 'ND 55 555',
      destination: '',
      seals: const [],
      product: 'Manganese',
      tons: '40.00',
      dispatchedBy: 'Controller',
      dispatchedAt: DateTime(2026, 7, 12, 8, 0),
    );

    final bytes = await WaybillPdfBuilder.build(data);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  // Read off a real slip in a browser on 2026-08-17, from a live completed
  // trip. Both of these rendered as if they were the whole value:
  //
  //     PRODUCT      "Chrome Ore"                            <- "Chrome Ore 42% Cr2O3 lumpy"
  //     DESTINATION  "Richards Bay Dry Bulk Terminal, Berth" <- "... Berth 704"
  //
  // The rules held `maxLines: 1, overflow: TextOverflow.clip`, so the end of a
  // long value was amputated with no ellipsis and nothing to say a character
  // was missing. The grade is what the load is priced on; "Berth" with no
  // number is not a shorter destination, it is a wrong one.
  //
  // The fields now scale down to fit. This asserts the document still builds
  // with values far longer than any rule — the failure mode being guarded
  // against is a layout assertion, since FittedBox computes its scale from the
  // child and throws on a zero-width one.
  test('a long value is carried, not amputated', () async {
    final data = WaybillData(
      sourceMine: 'Iron Hills Mining',
      waybillNumber: 'TRP-DEBBF4A139',
      transporter: 'Roadhaul Logistics (Pty) Ltd t/a Roadhaul Bulk Division',
      fleetReg: 'S6W001GP / S6T001GP / S6T002GP',
      destination: 'Richards Bay Dry Bulk Terminal, Berth 704, Gate 3, RBCT',
      seals: const ['IH-S4-0001', 'IH-S4-0002', 'IH-S4-0003', 'IH-S4-0004'],
      product: 'Chrome Ore 42% Cr2O3 lumpy 10-60mm, Cr:Fe 1.6, 6% moisture max',
      tons: '34.70',
      dispatchedBy: 'Controller Test, Weighbridge Load Controller',
      dispatchedAt: DateTime(2026, 8, 17, 14, 28),
      receivedBy: 'Driver Test',
      receivedAt: DateTime(2026, 8, 17, 14, 48),
    );

    final bytes = await WaybillPdfBuilder.build(data);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  // The blank rules are not an edge case, they are the normal state of an
  // unreceived load — and a scale factor cannot be computed from a zero-width
  // child. Kept beside the test above because that fix is what threatened it.
  test('every rule blank still builds', () async {
    final data = WaybillData(
      sourceMine: '',
      waybillNumber: '',
      transporter: '',
      fleetReg: '',
      destination: '',
      seals: const [],
      product: '',
      tons: '',
      dispatchedBy: '',
      dispatchedAt: DateTime(2026, 8, 17),
    );

    final bytes = await WaybillPdfBuilder.build(data);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  // The floor binds for a long product spec — 26 characters in the PRODUCT
  // rule needs about 4pt to fit whole, and 4pt on a printed slip is a smudge.
  // So characters do still come off there; the point is that they come off
  // VISIBLY. What this replaces was truncation that read as a complete value.
  test('past the readable floor the cut is marked, not hidden', () {
    // 13 characters at 11pt, floor 6pt -> capacity 23, so a 26-character value
    // is cut to 22 plus an ellipsis.
    final out = WaybillPdfBuilder.debugFitText(
        'Chrome Ore 42% Cr2O3 lumpy', 11, 13);
    expect(out, endsWith('…'),
        reason: 'a value the slip could not carry whole must SAY so');
    expect(out.length, lessThanOrEqualTo(23));
    expect(out, startsWith('Chrome Ore 42% Cr2O3'));

    // Anything that fits is untouched — no stray ellipsis on a normal slip.
    expect(WaybillPdfBuilder.debugFitText('Chrome Ore', 11, 13), 'Chrome Ore');
    expect(WaybillPdfBuilder.debugFitText('', 11, 13), '');
  });
}
