import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:async';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/chat/services/attachment_url.dart';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart'
    show openFile, openFiles, XTypeGroup;
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/utils/pointer_position_tracker.dart';
import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import 'package:flutter_application_1/features/chat/models/support_models.dart';
import 'package:flutter_application_1/features/chat/providers/chat_prefs_provider.dart';
import 'package:flutter_application_1/features/chat/providers/chat_presence_provider.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/chat/providers/support_providers.dart';
import 'package:flutter_application_1/features/chat/services/chat_sound_service.dart';
import 'package:flutter_application_1/core/design/tokens/ml_chat_palettes.dart';
import 'package:flutter_application_1/features/chat/widgets/live_chat_icon.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/presence/ml_presence.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

final _log = LoggerFactory.getLogger('ChatDock');

/// App shell overlay hosting the floating chat launcher (the 3D [LiveChatIcon])
/// and a draggable, resizable, minimizable/maximizable chat window — the
/// design's `ChatShell` + `ChatFab`. Mounted once per shell (portal +
/// super-admin); go_router's ShellRoute keeps it alive across sub-navigation so
/// the window's position/size/open-state persist while moving between screens.
class ChatDock extends ConsumerStatefulWidget {
  final Widget child;
  const ChatDock({super.key, required this.child});

  /// Whether a dock is mounted above [context] — i.e. firing
  /// [dockOpenRequestProvider] will actually open a chat window here. Both the
  /// portal and super-admin shells mount one; standalone legacy routes don't.
  static bool isMounted(BuildContext context) =>
      context.findAncestorStateOfType<_ChatDockState>() != null;

  @override
  ConsumerState<ChatDock> createState() => _ChatDockState();
}

class _ChatDockState extends ConsumerState<ChatDock>
    with SingleTickerProviderStateMixin {
  static const double _fabSize = 66;
  // Resize is free-form: down to a small floor (below which the title bar can't
  // fit) and up to the full viewport (the upper cap is effectively unlimited).
  static const double _minW = 200, _minH = 220, _maxW = 100000, _maxH = 100000;

  final ValueNotifier<Offset?> _fabPos = ValueNotifier<Offset?>(null);
  final ValueNotifier<Offset?> _panelPos = ValueNotifier<Offset?>(null);
  final ValueNotifier<Size?> _panelSize = ValueNotifier<Size?>(null);
  final ValueNotifier<bool> _maximized = ValueNotifier<bool>(false);

  // Open ⇄ closed morph. 0 = just the disc, 1 = full window.
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: MlMotion.of(context, MlMotion.enter),
    reverseDuration: const Duration(milliseconds: 210),
  );

  @override
  void dispose() {
    _anim.dispose();
    _fabPos.dispose();
    _panelPos.dispose();
    _panelSize.dispose();
    _maximized.dispose();
    super.dispose();
  }

  void _toggleOpen() {
    if (_anim.status == AnimationStatus.forward ||
        _anim.status == AnimationStatus.completed) {
      _anim.reverse();
    } else {
      _anim.forward();
    }
  }

  void _minimize() {
    _maximized.value = false;
    _anim.reverse();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  Offset _clampPos(Offset p, Size area, Size item) {
    final maxX = math.max(8.0, area.width - item.width - 8);
    final maxY = math.max(8.0, area.height - item.height - 8);
    return Offset(p.dx.clamp(8.0, maxX), p.dy.clamp(8.0, maxY));
  }

  Size _clampSize(Size s, Size area) {
    // Upper-bound to the viewport, but never below the functional minimum so
    // the panel's internal layout can't RenderFlex-overflow. On a very small
    // window the panel simply extends past the viewport (clipped) rather than
    // showing overflow stripes.
    final maxW = math.max(_minW, math.min(_maxW, area.width - 16));
    final maxH = math.max(_minH, math.min(_maxH, area.height - 16));
    return Size(s.width.clamp(_minW, maxW), s.height.clamp(_minH, maxH));
  }

  @override
  Widget build(BuildContext context) {
    // External open requests (e.g. the employee profile's "Message X" CTA).
    ref.listen(dockOpenRequestProvider, (_, __) {
      if (_anim.status != AnimationStatus.forward &&
          _anim.status != AnimationStatus.completed) {
        _anim.forward();
      }
    });
    final cursorTracking = ref.watch(
        chatPrefsProvider.select((p) => p.cursorTracking));
    final someoneTyping = ref.watch(typingInboxProvider).anyone;
    // Keep the global delivery marker alive (delivered = their app received it,
    // marked whenever the app is running — NOT tied to opening any chat).
    ref.watch(chatDeliveryProvider);
    // Live total unread across all conversations → glossy red disc badge.
    final unreadTotal = ref
            .watch(chatConversationsProvider)
            .valueOrNull
            ?.fold<int>(0, (sum, c) => sum + c.unreadCount) ??
        0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final full = Size(constraints.maxWidth, constraints.maxHeight);

        // KEEP OFF THE BOTTOM NAVIGATION BAR.
        //
        // This dock wraps the whole shell, so its area is the whole window —
        // including the compact bottom bar, which the `Scaffold` reserves for
        // its own body but knows nothing about out here. The launcher's
        // default position is "22 from the bottom of my area", and on a phone
        // that is 22 from the bottom of the SCREEN: measured on a 412x915
        // viewport in a browser, the 66px disc sat at y 835..890 inside a bar
        // occupying y 831..914 and covered **68% of the width of the fifth
        // destination**. That destination is "More", and it is the only route
        // from the bottom bar to the rest of the navigation.
        //
        // No picture could have shown it: `redesign_renders_test.dart` builds
        // `MlAppShell` directly and never mounts a dock, so the FAB is absent
        // from all 100 phone renders.
        //
        // The reserve is the bar's own height plus the window's bottom safe
        // area — the same two numbers the Scaffold subtracts — and it applies
        // to the CLAMP as well as the default, because a disc dragged under
        // the bar is a disc that cannot be tapped.
        final reserved = MlWindowClass.forWidth(full.width).usesBottomNav
            ? kMlBottomNavHeight + MediaQuery.viewPaddingOf(context).bottom
            : 0.0;
        final area = Size(full.width, math.max(0, full.height - reserved));

        final defaultFab =
            Offset(area.width - _fabSize - 22, area.height - _fabSize - 22);
        final defaultSize = Size(
          math.min(384.0, area.width - 24),
          math.min(560.0, area.height - 88),
        );

        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerHover: (e) =>
              PointerPositionTracker.instance.update(e.position),
          onPointerMove: (e) =>
              PointerPositionTracker.instance.update(e.position),
          child: Stack(
            children: [
              // NON-positioned on purpose: the Stack sizes itself to this
              // child. With every child Positioned the Stack would size to
              // the closed-panel SizedBox.shrink() placeholder instead —
              // 0×0 under the portal shell's loose constraints, which blanked
              // the whole app for org users.
              widget.child,
              // The chat window — morphs open out of the disc's corner. The
              // panel is built once (rebuilt only when maximize toggles) and
              // passed as `child`, so dragging/resizing only repositions it
              // instead of re-inflating the whole chat every frame → smooth.
              ValueListenableBuilder<bool>(
                valueListenable: _maximized,
                builder: (context, maximized, _) {
                  final panel = _ChatPanel(
                    maximized: maximized,
                    onDragTitle: (d) {
                      final size = maximized
                          ? area
                          : _clampSize(_panelSize.value ?? defaultSize, area);
                      final cur = _panelPos.value ??
                          Offset(area.width - size.width - 22,
                              area.height - size.height - 22);
                      _panelPos.value = _clampPos(cur + d, area, size);
                    },
                    onResize: (l, t, r, b, d) {
                      final cur =
                          _clampSize(_panelSize.value ?? defaultSize, area);
                      final pos = _panelPos.value ??
                          Offset(area.width - cur.width - 22,
                              area.height - cur.height - 22);
                      double left = pos.dx,
                          top = pos.dy,
                          right = pos.dx + cur.width,
                          bottom = pos.dy + cur.height;
                      if (r) right += d.dx;
                      if (l) left += d.dx;
                      if (b) bottom += d.dy;
                      if (t) top += d.dy;
                      final maxW = math.max(_minW, math.min(_maxW, area.width));
                      final maxH = math.max(_minH, math.min(_maxH, area.height));
                      final w = (right - left).clamp(_minW, maxW);
                      final h = (bottom - top).clamp(_minH, maxH);
                      // Keep the edge OPPOSITE the drag fixed.
                      if (l) left = right - w;
                      if (t) top = bottom - h;
                      left = left.clamp(0.0, math.max(0.0, area.width - w));
                      top = top.clamp(0.0, math.max(0.0, area.height - h));
                      _panelSize.value = Size(w, h);
                      _panelPos.value = Offset(left, top);
                    },
                    onMinimize: _minimize,
                    onToggleMax: () => _maximized.value = !_maximized.value,
                    onClose: _minimize,
                  );
                  return AnimatedBuilder(
                    animation:
                        Listenable.merge([_anim, _panelPos, _panelSize]),
                    child: panel,
                    builder: (context, child) {
                      final a = _anim.value;
                      if (a == 0) return const SizedBox.shrink();
                      final Size size = maximized
                          ? Size(math.max(area.width, _minW),
                              math.max(area.height, _minH))
                          : _clampSize(_panelSize.value ?? defaultSize, area);
                      final Offset pos = maximized
                          ? Offset.zero
                          : _clampPos(
                              _panelPos.value ??
                                  Offset(area.width - size.width - 22,
                                      area.height - size.height - 22),
                              area,
                              size);
                      final grow = Curves.easeOutCubic.transform(a);
                      final fade =
                          Curves.easeOut.transform(a.clamp(0.0, 1.0));
                      return Positioned(
                        left: pos.dx,
                        top: pos.dy,
                        width: size.width,
                        height: size.height,
                        child: IgnorePointer(
                          ignoring: a < 0.999,
                          child: Opacity(
                            opacity: fade,
                            child: Transform.scale(
                              scale:
                                  maximized ? 1.0 : _lerp(0.32, 1.0, grow),
                              alignment: Alignment.bottomRight,
                              child: child,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              // Floating disc — shrinks/fades away as the window takes over.
              // The disc widget is built ONCE (passed as `child`); only the
              // Positioned wrapper rebuilds while dragging, so the CustomPaint
              // disc is never re-inflated per frame → smooth 1:1 drag.
              AnimatedBuilder(
                animation: Listenable.merge([_anim, _fabPos]),
                child: _DraggableFab(
                  // Keyed so a test can measure where the launcher actually
                  // landed. It sat ON the bottom navigation bar until
                  // 2026-08-21, and the only reason that was ever noticed is
                  // that somebody opened the app on a phone-sized viewport.
                  key: const ValueKey('chat-dock-launcher'),
                  size: _fabSize,
                  cursorTracking: cursorTracking,
                  isTyping: someoneTyping,
                  unreadCount: unreadTotal,
                  onTap: _toggleOpen,
                  onDrag: (d) => _fabPos.value = _clampPos(
                      (_fabPos.value ?? defaultFab) + d,
                      area,
                      const Size(_fabSize, _fabSize)),
                ),
                builder: (context, child) {
                  final a = _anim.value;
                  final fade = (1 - a * 1.7).clamp(0.0, 1.0);
                  if (fade == 0) return const SizedBox.shrink();
                  final p = _clampPos(_fabPos.value ?? defaultFab, area,
                      const Size(_fabSize, _fabSize));
                  return Positioned(
                    left: p.dx,
                    top: p.dy,
                    child: IgnorePointer(
                      ignoring: a > 0.02,
                      child: Opacity(
                        opacity: fade,
                        child: Transform.scale(
                          scale: _lerp(1.0, 0.45, a),
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The 3D disc wrapped in a raw pointer layer: 1:1 drag (no slop), and a press
/// that barely moves counts as a tap to open/close the window.
class _DraggableFab extends StatefulWidget {
  final double size;
  final bool cursorTracking;
  final bool isTyping;
  final int unreadCount;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDrag;
  const _DraggableFab({
    super.key,
    required this.size,
    required this.cursorTracking,
    required this.isTyping,
    required this.unreadCount,
    required this.onTap,
    required this.onDrag,
  });

  @override
  State<_DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<_DraggableFab> {
  double _travelled = 0;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _travelled = 0,
      onPointerMove: (e) {
        _travelled += e.delta.distance;
        widget.onDrag(e.delta);
      },
      onPointerUp: (_) {
        if (_travelled < 5) widget.onTap();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: LiveChatIcon(
            size: widget.size,
            cursorTracking: widget.cursorTracking,
            isTyping: widget.isTyping,
            unreadCount: widget.unreadCount),
      ),
    );
  }
}

// ===========================================================================
// WINDOW (title bar + body + resize grip)
// ===========================================================================

class _ChatPanel extends ConsumerStatefulWidget {
  final bool maximized;
  final ValueChanged<Offset> onDragTitle;
  final void Function(bool left, bool top, bool right, bool bottom, Offset delta)
      onResize;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMax;
  final VoidCallback onClose;
  const _ChatPanel({
    required this.maximized,
    required this.onDragTitle,
    required this.onResize,
    required this.onMinimize,
    required this.onToggleMax,
    required this.onClose,
  });

  @override
  ConsumerState<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<_ChatPanel> {
  int _tab = 0; // 0 = Chats, 1 = People
  bool _inThread = false;
  bool _showSettings = false;
  bool _showSupport = false;
  ChatContact? _profile;

  // Delivery marking is global (chatDeliveryProvider, kept alive by the dock) —
  // messages are marked delivered whenever the app is running, not only while
  // the chat window is open. Read is still marked only on opening a thread.

  void _openRoom(ChatConversation room) {
    ref.read(activeRoomProvider.notifier).state = room;
    setState(() => _inThread = true);
  }

  void _showProfile(ChatContact c) => setState(() => _profile = c);

  /// Opens the profile panel for a user id (used when a @mention is tapped).
  void _showProfileByUserId(String userId) {
    final contacts = ref.read(chatContactsProvider).valueOrNull ?? const [];
    for (final c in contacts) {
      if (c.userId == userId) {
        _showProfile(c);
        return;
      }
    }
  }

  ChatContact? _partnerFor(ChatConversation room) {
    if (room.type != ChatRoomType.dm) return null;
    final myId = ref.read(messagingServiceProvider).currentUserId;
    final otherId =
        room.participantIds.firstWhere((p) => p != myId, orElse: () => '');
    if (otherId.isEmpty) return null;
    final contacts = ref.read(chatContactsProvider).valueOrNull ?? const [];
    for (final c in contacts) {
      if (c.userId == otherId) return c;
    }
    return null;
  }

  Future<void> _messageContact(ChatContact c) async {
    try {
      final svc = ref.read(messagingServiceProvider);
      final room = await svc.getOrCreateDm(
          otherUserId: c.userId, otherDisplayName: c.displayName);
      ref.invalidateIfMounted(chatConversationsProvider);
      if (!mounted) return;
      ref.read(activeRoomProvider.notifier).state = room;
      setState(() {
        _profile = null;
        _inThread = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open chat. ${friendlyError(e)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // When something outside the dock selects a room (profile "Message X"),
    // jump straight into that thread instead of the conversation list.
    ref.listen(activeRoomProvider, (prev, next) {
      if (next != null && !_inThread) setState(() => _inThread = true);
    });
    final pal = ref.watch(chatPrefsProvider).palette;
    final room = ref.watch(activeRoomProvider);
    final radius = widget.maximized ? 0.0 : MlTokens.rXl;

    Widget body;
    if (_showSupport) {
      body = _SupportView(
          pal: pal, onBack: () => setState(() => _showSupport = false));
    } else if (_showSettings) {
      body = _SettingsView(pal: pal, onBack: () => setState(() => _showSettings = false));
    } else if (_profile != null) {
      body = _ProfileView(
        pal: pal,
        contact: _profile!,
        onBack: () => setState(() => _profile = null),
        onMessage: () => _messageContact(_profile!),
      );
    } else if (_inThread && room != null) {
      final partner = _partnerFor(room);
      body = _ThreadView(
        pal: pal,
        room: room,
        onBack: () => setState(() => _inThread = false),
        onAvatarProfile: partner == null ? null : () => _showProfile(partner),
        onOpenUser: _showProfileByUserId,
      );
    } else {
      body = _ListView(
        pal: pal,
        tab: _tab,
        onTab: (t) => setState(() => _tab = t),
        onOpen: _openRoom,
        onProfile: _showProfile,
        onSupport: () => setState(() => _showSupport = true),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: pal.body,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: pal.divider),
          boxShadow: MlTokens.shadowLg,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                _TitleBar(
                  pal: pal,
                  maximized: widget.maximized,
                  onDragTitle: widget.maximized ? null : widget.onDragTitle,
                  onSettings: () =>
                      setState(() => _showSettings = !_showSettings),
                  onMinimize: widget.onMinimize,
                  onToggleMax: widget.onToggleMax,
                  onClose: widget.onClose,
                ),
                Container(height: 1, color: pal.divider),
                Expanded(child: body),
              ],
            ),
            if (!widget.maximized) ...[
              // Edges
              _ResizeEdge(
                cursor: SystemMouseCursors.resizeLeftRight,
                right: 0, top: 10, bottom: 10, width: 7,
                onDrag: (d) => widget.onResize(false, false, true, false, d),
              ),
              _ResizeEdge(
                cursor: SystemMouseCursors.resizeLeftRight,
                left: 0, top: 10, bottom: 10, width: 7,
                onDrag: (d) => widget.onResize(true, false, false, false, d),
              ),
              _ResizeEdge(
                cursor: SystemMouseCursors.resizeUpDown,
                left: 10, right: 10, bottom: 0, height: 7,
                onDrag: (d) => widget.onResize(false, false, false, true, d),
              ),
              _ResizeEdge(
                cursor: SystemMouseCursors.resizeUpDown,
                left: 10, right: 10, top: 0, height: 7,
                onDrag: (d) => widget.onResize(false, true, false, false, d),
              ),
              // Corners
              _ResizeEdge(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                left: 0, top: 0, width: 14, height: 14,
                onDrag: (d) => widget.onResize(true, true, false, false, d),
              ),
              _ResizeEdge(
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
                right: 0, top: 0, width: 14, height: 14,
                onDrag: (d) => widget.onResize(false, true, true, false, d),
              ),
              _ResizeEdge(
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
                left: 0, bottom: 0, width: 14, height: 14,
                onDrag: (d) => widget.onResize(true, false, false, true, d),
              ),
              _ResizeEdge(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                right: 0, bottom: 0, width: 18, height: 18,
                onDrag: (d) => widget.onResize(false, false, true, true, d),
                child: CustomPaint(painter: _GripPainter(pal.bodySubtle)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResizeEdge extends StatelessWidget {
  final double? left, top, right, bottom, width, height;
  final MouseCursor cursor;
  final ValueChanged<Offset> onDrag;
  final Widget? child;
  const _ResizeEdge({
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required this.cursor,
    required this.onDrag,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: cursor,
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerMove: (e) => onDrag(e.delta),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final ChatPalette pal;
  final bool maximized;
  final ValueChanged<Offset>? onDragTitle;
  final VoidCallback onSettings;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMax;
  final VoidCallback onClose;
  const _TitleBar({
    required this.pal,
    required this.maximized,
    required this.onDragTitle,
    required this.onSettings,
    required this.onMinimize,
    required this.onToggleMax,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      height: 42,
      padding: const EdgeInsets.only(left: 12, right: 6),
      color: pal.header,
      child: Row(
        children: [
          Icon(Icons.forum_rounded, size: 18, color: pal.accent),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Messages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.titleSmall.copyWith(
                color: pal.headerText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _WinBtn(icon: Icons.settings_outlined, tip: 'Messages settings', onTap: onSettings, pal: pal),
          _WinBtn(icon: Icons.remove_rounded, tip: 'Minimize', onTap: onMinimize, pal: pal),
          _WinBtn(
              icon: maximized
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
              tip: maximized ? 'Restore' : 'Maximize',
              onTap: onToggleMax,
              pal: pal),
          _WinBtn(icon: Icons.close_rounded, tip: 'Close', onTap: onClose, pal: pal),
        ],
      ),
    );

    if (onDragTitle == null) return bar;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: (e) => onDragTitle!(e.delta),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: bar),
    );
  }
}

class _WinBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final ChatPalette pal;
  const _WinBtn(
      {required this.icon, required this.tip, required this.onTap, required this.pal});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: MlShape.radiusSmall,
        hoverColor: pal.headerText.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 17, color: pal.headerText.withValues(alpha: 0.85)),
        ),
      ),
    );
  }
}

class _GripPainter extends CustomPainter {
  final Color color;
  _GripPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(w - 11, h - 4), Offset(w - 4, h - 11), p);
    canvas.drawLine(Offset(w - 6, h - 4), Offset(w - 4, h - 6), p);
  }

  @override
  bool shouldRepaint(covariant _GripPainter old) => old.color != color;
}

// ===========================================================================
// CONTENT HEADER (thread / profile) — sits under the window title bar
// ===========================================================================

class _ContentHeader extends StatelessWidget {
  final ChatPalette pal;
  final String title;
  final String subtitle;
  final bool isGroup;
  final bool isSuperAdmin;
  final VoidCallback onBack;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onInfo;
  final bool? online;
  const _ContentHeader({
    required this.pal,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.isGroup = false,
    this.isSuperAdmin = false,
    this.onAvatarTap,
    this.onInfo,
    this.online,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = _MiniAvatar(
        pal: pal,
        label: title,
        isGroup: isGroup,
        isSuperAdmin: isSuperAdmin,
        online: online);
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 10),
      height: 54,
      color: pal.header.withValues(alpha: pal.isDark ? 0.4 : 0.5),
      child: Row(
        children: [
          _WinBtn(icon: Icons.arrow_back_rounded, tip: 'Back', onTap: onBack, pal: pal),
          const SizedBox(width: 2),
          if (onAvatarTap != null)
            Tooltip(
              message: 'View profile',
              child: InkWell(
                onTap: onAvatarTap,
                customBorder: const CircleBorder(),
                child: avatar,
              ),
            )
          else
            avatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.titleMedium.copyWith(
                      color: pal.bodyText,
                      fontWeight: FontWeight.w800,
                    )),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.bodySmall.copyWith(
                      color: pal.bodySubtle,
                    )),
              ],
            ),
          ),
          if (onInfo != null)
            _WinBtn(
                icon: Icons.info_outline_rounded,
                tip: 'Info',
                onTap: onInfo!,
                pal: pal),
        ],
      ),
    );
  }
}

// ===========================================================================
// LIST (chats / people)
// ===========================================================================

class _ListView extends ConsumerWidget {
  final ChatPalette pal;
  final int tab;
  final ValueChanged<int> onTab;
  final ValueChanged<ChatConversation> onOpen;
  final ValueChanged<ChatContact> onProfile;
  final VoidCallback onSupport;
  const _ListView({
    required this.pal,
    required this.tab,
    required this.onTab,
    required this.onOpen,
    required this.onProfile,
    required this.onSupport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              _SegTabs(pal: pal, tab: tab, onTab: onTab),
              Expanded(
                child: Stack(
                  children: [
                    // Soft top glow keyed to the palette accent (kept subtle on
                    // light themes) — mirrors CPS's radial header glow.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.0, -0.9),
                              radius: 1.15,
                              colors: [
                                pal.accent.withValues(
                                    alpha: pal.isDark ? 0.10 : 0.06),
                                pal.body.withValues(alpha: 0.0),
                              ],
                              stops: const [0.0, 0.7],
                            ),
                          ),
                        ),
                      ),
                    ),
                    tab == 0
                        ? _ConversationsList(pal: pal, onOpen: onOpen)
                        : _ContactsList(
                            pal: pal, onOpen: onOpen, onProfile: onProfile),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: _SupportFab(pal: pal, onTap: onSupport),
        ),
      ],
    );
  }
}

/// WhatsApp-style floating action button (bottom-right of the chat list) that
/// opens the Support ticket area. Lifts on hover.
class _SupportFab extends StatefulWidget {
  final ChatPalette pal;
  final VoidCallback onTap;
  const _SupportFab({required this.pal, required this.onTap});

  @override
  State<_SupportFab> createState() => _SupportFabState();
}

class _SupportFabState extends State<_SupportFab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Contact MineLink support',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: MlMotion.of(context, MlMotion.instant),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
            height: 50,
            padding: EdgeInsets.symmetric(horizontal: _hover ? 16 : 13),
            decoration: BoxDecoration(
              color: pal.accent,
              borderRadius: MlShape.radiusLarge,
              boxShadow: [
                BoxShadow(
                  color: pal.accent.withValues(alpha: _hover ? 0.5 : 0.35),
                  blurRadius: _hover ? 20 : 12,
                  offset: Offset(0, _hover ? 8 : 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.support_agent_rounded,
                    size: 24, color: pal.accentText),
                AnimatedSize(
                  duration: MlMotion.of(context, MlMotion.instant),
                  curve: Curves.easeOut,
                  child: _hover
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'Support',
                            style: context.mlText.titleSmall.copyWith(
                              color: pal.accentText,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegTabs extends StatelessWidget {
  final ChatPalette pal;
  final int tab;
  final ValueChanged<int> onTab;
  const _SegTabs({required this.pal, required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, int i) {
      final active = tab == i;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onTab(i),
          child: AnimatedContainer(
            duration: MlTokens.durFast,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: active ? pal.tabSelectedBg : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: active ? pal.accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: context.mlText.titleSmall.copyWith(
                color: active ? pal.accent : pal.bodySubtle,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    // CPS-style tab bar: accent underline + selected fill on the header, with a
    // hairline divider beneath.
    return Container(
      decoration: BoxDecoration(
        color: pal.header,
        border: Border(bottom: BorderSide(color: pal.divider, width: 1)),
      ),
      child: Row(children: [seg('Conversations', 0), seg('Contacts', 1)]),
    );
  }
}

/// Premium hover wrapper for chat conversation / contact rows — ported from the
/// CPS Smart Central `ChatRowHover` so rows feel alive under the pointer and
/// flow smoothly as the mouse sweeps from the first row to the last. On hover it
/// eases in (170ms): an accent-tinted background with a soft "lift" shadow, a
/// leading accent bar that slides in along the left edge with a glow, the row
/// divider melting away, and the content nudging gently to the right.
///
/// [builder] receives the live `hovering` flag so individual rows can react
/// further — e.g. scale the avatar or light up a trailing chat action. All
/// affordances are harmless no-ops on touch platforms (hover never fires).
class _ChatRowHover extends StatefulWidget {
  const _ChatRowHover({
    required this.pal,
    required this.onTap,
    required this.builder,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.enabled = true,
  });

  final ChatPalette pal;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final bool enabled;
  final Widget Function(BuildContext context, bool hovering) builder;

  @override
  State<_ChatRowHover> createState() => _ChatRowHoverState();
}

class _ChatRowHoverState extends State<_ChatRowHover> {
  static const Duration _dur = Duration(milliseconds: 170);
  static const Curve _curve = Curves.easeOutCubic;

  bool _hovering = false;

  void _setHover(bool v) {
    if (!widget.enabled || _hovering == v) return;
    setState(() => _hovering = v);
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final accent = pal.accent;
    final base = pal.body;
    final active = _hovering && widget.enabled;

    final hoverBg = Color.alphaBlend(
      accent.withValues(alpha: pal.isDark ? 0.12 : 0.08),
      base,
    );
    final shadowColor = pal.isDark
        ? MlChatTone.scrim
        : accent.withValues(alpha: 0.18);

    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedContainer(
        duration: _dur,
        curve: _curve,
        decoration: BoxDecoration(
          color: active ? hoverBg : base,
          border: Border(
            bottom: BorderSide(
              color: active ? Colors.transparent : pal.divider,
              width: 0.6,
            ),
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 14,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Stack(
          children: [
            // Leading accent bar — grows + glows in on hover.
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: AnimatedContainer(
                duration: _dur,
                curve: _curve,
                width: active ? 3.5 : 0,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(MlShape.extraSmall)),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.55),
                            blurRadius: 8,
                            spreadRadius: -1,
                          ),
                        ]
                      : const [],
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                // Hover tint is handled by the AnimatedContainer above; keep
                // Ink's own hover overlay off so they don't double up.
                hoverColor: Colors.transparent,
                splashColor: accent.withValues(alpha: 0.12),
                highlightColor: accent.withValues(alpha: 0.06),
                child: AnimatedPadding(
                  duration: _dur,
                  curve: _curve,
                  padding: widget.padding
                      .add(EdgeInsets.only(left: active ? 6 : 0)),
                  child: widget.builder(context, active),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationsList extends ConsumerWidget {
  final ChatPalette pal;
  final ValueChanged<ChatConversation> onOpen;
  const _ConversationsList({required this.pal, required this.onOpen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convos = ref.watch(chatConversationsProvider);
    final online = ref.watch(onlineUsersProvider);
    final myId = ref.read(messagingServiceProvider).currentUserId;
    final contacts = ref.watch(chatContactsProvider).valueOrNull ?? const [];
    final nameById = {for (final c in contacts) c.userId: c.displayName};
    final lastSeenById = {for (final c in contacts) c.userId: c.lastSeenAt};
    return convos.when(
      loading: () => _loading(pal),
      error: (e, _) => _errorBox(pal, '$e'),
      data: (list) {
        if (list.isEmpty) {
          return _Empty(
            pal: pal,
            icon: Icons.forum_outlined,
            title: 'No conversations yet',
            // "Contacts", because that is what THIS surface calls the tab.
            //
            // The string was copied verbatim from `MessagesScreen`, whose
            // tabs really are Chats | People. The dock's are Conversations |
            // Contacts — so the one instruction shown to somebody with no
            // conversations pointed at a tab that is not on their screen.
            // Seen on a real handset, as the first thing a driver is told
            // when they open chat.
            message: 'Open the Contacts tab to start a chat.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final c = list[i];
            final otherId = c.type == ChatRoomType.dm
                ? c.participantIds.firstWhere((p) => p != myId, orElse: () => '')
                : '';
            final isOnline = otherId.isNotEmpty && online.contains(otherId);
            final displayName = c.type == ChatRoomType.dm && otherId.isNotEmpty
                ? (nameById[otherId] ?? c.name)
                : c.name;
            final hasUnread = c.unreadCount > 0;
            final isMyLast = c.lastMessageSenderId != null &&
                c.lastMessageSenderId == myId;
            return _ChatRowHover(
              pal: pal,
              onTap: () => onOpen(c.type == ChatRoomType.dm
                  ? c.copyWith(name: displayName)
                  : c),
              builder: (context, hovering) => Row(
                  children: [
                    AnimatedScale(
                      scale: hovering ? 1.06 : 1.0,
                      duration: MlMotion.of(context, MlMotion.instant),
                      curve: Curves.easeOut,
                      child: _MiniAvatar(
                          pal: pal,
                          label: displayName,
                          isGroup: c.type != ChatRoomType.dm,
                          online:
                              c.type == ChatRoomType.dm ? isOnline : null),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.mlText.titleSmall.copyWith(
                                    color: pal.accent,
                                    fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (c.lastMessageTimestamp != null)
                                Text(
                                  MlTime.agoTag(c.lastMessageTimestamp!),
                                  style: context.mlText.code(
                                    color: (hasUnread || hovering) ? pal.accent : pal.bodySubtle,
                                    size: 11,
                                    weight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              if (c.type == ChatRoomType.dm &&
                                  otherId.isNotEmpty)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                        top: 1, bottom: 1),
                                    child: _PresenceText(
                                      pal: pal,
                                      userId: otherId,
                                      dbLastSeen: lastSeenById[otherId],
                                      fontSize: 11,
                                      // Preview line below already shows
                                      // "typing…" — avoid doubling it.
                                      showTyping: false,
                                    ),
                                  ),
                                )
                              else
                                const Spacer(),
                              if (isMyLast && c.lastMessageContent != null)
                                _ConvTick(
                                  pal: pal,
                                  readAt: c.lastMessageReadAt,
                                  deliveredAt: c.lastMessageDeliveredAt,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                // Someone typing in this room (DM or group)
                                // takes over the preview line, mirroring the
                                // floating disc's typing bubble.
                                child: ref
                                        .watch(typingInboxProvider)
                                        .roomIds
                                        .contains(c.id)
                                    ? const Text(
                                        'typing…',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          fontStyle: FontStyle.italic,
                                          color: MlChatTone.online,
                                        ),
                                      )
                                    : Text(
                                        c.lastMessageContent == null
                                            ? 'No messages yet'
                                            : _stripMentionTokens(
                                                c.lastMessageContent!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.mlText.titleSmall.copyWith(
                                          color: hasUnread ? pal.bodyText : pal.bodySubtle,
                                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                              ),
                              if (hasUnread)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 1),
                                  constraints:
                                      const BoxConstraints(minWidth: 20),
                                  decoration: BoxDecoration(
                                    // Red unread badge — kept distinct from the
                                    // blue "read" tick. `unreadBadge`, not
                                    // `offline`: this one carries a numeral,
                                    // so it is measured as a ground for text
                                    // rather than as a dot.
                                    color: MlChatTone.unreadBadge,
                                    borderRadius: MlShape.pill,
                                  ),
                                  child: Text(
                                    c.unreadCount > 99
                                        ? '99+'
                                        : '${c.unreadCount}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: MlTokens.inkOnFill,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            );
          },
        );
      },
    );
  }
}

class _ContactsList extends ConsumerStatefulWidget {
  final ChatPalette pal;
  final ValueChanged<ChatConversation> onOpen;
  final ValueChanged<ChatContact> onProfile;
  const _ContactsList(
      {required this.pal, required this.onOpen, required this.onProfile});

  @override
  ConsumerState<_ContactsList> createState() => _ContactsListState();
}

class _ContactsListState extends ConsumerState<_ContactsList> {
  // Collapsed company/department sub-groups, keyed 'SECTION|Sub label' so the
  // same company collapses independently under ONLINE and OFFLINE.
  final Set<String> _collapsed = {};

  ChatPalette get pal => widget.pal;

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(chatContactsProvider);
    final online = ref.watch(onlineUsersProvider);
    return contacts.when(
      loading: () => _loading(pal),
      error: (e, _) => _errorBox(pal, '$e'),
      data: (list) {
        if (list.isEmpty) {
          return _Empty(
            pal: pal,
            icon: Icons.group_outlined,
            title: 'No contacts',
            message:
                'Contacts appear as your company and connections are set up.',
          );
        }
        final onlineList =
            list.where((c) => online.contains(c.userId)).toList();
        final offlineList =
            list.where((c) => !online.contains(c.userId)).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            ..._section('ONLINE', MlChatTone.online, onlineList),
            ..._section('OFFLINE', MlChatTone.offline, offlineList),
          ],
        );
      },
    );
  }

  // Groups a set of contacts into sub-groups: own company by department, other
  // companies by company name, plus Mine-Link. Own company first, then
  // Mine-Link, then connected/other companies.
  List<Widget> _section(String title, Color dot, List<ChatContact> members) {
    if (members.isEmpty) return const [];
    final subs = <String, List<ChatContact>>{};
    final order = <String, int>{};
    for (final c in members) {
      final sl = _subLabel(c);
      subs.putIfAbsent(sl, () => []).add(c);
      order[sl] = _subOrder(c);
    }
    final keys = subs.keys.toList()
      ..sort((a, b) {
        final o = order[a]!.compareTo(order[b]!);
        return o != 0 ? o : a.compareTo(b);
      });
    final w = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 2),
        child: Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: context.mlText.overline.copyWith(color: pal.bodyText)),
            const SizedBox(width: 6),
            Text('${members.length}',
                style: context.mlText.code(
                  color: pal.bodySubtle,
                  size: 11,
                  weight: FontWeight.w400,
                )),
          ],
        ),
      ),
    ];
    for (final k in keys) {
      final collapseKey = '$title|$k';
      final collapsed = _collapsed.contains(collapseKey);
      w.add(InkWell(
        onTap: () => setState(() {
          collapsed
              ? _collapsed.remove(collapseKey)
              : _collapsed.add(collapseKey);
        }),
        hoverColor: pal.bodyText.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 14, 4),
          child: Row(
            children: [
              Flexible(
                child: Text(k.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.overline.copyWith(color: pal.accent)),
              ),
              const SizedBox(width: 6),
              Text('${subs[k]!.length}',
                  style: context.mlText.code(
                    color: pal.bodySubtle,
                    size: 11,
                    weight: FontWeight.w400,
                  )),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: collapsed ? -0.25 : 0,
                duration: MlMotion.of(context, MlMotion.instant),
                curve: Curves.easeOut,
                child: Icon(Icons.expand_more, size: 15, color: pal.accent),
              ),
            ],
          ),
        ),
      ));
      if (!collapsed) {
        w.addAll(subs[k]!.map((c) => _ContactTile(
            pal: pal,
            contact: c,
            onOpen: widget.onOpen,
            onProfile: widget.onProfile)));
      }
    }
    return w;
  }

  String _subLabel(ChatContact c) {
    if (c.groupKind == ContactGroupKind.myCompany) return _dept(c.role);
    if (c.groupKind == ContactGroupKind.mineLink) return 'Mine-Link';
    return c.companyName ?? 'Other';
  }

  int _subOrder(ChatContact c) {
    switch (c.groupKind) {
      case ContactGroupKind.myCompany:
        return 0;
      case ContactGroupKind.mineLink:
        return 1;
      default:
        return 2;
    }
  }

  String _dept(String? role) {
    final r = (role ?? '').toLowerCase();
    if (r.contains('owner')) return 'Owners';
    if (r.contains('management')) return 'Management';
    if (r.contains('admin')) return 'Admin';
    if (r.contains('security')) return 'Security';
    if (r.contains('controller')) return 'Controllers';
    if (r.contains('driver')) return 'Drivers';
    return 'Team';
  }
}

class _ContactTile extends ConsumerWidget {
  final ChatPalette pal;
  final ChatContact contact;
  final ValueChanged<ChatConversation> onOpen;
  final ValueChanged<ChatContact> onProfile;
  const _ContactTile(
      {required this.pal,
      required this.contact,
      required this.onOpen,
      required this.onProfile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(onlineUsersProvider).contains(contact.userId);
    final isSelf =
        contact.userId == ref.read(messagingServiceProvider).currentUserId;
    return _ChatRowHover(
      pal: pal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      // No self-DMs: your own entry isn't tappable to open a chat (so it also
      // doesn't get the hover affordances — the avatar still opens your
      // profile).
      enabled: !isSelf,
      onTap: isSelf
          ? null
          : () async {
              try {
                final svc = ref.read(messagingServiceProvider);
                final room = await svc.getOrCreateDm(
                    otherUserId: contact.userId,
                    otherDisplayName: contact.displayName);
                ref.invalidateIfMounted(chatConversationsProvider);
                onOpen(room);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open chat. ${friendlyError(e)}')));
                }
              }
            },
      builder: (context, hovering) => Row(
          children: [
            Tooltip(
              message: 'View profile',
              child: AnimatedScale(
                scale: hovering ? 1.06 : 1.0,
                duration: MlMotion.of(context, MlMotion.instant),
                curve: Curves.easeOut,
                child: InkWell(
                  onTap: () => onProfile(contact),
                  customBorder: const CircleBorder(),
                  child: _MiniAvatar(
                      pal: pal,
                      label: contact.displayName,
                      isSuperAdmin: contact.isSuperAdmin,
                      online: isOnline),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSelf ? '${contact.displayName} (you)' : contact.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.titleSmall.copyWith(
                      color: pal.bodyText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _PresenceText(
                    pal: pal,
                    userId: contact.userId,
                    dbLastSeen: contact.lastSeenAt,
                    fontSize: 12,
                  ),
                ],
              ),
            ),
            if (contact.isBlocked)
              Tooltip(
                message: contact.blockedTooltip,
                child: _Pill(
                    icon: contact.isBlockedByExpiry
                        ? Icons.lock_clock_rounded
                        : Icons.block_rounded,
                    label: contact.blockedLabel,
                    color: contact.isBlockedByExpiry
                        ? MlTokens.amber700
                        : MlTokens.red600),
              )
            else if (!isSelf)
              // Trailing "start chat" affordance — fills into an accent pill on
              // hover so the row reads as a clear call to action (CPS parity).
              AnimatedContainer(
                duration: MlMotion.of(context, MlMotion.instant),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hovering
                      ? pal.accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                ),
                child: Icon(
                  hovering
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded,
                  color: pal.accent,
                  size: 18,
                ),
              ),
          ],
        ),
    );
  }
}

// ===========================================================================
// THREAD (messages + composer)
// ===========================================================================

class _ThreadView extends ConsumerStatefulWidget {
  final ChatPalette pal;
  final ChatConversation room;
  final VoidCallback onBack;
  final VoidCallback? onAvatarProfile;
  final void Function(String userId)? onOpenUser;
  const _ThreadView({
    required this.pal,
    required this.room,
    required this.onBack,
    required this.onAvatarProfile,
    this.onOpenUser,
  });

  @override
  ConsumerState<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends ConsumerState<_ThreadView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _dragging = false;
  String _myName = 'Someone';
  DateTime? _lastTyping;

  // Unread separator: captured once per room when the thread opens (BEFORE
  // marking read) so the "N unread messages" line stays anchored above the
  // first unread message even after everything is marked read.
  String? _capturedRoomId;
  int _unreadCount = 0;
  String? _unreadAnchorId;

  /// Message currently being replied to (null when not replying).
  ChatMessage? _replyTo;

  /// Per-message keys so a tapped reply-quote can scroll to the original.
  final Map<String, GlobalKey> _msgKeys = {};
  GlobalKey _keyFor(String id) => _msgKeys.putIfAbsent(id, () => GlobalKey());

  void _scrollToMessage(String id) {
    final ctx = _msgKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: MlMotion.of(context, MlMotion.enter),
          alignment: 0.3,
          curve: Curves.easeOut);
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onType);
    ref.read(myChatIdentityProvider.future).then((id) {
      if (mounted) _myName = id.name;
    });
  }

  void _onType() {
    if (_controller.text.trim().isEmpty) return;
    final now = DateTime.now();
    if (_lastTyping == null ||
        now.difference(_lastTyping!) > const Duration(milliseconds: 1500)) {
      _lastTyping = now;
      final svc = ref.read(messagingServiceProvider);
      // Per-room channel (drives the conversation header "…is typing").
      ref.read(typingProvider(widget.room.id).notifier).sendTyping(_myName);
      // Personal-inbox ping to each recipient (drives their floating disc).
      final others =
          widget.room.participantIds.where((p) => p != svc.currentUserId).toList();
      svc.pingTyping(others, _myName, roomId: widget.room.id);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onType);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendAttachments(
      List<({Uint8List bytes, String name})> picks) async {
    if (picks.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final svc = ref.read(messagingServiceProvider);
      final id = await ref.read(myChatIdentityProvider.future);
      for (final p in picks) {
        final up = await svc.uploadAttachment(
            bytes: p.bytes, fileName: p.name, roomId: widget.room.id);
        await svc.sendMessage(
          roomId: widget.room.id,
          content: '',
          senderName: id.name,
          senderAvatarUrl: id.avatarUrl,
          fileUrl: up.url,
          fileType: up.type,
          fileName: up.name,
        );
      }
      ref.invalidateIfMounted(chatConversationsProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not send attachment. ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _maybePlay(String role, [String? senderId]) {
    // Reached after the send await; closing the thread mid-send would
    // otherwise throw on `ref` rather than simply skipping the tone.
    if (!mounted) return;
    final prefs = ref.read(chatPrefsProvider);
    if (!prefs.soundsEnabled) return;
    if (role == 'send') {
      ChatSoundService.instance.play('send');
    } else {
      // Per-contact override falls back to the default incoming tone.
      final id = prefs.resolveIncoming(senderId);
      ChatSoundService.instance.playSelection(id, prefs.customSoundPath);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final svc = ref.read(messagingServiceProvider);
      final id = await ref.read(myChatIdentityProvider.future);
      // Parse any @[Display](user:id) tokens into a mentions payload.
      final mentions = _kMentionToken
          .allMatches(text)
          .map((m) => ChatMention(userId: m.group(2)!, displayName: m.group(1)!))
          .toList();
      await svc.sendMessage(
        roomId: widget.room.id,
        content: text,
        senderName: id.name,
        senderAvatarUrl: id.avatarUrl,
        replyToId: _replyTo?.id,
        mentions: mentions,
      );
      _controller.clear();
      if (_replyTo != null && mounted) setState(() => _replyTo = null);
      _maybePlay('send');
      // Clear my typing indicator on the recipients instantly (no lingering).
      _lastTyping = null;
      final others = widget.room.participantIds
          .where((p) => p != svc.currentUserId)
          .toList();
      // Fire-and-forget on purpose: the message is already sent, and a failed
      // typing-indicator broadcast must not surface as "Could not send".
      // Explicitly `unawaited` + swallowed — before this, the enclosing
      // try/catch looked like it covered them but could not: an unawaited
      // rejection escapes the try and lands as an unhandled zone error.
      unawaited(
        ref
            .read(typingProvider(widget.room.id).notifier)
            .sendStop(_myName)
            .catchError((Object e) => _log.d('sendStop failed: $e')),
      );
      unawaited(
        svc
            .pingTyping(others, _myName, stop: true, roomId: widget.room.id)
            .catchError((Object e) => _log.d('pingTyping(stop) failed: $e')),
      );
      ref.invalidateIfMounted(chatConversationsProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not send. ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final room = widget.room;

    final myId = ref.read(messagingServiceProvider).currentUserId;
    final messages = ref.watch(roomMessagesProvider(room.id));
    // Play a tone when a new message arrives from the other side.
    ref.listen(roomMessagesProvider(room.id), (prev, next) {
      final prevList = prev?.valueOrNull;
      final nextList = next.valueOrNull;
      if (prevList == null || nextList == null) return;
      if (nextList.length > prevList.length &&
          nextList.last.senderId != myId) {
        _maybePlay('incoming', nextList.last.senderId);
        // A message arrived → the sender has clearly stopped typing; clear the
        // indicator immediately rather than waiting for it to time out.
        ref
            .read(typingProvider(room.id).notifier)
            .clearName(nextList.last.senderName);
        // The thread is open → these are read immediately.
        ref.read(messagingServiceProvider).markRoomRead(room.id);
      }
    });
    final reactions =
        ref.watch(roomReactionsProvider(room.id)).valueOrNull ?? const [];
    final reactionsByMsg = <String, List<ChatReaction>>{};
    for (final r in reactions) {
      reactionsByMsg.putIfAbsent(r.messageId, () => []).add(r);
    }

    final onlineIds = ref.watch(onlineUsersProvider);
    final otherId = room.type == ChatRoomType.dm
        ? room.participantIds.firstWhere((p) => p != myId, orElse: () => '')
        : '';
    final partnerOnline = otherId.isNotEmpty && onlineIds.contains(otherId);
    DateTime? partnerLastSeen;
    if (otherId.isNotEmpty) {
      // Live presence-leave stamp wins; DB last_seen_at is the fallback.
      partnerLastSeen = ref.watch(presenceLastSeenProvider)[otherId];
      if (partnerLastSeen == null) {
        for (final c in (ref.watch(chatContactsProvider).valueOrNull ??
            const <ChatContact>[])) {
          if (c.userId == otherId) {
            partnerLastSeen = c.lastSeenAt;
            break;
          }
        }
      }
    }
    final typing = ref.watch(typingProvider(room.id));
    final headerSubtitle = typing.isNotEmpty
        ? (typing.length == 1 ? '${typing.first} is typing…' : 'Typing…')
        : (room.type == ChatRoomType.dm
            ? (partnerOnline
                ? 'Online'
                : (partnerLastSeen != null
                    ? 'Last seen ${_relativeTime(partnerLastSeen)}'
                    : 'Offline'))
            : 'Group');

    return Column(
      children: [
        _ContentHeader(
          pal: pal,
          title: room.name,
          subtitle: headerSubtitle,
          isGroup: room.type != ChatRoomType.dm,
          onBack: widget.onBack,
          onAvatarTap: widget.onAvatarProfile,
          onInfo: widget.onAvatarProfile,
          online: room.type == ChatRoomType.dm ? partnerOnline : null,
        ),
        Container(height: 1, color: pal.divider),
        Expanded(
          child: DropTarget(
            onDragEntered: (_) => setState(() => _dragging = true),
            onDragExited: (_) => setState(() => _dragging = false),
            onDragDone: (detail) async {
              setState(() => _dragging = false);
              final picks = <({Uint8List bytes, String name})>[];
              for (final f in detail.files) {
                picks.add((bytes: await f.readAsBytes(), name: f.name));
              }
              await _sendAttachments(picks);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: messages.when(
                    loading: () => _loading(pal),
                    error: (e, _) => _errorBox(pal, '$e'),
                    data: (list) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToBottom());
                      if (list.isEmpty) {
                        return _Empty(
                          pal: pal,
                          icon: Icons.waving_hand_outlined,
                          title: 'Say hello',
                          message:
                              'No messages yet — send the first one, or drop an image here.',
                        );
                      }
                      final msgById = {for (final mm in list) mm.id: mm};
                      // Capture the unread boundary once per room (before the
                      // messages are marked read), then mark read next frame so
                      // the "N unread messages" line stays put above the first
                      // unread message.
                      if (_capturedRoomId != room.id) {
                        _capturedRoomId = room.id;
                        final unread = list
                            .where(
                                (m) => m.senderId != myId && m.readAt == null)
                            .toList();
                        _unreadCount = unread.length;
                        _unreadAnchorId =
                            unread.isNotEmpty ? unread.first.id : null;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ref
                              .read(messagingServiceProvider)
                              .markRoomRead(room.id);
                        });
                      }
                      return ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final m = list[i];
                          final mine = m.senderId == myId;
                          // CPS shows the sender name + divider inside every
                          // incoming bubble (DM and group alike).
                          final showName = !mine;
                          final replyTo = m.replyToId != null
                              ? msgById[m.replyToId]
                              : null;
                          final bubble = KeyedSubtree(
                            key: _keyFor(m.id),
                            child: _BubbleRow(
                              pal: pal,
                              message: m,
                              mine: mine,
                              showName: showName,
                              reactions: reactionsByMsg[m.id] ?? const [],
                              myId: myId,
                              onReact: (emoji) => ref
                                  .read(messagingServiceProvider)
                                  .toggleReaction(
                                      roomId: room.id,
                                      messageId: m.id,
                                      emoji: emoji),
                              onReply: () => setState(() => _replyTo = m),
                              replyTo: replyTo,
                              onTapQuote: replyTo == null
                                  ? null
                                  : () => _scrollToMessage(replyTo.id),
                              onMentionTap: (mention) =>
                                  widget.onOpenUser?.call(mention.userId),
                            ),
                          );
                          // Leading separators: a date chip when the calendar
                          // day changes, and the "N unread messages" line above
                          // the first unread message.
                          final prev = i > 0 ? list[i - 1] : null;
                          final leading = <Widget>[];
                          if (prev == null ||
                              !_sameDay(prev.timestamp, m.timestamp)) {
                            leading.add(
                                _DateSeparator(pal: pal, date: m.timestamp));
                          }
                          if (_unreadAnchorId != null &&
                              m.id == _unreadAnchorId &&
                              _unreadCount > 0) {
                            leading.add(_UnreadSeparator(
                                pal: pal, count: _unreadCount));
                          }
                          if (leading.isEmpty) return bubble;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [...leading, bubble],
                          );
                        },
                      );
                    },
                  ),
                ),
                if (_dragging)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: pal.accent.withValues(alpha: 0.12),
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: pal.accent.withValues(alpha: 0.08),
                          borderRadius: MlShape.radiusLarge,
                          border: Border.all(color: pal.accent, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.upload_file_rounded,
                                size: 34, color: pal.accent),
                            const SizedBox(height: 8),
                            Text('Drop to send',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: pal.accent)),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_sending)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _UploadingChip(pal: pal),
                  ),
              ],
            ),
          ),
        ),
        _TypingIndicatorRow(
          pal: pal,
          visible: typing.isNotEmpty,
          name: typing.isNotEmpty ? typing.first : '',
        ),
        Container(height: 1, color: pal.divider),
        _Composer(
          pal: pal,
          controller: _controller,
          sending: _sending,
          onSend: _send,
          onAttach: _sendAttachments,
          replyTo: _replyTo,
          onCancelReply: () => setState(() => _replyTo = null),
        ),
      ],
    );
  }
}

/// Inline mention-token format shared by the composer, bubbles and previews:
/// `@[Display Name](user:USER_ID)`. group(1)=display, group(2)=userId.
final RegExp _kMentionToken = RegExp(r'@\[([^\]]+)\]\(user:([^)]+)\)');

/// Replaces mention tokens with a plain `@Display` (for list/reply previews).
String _stripMentionTokens(String text) =>
    text.replaceAllMapped(_kMentionToken, (m) => '@${m.group(1)}');

bool _sameDay(DateTime a, DateTime b) {
  final la = MlTime.sast(a);
  final lb = MlTime.sast(b);
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

String _ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

/// CPS date-separator label: Today / Yesterday / weekday (last 7 days) /
/// "14th Jan 2026" for anything older.
String _dateSeparatorLabel(DateTime dt) {
  final d = MlTime.sast(dt);
  // `MlTime.today()`, because the line above already converted. The
  // separator compared a South African wall clock against the DEVICE's
  // day, so "Today" and "Yesterday" were decided in two different
  // zones and a message could sit under the wrong one.
  final today = MlTime.today();
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff <= 7 && diff > 0) return DateFormat('EEEE').format(d);
  return '${d.day}${_ordinalSuffix(d.day)} ${DateFormat('MMM yyyy').format(d)}';
}

/// Relative "last seen" phrasing. The vocabulary is [MlTime.ago]'s, which this
/// one supplied most of - it was the only copy of nine with a `yesterday`.
String _relativeTime(DateTime dt) => MlTime.ago(dt);

/// CPS-style presence line: "Online" (green) / "Last seen X" / "Offline".
/// Fully real-time — watches live presence (online set + last-seen stamps) and
/// falls back to the DB `last_seen_at`. Used on contact rows, conversation
/// rows, the thread header and the profile.
class _PresenceText extends ConsumerWidget {
  final ChatPalette pal;
  final String? userId;
  final DateTime? dbLastSeen;
  final double fontSize;
  final FontWeight? weight;

  /// Typing beats presence where enabled. Conversation rows pass false —
  /// their preview line already becomes "typing…", so showing it here too
  /// would double it up.
  final bool showTyping;
  const _PresenceText({
    required this.pal,
    this.userId,
    this.dbLastSeen,
    this.fontSize = 11,
    this.weight,
    this.showTyping = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typing = showTyping &&
        userId != null &&
        ref.watch(typingInboxProvider).userIds.contains(userId);
    if (typing) {
      return Text('typing…',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight ?? FontWeight.w600,
              fontStyle: FontStyle.italic,
              color: MlChatTone.online));
    }
    final online =
        userId != null && ref.watch(onlineUsersProvider).contains(userId);
    if (online) {
      return Text('Online',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight ?? FontWeight.w600,
              color: MlChatTone.online));
    }
    final live =
        userId != null ? ref.watch(presenceLastSeenProvider)[userId] : null;
    // `mlLastSeen`, not `live ?? dbLastSeen`: the live channel only ever holds
    // the stamp for THIS session, so a contact whose database heartbeat is
    // newer than the moment they dropped off the channel was being reported as
    // last seen when they left the tab.
    final last = mlLastSeen(dbLastSeen: dbLastSeen, liveLastSeen: live);
    final label = last != null ? 'Last seen ${_relativeTime(last)}' : 'Offline';
    return Text(label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            fontSize: fontSize, fontWeight: weight, color: pal.bodySubtle));
  }
}

/// "N unread messages" divider shown above the first unread message (CPS).
class _UnreadSeparator extends StatelessWidget {
  final ChatPalette pal;
  final int count;
  const _UnreadSeparator({required this.pal, required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 unread message' : '$count unread messages';
    // Unread = red (matches the unread badge + disc), distinct from read-blue.
    const red = MlChatTone.unread;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Expanded(
              child: Divider(
                  color: red.withValues(alpha: 0.4), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: const TextStyle(
                    color: red, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          Expanded(
              child: Divider(
                  color: red.withValues(alpha: 0.4), thickness: 1)),
        ],
      ),
    );
  }
}

/// Delivery tick shown on a conversation row when my message is the latest:
/// ✓ sent (grey) / ✓✓ delivered (grey) / ✓✓ read (blue).
class _ConvTick extends StatelessWidget {
  final ChatPalette pal;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  const _ConvTick({required this.pal, this.readAt, this.deliveredAt});

  @override
  Widget build(BuildContext context) {
    // Same distinctive scheme as the bubble ticks: sent = grey, delivered
    // (unread) = red, read = vivid blue.
    final Color color;
    final IconData icon;
    if (readAt != null) {
      color = pal.isDark ? MlChatTone.readOnRowDark : MlChatTone.readOnRowLight;
      icon = Icons.done_all_rounded;
    } else if (deliveredAt != null) {
      color = MlChatTone.unread;
      icon = Icons.done_all_rounded;
    } else {
      color = pal.bodySubtle;
      icon = Icons.done_rounded;
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

/// Centered pill separating messages from different calendar days (CPS look).
class _DateSeparator extends StatelessWidget {
  final ChatPalette pal;
  final DateTime date;
  const _DateSeparator({required this.pal, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color:
                Color.alphaBlend(pal.accent.withValues(alpha: 0.08), pal.body),
            borderRadius: MlShape.radiusLargeIncreased,
            border: Border.all(color: pal.divider),
          ),
          child: Text(
            _dateSeparatorLabel(date),
            style: context.mlText.titleSmall.copyWith(color: pal.bodyText),
          ),
        ),
      ),
    );
  }
}

/// Slim animated row between the message list and composer that fades in while
/// the other participant is typing (mirrors CPS's in-thread typing indicator).
class _TypingIndicatorRow extends StatelessWidget {
  final ChatPalette pal;
  final bool visible;
  final String name;
  const _TypingIndicatorRow(
      {required this.pal, required this.visible, required this.name});

  @override
  Widget build(BuildContext context) {
    final first =
        name.trim().isEmpty ? 'Someone' : name.trim().split(RegExp(r'\s+')).first;
    return AnimatedSize(
      duration: MlMotion.of(context, MlMotion.instant),
      alignment: Alignment.topCenter,
      curve: Curves.easeOut,
      child: visible
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              color: pal.header.withValues(alpha: pal.isDark ? 0.2 : 0.3),
              child: Row(
                children: [
                  _TypingDots(color: pal.bodySubtle),
                  const SizedBox(width: 8),
                  Text(
                    '$first is typing…',
                    style: context.mlText.bodySmall.copyWith(
                      color: pal.bodySubtle,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

class _TypingDots extends StatefulWidget {
  final Color color;
  const _TypingDots({required this.color});
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A LOOP cannot be shortened into submission — collapsing 1100ms to 1ms
    // would run this wave at a thousand frames a second. The only right answer
    // for a repeating animation is not to start it.
    //
    // The dots still appear: "somebody is typing" is information, and only the
    // wave is decoration. But simply freezing the controller is not enough —
    // the three dots are 120° apart in the sine below, so a stopped controller
    // leaves them at three DIFFERENT opacities, which reads as a rendering
    // fault rather than as a deliberate still. `_reduce` makes build draw them
    // at one flat opacity instead.
    _reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduce) {
      if (_c.isAnimating) _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final wave =
                (math.sin(_c.value * 2 * math.pi - i * (2 * math.pi / 3)) + 1) /
                    2;
            // Mid-wave for all three when motion is off — one steady row of
            // dots, rather than three frozen at whatever phase they happened
            // to hold.
            final op = _reduce ? 0.675 : 0.35 + 0.65 * wave;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: op.clamp(0.0, 1.0)),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _UploadingChip extends StatelessWidget {
  final ChatPalette pal;
  const _UploadingChip({required this.pal});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: pal.accent,
        borderRadius: MlShape.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: pal.accentText),
          ),
          const SizedBox(width: 8),
          Text('Sending…',
              style: context.mlText.labelMedium.copyWith(
                color: pal.accentText,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

/// Renders message body text with any `@[Display](user:id)` mention tokens
/// shown as inline highlighted chips (CPS-style). Tapping a chip invokes
/// [onMentionTap] with the mentioned user.
class _MessageText extends StatelessWidget {
  final ChatPalette pal;
  final String text;
  final Color color;
  final void Function(ChatMention mention)? onMentionTap;
  const _MessageText({
    required this.pal,
    required this.text,
    required this.color,
    this.onMentionTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = context.mlText.bodyMedium.copyWith(color: color);
    final matches = _kMentionToken.allMatches(text).toList();
    if (matches.isEmpty) return Text(text, style: baseStyle);

    // Chip colours derive from the accent so mentions read on any bubble.
    final chipBg = pal.accent.withValues(alpha: 0.16);
    final chipFg = pal.isDark ? pal.accent : pal.senderName;

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in matches) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: baseStyle));
      }
      final display = m.group(1)!;
      final userId = m.group(2)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: GestureDetector(
            onTap: onMentionTap == null
                ? null
                : () => onMentionTap!(
                    ChatMention(userId: userId, displayName: display)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: MlShape.radiusSmall,
              ),
              child: Text('@$display',
                  style: context.mlText.titleSmall.copyWith(
                    color: chipFg,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  )),
            ),
          ),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: baseStyle));
    }
    return Text.rich(TextSpan(children: spans));
  }
}

/// Reply-quote block — shown inside a bubble (the quoted original) and in the
/// composer preview bar. Ported from CPS's ReplyQuoteBlock, palette-aware.
class _ReplyQuote extends StatelessWidget {
  final ChatPalette pal;
  final String senderName;
  final String? previewText;
  final bool hasAttachment;
  final String? attachmentName;

  /// Whether the CURRENT bubble is mine (affects colours when embedded).
  final bool mine;
  final bool composerPreview;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  const _ReplyQuote({
    required this.pal,
    required this.senderName,
    this.previewText,
    this.hasAttachment = false,
    this.attachmentName,
    this.mine = false,
    this.composerPreview = false,
    this.onTap,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final Color barColor;
    final Color bgColor;
    final Color nameColor;
    final Color textColor;
    if (composerPreview) {
      barColor = pal.accent;
      bgColor = pal.tabSelectedBg;
      nameColor = pal.accent;
      textColor = pal.bodySubtle;
    } else {
      // Inside a bubble. Every value comes from the palette rather than from
      // an alpha applied here — see [ChatPalette.quoteGround] for why the
      // obvious way round (tint with the ink, then write the ink on it) cut
      // the ratio on thirteen of the eighteen palettes and was invisible for
      // as long as the dock had no renders.
      //
      // The bar is a 3px graphic, not text, so it keeps the accent on an
      // incoming quote; WCAG's 4.5:1 governs glyphs.
      barColor = mine ? pal.outgoingText : pal.accent;
      bgColor = pal.quoteGround(mine: mine);
      nameColor = pal.quoteNameInk(mine: mine);
      textColor = pal.quotePreviewInk(mine: mine);
    }

    String preview = '';
    if (hasAttachment && (attachmentName?.isNotEmpty ?? false)) {
      preview = '📎 $attachmentName';
    } else if (previewText?.trim().isNotEmpty ?? false) {
      preview = _stripMentionTokens(previewText!.trim());
      if (preview.length > 80) preview = '${preview.substring(0, 80)}…';
    }

    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: MlShape.radiusSmall,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: MlShape.radiusExtraSmall,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.labelMedium.copyWith(
                      color: nameColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (preview.isNotEmpty)
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.bodySmall.copyWith(color: textColor),
                    ),
                ],
              ),
            ),
            if (onCancel != null)
              GestureDetector(
                onTap: onCancel,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded,
                      size: 18, color: pal.bodySubtle),
                ),
              ),
          ],
        ),
      ),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: box) : box;
  }
}

class _Bubble extends StatelessWidget {
  final ChatPalette pal;
  final ChatMessage message;
  final bool mine;
  final bool showName;
  final ChatMessage? replyTo;
  final VoidCallback? onTapQuote;
  final void Function(ChatMention mention)? onMentionTap;
  const _Bubble(
      {required this.pal,
      required this.message,
      required this.mine,
      required this.showName,
      this.replyTo,
      this.onTapQuote,
      this.onMentionTap});

  @override
  Widget build(BuildContext context) {
    final bg = mine ? pal.outgoingBubble : pal.incomingBubble;
    final fg = mine ? pal.outgoingText : pal.incomingText;
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(MlShape.largeIncreased),
            topRight: const Radius.circular(MlShape.largeIncreased),
            bottomLeft: Radius.circular(mine ? 20 : 4),
            bottomRight: Radius.circular(mine ? 4 : 20),
          ),
          border: mine ? null : Border.all(color: pal.divider),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showName)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: pal.bubbleSeparator)),
                ),
                child: Text(
                  message.senderName,
                  style: context.mlText.labelMedium.copyWith(
                    color: pal.senderName,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (replyTo != null) ...[
              _ReplyQuote(
                pal: pal,
                senderName: replyTo!.senderName,
                previewText: replyTo!.content,
                hasAttachment: replyTo!.hasAttachment,
                attachmentName: replyTo!.fileName,
                mine: mine,
                onTap: onTapQuote,
              ),
              const SizedBox(height: 6),
            ],
            if (message.hasAttachment) _attachment(fg),
            if (message.content.trim().isNotEmpty) ...[
              if (message.hasAttachment) const SizedBox(height: 6),
              _MessageText(
                  pal: pal,
                  text: message.content,
                  color: fg,
                  onMentionTap: onMentionTap),
            ],
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mine) ...[
                  // Distinctive per-state colours that stay legible on EVERY
                  // theme: sent = faint neutral, delivered (unread) = red,
                  // read = blue — each shade + a contrasting edge is picked
                  // from the bubble brightness so it never blends into a
                  // same-hue bubble.
                  Builder(builder: (_) {
                    final read = message.readAt != null;
                    final delivered = message.deliveredAt != null;
                    final darkBubble =
                        ThemeData.estimateBrightnessForColor(
                                pal.outgoingBubble) ==
                            Brightness.dark;
                    final Color c;
                    if (read) {
                      c = darkBubble
                          ? MlChatTone.readOnBubbleDark
                          : MlChatTone.readOnBubbleLight;
                    } else if (delivered) {
                      c = darkBubble
                          ? MlChatTone.deliveredOnBubbleDark
                          : MlChatTone.deliveredOnBubbleLight;
                    } else {
                      c = fg.withValues(alpha: darkBubble ? 0.6 : 0.5);
                    }
                    return Icon(
                      (read || delivered)
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 16,
                      color: c,
                      shadows: [
                        Shadow(
                          color: (darkBubble ? MlTokens.slate950 : MlTokens.inkOnFill)
                              .withValues(alpha: 0.45),
                          blurRadius: 1.5,
                        ),
                      ],
                    );
                  }),
                  const SizedBox(width: 4),
                ],
                Text(
                  MlTime.clock(message.timestamp),
                  style: context.mlText.labelSmall.copyWith(
                    // `fg` with NO extra alpha.
                    //
                    // `fg` is already the ink the palette chose for this
                    // bubble; taking 75% of it moves it back toward the
                    // bubble and eats the contrast the palette was picked
                    // for. On the default cyan bubble that put the timestamp
                    // at **1.46:1**. It stays quieter than the message by
                    // being `labelSmall` at w500 beside a w400 body - size
                    // and weight, which is the same answer `textFaint`, the
                    // pager and the driver hero all arrived at.
                    color: fg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
  }

  /// P3-52 / P3-53 (client ruling 3, 2026-08-12): `fileUrl` no longer holds a
  /// URL. Both attachment buckets are now PRIVATE, so the stored value is a
  /// bucket-qualified object path that has to be signed before anything can
  /// open it. Signing is a round-trip, hence the FutureBuilder — and hence the
  /// memoised resolver, because a chat bubble rebuilds on every new message,
  /// reaction, hover and scroll, and re-signing on each one would flash the
  /// image back to its placeholder every time.
  ///
  /// A null result means the viewer is not a participant of that room or ticket,
  /// or the object is gone. That renders as a stated "unavailable" chip rather
  /// than a broken image — the same rule P10-D2 settled for POD photos.
  Widget _attachment(Color fg) {
    return FutureBuilder<String?>(
      future: resolveAttachmentUrlCached(message.fileUrl),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _attachmentPlaceholder(context, fg, spinner: true);
        }
        final url = snap.data;
        if (url == null) {
          return _attachmentPlaceholder(context, fg, spinner: false);
        }
        return _attachmentBody(context, fg, url);
      },
    );
  }

  Widget _attachmentPlaceholder(BuildContext context, Color fg,
          {required bool spinner}) =>
      Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.10),
          borderRadius: MlShape.radiusMedium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: fg.withValues(alpha: 0.5)),
              )
            else
              Icon(Icons.lock_outline, size: 18, color: fg.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                spinner
                    ? (message.fileName ?? 'Attachment')
                    : 'Attachment unavailable',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.titleSmall.copyWith(
                  color: fg.withValues(alpha: spinner ? 1 : 0.7),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _attachmentBody(BuildContext context, Color fg, String url) {
    if (message.fileType == 'image') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ClipRRect(
          borderRadius: MlShape.radiusMedium,
          child: GestureDetector(
            onTap: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 240, maxHeight: 220),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (c, _) => Container(
                  width: 200,
                  height: 140,
                  color: fg.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: fg.withValues(alpha: 0.5)),
                  ),
                ),
                errorWidget: (c, _, _) => Container(
                  width: 200,
                  height: 100,
                  color: fg.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined,
                      color: fg.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.10),
          borderRadius: MlShape.radiusMedium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, size: 22, color: fg),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.fileName ?? 'File',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.titleSmall.copyWith(color: fg),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download_rounded,
                size: 18, color: fg.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

/// Wraps a [_Bubble] with hover-to-react and the reaction chips below it. On
/// hover a small "add reaction" button appears; a popup offers quick emoji.
class _BubbleRow extends StatefulWidget {
  final ChatPalette pal;
  final ChatMessage message;
  final bool mine;
  final bool showName;
  final List<ChatReaction> reactions;
  final String? myId;
  final ValueChanged<String> onReact;
  final ChatMessage? replyTo;
  final VoidCallback onReply;
  final VoidCallback? onTapQuote;
  final void Function(ChatMention mention)? onMentionTap;
  const _BubbleRow({
    required this.pal,
    required this.message,
    required this.mine,
    required this.showName,
    required this.reactions,
    required this.myId,
    required this.onReact,
    required this.onReply,
    this.replyTo,
    this.onTapQuote,
    this.onMentionTap,
  });

  @override
  State<_BubbleRow> createState() => _BubbleRowState();
}

class _BubbleRowState extends State<_BubbleRow> {
  bool _hover = false;
  bool _pickerOpen = false;
  static const _quick = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  // Floating hover "react" button — sits at the top inner corner of the bubble
  // (CPS puts its reply affordance here), clear of the sender avatar.
  Widget _reactToggle() => Tooltip(
        message: 'React',
        child: InkWell(
          onTap: () => setState(() => _pickerOpen = !_pickerOpen),
          customBorder: const CircleBorder(),
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.pal.body,
              shape: BoxShape.circle,
              border: Border.all(color: widget.pal.divider),
              boxShadow: MlTokens.shadowSm,
            ),
            child: Icon(
                _pickerOpen
                    ? Icons.close_rounded
                    : Icons.add_reaction_outlined,
                size: 14,
                color: widget.pal.bodySubtle),
          ),
        ),
      );

  // Floating hover "reply" button (CPS affordance), beside the react button.
  Widget _replyBtn() => Tooltip(
        message: 'Reply',
        child: InkWell(
          onTap: widget.onReply,
          customBorder: const CircleBorder(),
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.pal.body,
              shape: BoxShape.circle,
              border: Border.all(color: widget.pal.divider),
              boxShadow: MlTokens.shadowSm,
            ),
            child: Icon(Icons.reply_rounded,
                size: 14, color: widget.pal.bodySubtle),
          ),
        ),
      );

  // Sender avatar shown beside the bubble (outer side), CPS-style.
  Widget _avatar() {
    final pal = widget.pal;
    final url = widget.message.senderAvatarUrl;
    final provider = (url != null && url.isNotEmpty) ? NetworkImage(url) : null;
    final parts = widget.message.senderName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.take(2).map((p) => p[0].toUpperCase()).join();
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: CircleAvatar(
        radius: 15,
        backgroundColor: pal.accent,
        backgroundImage: provider,
        child: provider == null
            ? Text(initials,
                style: context.mlText.labelSmall.copyWith(
                  color: pal.accentText,
                  fontWeight: FontWeight.bold,
                ))
            : null,
      ),
    );
  }

  Widget _pickerBar() {
    final pal = widget.pal;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: pal.body,
        borderRadius: MlShape.pill,
        border: Border.all(color: pal.divider),
        boxShadow: MlTokens.shadowMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _quick
            .map((e) => InkWell(
                  onTap: () {
                    widget.onReact(e);
                    setState(() => _pickerOpen = false);
                  },
                  borderRadius: MlShape.pill,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final mine = widget.mine;

    final byEmoji = <String, List<ChatReaction>>{};
    for (final r in widget.reactions) {
      byEmoji.putIfAbsent(r.emoji, () => []).add(r);
    }

    final reactionChips = byEmoji.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding:
                const EdgeInsets.only(top: 1, bottom: 6, left: 2, right: 2),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: byEmoji.entries.map((e) {
                final reacted = widget.myId != null &&
                    e.value.any((r) => r.userId == widget.myId);
                return GestureDetector(
                  onTap: () => widget.onReact(e.key),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: reacted
                          ? pal.accent.withValues(alpha: 0.18)
                          : pal.tabSelectedBg,
                      borderRadius: MlShape.pill,
                      border:
                          Border.all(color: reacted ? pal.accent : pal.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The palette's ink, not the ambient theme's.
                        //
                        // With no colour this inherits `DefaultTextStyle`,
                        // which belongs to the APP theme — while the chip
                        // around it is painted from the CHAT palette, and the
                        // two are chosen independently. A user on light app
                        // theme with a dark chat palette got the app's dark
                        // ink on the palette's dark chip: 1.78:1. Colour
                        // emoji ignore the colour, which is exactly why this
                        // survived — it only shows when the glyph falls back
                        // to monochrome.
                        Text(e.key,
                            style: TextStyle(fontSize: 12, color: pal.bodyText)),
                        const SizedBox(width: 3),
                        Text('${e.value.length}',
                            style: context.mlText.labelSmall.copyWith(
                              color: pal.bodyText,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          mainAxisAlignment:
              mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Sender avatar on the outer side of the bubble (CPS look).
            if (!mine) ...[_avatar(), const SizedBox(width: 8)],
            Flexible(
              child: Column(
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (_pickerOpen) _pickerBar(),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Bubble(
                        pal: pal,
                        message: widget.message,
                        mine: mine,
                        showName: widget.showName,
                        replyTo: widget.replyTo,
                        onTapQuote: widget.onTapQuote,
                        onMentionTap: widget.onMentionTap,
                      ),
                      if (_hover || _pickerOpen)
                        Positioned(
                          top: -8,
                          right: mine ? null : -8,
                          left: mine ? -8 : null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!_pickerOpen) ...[
                                _replyBtn(),
                                const SizedBox(width: 4),
                              ],
                              _reactToggle(),
                            ],
                          ),
                        ),
                    ],
                  ),
                  reactionChips,
                ],
              ),
            ),
            if (mine) ...[const SizedBox(width: 8), _avatar()],
          ],
        ),
      ),
    );
  }
}

const List<String> _kEmojis = [
  '😀','😁','😂','🤣','😊','😅','😉','😍','😘','😎','🤩','🥳','😇','🙂','🙃','😌',
  '😴','🤔','🤨','😐','😑','😏','🙄','😬','😢','😭','😤','😠','😡','🤯','😳','🥺',
  '😱','😨','😰','😥','🤗','🤭','🤫','🤝','🙏','👍','👎','👌','✌️','🤞','💪','👏',
  '🙌','👋','🤙','☝️','✅','❌','❗','❓','⚠️','🔥','⭐','🎉','💯','❤️','🧡','💛',
  '💚','💙','💜','🖤','🚚','⛏️','🏗️','📦','📍','📌','⏰','📅','💬','📎','🔔','⚡',
];

/// Local predictive-text vocabulary (common words + MineLink domain terms).
/// Used to complete the word being typed, WhatsApp-style.
const List<String> _kPredict = [
  'the', 'and', 'you', 'are', 'for', 'with', 'have', 'this', 'that', 'your',
  'from', 'will', 'would', 'could', 'should', 'please', 'thanks', 'thank',
  'hello', 'morning', 'afternoon', 'evening', 'okay', 'sure', 'yes', 'not',
  'now', 'soon', 'message', 'messages', 'sending', 'send', 'sent', 'received',
  'receive', 'delivery', 'delivered', 'deliver', 'truck', 'trucks', 'driver',
  'drivers', 'load', 'loaded', 'loading', 'offload', 'offloading', 'route',
  'routes', 'waybill', 'waybills', 'tonnage', 'tons', 'mine', 'mines', 'buyer',
  'buyers', 'transporter', 'transporters', 'supplier', 'suppliers', 'dispatch',
  'dispatched', 'schedule', 'scheduled', 'pickup', 'arrive', 'arrived',
  'arriving', 'depart', 'departed', 'confirm', 'confirmed', 'confirmation',
  'approve', 'approved', 'approval', 'reject', 'rejected', 'request',
  'requested', 'requests', 'available', 'unavailable', 'ready', 'complete',
  'completed', 'pending', 'update', 'updated', 'status', 'information',
  'details', 'document', 'documents', 'attachment', 'image', 'photo',
  'screenshot', 'file', 'files', 'upload', 'uploaded', 'download', 'question',
  'questions', 'problem', 'issue', 'support', 'ticket', 'help', 'urgent',
  'important', 'priority', 'company', 'companies', 'account', 'profile',
  'contact', 'contacts', 'number', 'address', 'email', 'today', 'tomorrow',
  'yesterday', 'tonight', 'week', 'weekend', 'month', 'later', 'early',
  'about', 'after', 'again', 'because', 'before', 'between', 'during',
  'however', 'maybe', 'really', 'regards', 'kind', 'best', 'good', 'great',
  'perfect', 'excellent', 'working', 'works', 'done', 'doing', 'going',
  'coming', 'check', 'checking', 'looking', 'need', 'needed', 'want',
  'waiting', 'regarding', 'concerning', 'following', 'attached',
];

// WhatsApp-style predictive-text intents — scoped to the composer field via
// [Actions]. Enabled only while suggestions are visible, so normal arrow/Tab
// behaviour is untouched otherwise (and other fields are never affected).
class _PredNavIntent extends Intent {
  const _PredNavIntent(this.dir);
  final int dir;
}

class _PredAcceptIntent extends Intent {
  const _PredAcceptIntent();
}

class _PredNavAction extends Action<_PredNavIntent> {
  _PredNavAction(this.state);
  final _ComposerState state;
  @override
  bool isEnabled(_PredNavIntent intent) => state._suggestions.isNotEmpty;
  @override
  Object? invoke(_PredNavIntent intent) {
    state._move(intent.dir);
    return null;
  }
}

class _PredAcceptAction extends Action<_PredAcceptIntent> {
  _PredAcceptAction(this.state);
  final _ComposerState state;
  @override
  bool isEnabled(_PredAcceptIntent intent) => state._suggestions.isNotEmpty;
  @override
  Object? invoke(_PredAcceptIntent intent) {
    state._acceptCurrent();
    return null;
  }
}

/// CPS message-input keys: Enter sends, Shift+Enter inserts a newline.
class _ComposerSendIntent extends Intent {
  const _ComposerSendIntent();
}

class _ComposerNewlineIntent extends Intent {
  const _ComposerNewlineIntent();
}

class _Composer extends ConsumerStatefulWidget {
  final ChatPalette pal;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final ValueChanged<List<({Uint8List bytes, String name})>> onAttach;
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;
  const _Composer(
      {required this.pal,
      required this.controller,
      required this.sending,
      required this.onSend,
      required this.onAttach,
      this.replyTo,
      this.onCancelReply});

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  bool _showEmoji = false;
  bool _showHelp = false;
  List<String> _suggestions = const [];
  int _sel = 0;
  final FocusNode _focus = FocusNode();

  // ── @mention state ─────────────────────────────────────────────────────
  bool _mentionActive = false;
  String _mentionQuery = '';
  int _mentionAt = -1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateSuggestions);
    // Autofocus the field when a thread opens (CPS behaviour) so you can type
    // straight away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Enter pressed: if a @mention is being typed, accept the top match;
  /// otherwise send the message (CPS: Enter always sends).
  void _handleEnterSend() {
    final m = _topMentionMatch();
    if (m != null) {
      _insertMention(m);
      return;
    }
    widget.onSend();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Shift+Enter: insert a newline at the caret.
  void _insertNewline() {
    final c = widget.controller;
    final sel = c.selection;
    final start = sel.start < 0 ? c.text.length : sel.start;
    final end = sel.end < 0 ? c.text.length : sel.end;
    final newText = c.text.replaceRange(start, end, '\n');
    c.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  /// The first contact matching the live @mention query (for Enter-to-accept).
  ChatContact? _topMentionMatch() {
    if (!_mentionActive) return null;
    final myId = ref.read(messagingServiceProvider).currentUserId;
    final contacts =
        ref.read(chatContactsProvider).valueOrNull ?? const <ChatContact>[];
    final q = _mentionQuery.toLowerCase();
    for (final c in contacts) {
      if (c.userId == myId || c.isBlocked) continue;
      if (q.isEmpty || c.displayName.toLowerCase().contains(q)) return c;
    }
    return null;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateSuggestions);
    _focus.dispose();
    super.dispose();
  }

  /// Detects an active `@query` immediately before the caret. Returns the
  /// trigger '@' index and the query (letters/space-free) or `at == -1`.
  ({bool active, String query, int at}) _computeMention() {
    final c = widget.controller;
    final text = c.text;
    final cursor = c.selection.baseOffset;
    if (cursor < 0) return (active: false, query: '', at: -1);
    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at < 0) return (active: false, query: '', at: -1);
    if (at > 0 && before[at - 1] != ' ' && before[at - 1] != '\n') {
      return (active: false, query: '', at: -1);
    }
    final q = before.substring(at + 1);
    // Space/newline/'[' ends a mention query (and skips inserted tokens).
    if (q.contains(' ') || q.contains('\n') || q.contains('[')) {
      return (active: false, query: '', at: -1);
    }
    return (active: true, query: q, at: at);
  }

  void _insertMention(ChatContact c) {
    final controller = widget.controller;
    final text = controller.text;
    final cursor = controller.selection.baseOffset < 0
        ? text.length
        : controller.selection.baseOffset;
    final at = _mentionAt < 0 ? cursor : _mentionAt;
    final token = '@[${c.displayName}](user:${c.userId})';
    final before = text.substring(0, at);
    final after = cursor < text.length ? text.substring(cursor) : '';
    final newText = '$before$token $after';
    controller.value = TextEditingValue(
      text: newText,
      selection:
          TextSelection.collapsed(offset: before.length + token.length + 1),
    );
    setState(() {
      _mentionActive = false;
      _mentionQuery = '';
      _mentionAt = -1;
    });
    _focus.requestFocus();
  }

  static bool _isWordChar(String ch) =>
      ch.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(ch);

  ({int start, int cursor, String prefix}) _currentWord() {
    final c = widget.controller;
    final text = c.text;
    final cursor =
        c.selection.baseOffset < 0 ? text.length : c.selection.baseOffset;
    int start = cursor;
    while (start > 0 && _isWordChar(text[start - 1])) {
      start--;
    }
    return (start: start, cursor: cursor, prefix: text.substring(start, cursor));
  }

  void _updateSuggestions() {
    // A live @mention query takes priority over word prediction.
    final mention = _computeMention();
    if (mention.active) {
      if (!_mentionActive ||
          _mentionQuery != mention.query ||
          _mentionAt != mention.at ||
          _suggestions.isNotEmpty) {
        setState(() {
          _mentionActive = true;
          _mentionQuery = mention.query;
          _mentionAt = mention.at;
          _suggestions = const [];
          _sel = 0;
        });
      }
      return;
    }
    if (_mentionActive) {
      setState(() {
        _mentionActive = false;
        _mentionQuery = '';
        _mentionAt = -1;
      });
    }
    final w = _currentWord();
    List<String> next = const [];
    if (w.prefix.length >= 2) {
      final lp = w.prefix.toLowerCase();
      final cap = w.prefix[0] != lp[0]; // first letter is uppercase
      final seen = <String>{};
      final acc = <String>[];
      for (final word in _kPredict) {
        if (word.length > lp.length && word.startsWith(lp)) {
          final s = cap ? word[0].toUpperCase() + word.substring(1) : word;
          if (seen.add(s)) {
            acc.add(s);
            if (acc.length >= 6) break;
          }
        }
      }
      next = acc;
    }
    bool changed = next.length != _suggestions.length;
    if (!changed) {
      for (var i = 0; i < next.length; i++) {
        if (next[i] != _suggestions[i]) {
          changed = true;
          break;
        }
      }
    }
    if (changed) {
      setState(() {
        _suggestions = next;
        _sel = 0;
      });
    }
  }

  void _move(int dir) {
    if (_suggestions.isEmpty) return;
    setState(() => _sel = (_sel + dir).clamp(0, _suggestions.length - 1));
  }

  void _acceptCurrent() {
    if (_suggestions.isEmpty) return;
    _accept(_suggestions[_sel]);
  }

  void _accept(String word) {
    final w = _currentWord();
    final c = widget.controller;
    final replaced = c.text.replaceRange(w.start, w.cursor, '$word ');
    c.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: w.start + word.length + 1),
    );
    // Keep the cursor in the field so the user can keep typing uninterrupted.
    _focus.requestFocus();
    // listener recomputes (now empty) suggestions.
  }

  void _insert(String emoji) {
    final c = widget.controller;
    final sel = c.selection;
    final text = c.text;
    if (sel.isValid && sel.start >= 0) {
      final newText = text.replaceRange(sel.start, sel.end, emoji);
      c.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start + emoji.length),
      );
    } else {
      c.text = text + emoji;
      c.selection = TextSelection.collapsed(offset: c.text.length);
    }
    _focus.requestFocus();
  }

  Future<void> _pickFiles() async {
    try {
      final files = await openFiles();
      if (files.isEmpty) return;
      final picks = <({Uint8List bytes, String name})>[];
      for (final f in files) {
        picks.add((bytes: await f.readAsBytes(), name: f.name));
      }
      widget.onAttach(picks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not attach. ${friendlyError(e)}')));
      }
    }
  }

  /// Smart paste for the composer only (scoped via an Actions override, so it
  /// never affects other fields like login): a clipboard image or file is sent
  /// as an attachment; otherwise plain text is pasted at the cursor.
  Future<void> _smartPaste() async {
    try {
      final img = await Pasteboard.image;
      if (img != null && img.isNotEmpty) {
        widget.onAttach([(bytes: img, name: 'pasted-image.png')]);
        return;
      }
    } catch (e) {
      _log.d('smartPaste: clipboard image read failed, trying files: $e');
    }
    try {
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        final picks = <({Uint8List bytes, String name})>[];
        for (final p in files) {
          final xf = XFile(p);
          picks.add((bytes: await xf.readAsBytes(), name: xf.name));
        }
        widget.onAttach(picks);
        return;
      }
    } catch (e) {
      _log.d('smartPaste: clipboard files read failed, falling back to text: $e');
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) _insert(text);
  }

  /// Composer reply preview bar (shown while composing a reply).
  Widget _replyBar() {
    final pal = widget.pal;
    final r = widget.replyTo!;
    return Container(
      width: double.infinity,
      color: pal.header.withValues(alpha: pal.isDark ? 0.3 : 0.4),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: _ReplyQuote(
        pal: pal,
        senderName: r.senderName,
        previewText: r.content,
        hasAttachment: r.hasAttachment,
        attachmentName: r.fileName,
        composerPreview: true,
        onCancel: widget.onCancelReply,
      ),
    );
  }

  /// @mention picker — lists chattable contacts matching the live query.
  Widget _mentionPicker() {
    final pal = widget.pal;
    final myId = ref.read(messagingServiceProvider).currentUserId;
    final contacts = ref.watch(chatContactsProvider).valueOrNull ?? const [];
    final q = _mentionQuery.toLowerCase();
    final matches = contacts
        .where((c) => c.userId != myId && !c.isBlocked)
        .where((c) => q.isEmpty || c.displayName.toLowerCase().contains(q))
        .take(6)
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: pal.body,
        border: Border(top: BorderSide(color: pal.divider)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          for (final c in matches)
            InkWell(
              onTap: () => _insertMention(c),
              hoverColor: pal.accent.withValues(alpha: 0.06),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  children: [
                    _MiniAvatar(
                        pal: pal,
                        label: c.displayName,
                        isSuperAdmin: c.isSuperAdmin,
                        size: 30),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('@${c.displayName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.mlText.titleSmall.copyWith(
                                color: pal.bodyText,
                                fontWeight: FontWeight.w700,
                              )),
                          if (c.companyName != null)
                            Text(c.companyName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.mlText.labelSmall.copyWith(
                                  color: pal.bodySubtle,
                                  fontWeight: FontWeight.w400,
                                )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Help panel (opened by the ⓘ button) explaining the composer: shortcuts,
  /// predictive text, mentions, and emoji/attachments.
  Widget _helpPanel() {
    final pal = widget.pal;
    Widget row(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: pal.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: context.mlText.titleSmall.copyWith(
                          color: pal.bodyText,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 2),
                    Text(body,
                        style: context.mlText.bodySmall.copyWith(
                          color: pal.bodySubtle,
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: pal.body,
        border: Border(top: BorderSide(color: pal.divider)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: pal.accent),
                const SizedBox(width: 8),
                Text('How the composer works',
                    style: context.mlText.titleSmall.copyWith(
                      color: pal.bodyText,
                      fontWeight: FontWeight.w800,
                    )),
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _showHelp = false),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: pal.bodySubtle),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            row(Icons.send_rounded, 'Sending',
                'Click the paper-plane button to send. The message box grows to fit multiple lines as you type.'),
            row(Icons.auto_awesome_rounded, 'Predictive text',
                'Type a word (2+ letters) and suggestions appear in the strip above. Use ← / → to move between them and Tab — or a click — to accept the highlighted one.'),
            row(Icons.alternate_email_rounded, 'Mentions (@)',
                'Type @ then a name to mention someone you can chat with, and pick them from the list. Their name becomes a tappable chip that opens their profile.'),
            row(Icons.emoji_emotions_outlined, 'Emoji & attachments',
                'Tap the emoji button for the picker, or the clip to attach a file or image. You can also drag-and-drop or paste (Ctrl+V) an image straight in.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showEmoji)
          Container(
            height: 176,
            width: double.infinity,
            color: pal.body,
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: _kEmojis.length,
              itemBuilder: (context, i) => InkWell(
                onTap: () => _insert(_kEmojis[i]),
                borderRadius: MlShape.radiusSmall,
                child: Center(
                  child: Text(_kEmojis[i],
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            height: 44,
            width: double.infinity,
            color: pal.body,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final selected = i == _sel;
                return GestureDetector(
                  onTap: () => _accept(_suggestions[i]),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: selected ? pal.accent : pal.tabSelectedBg,
                      borderRadius: MlShape.pill,
                      border: Border.all(
                          color: selected ? pal.accent : pal.divider),
                    ),
                    child: Text(
                      _suggestions[i],
                      style: context.mlText.titleSmall.copyWith(
                        color: selected ? pal.accentText : pal.bodyText,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (_showHelp) _helpPanel(),
        if (_mentionActive) _mentionPicker(),
        if (widget.replyTo != null) _replyBar(),
        Container(
          // Stable key so the input keeps its element (and focus) when the
          // suggestion strip / emoji panel toggle above it.
          key: const ValueKey('ml-composer-input'),
          padding: const EdgeInsets.fromLTRB(6, 10, 10, 12),
          color: pal.header.withValues(alpha: pal.isDark ? 0.3 : 0.4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CircleBtn(
                icon: Icons.attach_file_rounded,
                tip: 'Attach a file or image',
                color: pal.bodySubtle,
                onTap: _pickFiles,
              ),
              _CircleBtn(
                icon: _showEmoji
                    ? Icons.keyboard_rounded
                    : Icons.emoji_emotions_outlined,
                tip: 'Emoji',
                color: _showEmoji ? pal.accent : pal.bodySubtle,
                onTap: () => setState(() => _showEmoji = !_showEmoji),
              ),
              Expanded(
                child: Shortcuts(
                  shortcuts: const <ShortcutActivator, Intent>{
                    // CPS rules: Enter sends, Shift+Enter is a newline.
                    SingleActivator(LogicalKeyboardKey.enter):
                        _ComposerSendIntent(),
                    SingleActivator(LogicalKeyboardKey.numpadEnter):
                        _ComposerSendIntent(),
                    SingleActivator(LogicalKeyboardKey.enter, shift: true):
                        _ComposerNewlineIntent(),
                    SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true):
                        _ComposerNewlineIntent(),
                    SingleActivator(LogicalKeyboardKey.arrowLeft):
                        _PredNavIntent(-1),
                    SingleActivator(LogicalKeyboardKey.arrowRight):
                        _PredNavIntent(1),
                    SingleActivator(LogicalKeyboardKey.tab):
                        _PredAcceptIntent(),
                  },
                  child: Actions(
                  actions: <Type, Action<Intent>>{
                    PasteTextIntent: CallbackAction<PasteTextIntent>(
                      onInvoke: (intent) {
                        _smartPaste();
                        return null;
                      },
                    ),
                    _ComposerSendIntent:
                        CallbackAction<_ComposerSendIntent>(onInvoke: (_) {
                      _handleEnterSend();
                      return null;
                    }),
                    _ComposerNewlineIntent:
                        CallbackAction<_ComposerNewlineIntent>(onInvoke: (_) {
                      _insertNewline();
                      return null;
                    }),
                    _PredNavIntent: _PredNavAction(this),
                    _PredAcceptIntent: _PredAcceptAction(this),
                  },
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    // Enter is intercepted by the Shortcut above (send);
                    // Shift+Enter inserts a newline. Matches CPS.
                    textInputAction: TextInputAction.send,
                    onTap: () {
                      if (_showEmoji) setState(() => _showEmoji = false);
                    },
                    cursorColor: pal.accent,
                    style: context.mlText.bodyMedium.copyWith(
                      color: pal.bodyText,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write a message…',
                      hintStyle: TextStyle(color: pal.bodySubtle),
                      isDense: true,
                      filled: true,
                      fillColor: pal.body,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MlTokens.rMd),
                        borderSide: BorderSide(color: pal.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MlTokens.rMd),
                        borderSide: BorderSide(color: pal.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MlTokens.rMd),
                        borderSide: BorderSide(color: pal.accent),
                      ),
                    ),
                  ),
                ),
                ),
              ),
              _CircleBtn(
                icon: _showHelp
                    ? Icons.info_rounded
                    : Icons.info_outline_rounded,
                tip: 'How mentions, shortcuts & predictions work',
                color: _showHelp ? pal.accent : pal.bodySubtle,
                onTap: () => setState(() {
                  _showHelp = !_showHelp;
                  if (_showHelp) _showEmoji = false;
                }),
              ),
              const SizedBox(width: 8),
              Material(
                color: widget.sending ? pal.divider : pal.accent,
                borderRadius: BorderRadius.circular(MlTokens.rMd),
                child: InkWell(
                  onTap: widget.sending ? null : widget.onSend,
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Icon(Icons.send_rounded,
                        size: 19, color: pal.accentText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final Color color;
  final VoidCallback onTap;
  const _CircleBtn(
      {required this.icon,
      required this.tip,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }
}

// ===========================================================================
// PROFILE
// ===========================================================================

class _ProfileView extends StatelessWidget {
  final ChatPalette pal;
  final ChatContact contact;
  final VoidCallback onBack;
  final VoidCallback onMessage;
  const _ProfileView({
    required this.pal,
    required this.contact,
    required this.onBack,
    required this.onMessage,
  });

  // `OrgType.labelFor`, not a private switch. This panel used to carry its
  // own mapping, and it matched 'mine' and 'supplier' — neither of which the
  // database stores. `companies.org_type` is `mineSupplier`, so every mine
  // contact's profile read "Organisation type | mineSupplier": the wire value,
  // in camelCase, in a sentence. Seen on 2026-08-23 while driving a chat
  // between two Iron Hills accounts. Same class as the three sites
  // `OrgType.labelFor` was written to close, and now the fourth.
  String get _orgTypeLabel => OrgType.labelFor(contact.orgType);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ContentHeader(
          pal: pal,
          title: "${contact.displayName}'s profile",
          subtitle: contact.companyName ?? 'Contact',
          isSuperAdmin: contact.isSuperAdmin,
          onBack: onBack,
        ),
        Container(height: 1, color: pal.divider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              Center(
                child: Column(
                  children: [
                    _MiniAvatar(
                        pal: pal,
                        label: contact.displayName,
                        isSuperAdmin: contact.isSuperAdmin,
                        size: 84),
                    const SizedBox(height: 12),
                    Text(
                      contact.displayName,
                      textAlign: TextAlign.center,
                      style: context.mlText.titleLarge.copyWith(
                        color: pal.bodyText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact.companyName ?? _orgTypeLabel,
                      textAlign: TextAlign.center,
                      style: context.mlText.bodyMedium.copyWith(
                        color: pal.bodySubtle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _PresenceText(
                      pal: pal,
                      userId: contact.userId,
                      dbLastSeen: contact.lastSeenAt,
                      fontSize: 13,
                      weight: FontWeight.w600,
                    ),
                    const SizedBox(height: 10),
                    if (contact.isSuperAdmin)
                      _Pill(
                          icon: Icons.verified_rounded,
                          label: 'Mine-Link Admin',
                          color: pal.accent)
                    else if (contact.isBlocked)
                      Tooltip(
                        message: contact.blockedTooltip,
                        child: _Pill(
                            icon: contact.isBlockedByExpiry
                                ? Icons.lock_clock_rounded
                                : Icons.block_rounded,
                            label: contact.blockedLabel,
                            color: contact.isBlockedByExpiry
                                ? MlTokens.amber700
                                : MlTokens.red600),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 44,
                child: Material(
                  color: pal.accent,
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                  child: InkWell(
                    onTap: onMessage,
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_rounded, size: 18, color: pal.accentText),
                        const SizedBox(width: 8),
                        Text(
                          'Message',
                          style: context.mlText.titleSmall.copyWith(
                            color: pal.accentText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                  pal: pal,
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: contact.roleLabel),
              _InfoRow(
                  pal: pal,
                  icon: Icons.apartment_outlined,
                  label: 'Company',
                  value: contact.companyName ?? '—'),
              _InfoRow(
                  pal: pal,
                  icon: Icons.category_outlined,
                  label: 'Organisation type',
                  value: _orgTypeLabel),
              _InfoRow(
                  pal: pal,
                  icon: Icons.groups_outlined,
                  label: 'Contact group',
                  value: contact.groupLabel.isEmpty ? '—' : contact.groupLabel),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: pal.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This is their public profile as set up in their '
                        'company information — you can view it but not edit it.',
                        style: context.mlText.bodySmall.copyWith(
                          color: pal.bodySubtle,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final ChatPalette pal;
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.pal,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: pal.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: pal.bodySubtle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.mlText.bodySmall.copyWith(
                      color: pal.bodySubtle,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: context.mlText.titleSmall.copyWith(
                      color: pal.bodyText,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// SETTINGS (theme + follow-cursor)
// ===========================================================================

class _SettingsView extends ConsumerWidget {
  final ChatPalette pal;
  final VoidCallback onBack;
  const _SettingsView({required this.pal, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(chatPrefsProvider);
    final ctrl = ref.read(chatPrefsProvider.notifier);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(left: 6, right: 10),
          height: 48,
          color: pal.header.withValues(alpha: pal.isDark ? 0.4 : 0.5),
          child: Row(
            children: [
              _WinBtn(icon: Icons.arrow_back_rounded, tip: 'Back', onTap: onBack, pal: pal),
              const SizedBox(width: 4),
              Icon(Icons.settings_outlined, size: 17, color: pal.accent),
              const SizedBox(width: 8),
              Text('Messages Settings',
                  style: context.mlText.titleSmall.copyWith(
                    color: pal.bodyText,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
        Container(height: 1, color: pal.divider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionLabel(pal: pal, text: 'THEME'),
              Text(
                'Pick a colour scheme just for your messenger. Every theme is '
                'tuned for high contrast — names and messages stay easy to read.',
                style: context.mlText.bodySmall.copyWith(color: pal.bodySubtle),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 92,
                ),
                itemCount: ChatThemes.palettes.length,
                itemBuilder: (context, i) {
                  final p = ChatThemes.palettes[i];
                  return _ThemeTile(
                    p: p,
                    selected: p.id == prefs.paletteId,
                    onTap: () => ctrl.setPalette(p.id),
                  );
                },
              ),
              const SizedBox(height: 20),
              _SectionLabel(pal: pal, text: 'PREVIEW'),
              _BubblePreview(pal: pal),
              const SizedBox(height: 20),
              _SectionLabel(pal: pal, text: 'CHAT ICON'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: pal.divider),
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Follow the cursor',
                              style: context.mlText.titleSmall.copyWith(
                                color: pal.bodyText,
                              )),
                          const SizedBox(height: 2),
                          Text(
                            'The floating chat icon turns to face your mouse '
                            'anywhere on screen. Turn off to keep it still.',
                            style: context.mlText.bodySmall.copyWith(
                              color: pal.bodySubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _Toggle(
                      pal: pal,
                      on: prefs.cursorTracking,
                      onChange: ctrl.setCursorTracking,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionLabel(pal: pal, text: 'MESSAGE SOUNDS'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: pal.divider),
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Play a sound on new messages',
                                  style: context.mlText.titleSmall.copyWith(
                                    color: pal.bodyText,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                'A soft tone plays when a message arrives and '
                                'when you send one.',
                                style: context.mlText.bodySmall.copyWith(
                                  color: pal.bodySubtle,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Toggle(
                          pal: pal,
                          on: prefs.soundsEnabled,
                          onChange: ctrl.setSoundsEnabled,
                        ),
                      ],
                    ),
                    if (prefs.soundsEnabled) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Default sound',
                            style: context.mlText.labelMedium.copyWith(
                              color: pal.bodySubtle,
                            )),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in ChatSoundService.incomingTones)
                            _SoundChip(
                              pal: pal,
                              selected: prefs.incomingSound == id,
                              icon: prefs.incomingSound == id
                                  ? Icons.play_circle_rounded
                                  : Icons.play_circle_outline_rounded,
                              label: ChatSoundService.labels[id] ?? id,
                              onTap: () {
                                ctrl.setIncomingSound(id);
                                ChatSoundService.instance.play(id);
                              },
                            ),
                          for (final id in ChatSoundService.cpsTones)
                            _SoundChip(
                              pal: pal,
                              selected: prefs.incomingSound == id,
                              icon: prefs.incomingSound == id
                                  ? Icons.play_circle_rounded
                                  : Icons.play_circle_outline_rounded,
                              label: ChatSoundService.cpsLabels[id] ?? id,
                              onTap: () {
                                ctrl.setIncomingSound(id);
                                ChatSoundService.instance.play(id);
                              },
                            ),
                          _SoundChip(
                            pal: pal,
                            selected: prefs.incomingSound == 'custom',
                            icon: Icons.folder_open_rounded,
                            label: prefs.incomingSound == 'custom' &&
                                    prefs.customSoundName != null
                                ? prefs.customSoundName!
                                : 'Custom…',
                            onTap: () async {
                              final file = await openFile(
                                acceptedTypeGroups: const [
                                  XTypeGroup(label: 'Audio', extensions: [
                                    'mp3',
                                    'wav',
                                    'ogg',
                                    'm4a',
                                    'aac',
                                    'flac',
                                    'opus'
                                  ]),
                                ],
                              );
                              if (file != null) {
                                await ctrl.setCustomSound(file.path, file.name);
                                // Preview playback — deliberately not awaited.
                                unawaited(ChatSoundService.instance
                                    .playFile(file.path)
                                    .catchError((Object e) =>
                                        _log.d('sound preview failed: $e')));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tip: grab free tones from Pixabay or Mixkit, then pick '
                        'them with Custom…',
                        style: context.mlText.bodySmall.copyWith(
                          color: pal.bodySubtle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (prefs.soundsEnabled) ...[
                const SizedBox(height: 20),
                _SectionLabel(pal: pal, text: 'PER-CONTACT SOUNDS'),
                Text(
                  'Give a specific person their own incoming tone. "Default" '
                  'uses the sound above.',
                  style:
                      context.mlText.bodySmall.copyWith(color: pal.bodySubtle),
                ),
                const SizedBox(height: 12),
                _PerContactSounds(pal: pal),
              ],
              const SizedBox(height: 18),
              Center(
                child: TextButton.icon(
                  onPressed: () => ctrl.setPalette(ChatThemes.defaultId),
                  icon: Icon(Icons.restart_alt_rounded,
                      size: 18, color: pal.accent),
                  label: Text('Reset to Default',
                      style: TextStyle(
                          color: pal.accent, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final ChatPalette pal;
  final String text;
  const _SectionLabel({required this.pal, required this.text});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: context.mlText.overline.copyWith(color: pal.accent)),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final ChatPalette p;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeTile(
      {required this.p, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: MlShape.radiusMedium,
          border: Border.all(
              color: selected ? p.accent : p.divider, width: selected ? 2 : 1),
          boxShadow: selected
              ? [BoxShadow(color: p.accent.withValues(alpha: 0.30), blurRadius: 0, spreadRadius: 2)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: p.body,
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _swatch(context, 'Aa', p.incomingBubble, p.incomingText),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _swatch(context, 'Aa', p.outgoingBubble, p.outgoingText),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              color: p.header,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.mlText.labelMedium.copyWith(
                          color: p.headerText,
                          fontWeight: FontWeight.w700,
                        )),
                  ),
                  if (selected)
                    Icon(Icons.check_circle_rounded, size: 15, color: p.accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(BuildContext context, String t, Color bg, Color fg) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: MlShape.radiusSmall),
        child: Text(t,
            style: context.mlText.labelSmall.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            )),
      );
}

class _BubblePreview extends StatelessWidget {
  final ChatPalette pal;
  const _BubblePreview({required this.pal});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.body,
        border: Border.all(color: pal.divider),
        borderRadius: MlShape.radiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: pal.incomingBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(MlShape.large),
                topRight: Radius.circular(MlShape.large),
                bottomRight: Radius.circular(MlShape.large),
                bottomLeft: Radius.circular(MlShape.extraSmall),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: pal.bubbleSeparator))),
                  child: Text('Johan Steyn',
                      style: context.mlText.titleSmall.copyWith(
                        color: pal.senderName,
                        fontWeight: FontWeight.w800,
                      )),
                ),
                Text('Trucks are loaded and ready to roll.',
                    style: context.mlText.bodyMedium.copyWith(
                      color: pal.incomingText,
                    )),
                const SizedBox(height: 3),
                Text('09:19',
                    style: context.mlText.code(
                      color: pal.incomingText.withValues(alpha: 0.6),
                      size: 11,
                      weight: FontWeight.w400,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                color: pal.outgoingBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(MlShape.large),
                  topRight: Radius.circular(MlShape.large),
                  bottomLeft: Radius.circular(MlShape.large),
                  bottomRight: Radius.circular(MlShape.extraSmall),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Great — sending waybills now.',
                      style: context.mlText.bodyMedium.copyWith(
                        color: pal.outgoingText,
                      )),
                  const SizedBox(height: 3),
                  // The read receipt is an ICON, not a `✓✓` in the string.
                  // U+2713 is in none of the three shipped faces — on a handset
                  // the platform's fallback chain supplies it, so it looked
                  // right wherever anyone had looked, and it came out as two
                  // tofu boxes the first time this was rendered anywhere else.
                  // `tool/glyph_coverage_check.py` holds the line.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('09:20',
                          style: context.mlText.code(
                            color: pal.outgoingText.withValues(alpha: 0.7),
                            size: 11,
                            weight: FontWeight.w400,
                          )),
                      const SizedBox(width: 4),
                      Icon(Icons.done_all_rounded,
                          size: 13,
                          color: pal.outgoingText.withValues(alpha: 0.7)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final ChatPalette pal;
  final bool on;
  final ValueChanged<bool> onChange;
  const _Toggle({required this.pal, required this.on, required this.onChange});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChange(!on),
      child: AnimatedContainer(
        duration: MlTokens.durFast,
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: on ? pal.accent : pal.divider,
          borderRadius: MlShape.pill,
        ),
        child: AnimatedAlign(
          duration: MlTokens.durFast,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              color: MlTokens.inkOnFill,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: MlChatTone.shadow, blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SoundChip extends StatelessWidget {
  final ChatPalette pal;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SoundChip({
    required this.pal,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? pal.accent : pal.tabSelectedBg,
          borderRadius: MlShape.pill,
          border: Border.all(color: selected ? pal.accent : pal.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: selected ? pal.accentText : pal.bodySubtle),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.titleSmall.copyWith(
                  color: selected ? pal.accentText : pal.bodyText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-contact sound overrides — one row per chattable contact with a dropdown
/// (Default + every MineLink/CPS tone) and a preview button. Mirrors CPS.
class _PerContactSounds extends ConsumerWidget {
  final ChatPalette pal;
  const _PerContactSounds({required this.pal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(chatContactsProvider);
    final prefs = ref.watch(chatPrefsProvider);
    final ctrl = ref.read(chatPrefsProvider.notifier);
    final myId = ref.read(messagingServiceProvider).currentUserId;

    return contactsAsync.when(
      loading: () => _loading(pal),
      error: (e, _) => _errorBox(pal, '$e'),
      data: (list) {
        final people =
            list.where((c) => c.userId != myId && !c.isBlocked).toList();
        if (people.isEmpty) {
          return Text('No other contacts yet.',
              style: context.mlText.bodySmall.copyWith(color: pal.bodySubtle));
        }
        return Column(
          children: [
            for (final c in people)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: pal.divider),
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                  ),
                  child: Row(
                    children: [
                      _MiniAvatar(
                          pal: pal,
                          label: c.displayName,
                          isSuperAdmin: c.isSuperAdmin,
                          size: 30),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(c.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.titleSmall.copyWith(
                              color: pal.bodyText,
                            )),
                      ),
                      const SizedBox(width: 8),
                      // Capped and expanded. A DropdownButton sizes to its
                      // WIDEST item, and the widest here is a CPS tone name
                      // with " (CPS)" after it — unflexed beside an `Expanded`
                      // contact name, that tone name decides how much room is
                      // left for the person it belongs to, and at a large text
                      // size the answer is none.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: prefs.perContactSound[c.userId] ?? '',
                            isExpanded: true,
                            isDense: true,
                            dropdownColor: pal.header,
                            borderRadius: MlShape.radiusMedium,
                            style:
                                context.mlText.bodyMedium.copyWith(
                                  color: pal.bodyText,
                                ),
                            iconEnabledColor: pal.accent,
                            items: [
                              const DropdownMenuItem(
                                  value: '', child: Text('Default')),
                              for (final id in ChatSoundService.incomingTones)
                                DropdownMenuItem(
                                    value: id,
                                    child: Text(
                                        ChatSoundService.labels[id] ?? id)),
                              for (final id in ChatSoundService.cpsTones)
                                DropdownMenuItem(
                                    value: id,
                                    child: Text(
                                        '${ChatSoundService.cpsLabels[id] ?? id} (CPS)')),
                            ],
                            onChanged: (v) {
                              ctrl.setContactSound(
                                  c.userId, (v == null || v.isEmpty) ? null : v);
                              final play = (v == null || v.isEmpty)
                                  ? prefs.incomingSound
                                  : v;
                              ChatSoundService.instance.play(play);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Preview',
                        icon: Icon(Icons.play_circle_outline_rounded,
                            color: pal.accent, size: 20),
                        onPressed: () => ChatSoundService.instance.play(
                            prefs.perContactSound[c.userId] ??
                                prefs.incomingSound),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ===========================================================================
// Shared bits
// ===========================================================================

class _MiniAvatar extends StatelessWidget {
  final ChatPalette pal;
  final String label;
  final bool isGroup;
  final bool isSuperAdmin;
  final double size;
  // null = no presence dot, true = green (online), false = red (offline).
  final bool? online;
  const _MiniAvatar({
    required this.pal,
    required this.label,
    this.isGroup = false,
    this.isSuperAdmin = false,
    this.size = 36,
    this.online,
  });

  @override
  Widget build(BuildContext context) {
    final initials = label.trim().isEmpty
        ? '?'
        : label
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e[0])
            .join()
            .toUpperCase();
    final color = pal.accent;
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: isSuperAdmin ? Border.all(color: color, width: 1.5) : null,
      ),
      child: isGroup
          ? Icon(Icons.groups_rounded, color: color, size: size * 0.5)
          : Text(
              initials,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
                color: color,
              ),
            ),
    );
    if (online == null) return avatar;
    final dot = size * 0.30;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: online! ? MlChatTone.online : MlChatTone.offline,
              shape: BoxShape.circle,
              border: Border.all(color: pal.body, width: size * 0.06),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: MlShape.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: context.mlText.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final ChatPalette pal;
  final IconData icon;
  final String title;
  final String message;
  const _Empty(
      {required this.pal,
      required this.icon,
      required this.title,
      required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: pal.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: pal.accent),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: context.mlText.titleMedium.copyWith(
                  color: pal.bodyText,
                  fontWeight: FontWeight.w700,
                )),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: context.mlText.bodyMedium.copyWith(color: pal.bodySubtle)),
          ],
        ),
      ),
    );
  }
}

Widget _loading(ChatPalette pal) => Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: pal.accent),
      ),
    );

Widget _errorBox(ChatPalette pal, String message) => Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.bodySubtle)),
      ),
    );

// ===========================================================================
// SUPPORT — tickets (log → admin inbox → accept → in-progress → complete)
// ===========================================================================

class _SupportView extends ConsumerStatefulWidget {
  final ChatPalette pal;
  final VoidCallback onBack;
  const _SupportView({required this.pal, required this.onBack});

  @override
  ConsumerState<_SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends ConsumerState<_SupportView> {
  String _screen = 'home'; // home | new | ticket
  String? _ticketId;

  void _openTicket(String id) {
    ref.read(supportServiceProvider).markNotifsRead(id);
    ref.invalidate(supportNotificationsProvider);
    setState(() {
      _ticketId = id;
      _screen = 'ticket';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final isAdmin = ref.watch(supportIsAdminProvider).valueOrNull ?? false;
    switch (_screen) {
      case 'new':
        return _NewTicketForm(
          pal: pal,
          onBack: () => setState(() => _screen = 'home'),
          onCreated: (id) {
            ref.invalidate(myTicketsProvider);
            _openTicket(id);
          },
        );
      case 'ticket':
        return _TicketView(
          pal: pal,
          ticketId: _ticketId!,
          isAdmin: isAdmin,
          onBack: () => setState(() => _screen = 'home'),
        );
      default:
        return _SupportHome(
          pal: pal,
          isAdmin: isAdmin,
          onBack: widget.onBack,
          onNew: () => setState(() => _screen = 'new'),
          onOpenTicket: _openTicket,
        );
    }
  }
}

class _SupportHeader extends StatelessWidget {
  final ChatPalette pal;
  final String title;
  final IconData icon;
  final VoidCallback onBack;
  final Widget? trailing;
  const _SupportHeader({
    required this.pal,
    required this.title,
    required this.icon,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 10),
      height: 54,
      color: pal.header.withValues(alpha: pal.isDark ? 0.4 : 0.5),
      child: Row(
        children: [
          _WinBtn(icon: Icons.arrow_back_rounded, tip: 'Back', onTap: onBack, pal: pal),
          const SizedBox(width: 4),
          Icon(icon, size: 18, color: pal.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.titleMedium.copyWith(
                  color: pal.bodyText,
                  fontWeight: FontWeight.w800,
                )),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    IconData icon;
    switch (status) {
      case 'in_progress':
        c = MlChatTone.inProgress;
        label = 'IN PROGRESS';
        icon = Icons.autorenew_rounded;
        break;
      case 'completed':
        c = MlTokens.green600;
        label = 'COMPLETED';
        icon = Icons.check_circle_rounded;
        break;
      default:
        c = MlTokens.blue600;
        label = 'TICKET SENT';
        icon = Icons.mark_email_read_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: c, borderRadius: MlShape.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: MlTokens.inkOnFill),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: MlTokens.inkOnFill)),
        ],
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  final ChatPalette pal;
  final SupportTicket ticket;
  final String subtitle;
  final VoidCallback onTap;
  const _TicketRow(
      {required this.pal,
      required this.ticket,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: pal.accent.withValues(alpha: 0.06),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: pal.divider))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: pal.tabSelectedBg,
                borderRadius: MlShape.radiusMedium,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.confirmation_number_outlined,
                  size: 20, color: pal.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(ticket.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.titleSmall.copyWith(
                              color: pal.bodyText,
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(status: ticket.status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.bodySmall.copyWith(
                        color: pal.bodySubtle,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportHome extends ConsumerWidget {
  final ChatPalette pal;
  final bool isAdmin;
  final VoidCallback onBack;
  final VoidCallback onNew;
  final ValueChanged<String> onOpenTicket;
  const _SupportHome({
    required this.pal,
    required this.isAdmin,
    required this.onBack,
    required this.onNew,
    required this.onOpenTicket,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _SupportHeader(
            pal: pal,
            title: 'Support',
            icon: Icons.support_agent_rounded,
            onBack: onBack),
        Container(height: 1, color: pal.divider),
        Expanded(child: isAdmin ? _admin(context, ref) : _user(context, ref)),
      ],
    );
  }

  Widget _label(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Text(t,
            style: context.mlText.overline.copyWith(color: pal.bodySubtle)),
      );

  Widget _user(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(myTicketsProvider);
    final notifs = ref.watch(supportNotificationsProvider);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 4),
          child: Column(
            children: [
              SizedBox(
                height: 46,
                width: double.infinity,
                child: Material(
                  color: pal.accent,
                  borderRadius: MlShape.radiusMedium,
                  child: InkWell(
                    onTap: onNew,
                    borderRadius: MlShape.radiusMedium,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 20, color: pal.accentText),
                        const SizedBox(width: 8),
                        Text('Log a support ticket',
                            style: context.mlText.titleSmall.copyWith(
                              color: pal.accentText,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Questions, queries, problems or bugs — sent to the '
                'Mine-Link team.',
                textAlign: TextAlign.center,
                style: context.mlText.bodySmall.copyWith(color: pal.bodySubtle),
              ),
            ],
          ),
        ),
        notifs.maybeWhen(
          data: (list) {
            final unreadFirst = list;
            if (unreadFirst.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(context, 'UPDATES'),
                ...unreadFirst.take(5).map((n) => InkWell(
                      onTap: () => onOpenTicket(n.ticketId),
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: n.read
                              ? Colors.transparent
                              : pal.tabSelectedBg,
                          borderRadius: MlShape.radiusMedium,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notifications_rounded,
                                size: 16,
                                color:
                                    n.read ? pal.bodySubtle : pal.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n.text,
                                      style: context.mlText.bodyMedium.copyWith(
                                        color: pal.bodyText,
                                      )),
                                  const SizedBox(height: 2),
                                  Text(
                                      // `calendarStamp`: SupportNotification
                                      // converts at parse, so `stamp` would
                                      // convert a wall clock a second time.
                                      MlTime.calendarStamp(n.createdAt),
                                      style: context.mlText.code(
                                        color: pal.bodySubtle,
                                        size: 11,
                                        weight: FontWeight.w400,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
        tickets.when(
          loading: () => Padding(
              padding: const EdgeInsets.all(24), child: _loading(pal)),
          error: (e, _) => _errorBox(pal, '$e'),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(context, 'MY TICKETS · ${list.length}'),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text('No tickets yet.',
                        style: TextStyle(color: pal.bodySubtle)),
                  ),
                )
              else
                ...list.map((t) => _TicketRow(
                      pal: pal,
                      ticket: t,
                      subtitle:
                          '${t.category}${t.acceptedByName != null ? ' · handled by ${t.acceptedByName}' : ' · awaiting a team member'}',
                      onTap: () => onOpenTicket(t.id),
                    )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _admin(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(allTicketsProvider);
    return ListView(
      children: [
        _label(context, 'WHO RECEIVES TICKETS'),
        _InboxToggles(pal: pal),
        tickets.when(
          loading: () => Padding(
              padding: const EdgeInsets.all(24), child: _loading(pal)),
          error: (e, _) => _errorBox(pal, '$e'),
          data: (list) {
            final open = list.where((t) => t.isOpen).toList();
            final done = list.where((t) => !t.isOpen).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label(context, 'OPEN · ${open.length}'),
                if (open.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                        child: Text('No open tickets.',
                            style: TextStyle(color: pal.bodySubtle))),
                  )
                else
                  ...open.map((t) => _TicketRow(
                        pal: pal,
                        ticket: t,
                        subtitle:
                            '${t.category}${t.acceptedByName != null ? ' · handling: ${t.acceptedByName}' : ' · unassigned'}',
                        onTap: () => onOpenTicket(t.id),
                      )),
                if (done.isNotEmpty) _label(context, 'COMPLETED · ${done.length}'),
                ...done.map((t) => _TicketRow(
                      pal: pal,
                      ticket: t,
                      subtitle:
                          'completed by ${t.acceptedByName ?? 'admin'}',
                      onTap: () => onOpenTicket(t.id),
                    )),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The "who receives tickets" toggle list. Flips optimistically (instant) and
/// persists in the background — no DB round-trip before the switch moves.
class _InboxToggles extends ConsumerStatefulWidget {
  final ChatPalette pal;
  const _InboxToggles({required this.pal});

  @override
  ConsumerState<_InboxToggles> createState() => _InboxTogglesState();
}

class _InboxTogglesState extends ConsumerState<_InboxToggles> {
  final Map<String, bool> _override = {};

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final adminsAsync = ref.watch(inboxAdminsProvider);
    return adminsAsync.maybeWhen(
      data: (list) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            ...list.map((a) {
              final on = _override[a.id] ?? a.receiving;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name,
                              style: context.mlText.titleSmall.copyWith(
                                color: pal.bodyText,
                              )),
                          Text(
                              on
                                  ? 'Receiving new tickets'
                                  : 'Not receiving tickets',
                              style: context.mlText.bodySmall.copyWith(
                                color: pal.bodySubtle,
                              )),
                        ],
                      ),
                    ),
                    _Toggle(
                      pal: pal,
                      on: on,
                      onChange: (v) {
                        setState(() => _override[a.id] = v);
                        // Persist in the background; revert on failure.
                        ref
                            .read(supportServiceProvider)
                            .setInbox(a.id, v)
                            .catchError((_) {
                          if (mounted) setState(() => _override[a.id] = !v);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pal.tabSelectedBg,
                borderRadius: MlShape.radiusMedium,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: pal.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Both admins can be assigned. Whoever accepts a ticket '
                      'becomes its handler and it moves to In progress.',
                      style: context.mlText.bodySmall.copyWith(
                        color: pal.bodySubtle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _NewTicketForm extends ConsumerStatefulWidget {
  final ChatPalette pal;
  final VoidCallback onBack;
  final ValueChanged<String> onCreated;
  const _NewTicketForm(
      {required this.pal, required this.onBack, required this.onCreated});

  @override
  ConsumerState<_NewTicketForm> createState() => _NewTicketFormState();
}

class _NewTicketFormState extends ConsumerState<_NewTicketForm> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  String _category = kSupportCategories.first;
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_subject.text.trim().isEmpty || _body.text.trim().isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final id = await ref.read(supportServiceProvider).createTicket(
          _subject.text.trim(), _category, _body.text.trim());
      if (mounted) widget.onCreated(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not send ticket. ${friendlyError(e)}')));
        setState(() => _sending = false);
      }
    }
  }

  InputDecoration _dec(ChatPalette pal, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: pal.bodySubtle),
        isDense: true,
        filled: true,
        fillColor: pal.body,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MlTokens.rMd),
          borderSide: BorderSide(color: pal.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MlTokens.rMd),
          borderSide: BorderSide(color: pal.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MlTokens.rMd),
          borderSide: BorderSide(color: pal.accent),
        ),
      );

  Widget _fieldLabel(ChatPalette pal, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: context.mlText.titleSmall.copyWith(color: pal.bodyText)),
      );

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    return Column(
      children: [
        _SupportHeader(
            pal: pal,
            title: 'New support ticket',
            icon: Icons.confirmation_number_outlined,
            onBack: widget.onBack),
        Container(height: 1, color: pal.divider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _fieldLabel(pal, 'Subject'),
              TextField(
                controller: _subject,
                style: context.mlText.bodyMedium.copyWith(color: pal.bodyText),
                cursorColor: pal.accent,
                decoration:
                    _dec(pal, 'Short summary of your question or issue'),
              ),
              const SizedBox(height: 14),
              _fieldLabel(pal, 'Category'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: pal.body,
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                  border: Border.all(color: pal.divider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _category,
                    isExpanded: true,
                    dropdownColor: pal.body,
                    style: context.mlText.bodyMedium.copyWith(
                      color: pal.bodyText,
                    ),
                    icon: Icon(Icons.expand_more_rounded, color: pal.bodySubtle),
                    items: kSupportCategories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _category = v ?? _category),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _fieldLabel(pal, 'Describe it'),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 8,
                style: context.mlText.bodyMedium.copyWith(color: pal.bodyText),
                cursorColor: pal.accent,
                decoration: _dec(pal,
                    'What happened, what you expected, and any steps to reproduce.'),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: pal.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Your ticket goes to the Mine-Link support team. You'll "
                      'get a notification here at every stage.',
                      style: context.mlText.bodySmall.copyWith(
                        color: pal.bodySubtle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: Material(
                  color: pal.accent,
                  borderRadius: MlShape.radiusMedium,
                  child: InkWell(
                    onTap: _sending ? null : _send,
                    borderRadius: MlShape.radiusMedium,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_sending)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: pal.accentText),
                          )
                        else
                          Icon(Icons.send_rounded,
                              size: 18, color: pal.accentText),
                        const SizedBox(width: 8),
                        Text(_sending ? 'Sending…' : 'Send ticket',
                            style: context.mlText.titleSmall.copyWith(
                              color: pal.accentText,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TicketView extends ConsumerStatefulWidget {
  final ChatPalette pal;
  final String ticketId;
  final bool isAdmin;
  final VoidCallback onBack;
  const _TicketView({
    required this.pal,
    required this.ticketId,
    required this.isAdmin,
    required this.onBack,
  });

  @override
  ConsumerState<_TicketView> createState() => _TicketViewState();
}

class _TicketViewState extends ConsumerState<_TicketView> {
  final _reply = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  bool _uploading = false;

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<String> _myName() async {
    final id = await ref.read(myChatIdentityProvider.future);
    return id.name;
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supportServiceProvider)
          .acceptTicket(widget.ticketId, await _myName());
      ref.invalidateIfMounted(allTicketsProvider);
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supportServiceProvider)
          .completeTicket(widget.ticketId, await _myName());
      ref.invalidateIfMounted(allTicketsProvider);
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(supportServiceProvider)
          .addMessage(widget.ticketId, text, await _myName());
      _reply.clear();
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Picks an image from the gallery, uploads it to the support-attachments
  /// bucket and sends it as a ticket message (with any typed text as caption).
  /// Mirrors the main chat's attach-and-send flow.
  Future<void> _attachImage() async {
    if (_busy || _uploading) return;
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() => _uploading = true);
      final svc = ref.read(supportServiceProvider);
      final up = await svc.uploadTicketAttachment(
          bytes: bytes, fileName: picked.name, ticketId: widget.ticketId);
      await svc.addMessage(
        widget.ticketId,
        _reply.text.trim(),
        await _myName(),
        fileUrl: up.url,
        fileType: up.type,
        fileName: up.name,
      );
      _reply.clear();
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _err(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Action failed. ${friendlyError(e)}')));
    }
  }

  String _eventLabel(SupportEvent e) {
    switch (e.type) {
      case 'accepted':
        return 'Accepted by ${e.actorName ?? 'admin'}';
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed by ${e.actorName ?? 'admin'}';
      default:
        return (e.actorName != null && e.actorName!.isNotEmpty)
            ? 'Ticket sent by ${e.actorName}'
            : 'Ticket sent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final ticketAsync = ref.watch(ticketStreamProvider(widget.ticketId));
    final ticket = ticketAsync.valueOrNull;
    final events = ref.watch(ticketEventsProvider(widget.ticketId));
    final messages = ref.watch(ticketMessagesProvider(widget.ticketId));
    final myId = ref.read(supportServiceProvider).currentUserId;

    return Column(
      children: [
        _SupportHeader(
          pal: pal,
          title: ticket?.subject ?? 'Ticket',
          icon: Icons.confirmation_number_outlined,
          onBack: widget.onBack,
          trailing:
              ticket == null ? null : _StatusPill(status: ticket.status),
        ),
        Container(height: 1, color: pal.divider),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: [
              // Timeline
              events.maybeWhen(
                data: (list) => Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: pal.divider),
                    borderRadius: MlShape.radiusMedium,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROGRESS',
                          style: context.mlText.overline.copyWith(
                            color: pal.bodySubtle,
                          )),
                      const SizedBox(height: 10),
                      ...list.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: _StatusPill(status: e.type)
                                        ._dotColor(),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(_eventIcon(e.type),
                                      size: 13, color: MlTokens.inkOnFill),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(_eventLabel(e),
                                          style: context.mlText.titleSmall.copyWith(
                                            color: pal.bodyText,
                                            fontWeight: FontWeight.w700,
                                          )),
                                      Text(
                                          // Already SAST at parse — see the
                                          // note on the notification above.
                                          MlTime.calendarStamp(e.createdAt),
                                          style: context.mlText.code(
                                            color: pal.bodySubtle,
                                            size: 11,
                                            weight: FontWeight.w400,
                                          )),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              if (ticket?.status == 'in_progress' &&
                  ticket?.acceptedByName != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: pal.tabSelectedBg,
                    borderRadius: MlShape.radiusMedium,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.support_agent_rounded,
                          size: 16, color: pal.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${ticket!.acceptedByName} is handling this ticket.',
                          style: context.mlText.bodyMedium.copyWith(
                            color: pal.bodyText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Text('CONVERSATION',
                  style: context.mlText.overline.copyWith(color: pal.bodySubtle)),
              const SizedBox(height: 8),
              messages.when(
                loading: () => _loading(pal),
                error: (e, _) => _errorBox(pal, '$e'),
                data: (list) => Column(
                  children: list.map((m) {
                    final mine = m.senderId == myId;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: _Bubble(
                        pal: pal,
                        message: ChatMessage(
                          id: m.id,
                          chatRoomId: m.ticketId,
                          content: m.content,
                          senderId: m.senderId,
                          senderName: m.senderName.isEmpty
                              ? 'Support'
                              : m.senderName,
                          timestamp: m.createdAt,
                          fileUrl: m.fileUrl,
                          fileType: m.fileType,
                          fileName: m.fileName,
                        ),
                        mine: mine,
                        showName: !mine && m.senderName.isNotEmpty,
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (ticket?.status == 'completed')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: MlTokens.green600.withValues(alpha: 0.14),
                        borderRadius: MlShape.pill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: MlTokens.green600),
                          const SizedBox(width: 6),
                          Text(
                              'Ticket completed${ticket?.acceptedByName != null ? ' by ${ticket!.acceptedByName}' : ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: MlTokens.green600)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _ticketActions(pal, ticket),
      ],
    );
  }

  Widget _ticketActions(ChatPalette pal, SupportTicket? ticket) {
    if (ticket == null) return const SizedBox.shrink();
    // Admin, unassigned → Accept.
    if (widget.isAdmin && ticket.status == 'sent') {
      return Container(
        padding: const EdgeInsets.all(12),
        color: pal.header.withValues(alpha: pal.isDark ? 0.3 : 0.4),
        child: SizedBox(
          height: 46,
          child: Material(
            color: pal.accent,
            borderRadius: MlShape.radiusMedium,
            child: InkWell(
              onTap: _busy ? null : _accept,
              borderRadius: MlShape.radiusMedium,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_reg_rounded, size: 18, color: pal.accentText),
                  const SizedBox(width: 8),
                  Text('Accept ticket',
                      style: context.mlText.titleSmall.copyWith(
                        color: pal.accentText,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // In progress → reply composer (+ Complete for admins).
    if (ticket.status == 'in_progress') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: pal.divider),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            color: pal.header.withValues(alpha: pal.isDark ? 0.3 : 0.4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_uploading)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: pal.accent),
                    ),
                  )
                else
                  _CircleBtn(
                    icon: Icons.attach_file_rounded,
                    tip: 'Attach an image',
                    color: pal.bodySubtle,
                    onTap: _attachImage,
                  ),
                const SizedBox(width: 2),
                Expanded(
                  child: TextField(
                    controller: _reply,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    cursorColor: pal.accent,
                    style: context.mlText.bodyMedium.copyWith(
                      color: pal.bodyText,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.isAdmin
                          ? 'Ask the user a question…'
                          : 'Reply to the support team…',
                      hintStyle: TextStyle(color: pal.bodySubtle),
                      isDense: true,
                      filled: true,
                      fillColor: pal.body,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MlTokens.rMd),
                        borderSide: BorderSide(color: pal.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MlTokens.rMd),
                        borderSide: BorderSide(color: pal.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(MlTokens.rMd),
                        borderSide: BorderSide(color: pal.accent),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: pal.accent,
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                  child: InkWell(
                    onTap: _busy ? null : _send,
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                    child: Padding(
                      padding: const EdgeInsets.all(11),
                      child: Icon(Icons.send_rounded,
                          size: 19, color: pal.accentText),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              color: pal.header.withValues(alpha: pal.isDark ? 0.3 : 0.4),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _complete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MlTokens.green600,
                  side: const BorderSide(color: MlTokens.green600),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 17),
                label: const Text('Mark as completed'),
              ),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

IconData _eventIcon(String type) {
  switch (type) {
    case 'accepted':
      return Icons.how_to_reg_rounded;
    case 'in_progress':
      return Icons.autorenew_rounded;
    case 'completed':
      return Icons.check_circle_rounded;
    default:
      return Icons.mark_email_read_rounded;
  }
}

extension _StatusPillDot on _StatusPill {
  Color _dotColor() {
    switch (status) {
      case 'in_progress':
        return MlChatTone.inProgress;
      case 'completed':
        return MlTokens.green600;
      default:
        return MlTokens.blue600;
    }
  }
}
