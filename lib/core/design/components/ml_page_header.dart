import 'package:flutter/material.dart';

export 'package:flutter_application_1/core/design/components/ml_meta.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';


/// The title block every portal screen opens with.
///
/// All 36 portal screens hand-rolled this:
///
/// ```dart
/// Text(title, style: Theme.of(context).textTheme.headlineSmall
///     ?.copyWith(fontWeight: FontWeight.w800)),
/// const SizedBox(height: 4),
/// Text(description, ...),
/// ```
///
/// Three things follow from copying it rather than sharing it.
///
/// 1. **It is in the wrong face.** `docs/design-reference.md` §3 puts titles in
///    Fraunces, and the console renders them that way. Thirty-six screens in
///    PlusJakartaSans ExtraBold is the portal speaking a different type
///    language from the surface the client designated as the reference.
/// 2. **There was nowhere to put a meta line.** S5-22 requires one on every
///    migrated screen, plus a `View →` / filter / export affordance where the
///    screen has one. A bare `Text` has no slot for either, so the gate could
///    not be satisfied without changing the shape.
/// 3. **A rule applied by hand 36 times holds in 34 places.** That is what
///    S5-13 and S5-17 exist to stop.
///
/// [actions] sit on the right of the title row and wrap under it when the row
/// runs out of width, which on a 360px phone at text scale 1.3 it does. They
/// are laid out in a [Wrap] rather than a `Row` deliberately — CLAUDE.md §10.4
/// records that an unflexed `Wrap` inside a `Row` is measured against
/// unbounded width and pushes the row over, so the title and the actions are
/// siblings in one `Wrap`, not a `Row` containing one.
///
/// Pinned by `test/widgets/portal_page_header_test.dart`.
class MlPageHeader extends StatelessWidget {
  const MlPageHeader({
    super.key,
    required this.title,
    this.description,
    this.meta,
    this.actions = const [],
    this.padding = const EdgeInsets.only(bottom: 18),
  });

  final String title;

  /// One calm sentence saying what the screen is for. Kept to the body face —
  /// the reference reserves the display face for titles and numerals.
  final String? description;

  /// Right-aligned context: `Last 24h · 14 loads`, `Updated 2 minutes ago`.
  /// This is the meta line S5-22 asks for.
  final String? meta;

  /// Screen-level actions — export, record, refresh.
  final List<Widget> actions;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final glass = MlGlass.of(context);

    final titleText = Text(
      title,
      style: context.mlText.editorialLarge.copyWith(
        color: semantic.textStrong,
        fontWeight: FontWeight.w400,
      ),
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (actions.isEmpty && meta == null)
            titleText
          else
            // `width: double.infinity` is load-bearing, not defensive. A Wrap
            // sizes to its content, so without it `WrapAlignment.spaceBetween`
            // has no free space to distribute and "space between" means
            // nothing — the meta renders glued to the title instead of at the
            // right edge. Measured at 516px inside a 1000px column before this
            // was added; caught by looking at the component capture.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  titleText,
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (meta != null)
                        Text(
                          meta!,
                          style: context.mlText.labelSmall.copyWith(
                            color: glass.inkLo,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ...actions,
                    ],
                  ),
                ],
              ),
            ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: context.mlText.bodyMedium.copyWith(
                color: semantic.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
