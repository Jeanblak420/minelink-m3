import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';

import 'charts.dart';
import 'overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'primitives.dart';

/// Left card of the top row. Fixed 320px wide on desktop (`flex: 0 1 320px`) —
/// if it grows past that on a wide window, `grow: false` was lost.
///
/// The row runs it to the height of the tons-moved card beside it
/// (`OvFlexRow(equalHeight: true)`), so on a desktop width it is handed more
/// height than its content needs. The slack goes to the donut: it is the thing
/// on this card worth looking at, and it ends up optically centred with the
/// legend holding the bottom edge. Pinning the content to the top would leave
/// a dead band under the last legend row and read as an unfinished card.
class OvFleetDistributionCard extends StatelessWidget {
  const OvFleetDistributionCard({
    super.key,
    required this.tokens,
    required this.data,
  });

  final MlOv tokens;
  final FleetDistribution data;

  static const EdgeInsets _padding = EdgeInsets.all(24);

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    // Outside the card, where the row's constraints are still intact — the
    // glass card loosens them for its content, so a LayoutBuilder in there
    // would see no floor at all.
    return LayoutBuilder(
      builder: (context, c) {
        // `OvFlexRow(equalHeight: true)` gives the short card of the row a
        // minimum height, the tall card's. Nothing else on this screen sets
        // one, so a floor here means "you are the short card". Stacked, there
        // is no floor and the card keeps its natural size.
        final floor = c.minHeight;
        return OvGlassCard(
          tokens: t,
          padding: _padding,
          child: floor > 0
              ? SizedBox(
                  height: (floor - _padding.vertical).clamp(0.0, floor),
                  child: _content(t, fill: true),
                )
              : _content(t, fill: false),
        );
      },
    );
  }

  Widget _content(MlOv t, {required bool fill}) {
    final donut = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: OvFleetDonut(
        tokens: t,
        slices: data.slices,
        centreValue: data.utilisedPercent,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      children: [
        OvCardHeader(
          tokens: t,
          label: 'Fleet distribution',
          trailing: OvPill(
            tokens: t,
            label: data.totalLabel,
            tone: OvTone.accent,
          ),
        ),
        if (fill)
          // scaleDown rather than a plain Center: if a long legend ever leaves
          // less room than the donut's 160px, the donut shrinks to fit instead
          // of overflowing the height it was matched to.
          Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: donut))
        else
          Center(child: donut),
        if (data.slices.isEmpty)
          Text(
            'No fleet on file for any transporter',
            style: t.s(size: 12, color: t.inkMid),
          )
        else
          for (var i = 0; i < data.slices.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _LegendRow(tokens: t, slice: data.slices[i]),
          ],
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.tokens, required this.slice});

  final MlOv tokens;
  final FleetSlice slice;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: t.tone(slice.tone),
            borderRadius: MlShape.radiusExtraSmall,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slice.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.s(size: 12, color: t.ink),
          ),
        ),
        const SizedBox(width: 10),
        Text('${slice.count}', style: t.m(size: 12)),
      ],
    );
  }
}
