import 'package:flutter/material.dart';

/// Two form fields side by side when each gets room for its label, stacked
/// when not.
///
/// Found on Jean's S25 (411dp, system font 1.3) on 2026-10-26: dialogs that
/// put two `TextField`s in a `Row` cut both labels in half — "Commod…" and
/// "Pit / secti…" on Record production, "Target Cr…" and "Max mois…" on the
/// contract spec. A phone dialog is ~260px wide, so each half got ~125px.
///
/// The rule scales with the reader's text size, because that is what the
/// label's width does: a pair that fits at 1.0 on a laptop must not be the
/// reason it is cut at 1.3 on a phone.
///
/// It decides from the SCREEN width, not a `LayoutBuilder`. These pairs live
/// in `AlertDialog`s, which size their content by intrinsic width, and a
/// LayoutBuilder cannot answer that question — the first version of this
/// widget threw "LayoutBuilder does not support returning intrinsic
/// dimensions" in the contract-spec dialog (caught by its render).
class MlFieldPair extends StatelessWidget {
  const MlFieldPair({
    super.key,
    required this.first,
    required this.second,
    this.gap = 10,
    this.minFieldWidth = 180,
  });

  final Widget first;
  final Widget second;
  final double gap;

  /// The narrowest a field may be, at text scale 1.0, before the pair stacks.
  final double minFieldWidth;

  /// What a form gets of the screen once a dialog's insets (40 each side)
  /// and its content padding (24 each side) are taken off.
  static const double _dialogChrome = 128;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final room = MediaQuery.sizeOf(context).width - _dialogChrome;
    final half = (room - gap) / 2;
    if (half >= scaler.scale(minFieldWidth)) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          SizedBox(width: gap),
          Expanded(child: second),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [first, SizedBox(height: gap + 2), second],
    );
  }
}
