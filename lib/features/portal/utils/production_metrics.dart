/// Mined-versus-dispatched arithmetic for the mine's Production screen.
///
/// ## Why this is a type and not two local expressions
///
/// Yield and pit-to-port loss are the same measurement read two ways, and they
/// are only meaningful when the pit actually recorded production in the window.
/// The screen computed them separately and only ONE of them knew that:
///
///     final loss = mined - dispatched;
///     final yieldPct = mined > 0 ? (dispatched / mined * 100) : null;
///
/// So on the live Iron Hills production screen, 2026-08-22, a 30-day window
/// with no production recorded read:
///
///     0.00 t Mined · 771.32 t Dispatched · — Yield · -771.32 t Pit-to-port loss
///
/// Yield correctly declined to answer. The loss tile, from the same zero,
/// reported **minus seven hundred and seventy-one tons** — which read plainly
/// says the mine gained 771 t it never mined. And its tone is
/// `loss > 0 ? warn : done`, so the figure was painted GREEN: a meaningless
/// number presented as a good result, on the screen a mine manager would use
/// to judge whether product is going missing between the pit and the port.
///
/// Nothing was wrong with the data. `production_entries` is simply empty —
/// nobody has recorded a day's production — and "we have not been told what
/// was mined" is not the same fact as "nothing was mined", let alone
/// "everything arrived safely".
///
/// Both figures now come from here, so they cannot disagree again about
/// whether there is an answer to give.
class ProductionYield {
  const ProductionYield({
    required this.minedTons,
    required this.dispatchedTons,
  });

  final double minedTons;
  final double dispatchedTons;

  /// True when the pit recorded nothing in this window, so neither derived
  /// figure has a denominator. The single condition both tiles read.
  bool get isUnmeasured => minedTons <= 0;

  /// Dispatched as a percentage of mined. Null when [isUnmeasured].
  double? get yieldPercent =>
      isUnmeasured ? null : (dispatchedTons / minedTons * 100);

  /// Tonnage mined that did not leave the weighbridge. Null when
  /// [isUnmeasured] — a difference against an unknown is not a loss.
  double? get lossTons => isUnmeasured ? null : (minedTons - dispatchedTons);
}
