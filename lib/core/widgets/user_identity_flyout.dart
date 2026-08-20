import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/image_provider_utils.dart';

/// One row in the identity flyout's action list.
@immutable
class UserIdentityAction {
  const UserIdentityAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Renders in the warn tone and sits below its own divider — sign-out, and
  /// nothing else so far.
  final bool danger;
}

/// The signed-in person, as the flyout needs them. Deliberately not tied to a
/// provider: the console rail and the portal rail resolve their user very
/// differently and both already hold these strings.
@immutable
class UserIdentity {
  const UserIdentity({
    required this.name,
    required this.email,
    this.roleLabel,
    this.avatarUrl,
    this.online = true,
  });

  final String name;
  final String email;

  /// "Super Admin", "Load Controller" — whatever the surface calls this
  /// person. Null hides the badge rather than printing an empty pill.
  final String? roleLabel;
  final String? avatarUrl;
  final bool online;

  /// Up to two initials, so "jean" gives J and "Jean Blak" gives JB.
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'[\s.]+'))
        .where((p) => p.isNotEmpty)
        .take(2);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p.characters.first.toUpperCase()).join();
  }
}

/// Hover (or long-press, or focus) a user chip and get a card naming who is
/// signed in, with the two or three things anyone opens that chip for.
/// Clicking the chip itself goes to the profile — the card is the preview,
/// not the destination.
///
/// Hand-rolled on [Overlay] + [LayerLink] for the same reason `MlFlyout` is:
/// it has to work on the Flutter version this repo pins, without
/// `OverlayPortal` or `MenuAnchor`.
///
/// The panel is anchored **bottom-to-bottom** and grows upward. Every chip
/// that uses it is the last thing in its rail, so upward is the only
/// direction with room; anchoring by centre would push half the card off the
/// bottom of the window.
class UserIdentityFlyout extends StatefulWidget {
  const UserIdentityFlyout({
    super.key,
    required this.child,
    required this.user,
    this.onOpenProfile,
    this.actions = const <UserIdentityAction>[],
    this.accent = MlTokens.accent,
    this.enabled = true,
    this.horizontalGap = 12,
    this.openDelay = const Duration(milliseconds: 120),
    this.closeDelay = const Duration(milliseconds: 160),
  });

  final Widget child;
  final UserIdentity user;

  /// Where a click on the chip lands. Null leaves the chip inert to taps but
  /// still hoverable.
  final VoidCallback? onOpenProfile;

  final List<UserIdentityAction> actions;
  final Color accent;
  final bool enabled;
  final double horizontalGap;
  final Duration openDelay;
  final Duration closeDelay;

  @override
  State<UserIdentityFlyout> createState() => _UserIdentityFlyoutState();
}

class _UserIdentityFlyoutState extends State<UserIdentityFlyout> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;
  bool _pointerInPanel = false;
  bool _pointerInAnchor = false;
  bool _hovered = false;

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  void _open() {
    if (!widget.enabled || _entry != null || !mounted) return;
    if (widget.actions.isEmpty && widget.user.email.isEmpty) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Read the semantic palette from the anchor, not from the overlay's
    // context: the overlay sits above any MlSemanticScope a premium mine
    // theme has installed, so building the card there would silently drop
    // that palette.
    final semantic = MlSemantic.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height - 24;

    _entry = OverlayEntry(
      builder: (ctx) => Positioned(
        left: 0,
        top: 0,
        child: CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.bottomLeft,
          offset: Offset(widget.horizontalGap, 0),
          child: MouseRegion(
            onEnter: (_) => _pointerInPanel = true,
            onExit: (_) {
              _pointerInPanel = false;
              _scheduleClose();
            },
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: UserIdentityCard(
                  user: widget.user,
                  actions: widget.actions,
                  accent: widget.accent,
                  semantic: semantic,
                  onActionTap: (action) {
                    close();
                    action.onTap();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  void close() {
    _entry?.remove();
    _entry = null;
  }

  Future<void> _scheduleOpen() async {
    await Future<void>.delayed(widget.openDelay);
    if (!mounted) return;
    if (_pointerInAnchor) _open();
  }

  Future<void> _scheduleClose() async {
    await Future<void>.delayed(widget.closeDelay);
    if (!mounted) return;
    if (!_pointerInAnchor && !_pointerInPanel) close();
  }

  void _handleTap() {
    close();
    widget.onOpenProfile?.call();
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: widget.onOpenProfile == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) {
          _pointerInAnchor = true;
          if (mounted) setState(() => _hovered = true);
          _scheduleOpen();
        },
        onExit: (_) {
          _pointerInAnchor = false;
          if (mounted) setState(() => _hovered = false);
          _scheduleClose();
        },
        // `container: true` and the ExcludeSemantics below are both load-
        // bearing, and measured rather than assumed: without them the chip's
        // own name and email Texts each form their own node, this label is
        // dropped to the empty string, and the button role never reaches a
        // screen reader. The GestureDetector stays OUTSIDE the exclusion, so
        // the tap action still merges into the same node.
        child: Semantics(
          container: true,
          button: widget.onOpenProfile != null,
          label: widget.user.email.isEmpty
              ? widget.user.name
              : '${widget.user.name}, ${widget.user.email}',
          hint: widget.onOpenProfile == null ? null : 'Opens your profile',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onOpenProfile == null ? null : _handleTap,
            // Touch devices never hover, so long-press is how the card opens
            // there. Same escape hatch MlFlyout uses on the rail.
            onLongPress: () => _entry == null ? _open() : close(),
            child: Focus(
              canRequestFocus: widget.onOpenProfile != null,
              onFocusChange: (focused) => focused ? _open() : close(),
              child: AnimatedContainer(
                duration: _motion(context, MlTokens.durFast),
                curve: MlTokens.easeOutCubic,
                decoration: BoxDecoration(
                  color: _hovered
                      ? widget.accent.withValues(alpha: 0.10)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                  border: Border.all(
                    color: _hovered
                        ? widget.accent.withValues(alpha: 0.30)
                        : Colors.transparent,
                  ),
                ),
                child: ExcludeSemantics(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: semantic.textBody),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The panel itself. Public so a test can pump it on its own, and so a
/// surface that wants this card somewhere other than a hover (a mobile
/// bottom sheet, say) can reuse it.
class UserIdentityCard extends StatelessWidget {
  const UserIdentityCard({
    super.key,
    required this.user,
    required this.actions,
    required this.accent,
    required this.semantic,
    required this.onActionTap,
  });

  final UserIdentity user;
  final List<UserIdentityAction> actions;
  final Color accent;
  final MlSemantic semantic;
  final ValueChanged<UserIdentityAction> onActionTap;

  @override
  Widget build(BuildContext context) {
    final avatarImage = imageProviderFromString(user.avatarUrl);
    final quick = actions.where((a) => !a.danger).toList();
    final danger = actions.where((a) => a.danger).toList();

    return Container(
      // Bounded, not fixed: the card has to grow with the console's per-user
      // text scale (0.85–1.3) rather than overflow at the top of it.
      constraints: const BoxConstraints(minWidth: 244, maxWidth: 312),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        border: Border.all(color: semantic.borderCard),
        boxShadow: MlTokens.shadowLg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: avatarImage == null
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.55),
                              ],
                            )
                          : null,
                      image: avatarImage == null
                          ? null
                          : DecorationImage(
                              image: avatarImage,
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: avatarImage == null
                        ? Text(
                            user.initials,
                            style: const TextStyle(
                              fontFamily: MlTokens.fontSans,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: MlTokens.inkOnAccent,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 11),
                  // Expanded, not Flexible: this is the long child, and it is
                  // the only one competing for the row's free space.
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            color: semantic.textStrong,
                          ),
                        ),
                        if (user.email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          // The card exists partly to show the address the
                          // chip had to truncate, so this one wraps.
                          Text(
                            user.email,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: MlTokens.fontMono,
                              fontSize: 11,
                              height: 1.35,
                              color: semantic.textMuted,
                            ),
                          ),
                        ],
                        if (user.roleLabel != null || user.online) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (user.roleLabel != null)
                                _Pill(
                                  label: user.roleLabel!.toUpperCase(),
                                  foreground: accent,
                                  background: accent.withValues(alpha: 0.14),
                                  border: accent.withValues(alpha: 0.30),
                                ),
                              if (user.online)
                                _Pill(
                                  label: 'ONLINE',
                                  foreground: MlTokens.green500,
                                  background:
                                      MlTokens.green500.withValues(alpha: 0.13),
                                  border:
                                      MlTokens.green500.withValues(alpha: 0.28),
                                  dot: true,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (quick.isNotEmpty) ...[
              Divider(height: 1, thickness: 1, color: semantic.divider),
              const SizedBox(height: 6),
              for (final action in quick)
                _ActionRow(
                  action: action,
                  semantic: semantic,
                  accent: accent,
                  onTap: () => onActionTap(action),
                ),
              const SizedBox(height: 6),
            ],
            if (danger.isNotEmpty) ...[
              Divider(height: 1, thickness: 1, color: semantic.divider),
              const SizedBox(height: 6),
              for (final action in danger)
                _ActionRow(
                  action: action,
                  semantic: semantic,
                  accent: MlTokens.orange500,
                  onTap: () => onActionTap(action),
                ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    this.dot = false,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.action,
    required this.semantic,
    required this.accent,
    required this.onTap,
  });

  final UserIdentityAction action;
  final MlSemantic semantic;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tint =
        widget.action.danger ? MlTokens.orange500 : widget.semantic.textBody;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MlTokens.rSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(MlTokens.rSm),
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hovered = h),
          child: AnimatedContainer(
            duration: _motion(context, MlTokens.durFast),
            curve: MlTokens.easeOutCubic,
            // minHeight, not height: a border plus padding on a fixed height
            // is the console's most-repeated 1px overflow.
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(MlTokens.rSm),
            ),
            child: Row(
              children: [
                Icon(
                  widget.action.icon,
                  size: 17,
                  color: _hovered ? widget.accent : tint,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    widget.action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _hovered ? widget.accent : tint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Reduce-motion helper. Never [Duration.zero] — a zero duration makes
/// [AnimationController] notify synchronously, which re-dirties an animated
/// box inside its own layout. 1ms still lands in the first frame.
Duration _motion(BuildContext context, Duration full) {
  final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return reduce ? const Duration(milliseconds: 1) : full;
}
