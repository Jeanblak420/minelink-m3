import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';

/// A single outbound load row backing the Tons-out detail table.
///
/// Field names mirror the weighbridge/dispatch sheet columns: date, time,
/// transporter, truck registration, destination, product, customer, net mass —
/// plus the waybill number, source, delivered tons and variance the recon
/// tables carry, so the two views of the same load agree.
///
/// **Built from real recon rows.** Until 2026-08-17 this model was fed by
/// `tonsOutEntriesFromWaybills`, which had zero callers anywhere in the tree,
/// so the screen it backs could only ever be constructed with an empty list —
/// it was a table with no way to reach data. Jean's ruling that day was that
/// all of this is supposed to be linked to real data, so [fromReconRow] maps it
/// from the same `list_raw_recon_rows` output the recon tables read.
class TonsOutEntry {
  final DateTime date;
  final String time; // HH:mm as captured at the gate
  final String transporter;
  final String truckReg;
  final String destination;
  final String product;
  final String customer;
  final double netMass; // tons

  /// The shared transaction reference (`TRP-…`) — the same value the waybill
  /// prints as its NUMBER and the recon table shows in WAYBILL NUMBER.
  final String? waybillNumber;

  /// The mine the load came from.
  final String? source;

  /// Re-weighed at the destination. Null until the driver files a POD.
  final double? deliveredTons;

  /// `netMass - deliveredTons`, as Postgres generated it. Positive means mass
  /// that left the mine and did not arrive; null means the two weights are not
  /// comparable, which is not a measured zero.
  final double? varianceTons;

  /// Object path of the driver's POD photo, when one was uploaded.
  final String? podPhotoPath;

  final String? tripId;

  const TonsOutEntry({
    required this.date,
    required this.time,
    required this.transporter,
    required this.truckReg,
    required this.destination,
    required this.product,
    required this.customer,
    required this.netMass,
    this.waybillNumber,
    this.source,
    this.deliveredTons,
    this.varianceTons,
    this.podPhotoPath,
    this.tripId,
  });

  /// One real load, from the row the recon tables already read.
  ///
  /// The date follows `timeOut ?? tripDate` — the same basis
  /// `RawReconView`'s period cards use, so the two screens cannot disagree
  /// about which day a load fell on. (They did once, which is what
  /// `230991f` fixed.)
  factory TonsOutEntry.fromReconRow(RawReconRow r) {
    final when = r.timeOut ?? r.tripDate;
    final at = r.timeOut ?? r.timeIn;
    return TonsOutEntry(
      date: DateTime(when.year, when.month, when.day),
      // `calendarClock`, not hand-rolled padding: `at` is already a South
      // African wall clock (see the note above), so it is FORMATTED, never
      // converted — and it now says so in the product's one vocabulary.
      time: at == null ? '—' : MlTime.calendarClock(at),
      transporter: r.transporterName ?? '—',
      truckReg: r.truckReg ?? '—',
      destination: r.destination ?? '—',
      product: r.product ?? '—',
      customer: r.customerName ?? '—',
      netMass: r.netMass ?? 0,
      waybillNumber: r.waybillNumber,
      source: r.sourceName,
      deliveredTons: r.deliveredTons,
      varianceTons: r.varianceTons,
      podPhotoPath: r.podPhotoPath,
      tripId: r.tripId,
    );
  }
}
