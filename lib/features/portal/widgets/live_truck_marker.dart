import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// A truck marker for the live map that reveals a rich info card on hover
/// (desktop/web) or tap (touch): fleet + driver details, when the position was
/// last updated, the trip's lifecycle status, and whether the truck is moving
/// or how long it has been standing still.
///
/// The card is drawn in the app [Overlay] and pinned above the marker via a
/// [CompositedTransformFollower], so it tracks the truck as the map pans/zooms
/// and never gets clipped by the map viewport.
class LiveTruckMarker extends StatefulWidget {
  final LiveTripPosition trip;
  final bool highlighted;

  /// Called when the marker is tapped (used to highlight the trip elsewhere).
  final VoidCallback? onTap;

  const LiveTruckMarker({
    super.key,
    required this.trip,
    this.highlighted = false,
    this.onTap,
  });

  @override
  State<LiveTruckMarker> createState() => _LiveTruckMarkerState();
}

class _LiveTruckMarkerState extends State<LiveTruckMarker> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _card = OverlayPortalController();

  void _show() {
    if (!_card.isShowing) _card.show();
  }

  void _hide() {
    if (_card.isShowing) _card.hide();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.highlighted ? scheme.error : scheme.primary;
    final size = widget.highlighted ? 44.0 : 32.0;

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            widget.onTap?.call();
            // Touch devices have no hover — tap toggles the card instead.
            _card.isShowing ? _hide() : _show();
          },
          child: OverlayPortal(
            controller: _card,
            // The Overlay lays out its children with TIGHT full-screen
            // constraints; passed straight into the follower they inflate the
            // card to the whole screen (a giant empty box anchored above the
            // marker). Align absorbs them so the follower hugs the card.
            //
            // The card must NEVER be clipped by the screen edges, wherever the
            // truck sits in the viewport: it flips below the marker when there
            // is no headroom above, its horizontal position is clamped to the
            // screen, and its height is capped to the available space (the
            // content scrolls if it can't fit whole).
            overlayChildBuilder: (overlayContext) {
              const cardWidth = _TruckInfoCard.width;
              const margin = 8.0; // minimum gap to every screen edge
              const gap = 6.0; // gap between marker and card
              final screen = MediaQuery.sizeOf(overlayContext);

              // Marker's on-screen rect (from its laid-out render box).
              final markerBox = context.findRenderObject() as RenderBox?;
              final markerRect =
                  (markerBox != null && markerBox.attached && markerBox.hasSize)
                  ? markerBox.localToGlobal(Offset.zero) & markerBox.size
                  : Rect.fromCenter(
                      center: Offset(screen.width / 2, screen.height / 2),
                      width: 44,
                      height: 44,
                    );

              // Horizontal: keep the card centred on the truck, clamped fully
              // on-screen (relative to the topCenter/bottomCenter anchor).
              final maxWidth = math.min(cardWidth, screen.width - 2 * margin);
              final left = (markerRect.center.dx - maxWidth / 2).clamp(
                margin,
                math.max(margin, screen.width - maxWidth - margin),
              );
              final dx = left - markerRect.center.dx;

              // Vertical: above by default; below when cramped up top and the
              // bottom has more room. Cap height to the chosen side's space.
              final spaceAbove = markerRect.top - gap - margin;
              final spaceBelow =
                  screen.height - markerRect.bottom - gap - margin;
              final below = spaceAbove < 420 && spaceBelow > spaceAbove;
              final maxHeight = math.max(96.0, below ? spaceBelow : spaceAbove);

              return Align(
                alignment: Alignment.topLeft,
                child: CompositedTransformFollower(
                  link: _link,
                  showWhenUnlinked: false,
                  targetAnchor: below
                      ? Alignment.bottomCenter
                      : Alignment.topCenter,
                  followerAnchor: below
                      ? Alignment.topLeft
                      : Alignment.bottomLeft,
                  offset: Offset(dx, below ? gap : -gap),
                  child: MouseRegion(
                    // Keep the card open while the pointer is over it.
                    onEnter: (_) => _show(),
                    onExit: (_) => _hide(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        maxHeight: maxHeight,
                      ),
                      child: _TruckInfoCard(trip: widget.trip),
                    ),
                  ),
                ),
              );
            },
            child: Icon(Icons.local_shipping_rounded, color: color, size: size),
          ),
        ),
      ),
    );
  }
}

/// The floating detail card shown for a truck on the live map.
class _TruckInfoCard extends StatelessWidget {
  /// Designed card width; the overlay clamps it down on tiny screens.
  static const width = 288.0;

  final LiveTripPosition trip;

  const _TruckInfoCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final t = trip;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: semantic.surfaceCard,
          borderRadius: BorderRadius.circular(MlTokens.rLg),
          border: Border.all(color: semantic.borderCard),
          boxShadow: MlTokens.shadowDrawer,
        ),
        // Scrolls when the overlay caps the card's height (cramped viewport)
        // so the content is never clipped, only scrolled.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: truck reg + lifecycle status.
              Row(
                children: [
                  MlIconWell(
                    icon: Icons.local_shipping_rounded,
                    tone: MlTone.transit,
                    size: 34,
                    radius: 10,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t.truckReg != null && t.truckReg!.isNotEmpty)
                          MlPlatePill(t.truckReg!, fontSize: 12)
                        else
                          Text(
                            'Trip ${t.tripId.substring(0, 6)}…',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Text(
                          t.transporterName ?? 'Transporter —',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.mlText.bodySmall.copyWith(
                            color: semantic.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              MlStatusBadge.forStatus(t.status.label, dot: true),
              const SizedBox(height: 10),
              _MotionRow(trip: t),
              Divider(height: 20, color: semantic.divider),

              // Driver.
              _DetailRow(
                icon: Icons.person_rounded,
                label: 'Driver',
                value: (t.driverName != null && t.driverName!.isNotEmpty)
                    ? t.driverName!
                    : 'Not assigned',
              ),
              if (t.driverPhone != null && t.driverPhone!.isNotEmpty)
                _DetailRow(
                  icon: Icons.phone_rounded,
                  label: 'Contact',
                  value: t.driverPhone!,
                  mono: true,
                ),

              // Journey.
              _DetailRow(
                icon: Icons.factory_rounded,
                label: 'Source',
                value: _clean(t.loadingPoint) ?? '—',
              ),
              _DetailRow(
                icon: Icons.flag_rounded,
                label: 'Destination',
                value: _clean(t.offloadingPoint) ?? '—',
              ),
              if (t.buyerName != null && t.buyerName!.isNotEmpty)
                _DetailRow(
                  icon: Icons.shopping_bag_rounded,
                  label: 'Customer',
                  value: t.buyerName!,
                ),

              Divider(height: 20, color: semantic.divider),

              // GPS freshness.
              _DetailRow(
                icon: Icons.gps_fixed_rounded,
                label: 'Last updated',
                value: t.recordedAt == null
                    ? 'No fix yet'
                    : '${_ago(t.recordedAt!)} · ${MlTime.stamp(t.recordedAt!)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Drop a stored `?q=lat,lng` maps link down to something human — if the
  /// point is only coordinates, show them; otherwise show the text as-is.
  static String? _clean(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final s = v.trim();
    if (s.startsWith('http')) {
      final q = Uri.tryParse(s)?.queryParameters['q'];
      return q ?? s;
    }
    return s;
  }

  static String _ago(DateTime at) => MlTime.ago(at);
}

/// The moving / standing-still readout — the headline the user asked for.
class _MotionRow extends StatelessWidget {
  final LiveTripPosition trip;

  const _MotionRow({required this.trip});

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final MlTone tone;
    final IconData icon;
    final String text;

    if (!t.hasFix) {
      tone = MlTone.neutral;
      icon = Icons.gps_off_rounded;
      text = 'Awaiting first GPS ping';
    } else if (t.isMoving) {
      tone = MlTone.transit;
      icon = Icons.navigation_rounded;
      final v = t.speedKmh!;
      text = 'Moving · ${v.toStringAsFixed(0)} km/h';
    } else if (t.isStationary) {
      tone = MlTone.warn;
      icon = Icons.pause_circle_rounded;
      final held = t.stationaryFor;
      text = held == null
          ? 'Standing still'
          : 'Standing still for ${_dur(held)}';
    } else {
      // Fix exists but no speed reading — motion unknown.
      tone = MlTone.neutral;
      icon = Icons.help_outline_rounded;
      text = 'Motion unknown';
    }

    final colors = tone.colors(Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.mlText.titleSmall.copyWith(
                color: colors.fg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dur(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h < 24) return m == 0 ? '${h}h' : '${h}h ${m}m';
    final days = d.inDays;
    final rh = d.inHours % 24;
    return rh == 0 ? '${days}d' : '${days}d ${rh}h';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: semantic.textFaint),
          const SizedBox(width: 8),
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: context.mlText.bodySmall.copyWith(
                color: semantic.textFaint,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: semantic.textStrong,
                fontFamily: mono ? MlTokens.fontMono : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
