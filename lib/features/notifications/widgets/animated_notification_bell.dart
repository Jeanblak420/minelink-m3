import 'dart:async';

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

class AnimatedNotificationBell extends ConsumerStatefulWidget {
  const AnimatedNotificationBell({super.key});

  @override
  ConsumerState<AnimatedNotificationBell> createState() =>
      _AnimatedNotificationBellState();
}

class _AnimatedNotificationBellState
    extends ConsumerState<AnimatedNotificationBell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  int _previousUnreadCount = 0;

  late Animation<double> _scaleAnimation;
  /// 0 → 1 over the first half of a shake: how far the bell has turned from
  /// the app bar's own icon colour towards amber.
  late Animation<double> _alertTint;

  /// The 30-second re-shake, HELD so it can be cancelled.
  ///
  /// It was a bare `Future.delayed` with a `mounted` check inside, which
  /// cannot be cancelled at all: the delay outlives `dispose()` and keeps a
  /// live timer for up to thirty seconds after the widget is gone. This bell
  /// is in the app bar of every screen in the product, so navigating around
  /// leaves one behind each time. In a widget test it is worse than untidy —
  /// the pending timer fails the test after the body has finished, which is
  /// how the driver app's dashboard came to be unphotographable.
  Timer? _reShake;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Create a more noticeable bell animation
    _rotationAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: -0.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.2,
          end: 0.2,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.2,
          end: -0.15,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: -0.15,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20.0,
      ),
    ]).animate(_controller);

    // Add scale animation for more emphasis
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.2,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.2,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50.0,
      ),
    ]).animate(_controller);

    // The bell starts from the app bar's own icon colour, never a fixed
    // grey. It was `slate600` at rest, which on the dark bar read as a
    // disabled button beside the white chat and alerts icons (S25 walk,
    // 2026-10-26). It only turns amber while there is something unread.
    _alertTint = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _reShake?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    final unreadCount = notificationState.unreadCount;

    // Not when the user has asked the system to stop moving things.
    //
    // This bell shakes when a notification arrives AND THEN RE-SHAKES EVERY 30
    // SECONDS, indefinitely, for as long as anything is unread — see the
    // Future.delayed below. It sits in the app bar of every screen in the
    // product, so for somebody with vestibular sensitivity it is a permanent,
    // unavoidable motion source that only stops when they clear their inbox.
    //
    // The guard is on the TRIGGER rather than on the duration: shortening a
    // shake to 1ms still moves the icon, and the re-arming timer would go on
    // firing forever. The bell still turns red and still carries its unread
    // badge; it simply stops waving.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Trigger animation when unread count increases or when there are unread notifications
    if (!reduce &&
        (unreadCount > _previousUnreadCount ||
            (unreadCount > 0 && !_controller.isAnimating))) {
      _controller.reset();
      _controller.forward().then((_) {
        // If there are still unread notifications, repeat the animation periodically
        if (unreadCount > 0 && mounted) {
          _reShake?.cancel();
          _reShake = Timer(const Duration(seconds: 30), () {
            if (mounted && unreadCount > 0 && !_controller.isAnimating) {
              setState(() {
                // Trigger animation again
                _controller.reset();
                _controller.forward();
              });
            }
          });
        }
      });
    }

    // Update previous count for next comparison
    _previousUnreadCount = unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: RotationTransition(
            turns: _rotationAnimation,
            child: IconButton(
              tooltip: 'Notifications',
              icon: AnimatedBuilder(
                animation: _alertTint,
                builder: (context, child) {
                  final rest = IconTheme.of(context).color;
                  return Icon(
                    Icons.notifications,
                    color: unreadCount > 0
                        ? Color.lerp(rest, MlTokens.amber700, _alertTint.value)
                        : rest,
                  );
                },
              ),
              onPressed: () {
                final role = ref.read(currentPlatformRoleProvider).valueOrNull;
                context.go(NotificationsInboxRoute.forPlatformRole(role));
              },
            ),
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: MlTokens.red600,
                borderRadius: MlShape.radiusMedium,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: MlTokens.inkOnFill,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
