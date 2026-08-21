import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/constants/app_branding.dart';
import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_chrome.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/widgets/minelink_logo.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';

/// The brand block at the top of the rail.
///
/// Shared by the console and the portal. Previously each drew its own — same
/// logo, different padding, different collapsed behaviour — so the two rails
/// did not line up with each other at any width.
///
/// ## Why the MARK and not the lockup
///
/// This drew `MineLinkLogo(height: 28)` — the full STACKED lockup, which is
/// three tiers of artwork: the chain mark, the "MineLink" wordmark under it,
/// and a letter-spaced "TECHNOLOGIES" strapline under that. Measured against
/// the asset's own ink bands (1281x991, `minelink_logo_white.png`), 28 logical
/// pixels buys:
///
///   * chain mark      584/991 of the height  ->  **16.50 px**
///   * "MineLink"      231/991                ->  **6.53 px**
///   * "TECHNOLOGIES"   67/991                ->  **1.89 px**
///
/// A 6.5px wordmark and a 1.9px strapline are not small type, they are mush —
/// and the mark itself came out SMALLER than the 34px avatar at the foot of
/// the same rail. It was photographed in `console-desktop-dark.png` from the
/// first render onward and read as a broken image rather than as a brand.
///
/// So the rail now draws what that slot is for: `MineLinkMark`, which is the
/// chain mark alone and is documented for exactly this ("compact brand spots
/// (collapsed sidebars, auth headers)"). The wordmark comes back as REAL TEXT
/// in the app's own face — which is also what `MlChrome.wordmarkStart/End`
/// were added for. Those two tokens were defined, threaded through `copyWith`
/// and `lerp`, and then used by no widget at all; this is the widget they
/// were waiting for.
///
/// The lockup is still right where it is large enough to be read — the auth
/// panel (132px, and 290px wide) and the boot screen (128px / 96px). The
/// `brand-lockup-drawn-too-small` guard holds the floor at its own default
/// height of 64, below which the strapline drops under 4.3px.
class MlRailBrand extends StatelessWidget {
  const MlRailBrand({
    super.key,
    required this.expanded,
    required this.onTap,
    this.subtitle,
  });

  /// The caller's preference. The **rail's own** state wins where one is
  /// published — see [MlRailScope]. This is the fallback for a block drawn
  /// outside a rail: the modal drawer, which is full width, and tests.
  final bool expanded;
  final VoidCallback onTap;

  /// The line under the wordmark — "Global Admin", the company name.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final chrome = MlChrome.of(context);
    final text = Theme.of(context).textTheme;
    // The rail's own state where it publishes one; the parameter is only a
    // fallback for a block drawn outside a rail (MlRailScope explains why).
    final open = MlRailScope.maybeOf(context) ?? expanded;

    return Padding(
      padding: EdgeInsets.fromLTRB(open ? 16 : 8, 16, open ? 16 : 8, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: MlShape.radiusMedium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: open
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const MineLinkMark(size: 30, onDark: true),
                if (open) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RailWordmark(
                          start: chrome.wordmarkStart,
                          end: chrome.wordmarkEnd,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            height: 1.05,
                            // Painted over by the shader. It is a real token
                            // rather than a placeholder so that the one case
                            // where the shader does not apply — a platform
                            // that declines the mask — still reads.
                            color: chrome.railLabelSelected,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: chrome.railSectionLabel,
                              letterSpacing: 1.1,
                              height: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The product name, in the app's own face, under the brand's cyan->blue.
///
/// `BlendMode.srcIn` paints the gradient THROUGH the glyphs, so the shader
/// replaces the text colour rather than tinting a box around it. The gradient
/// runs across the text's own bounds, not the rail's, so the two stops land on
/// the word whatever the rail is doing behind it.
///
/// Both stops clear WCAG AA *body* against every rail ground the product has,
/// in both brightnesses — 6.54:1 at worst (`#5AA2FF` on the light theme's
/// `#0C1C34` rail top). That is not luck: the rail is navy in BOTH themes by
/// design (see `MlChrome.dark`'s note), so there is no light-mode ground for
/// this to fall onto. `test/design/token_contrast_test.dart` measures it.
class _RailWordmark extends StatelessWidget {
  const _RailWordmark({
    required this.start,
    required this.end,
    required this.style,
  });

  final Color start;
  final Color end;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: [start, end],
      ).createShader(Offset.zero & bounds.size),
      child: Text(
        AppBranding.appName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// The signed-in user, at the foot of the rail.
///
/// Wraps [UserIdentityFlyout] so the hover card, its quick actions and the
/// click-through to the profile behave identically for a super admin and a
/// driver. The console had this; the portal did not, which is why a company
/// user had no way to see which account they were signed in as without opening
/// a screen.
class MlRailIdentity extends StatelessWidget {
  const MlRailIdentity({
    super.key,
    required this.expanded,
    required this.identity,
    required this.onOpenProfile,
    this.actions = const <UserIdentityAction>[],
  });

  /// The caller's preference. The **rail's own** state wins where one is
  /// published — see [MlRailScope]. This is the fallback for a block drawn
  /// outside a rail: the modal drawer, which is full width, and tests.
  final bool expanded;
  final UserIdentity identity;
  final VoidCallback onOpenProfile;
  final List<UserIdentityAction> actions;

  @override
  Widget build(BuildContext context) {
    final chrome = MlChrome.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final initials = identity.name.trim().isEmpty
        ? '?'
        : identity.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w.characters.first.toUpperCase())
            .join();

    final avatar = Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: chrome.railIndicator,
        shape: const CircleBorder(),
      ),
      child: Text(
        initials,
        style: text.labelMedium?.copyWith(color: chrome.railIconSelected),
      ),
    );

    // The rail's own state where it publishes one; the parameter is only a
    // fallback for a block drawn outside a rail (MlRailScope explains why).
    final open = MlRailScope.maybeOf(context) ?? expanded;

    return Padding(
      padding: EdgeInsets.fromLTRB(open ? 12 : 8, 8, open ? 12 : 8, 12),
      child: UserIdentityFlyout(
        user: identity,
        accent: scheme.primary,
        onOpenProfile: onOpenProfile,
        actions: actions,
        child: Material(
          color: Colors.transparent,
          borderRadius: MlShape.radiusMedium,
          child: InkWell(
            borderRadius: MlShape.radiusMedium,
            onTap: onOpenProfile,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: AnimatedSize(
                duration: MlMotion.of(context, MlMotion.stateChange),
                curve: MlMotion.curveOf(context, MlMotion.standard),
                child: open
                    ? Row(
                        children: [
                          avatar,
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  identity.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.labelLarge?.copyWith(
                                    color: chrome.railLabelSelected,
                                  ),
                                ),
                                if (identity.roleLabel != null)
                                  Text(
                                    identity.roleLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall?.copyWith(
                                      color: chrome.railLabel,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Center(child: avatar),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
