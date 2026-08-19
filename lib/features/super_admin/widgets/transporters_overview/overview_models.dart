// ============================================================================
// Transporters overview — view-models
// ----------------------------------------------------------------------------
// Ported from the 2026-08-09 drop. Numbers arrive **pre-formatted**: the drop's
// rule is that grouping and decimal places are decided once, in the mapper, so
// the widgets can never drift from the design's formatting. See its README §8.
//
// Two changes were made on the way in, both for the same reason — this console
// renders live data, and the drop was a static mock:
//
//  • Anything the platform may genuinely not have is nullable. A missing figure
//    renders as nothing or an em dash; it never falls back to a plausible
//    number. That rule is why the previous cut of this screen exists at all —
//    see the `Target 28.0k` note in CLAUDE.md §4.
//  • Colours are carried as [OvTone], not `Color`, so a view-model survives the
//    console's light/dark toggle.
// ============================================================================

import 'package:flutter/widgets.dart';

import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';

/// A small tinted label — "Top volume", "▲ 16.2%", "9 total".
@immutable
class OvBadge {
  const OvBadge(this.label, this.tone);

  final String label;
  final OvTone tone;
}

// ---------------------------------------------------------------------------
// Fleet distribution
// ---------------------------------------------------------------------------

@immutable
class FleetSlice {
  const FleetSlice({
    required this.label,
    required this.count,
    required this.tone,
  });

  final String label;
  final int count;
  final OvTone tone;
}

@immutable
class FleetDistribution {
  const FleetDistribution({
    required this.slices,
    required this.totalLabel,
    required this.utilisedPercent,
  });

  final List<FleetSlice> slices;

  /// e.g. "9 total".
  final String totalLabel;

  /// Rendered as "33%" in the donut centre.
  final int utilisedPercent;

  int get total => slices.fold(0, (a, b) => a + b.count);
}

// ---------------------------------------------------------------------------
// Tons moved this period
// ---------------------------------------------------------------------------

/// One of the three icon-well metrics under the flagship chart.
@immutable
class MiniMetric {
  const MiniMetric({
    required this.icon,
    required this.tone,
    required this.label,
    required this.value,
    this.unit,
    this.trailing,
    this.trailingTone,
  });

  final IconData icon;
  final OvTone tone;
  final String label;

  /// Already formatted, or an em dash when the platform has no figure.
  final String value;
  final String? unit;
  final String? trailing;
  final OvTone? trailingTone;
}

/// One cell of the four-up footer under the flagship.
@immutable
class OvStatCell {
  const OvStatCell({
    required this.label,
    required this.value,
    this.suffix,
    this.tone = OvTone.ink,
  });

  final String label;
  final String value;
  final String? suffix;
  final OvTone tone;
}

@immutable
class TonsMoved {
  const TonsMoved({
    required this.value,
    required this.valueSuffix,
    required this.contextLine,
    required this.series,
    required this.compareSeries,
    required this.markerIndexes,
    required this.axisLabels,
    required this.metrics,
    required this.footer,
    required this.legend,
    this.delta,
    this.deltaLine,
    this.deltaLineTone = OvTone.good,
    this.targetY,
    this.targetLabel,
    this.calloutLabel,
  });

  /// "29,240" — the whole part of the headline.
  final String value;

  /// ".5 t" — the smaller tail.
  final String valueSuffix;

  /// ["Combined organizations", "Aug 2026 · MTD"].
  final List<String> contextLine;

  /// "▲ 16.2%". Null when there is no prior period to compare against; the
  /// pill then does not render, rather than rendering a zero.
  final OvBadge? delta;

  /// "▲ 4,076 t vs. Jul". Null under the same condition.
  final String? deltaLine;
  final OvTone deltaLineTone;

  /// Normalised y in 0..1, where 0 is the top of the plot box (SVG
  /// orientation). Both series share one scale so they can be read together.
  final List<double> series;
  final List<double> compareSeries;

  /// Normalised y of the dashed target rule, and its caption.
  ///
  /// Null means NO TARGET SET, and nothing at all is drawn — no rule, no
  /// caption, no legend key. This is the whole point of the 2026-08-08 fix:
  /// a target nobody chose must not render like one somebody did.
  final double? targetY;
  final String? targetLabel;

  /// Indexes of [series] that get a dot; the last one gets the glow.
  final List<int> markerIndexes;

  /// Bottom axis ticks as (normalised x 0..1, label).
  final List<MapEntry<double, String>> axisLabels;

  /// The chip pinned top-right of the plot. Null hides it.
  final String? calloutLabel;

  /// Exactly three, in the drop's order: peak day · avg per day · third slot.
  final List<MiniMetric> metrics;

  /// Exactly four, top-bordered.
  final List<OvStatCell> footer;

  /// Chart key. Built by the mapper so it can omit the target entry when there
  /// is no target line to explain.
  final List<OvLegendKey> legend;
}

@immutable
class OvLegendKey {
  const OvLegendKey({
    required this.label,
    required this.tone,
    required this.dashed,
    this.muted = false,
  });

  final String label;
  final OvTone tone;
  final bool dashed;

  /// Draws the key in ink rather than the tone — used for the prior period.
  final bool muted;
}

// ---------------------------------------------------------------------------
// Transporter card
// ---------------------------------------------------------------------------

/// One of the two thin meters on the right of a transporter card.
@immutable
class OvMeterSpec {
  const OvMeterSpec(this.label, this.percent);

  final String label;
  final int percent;
}

@immutable
class TransporterRow {
  const TransporterRow({
    required this.id,
    required this.code,
    required this.name,
    required this.badges,
    required this.employees,
    required this.drivers,
    required this.fleet,
    required this.routes,
    required this.lastActive,
    required this.tempo,
    required this.trips,
    required this.tons,
    required this.tonsValue,
    required this.waybillsDone,
    required this.waybillsOpen,
    required this.meters,
  });

  /// Company id. Empty means the card offers no workspace link rather than a
  /// button that goes nowhere.
  final String id;

  /// "RH" — the avatar initials.
  final String code;
  final String name;
  final List<OvBadge> badges;

  final int employees;
  final int drivers;
  final int fleet;
  final int routes;

  /// "3m ago" / "never".
  final String lastActive;

  /// 15 raw daily values; the bars normalise themselves.
  final List<double> tempo;

  final String trips;

  /// Formatted, e.g. "12,420.5".
  final String tons;

  /// The same tonnage as a number, so filtering never parses a formatted
  /// string back into one.
  final double tonsValue;

  final String waybillsDone;
  final int waybillsOpen;

  final List<OvMeterSpec> meters;

  /// The drop's open-waybill colour ladder.
  OvTone get openTone => waybillsOpen >= 6
      ? OvTone.bad
      : waybillsOpen >= 4
          ? OvTone.warn
          : OvTone.ink;
}

/// The chips above the transporter list. In the drop these were decoration
/// that changed nothing; they filter for real.
enum OvTransporterFilter {
  all('All'),
  active('Active'),
  highThroughput('High throughput'),
  attention('Attention');

  const OvTransporterFilter(this.label);

  final String label;

  /// [avgTons] is the mean across the unfiltered set, so "high throughput"
  /// means "above average for this month" rather than an arbitrary cut-off.
  bool accepts(TransporterRow c, double avgTons) {
    switch (this) {
      case OvTransporterFilter.all:
        return true;
      case OvTransporterFilter.active:
        return c.tonsValue > 0 || c.trips != '0';
      case OvTransporterFilter.highThroughput:
        return avgTons > 0 && c.tonsValue >= avgTons;
      case OvTransporterFilter.attention:
        return c.waybillsOpen > 0 ||
            c.trips == '0' ||
            (c.meters.isNotEmpty && c.meters.first.percent == 0);
    }
  }
}

// ---------------------------------------------------------------------------
// Aside
// ---------------------------------------------------------------------------

@immutable
class TrendStat {
  const TrendStat({
    required this.value,
    required this.label,
    this.unit,
    this.tone = OvTone.ink,
  });

  final String value;
  final String? unit;
  final String label;
  final OvTone tone;
}

@immutable
class MonthlyTrend {
  const MonthlyTrend({
    required this.caption,
    required this.series,
    required this.stats,
    this.headline,
    this.captionTone = OvTone.good,
  });

  /// "+18%". Null when there is no prior month; renders as an em dash.
  final String? headline;
  final String caption;
  final OvTone captionTone;

  /// Normalised y (0 top, 1 bottom).
  final List<double> series;

  /// Rendered two-up, so an even count reads best.
  final List<TrendStat> stats;
}

@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.tons,
    required this.share,
    required this.barFraction,
    this.muted = false,
  });

  /// Kept as a string so the design's leading zeros survive ("04").
  final String rank;
  final String name;

  /// "12,460.8 t".
  final String tons;

  /// "43.2%".
  final String share;

  /// Bar width **relative to the leader** (leader = 1.0), not the share.
  final double barFraction;

  /// The zero state: muted text, empty track, no fill.
  final bool muted;
}

@immutable
class Leaderboard {
  const Leaderboard({required this.totalLabel, required this.entries});

  final String totalLabel;
  final List<LeaderboardEntry> entries;
}

@immutable
class AlertItem {
  const AlertItem({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.age,
  });

  final IconData icon;
  final OvTone tone;
  final String title;
  final String body;

  /// "12m", "this month".
  final String age;
}

// ---------------------------------------------------------------------------

@immutable
class OverviewData {
  const OverviewData({
    required this.fleet,
    required this.tons,
    required this.transporters,
    required this.trend,
    required this.leaderboard,
    required this.alerts,
    required this.topTransportersSubtitle,
  });

  final FleetDistribution fleet;
  final TonsMoved tons;
  final List<TransporterRow> transporters;
  final MonthlyTrend trend;
  final Leaderboard leaderboard;
  final List<AlertItem> alerts;
  final String topTransportersSubtitle;
}
