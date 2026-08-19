import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';

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
  late Animation<Color?> _colorAnimation;

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

    // Add color animation for the bell icon
    _colorAnimation =
        ColorTween(begin: MlTokens.slate600, end: MlTokens.amber700).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            reverseCurve: Curves.easeIn,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    final unreadCount = notificationState.unreadCount;

    // Trigger animation when unread count increases or when there are unread notifications
    if (unreadCount > _previousUnreadCount ||
        (unreadCount > 0 && !_controller.isAnimating)) {
      _controller.reset();
      _controller.forward().then((_) {
        // If there are still unread notifications, repeat the animation periodically
        if (unreadCount > 0 && mounted) {
          Future.delayed(const Duration(seconds: 30), () {
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
              icon: AnimatedBuilder(
                animation: _colorAnimation,
                builder: (context, child) {
                  return Icon(
                    Icons.notifications,
                    color: _colorAnimation.value,
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
                borderRadius: BorderRadius.circular(10),
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
