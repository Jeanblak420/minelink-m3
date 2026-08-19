import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// How seriously to read a trip's weight variance (P3-13).
///
/// One definition, used by the Side A raw recon table and the Side B
/// reconciliation view alike. Two screens showing the same load in different
/// colours is worse than either colour being wrong, because it teaches the
/// reader that the colour means nothing.
///
/// **Severity is a percentage of the load, not a tonnage.** 0.5 t missing off a
/// 4 t load and off a 40 t load are not the same event, and a flat threshold
/// cannot tell them apart. Side B previously used a flat `0.05 t`, which on the
/// live data flagged **every one of the 35 reconciled loads as an error** — all
/// of them are short by ≤ 0.20 t on ~35 t, i.e. about 0.57%, which is ordinary
/// weighbridge scatter. A signal that fires on everything is not a signal.
///
/// ⚠ A *systematic* small shortfall across every load — which is exactly what
/// the live data shows — is itself worth knowing about, but it is an aggregate
/// finding, not a per-load one. Colouring each row red does not surface it; it
/// buries it. That belongs on the recon totals, not here.
enum VarianceSeverity {
  /// One of the two weights is missing, so there is nothing to compare. Not a
  /// measured zero, and never rendered as one.
  notComparable,

  /// Within scale tolerance.
  balanced,

  /// 1–3% of the load. Worth a look, not yet an incident.
  watch,

  /// Over 3% of the load: the lost / stolen / swapped-mass signal the whole
  /// reconciliation layer exists to produce.
  material,
}

/// Absolute floor, in tons, below which a difference is scale rounding
/// regardless of load size — it stops a tiny load turning a 20 kg rounding
/// difference into a percentage that looks alarming.
const double kVarianceScaleFloorTons = 0.05;

/// Percentage of the load above which a shortfall is a warning.
const double kVarianceWatchPct = 1.0;

/// Percentage of the load above which a shortfall is material.
const double kVarianceMaterialPct = 3.0;

/// Classify a variance against the load it came off.
///
/// [varianceTons] is `net_tons - delivered_tons` (positive = mass that did not
/// arrive); [netTons] is the mine's authoritative weighbridge mass.
///
/// An **over**-delivery (negative variance) is graded on the same scale by
/// magnitude: it is also a pair of weights that do not reconcile, and reading
/// it as "fine" is how a swapped load hides.
VarianceSeverity varianceSeverityOf({
  required double? varianceTons,
  required double? netTons,
}) {
  if (varianceTons == null || netTons == null || netTons <= 0) {
    return VarianceSeverity.notComparable;
  }
  final magnitude = varianceTons.abs();
  if (magnitude <= kVarianceScaleFloorTons) return VarianceSeverity.balanced;
  final pct = (magnitude / netTons) * 100;
  if (pct > kVarianceMaterialPct) return VarianceSeverity.material;
  if (pct > kVarianceWatchPct) return VarianceSeverity.watch;
  return VarianceSeverity.balanced;
}

/// The tone a severity renders in. `notComparable` is neutral, never green —
/// "we could not check" must not look like "it checked out".
MlTone varianceTone(VarianceSeverity severity) => switch (severity) {
      VarianceSeverity.notComparable => MlTone.neutral,
      VarianceSeverity.balanced => MlTone.done,
      VarianceSeverity.watch => MlTone.warn,
      VarianceSeverity.material => MlTone.error,
    };
