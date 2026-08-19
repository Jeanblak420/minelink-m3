import 'package:flutter/material.dart';

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
class MlRailBrand extends StatelessWidget {
  const MlRailBrand({
    super.key,
    required this.expanded,
    required this.onTap,
    this.subtitle,
  });

  final bool expanded;
  final VoidCallback onTap;

  /// The line under the wordmark — "Global Admin", the company name.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final chrome = MlChrome.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(expanded ? 16 : 8, 16, expanded ? 16 : 8, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: MlShape.radiusMedium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const MineLinkLogo(height: 28, onDark: true),
                if (expanded && subtitle != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: chrome.railSectionLabel,
                        letterSpacing: 1.1,
                      ),
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

    return Padding(
      padding: EdgeInsets.fromLTRB(expanded ? 12 : 8, 8, expanded ? 12 : 8, 12),
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
                child: expanded
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
