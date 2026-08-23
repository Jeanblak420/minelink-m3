// ============================================================================
// Full-screen leaderboard — view-models
// ----------------------------------------------------------------------------
// Ported from the drop's `models/leaderboard_models.dart`, with the same rule
// the overview models follow: numbers arrive as PRE-FORMATTED STRINGS and
// colours arrive as [OvTone], never as `Color`. Formatting lives in the mapper
// so the table cannot re-round a figure and drift from the rest of the console;
// tones survive the console's light/dark toggle, a baked-in `Color(0x…)` does
// not. That is the one deviation from the drop, which is dark-only and stores
// `Color`s directly.
// ============================================================================

import 'package:flutter/foundation.dart';

import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';

/// One of the four tiles above the podium.
@immutable
class OvBoardKpi {
  const OvBoardKpi({
    required this.label,
    required this.value,
    this.unit,
    this.tone,
  });

  final String label;

  /// Pre-formatted, e.g. "28,840.8" or "3".
  final String value;

  /// Small trailing span, e.g. " t" or " of 5".
  final String? unit;

  /// Null renders in `inkHi`. Exactly one tile in the design is tinted.
  final OvTone? tone;
}

/// One of the three podium cards. Rank 1 gets the accent treatment.
@immutable
class OvPodiumEntry {
  const OvPodiumEntry({
    required this.rank,
    required this.name,
    required this.tons,
    required this.shareLabel,
    required this.barFraction,
    this.metaSuffix,
    this.delta,
    this.deltaTone = OvTone.good,
  });

  final int rank;
  final String name;

  /// "12,460.8" — the unit is rendered separately.
  final String tons;

  /// "43.2% of network"; rank 1 appends [metaSuffix] ("· 18 trips").
  final String shareLabel;
  final String? metaSuffix;

  /// Relative to the leader (leader = 1.0), NOT the share percentage —
  /// using the share here is the drop's listed way to make every bar short.
  final double barFraction;

  /// "▲ 12.4%" / "▼ 2.8%" / "unchanged". Null when there is no prior period
  /// to compare against, which renders as nothing rather than as "0.0%".
  final String? delta;

  /// The delta's tone — the same one the ranking rows carry. This was a
  /// `deltaUp` boolean, which could only say green or red: a true zero
  /// painted "▲ 0.0%" in green, and a fall was red where the reference
  /// reserves red for a fault (§4: "negative deltas are amber, not red").
  /// Phase 3 pass, 2026-08-23.
  final OvTone deltaTone;
}

/// One row of the full ranking table.
@immutable
class OvRankRow {
  const OvRankRow({
    required this.rank,
    required this.name,
    required this.meta,
    required this.shareLabel,
    required this.barFraction,
    required this.tons,
    required this.trips,
    required this.avgPerTrip,
    required this.onTime,
    required this.onTimeTone,
    required this.waybillsOpen,
    required this.waybillsOpenTone,
    required this.delta,
    required this.deltaTone,
    this.inactive = false,
  });

  final int rank;
  final String name;

  /// "42 fleet · 9 routes" / "1 fleet · no active route"
  final String meta;

  /// "43.2%"
  final String shareLabel;

  /// Relative to the leader (leader = 1.0); 0 renders an empty track.
  final double barFraction;

  final String tons;
  final String trips;

  /// "692.3", or an em dash when no trip ran.
  final String avgPerTrip;

  /// "96%", or an em dash when NOTHING WAS JUDGEABLE — no agreed transit time
  /// on the route, or no trip that both left the mine and offloaded. A dash is
  /// not the same statement as "0%", and this column must never make it.
  final String onTime;
  final OvTone onTimeTone;

  final String waybillsOpen;
  final OvTone waybillsOpenTone;

  /// "▲ 12.4%", or an em dash with no prior period to compare against.
  final String delta;
  final OvTone deltaTone;

  /// Zero-state row: muted text, empty share track.
  final bool inactive;
}

/// Everything the full-screen board renders.
@immutable
class OvLeaderboardBoard {
  const OvLeaderboardBoard({
    required this.eyebrow,
    required this.titleLead,
    required this.titleAccent,
    required this.subtitle,
    required this.periods,
    required this.activePeriod,
    required this.kpis,
    required this.podium,
    required this.tableTitle,
    required this.tableSubtitle,
    required this.countLabel,
    required this.rows,
    required this.deltaColumnLabel,
    required this.footnote,
  });

  final String eyebrow;
  final String titleLead;

  /// Rendered italic in the accent colour.
  final String titleAccent;

  final String subtitle;

  /// Chip labels for the period control, in order.
  final List<String> periods;
  final int activePeriod;

  /// Four in the design; the widget lays out however many it is given.
  final List<OvBoardKpi> kpis;

  /// Up to three, in rank order. The widget reorders them to 2 · 1 · 3.
  final List<OvPodiumEntry> podium;

  final String tableTitle;
  final String tableSubtitle;
  final String countLabel;
  final List<OvRankRow> rows;

  /// Header of the delta column — "VS. JUL", "VS. Q2", "VS. 2025". The drop
  /// hardcoded "VS. JUL"; it has to follow the selected period or the column
  /// names a comparison it is not making.
  final String deltaColumnLabel;

  /// States what the share is measured against and how tied rows are ordered.
  /// It is a claim about the data, so the mapper writes it from the same
  /// figures the table shows rather than carrying a fixed sentence.
  final String footnote;
}
