import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Pure data-mapping helpers for the premium Mine/Supplier overview screen.
///
/// These are deliberately UI-free so they can be unit tested without a widget
/// tree. Tons-out figures sum each transaction's real weighbridge Net Mass
/// ([OperationTransaction.netTonsOut], from `trips.net_tons`), NOT the ordered
/// `quantity` — matching the recon table and the server-side super-admin
/// dashboard (migration 20260714000000_dashboard_tons_from_net_mass.sql).

/// How full the mine's ORDER piles are, and how much tonnage that ratio
/// cannot speak for.
///
/// ## Why a type rather than three local sums
///
/// The mine overview shows a headline "Stockpile balance" over a caption
/// giving cover against ordered caps. Those are two different sets, because a
/// pile with no `max_cap_tons` cannot appear in a ratio — and on 2026-08-22 the
/// live screen read **210.3 t** with **"150.3 of 1240 t ordered · 12%"**
/// directly underneath. Both were correct. The 60.0 t between them was one real
/// pile ("C Grade Blue Coal - Atlas Buyer", cap null) that the caption silently
/// dropped from both sides of its fraction.
///
/// Scoping both sides of the ratio to capped piles is right, and was itself a
/// fix: counting every pile in the numerator against a capped denominator once
/// reported a mine at "300% of ordered cap". What was missing is that the
/// exclusion has to be VISIBLE, because the reader is looking at the excluded
/// tonnage in the number immediately above.
///
/// So this returns all three figures together and the caller states the
/// uncapped remainder whenever there is one. The arithmetic then closes on
/// screen: 150.3 + 60 = 210.3, which is the headline.
///
/// The note the previous fix left — "invisible in production TODAY because no
/// live pile has a cap" — expired. Seven of Iron Hills' nine piles carry caps
/// now, exactly as predicted for the first dispatch.
class StockpileCover {
  const StockpileCover({
    required this.totalTons,
    required this.cappedTons,
    required this.capacityTons,
  });

  /// Every pile on the ground. The honest headline.
  final double totalTons;

  /// Only the piles that have a cap — the numerator of the ratio.
  final double cappedTons;

  /// Sum of the caps. Null when no pile has one, so there is no ratio at all.
  final double? capacityTons;

  /// Tonnage that is real, is in [totalTons], and CANNOT be in the ratio.
  /// Zero is the ordinary case; anything else has to be said out loud.
  double get uncappedTons => totalTons - cappedTons;

  bool get hasRatio => capacityTons != null && capacityTons! > 0;

  /// Percent full, rounded. Only meaningful when [hasRatio].
  int get percent => hasRatio ? (cappedTons / capacityTons! * 100).round() : 0;

  /// The caption that sits under the "Stockpile balance" figure.
  ///
  /// Lives here, next to the arithmetic, rather than in the screen, because
  /// the whole fault was a caption that could not be checked against the
  /// number above it. A string built beside the figures it describes can be
  /// tested against them; one built inline in a `sublabel:` cannot.
  ///
  /// [tons] is the screen's own formatter, passed in so the caption reads in
  /// exactly the same units as the headline it has to reconcile with.
  String caption(String Function(double) tons) {
    if (!hasRatio) return 'No capped order piles';
    final base =
        '${tons(cappedTons)} of ${tons(capacityTons!)} t '
        'ordered \u00b7 $percent%';
    // Below a rounding crumb there is nothing worth saying, and "0 t uncapped"
    // would be noise on the ordinary case.
    if (uncappedTons <= 0.05) return base;
    return '$base \u00b7 ${tons(uncappedTons)} t uncapped';
  }

  static StockpileCover of(List<StockpileEntry> piles) {
    final capped = piles.where((p) => p.maxCapTons != null);
    return StockpileCover(
      totalTons: piles.fold<double>(0, (a, p) => a + p.tons),
      cappedTons: capped.fold<double>(0, (a, p) => a + p.tons),
      capacityTons: capped.isEmpty
          ? null
          : capped.fold<double>(0, (a, p) => a + p.maxCapTons!),
    );
  }
}

/// Tons shipped over rolling time windows (overlapping: yearly includes
/// monthly includes weekly includes daily), plus the all-time total.
class TonsOutWindows {
  final double daily;
  final double weekly;
  final double monthly;
  final double yearly;
  final double total;

  const TonsOutWindows({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
    required this.total,
  });

  static const zero = TonsOutWindows(
    daily: 0,
    weekly: 0,
    monthly: 0,
    yearly: 0,
    total: 0,
  );
}

/// One calendar day's outbound tonnage (for the "Tons out — last 7 days" bars).
class DayTons {
  final DateTime day;
  final double tons;

  const DayTons({required this.day, required this.tons});
}

/// A single buyer's outbound tonnage, with a resolved display name.
class BuyerTons {
  final String companyId;
  final String name;
  final double tons;

  const BuyerTons({
    required this.companyId,
    required this.name,
    required this.tons,
  });
}

abstract final class MineSupplierOverviewMetrics {
  /// Sums waybill quantities into rolling windows relative to [now].
  static TonsOutWindows tonsOut(
    List<OperationTransaction> waybills, {
    required DateTime now,
  }) {
    final dayAgo = now.subtract(const Duration(days: 1));
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    final yearAgo = now.subtract(const Duration(days: 365));

    double daily = 0, weekly = 0, monthly = 0, yearly = 0, total = 0;
    for (final w in waybills) {
      final q = w.netTonsOut;
      // The pit clock. This was the RAW instant while `tonsPerDay` a few
      // lines down used `.toLocal()` — the same waybills bucketed two
      // different ways inside one class.
      final at = MlTime.sast(w.updatedAt);
      total += q;
      if (at.isAfter(yearAgo)) yearly += q;
      if (at.isAfter(monthAgo)) monthly += q;
      if (at.isAfter(weekAgo)) weekly += q;
      if (at.isAfter(dayAgo)) daily += q;
    }
    return TonsOutWindows(
      daily: daily,
      weekly: weekly,
      monthly: monthly,
      yearly: yearly,
      total: total,
    );
  }

  /// Sums waybill quantities per calendar day for the trailing [days] window
  /// ending on [now]'s day, oldest first (drives the 7-day bar chart).
  static List<DayTons> tonsPerDay(
    List<OperationTransaction> waybills, {
    required DateTime now,
    int days = 7,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final totals = List<double>.filled(days, 0);
    for (final w in waybills) {
      final at = MlTime.sast(w.updatedAt);
      final day = DateTime(at.year, at.month, at.day);
      final offset = today.difference(day).inDays;
      if (offset >= 0 && offset < days) {
        totals[days - 1 - offset] += w.netTonsOut;
      }
    }
    return [
      for (var i = 0; i < days; i++)
        DayTons(
          day: today.subtract(Duration(days: days - 1 - i)),
          tons: totals[i],
        ),
    ];
  }

  /// Groups outbound tonnage by buyer company, resolves names from
  /// [nameById], and returns the list sorted by tonnage descending.
  static List<BuyerTons> buyerTonnage(
    List<OperationTransaction> waybills, {
    required Map<String, String> nameById,
  }) {
    final totals = <String, double>{};
    for (final w in waybills) {
      final id = w.buyerCompanyId;
      if (id == null || id.isEmpty) continue;
      totals[id] = (totals[id] ?? 0) + w.netTonsOut;
    }
    final result =
        totals.entries
            .map(
              (e) => BuyerTons(
                companyId: e.key,
                name: nameById[e.key] ?? _shortId(e.key),
                tons: e.value,
              ),
            )
            .toList()
          ..sort((a, b) => b.tons.compareTo(a.tons));
    return result;
  }

  /// Buyers that have at least one stockpile allocated to them, shown with
  /// their REAL delivered tonnage (summed from waybill Net Weight), sorted
  /// descending.
  ///
  /// This gates the per-buyer cards on the overview: a buyer only surfaces once
  /// a stockpile has been allocated to it. [StockpileEntry.buyer] is the
  /// allocation; entries with no buyer are ignored. The tonnage shown is the
  /// delivered tons-out taken from [waybills] — matched to the allocation by
  /// buyer company id — not the allocated stockpile estimate, so the dashboard
  /// reflects real deliveries (0 t until a load has been delivered for a buyer).
  static List<BuyerTons> allocatedBuyers(
    List<StockpileEntry> stockpiles, {
    required List<OperationTransaction> waybills,
  }) {
    final deliveredByCompany = <String, double>{};
    for (final w in waybills) {
      final id = w.buyerCompanyId;
      if (id == null || id.isEmpty) continue;
      deliveredByCompany[id] = (deliveredByCompany[id] ?? 0) + w.netTonsOut;
    }

    // One row per allocated buyer, deduped by display name; delivered tons are
    // resolved by the stockpile's buyer company id when known.
    final rows = <String, BuyerTons>{};
    for (final s in stockpiles) {
      final name = s.buyer;
      if (name == null || name.isEmpty) continue;
      final companyId = s.buyerCompanyId;
      rows[name] = BuyerTons(
        companyId: companyId ?? name,
        name: name,
        tons: companyId == null ? 0 : (deliveredByCompany[companyId] ?? 0),
      );
    }
    return rows.values.toList()..sort((a, b) => b.tons.compareTo(a.tons));
  }

  /// Convenience: build an id -> name map from partner company pins.
  static Map<String, String> namesFromPins(List<CompanyPin> pins) {
    return {for (final p in pins) p.id: p.name};
  }

  /// Trips that represent trucks currently inbound / on the move.
  static int incomingTrucks(List<TripRecord> trips) {
    const active = {'in_transit', 'loading', 'en_route', 'inbound', 'active'};
    return trips.where((t) => active.contains(t.status)).length;
  }

  /// Trips whose latest update falls on [now]'s calendar day.
  static int scheduledToday(List<TripRecord> trips, {required DateTime now}) {
    return trips.where((t) {
      final d = MlTime.sast(t.updatedAt);
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).length;
  }

  /// A placeholder for a buyer whose company row this party cannot read.
  ///
  /// ALWAYS prefixed, and it did not used to be: `id.length <= 8` returned the
  /// raw id, so a short company id rendered as a company NAME. Photographed
  /// 2026-08-21 on the mine's Buyers page, where two cards were headed
  /// `co-buyer` and `Buyer co-buy` — one a database key printed as a name, the
  /// other a key with a word glued to the front of it. A name we do not have
  /// must look like a name we do not have.
  static String _shortId(String id) =>
      'Buyer ${id.substring(0, id.length < 6 ? id.length : 6)}';
}
